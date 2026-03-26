//
//  ViewController.m
//  VoiceAgent
//

#import "ViewController.h"
#import "TranscriptCell.h"
#import "KeyCenter.h"
#import "AgentManager.h"
#import "ConfigBackgroundView.h"
#import "ChatBackgroundView.h"
#import <Masonry/Masonry.h>
#import <AgoraRtcKit/AgoraRtcKit.h>
#import <AgoraRtmKit/AgoraRtmKit.h>
#import "VoiceAgent-Swift.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, AgoraRtcEngineDelegate, AgoraRtmClientDelegate, ConversationalAIAPIEventHandler>

@property (nonatomic, strong) ConfigBackgroundView *configBackgroundView;
@property (nonatomic, strong) ChatBackgroundView *chatBackgroundView;
@property (nonatomic, strong) UITextView *debugInfoTextView;

@property (nonatomic, assign) NSInteger uid;
@property (nonatomic, assign) NSInteger agentUid;
@property (nonatomic, copy) NSString *channel;
@property (nonatomic, strong) NSMutableArray<Transcript *> *transcripts;
@property (nonatomic, assign) BOOL isMicMuted;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isError;
@property (nonatomic, strong) NSError *initializationError;
@property (nonatomic, assign) NSInteger currentAgentState;
@property (nonatomic, assign) BOOL rtcJoined;
@property (nonatomic, assign) BOOL rtmLoggedIn;

@property (nonatomic, copy) NSString *userToken;
@property (nonatomic, copy) NSString *agentToken;
@property (nonatomic, copy) NSString *authToken;
@property (nonatomic, copy) NSString *agentId;

@property (nonatomic, strong) AgoraRtcEngineKit *rtcEngine;
@property (nonatomic, strong) AgoraRtmClientKit *rtmEngine;
@property (nonatomic, strong) ConversationalAIAPIImpl *convoAIAPI;
@property (nonatomic, strong) UIView *loadingToast;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.uid = [self randomUid];
    self.agentUid = [self randomUid];
    while (self.agentUid == self.uid) {
        self.agentUid = [self randomUid];
    }
    self.transcripts = [NSMutableArray array];
    self.currentAgentState = 5;

    [self setupUI];
    [self setupConstraints];
    [self initializeEngines];
}

#pragma mark - Setup

- (NSInteger)randomUid {
    return arc4random_uniform(900000) + 100000;
}

- (NSString *)randomChannelName {
    return [NSString stringWithFormat:@"channel_oc_%ld", (long)[self randomUid]];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.debugInfoTextView = [[UITextView alloc] init];
    self.debugInfoTextView.editable = NO;
    self.debugInfoTextView.selectable = YES;
    self.debugInfoTextView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.debugInfoTextView.textColor = [UIColor secondaryLabelColor];
    self.debugInfoTextView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.debugInfoTextView.layer.cornerRadius = 12;
    self.debugInfoTextView.layer.borderWidth = 0.5;
    self.debugInfoTextView.layer.borderColor = [UIColor separatorColor].CGColor;
    self.debugInfoTextView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    self.debugInfoTextView.text = @"Waiting for connection...\n";
    [self.view addSubview:self.debugInfoTextView];

    self.configBackgroundView = [[ConfigBackgroundView alloc] init];
    [self.configBackgroundView.startButton addTarget:self action:@selector(startButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.configBackgroundView];

    self.chatBackgroundView = [[ChatBackgroundView alloc] init];
    self.chatBackgroundView.hidden = YES;
    self.chatBackgroundView.tableView.delegate = self;
    self.chatBackgroundView.tableView.dataSource = self;
    [self.chatBackgroundView.micButton addTarget:self action:@selector(toggleMicrophone) forControlEvents:UIControlEventTouchUpInside];
    [self.chatBackgroundView.endCallButton addTarget:self action:@selector(endCall) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.chatBackgroundView];
}

- (void)setupConstraints {
    [self.debugInfoTextView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(20);
        make.left.right.equalTo(self.view).inset(20);
        make.height.mas_equalTo(120);
    }];

    [self.configBackgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.debugInfoTextView.mas_bottom).offset(20);
        make.left.right.bottom.equalTo(self.view);
    }];

    [self.chatBackgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.debugInfoTextView.mas_bottom).offset(20);
        make.left.right.bottom.equalTo(self.view);
    }];
}

#pragma mark - Logs

- (void)addDebugMessage:(NSString *)message {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterMediumStyle;
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.debugInfoTextView.text = [self.debugInfoTextView.text stringByAppendingString:line];
        if (self.debugInfoTextView.text.length > 0) {
            NSRange bottom = NSMakeRange(self.debugInfoTextView.text.length - 1, 1);
            [self.debugInfoTextView scrollRangeToVisible:bottom];
        }
    });
}

- (void)clearDebugMessages {
    self.debugInfoTextView.text = @"Waiting for connection...\n";
}

#pragma mark - Engine Initialization

- (void)initializeEngines {
    [self initializeRTM];
    [self initializeRTC];
    [self initializeConvoAIAPI];
}

- (void)initializeRTM {
    AgoraRtmClientConfig *config = [[AgoraRtmClientConfig alloc] initWithAppId:[KeyCenter AG_APP_ID]
                                                                        userId:[NSString stringWithFormat:@"%ld", (long)self.uid]];
    config.areaCode = AgoraRtmAreaCodeCN | AgoraRtmAreaCodeNA;
    config.presenceTimeout = 30;
    config.heartbeatInterval = 10;
    config.useStringUserId = YES;

    NSError *error = nil;
    self.rtmEngine = [[AgoraRtmClientKit alloc] initWithConfig:config delegate:self error:&error];
    if (error) {
        [self addDebugMessage:[NSString stringWithFormat:@"RTM Client 初始化失败: %@", error.localizedDescription]];
    } else {
        [self addDebugMessage:@"RTM Client 初始化成功"];
    }
}

- (void)initializeRTC {
    AgoraRtcEngineConfig *config = [[AgoraRtcEngineConfig alloc] init];
    config.appId = [KeyCenter AG_APP_ID];
    config.channelProfile = AgoraChannelProfileLiveBroadcasting;
    config.audioScenario = AgoraAudioScenarioAiClient;
    self.rtcEngine = [AgoraRtcEngineKit sharedEngineWithConfig:config delegate:self];
    [self.rtcEngine enableVideo];
    [self.rtcEngine enableAudioVolumeIndication:100 smooth:3 reportVad:NO];
    [self.rtcEngine setParameters:@"{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}"];
    [self addDebugMessage:@"RTC Engine 初始化成功"];
}

- (void)initializeConvoAIAPI {
    if (!self.rtcEngine || !self.rtmEngine) { return; }
    ConversationalAIAPIConfig *config = [[ConversationalAIAPIConfig alloc] initWithRtcEngine:self.rtcEngine
                                                                                    rtmEngine:self.rtmEngine
                                                                                   renderMode:TranscriptRenderModeWords
                                                                                    enableLog:YES];
    self.convoAIAPI = [[ConversationalAIAPIImpl alloc] initWithConfig:config];
    [self.convoAIAPI addHandlerWithHandler:self];
}

#pragma mark - Connection Flow

- (void)startConnection {
    self.channel = [self randomChannelName];
    self.isLoading = YES;
    self.rtcJoined = NO;
    self.rtmLoggedIn = NO;
    [self showLoadingToast];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success =
        [self generateUserToken:&error] &&
        [self loginRTM:&error] &&
        [self joinRTCChannel:&error] &&
        [self subscribeConvoAIMessage:&error] &&
        [self generateAgentToken:&error] &&
        [self generateAuthToken:&error] &&
        [self startAgent:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            [self hideLoadingToast];
            if (success) {
                [self switchToChatView];
            } else {
                self.initializationError = error;
                self.isError = YES;
                [self showErrorToast:error.localizedDescription ?: @"Unknown error"];
            }
        });
    });
}

- (BOOL)generateUserToken:(NSError **)error {
    [self addDebugMessage:@"获取 Token 调用中..."];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *localError = nil;
    [AgentManager generateTokenWithChannelName:@""
                                           uid:[NSString stringWithFormat:@"%ld", (long)self.uid]
                                        types:@[@1, @2]
                                      success:^(NSString * _Nullable token) {
        if (token.length > 0) {
            self.userToken = token;
            [self addDebugMessage:@"获取 Token 调用成功"];
            success = YES;
        } else {
            [self addDebugMessage:@"获取 Token 调用失败"];
            localError = [NSError errorWithDomain:@"generateUserToken" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"获取 token 失败，请重试"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!success && error) *error = localError;
    return success;
}

- (BOOL)generateAgentToken:(NSError **)error {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *localError = nil;
    [AgentManager generateTokenWithChannelName:self.channel
                                           uid:[NSString stringWithFormat:@"%ld", (long)self.agentUid]
                                        types:@[@1, @2]
                                      success:^(NSString * _Nullable token) {
        if (token.length > 0) {
            self.agentToken = token;
            [self addDebugMessage:@"Agent Token 调用成功"];
            success = YES;
        } else {
            [self addDebugMessage:@"Agent Token 调用失败"];
            localError = [NSError errorWithDomain:@"generateAgentToken" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"获取 agent token 失败"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!success && error) *error = localError;
    return success;
}

- (BOOL)generateAuthToken:(NSError **)error {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *localError = nil;
    [AgentManager generateTokenWithChannelName:self.channel
                                           uid:[NSString stringWithFormat:@"%ld", (long)self.agentUid]
                                        types:@[@1, @2]
                                      success:^(NSString * _Nullable token) {
        if (token.length > 0) {
            self.authToken = token;
            [self addDebugMessage:@"Auth Token 调用成功"];
            success = YES;
        } else {
            [self addDebugMessage:@"Auth Token 调用失败"];
            localError = [NSError errorWithDomain:@"generateAuthToken" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"获取 auth token 失败"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!success && error) *error = localError;
    return success;
}

- (BOOL)loginRTM:(NSError **)error {
    if (!self.rtmEngine) {
        if (error) *error = [NSError errorWithDomain:@"loginRTM" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"RTM engine 未初始化"}];
        return NO;
    }
    [self addDebugMessage:@"RTM Login 调用中..."];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *localError = nil;
    [self.rtmEngine loginByToken:self.userToken completion:^(AgoraRtmCommonResponse * _Nullable response, AgoraRtmErrorInfo * _Nullable errorInfo) {
        if (errorInfo == nil) {
            self.rtmLoggedIn = YES;
            [self addDebugMessage:@"RTM Login 调用成功"];
            success = YES;
        } else {
            [self addDebugMessage:[NSString stringWithFormat:@"RTM Login 调用失败: %@", errorInfo.reason]];
            localError = [NSError errorWithDomain:@"loginRTM" code:errorInfo.errorCode userInfo:@{NSLocalizedDescriptionKey: errorInfo.reason ?: @"rtm 登录失败"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!success && error) *error = localError;
    return success;
}

- (BOOL)joinRTCChannel:(NSError **)error {
    if (!self.rtcEngine) {
        if (error) *error = [NSError errorWithDomain:@"joinRTCChannel" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"RTC engine 未初始化"}];
        return NO;
    }

    [self addDebugMessage:@"joinChannel 调用中..."];
    AgoraRtcChannelMediaOptions *options = [[AgoraRtcChannelMediaOptions alloc] init];
    options.clientRoleType = AgoraClientRoleBroadcaster;
    options.publishMicrophoneTrack = YES;
    options.publishCameraTrack = NO;
    options.autoSubscribeAudio = YES;
    options.autoSubscribeVideo = YES;

    NSInteger result = [self.rtcEngine joinChannelByToken:self.userToken channelId:self.channel uid:self.uid mediaOptions:options joinSuccess:nil];
    if (result != 0) {
        [self addDebugMessage:[NSString stringWithFormat:@"joinChannel 调用失败: ret=%ld", (long)result]];
        if (error) *error = [NSError errorWithDomain:@"joinRTCChannel" code:result userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"加入 RTC 频道失败，错误码: %ld", (long)result]}];
        return NO;
    }
    [self addDebugMessage:[NSString stringWithFormat:@"joinChannel 调用成功: ret=%ld", (long)result]];
    return YES;
}

- (BOOL)subscribeConvoAIMessage:(NSError **)error {
    if (!self.convoAIAPI) {
        if (error) *error = [NSError errorWithDomain:@"subscribeConvoAIMessage" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"ConvoAI API 未初始化"}];
        return NO;
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = YES;
    __block NSError *localError = nil;
    [self.convoAIAPI subscribeMessageWithChannelName:self.channel completion:^(ConversationalAIAPIError * _Nullable err) {
        if (err) {
            [self addDebugMessage:[NSString stringWithFormat:@"订阅消息失败: %@", err.message]];
            localError = [NSError errorWithDomain:@"subscribeConvoAIMessage" code:err.code userInfo:@{NSLocalizedDescriptionKey: err.message ?: @"订阅失败"}];
            success = NO;
        } else {
            [self addDebugMessage:@"订阅消息成功"];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!success && error) *error = localError;
    return success;
}

- (NSDictionary *)startAgentParameter {
    return @{
        @"name": [NSString stringWithFormat:@"agent_%@_%ld_%ld", self.channel, (long)self.agentUid, (long)[NSDate date].timeIntervalSince1970],
        @"properties": @{
            @"channel": self.channel,
            @"agent_rtc_uid": [NSString stringWithFormat:@"%ld", (long)self.agentUid],
            @"remote_rtc_uids": @[@"*"],
            @"token": self.agentToken,
            @"enable_string_uid": @YES,
            @"idle_timeout": @120,
            @"advanced_features": @{@"enable_rtm": @YES},
            @"asr": @{
                @"vendor": @"fengming",
                @"language": @"zh-CN"
            },
            @"llm": @{
                @"url": [KeyCenter LLM_URL],
                @"api_key": [KeyCenter LLM_API_KEY],
                @"vendor": @"aliyun",
                @"system_messages": @[@{@"role": @"system", @"content": @"你是一名有帮助的 AI 助手。"}],
                @"greeting_message": @"你好！我是你的 AI 助手，有什么可以帮你？",
                @"failure_message": @"抱歉，我暂时处理不了你的请求，请稍后再试。",
                @"params": @{@"model": [KeyCenter LLM_MODEL]}
            },
            @"tts": @{
                @"vendor": @"bytedance",
                @"params": @{
                    @"token": [KeyCenter TTS_BYTEDANCE_TOKEN],
                    @"app_id": [KeyCenter TTS_BYTEDANCE_APP_ID],
                    @"cluster": @"volcano_tts",
                    @"voice_type": @"BV700_streaming",
                    @"speed_ratio": @1.0,
                    @"volume_ratio": @1.0,
                    @"pitch_ratio": @1.0
                }
            },
            @"parameters": @{
                @"data_channel": @"rtm",
                @"enable_error_message": @YES
            }
        }
    };
}

- (BOOL)startAgent:(NSError **)error {
    [self addDebugMessage:@"Agent Start 调用中..."];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *localError = nil;
    [AgentManager startAgentWithParameter:[self startAgentParameter] token:self.authToken completion:^(NSString * _Nullable agentId, NSError * _Nullable errorValue) {
        if (errorValue) {
            [self addDebugMessage:[NSString stringWithFormat:@"Agent Start 调用失败: %@", errorValue.localizedDescription]];
            localError = errorValue;
        } else if (agentId.length > 0) {
            self.agentId = agentId;
            [self addDebugMessage:[NSString stringWithFormat:@"Agent Start 调用成功 (agentId: %@)", agentId]];
            success = YES;
        } else {
            [self addDebugMessage:@"Agent Start 调用失败: 未返回 agentId"];
            localError = [NSError errorWithDomain:@"startAgent" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"请求失败"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!success && error) *error = localError;
    return success;
}

#pragma mark - View State

- (void)switchToChatView {
    self.configBackgroundView.hidden = YES;
    self.chatBackgroundView.hidden = NO;
}

- (void)switchToConfigView {
    self.chatBackgroundView.hidden = YES;
    self.configBackgroundView.hidden = NO;
}

- (void)resetConnectionState {
    [self.rtcEngine leaveChannel:nil];
    [self.rtmEngine logout];
    [self.convoAIAPI unsubscribeMessageWithChannelName:self.channel completion:^(ConversationalAIAPIError * _Nullable error) {
        if (error) {
            [self addDebugMessage:[NSString stringWithFormat:@"unsubscribe FAIL: %@", error.message]];
        }
    }];
    [self switchToConfigView];
    [self.transcripts removeAllObjects];
    [self.chatBackgroundView.tableView reloadData];
    [self clearDebugMessages];
    self.isMicMuted = NO;
    self.currentAgentState = 5;
    [self.chatBackgroundView updateStatusView:self.currentAgentState];
    self.agentId = @"";
    self.userToken = @"";
    self.agentToken = @"";
    self.authToken = @"";
}

#pragma mark - Actions

- (void)startButtonTapped:(UIButton *)sender {
    self.channel = [self randomChannelName];
    [self startConnection];
}

- (void)toggleMicrophone {
    self.isMicMuted = !self.isMicMuted;
    [self.chatBackgroundView updateMicButtonState:self.isMicMuted];
    [self.rtcEngine adjustRecordingSignalVolume:self.isMicMuted ? 0 : 100];
}

- (void)endCall {
    if (self.agentId.length > 0 && self.authToken.length > 0) {
        [AgentManager stopAgentWithAgentId:self.agentId token:self.authToken completion:^(NSError * _Nullable error) {
            if (error) {
                [self addDebugMessage:[NSString stringWithFormat:@"stopAgent FAIL: %@", error.localizedDescription]];
            }
        }];
    }
    [self resetConnectionState];
}

#pragma mark - Toast

- (void)showLoadingToast {
    UIView *toast = [[UIView alloc] init];
    toast.backgroundColor = [[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:0.9];
    toast.layer.cornerRadius = 12;
    [self.view addSubview:toast];

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    [indicator startAnimating];
    [toast addSubview:indicator];

    [toast mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
        make.width.height.mas_equalTo(100);
    }];
    [indicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(toast);
    }];
    self.loadingToast = toast;
}

- (void)hideLoadingToast {
    [self.loadingToast removeFromSuperview];
    self.loadingToast = nil;
}

- (void)showErrorToast:(NSString *)message {
    UIView *toast = [[UIView alloc] init];
    toast.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.92];
    toast.layer.cornerRadius = 12;
    [self.view addSubview:toast];

    UILabel *label = [[UILabel alloc] init];
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    [toast addSubview:label];

    [toast mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
        make.width.lessThanOrEqualTo(@300);
    }];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(toast).inset(16);
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast removeFromSuperview];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.transcripts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TranscriptCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TranscriptCell" forIndexPath:indexPath];
    [cell configureWithTranscript:self.transcripts[indexPath.row]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

#pragma mark - AgoraRtcEngineDelegate

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    self.rtcJoined = YES;
    [self addDebugMessage:@"onJoinChannelSuccess"];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    [self addDebugMessage:[NSString stringWithFormat:@"onUserJoined: %lu", (unsigned long)uid]];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason {
    [self addDebugMessage:[NSString stringWithFormat:@"onUserOffline: %lu", (unsigned long)uid]];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOccurError:(AgoraErrorCode)errorCode {
    [self addDebugMessage:[NSString stringWithFormat:@"onError: %ld", (long)errorCode]];
}

#pragma mark - AgoraRtmClientDelegate

- (void)rtmKit:(AgoraRtmClientKit *)rtmKit didReceiveLinkStateEvent:(AgoraRtmLinkStateEvent *)event {
    [self addDebugMessage:[NSString stringWithFormat:@"RTM link state: %ld", (long)event.currentState]];
}

#pragma mark - ConversationalAIAPIEventHandler

- (void)onAgentVoiceprintStateChangedWithAgentUserId:(NSString *)agentUserId event:(VoiceprintStateChangeEvent *)event {
    [self addDebugMessage:[NSString stringWithFormat:@"onAgentVoiceprintStateChanged: %@", event]];
}

- (void)onMessageErrorWithAgentUserId:(NSString *)agentUserId error:(MessageError *)error {
    [self addDebugMessage:[NSString stringWithFormat:@"onMessageError: %@", error]];
}

- (void)onMessageReceiptUpdatedWithAgentUserId:(NSString *)agentUserId messageReceipt:(MessageReceipt *)messageReceipt {
    [self addDebugMessage:[NSString stringWithFormat:@"onMessageReceiptUpdated: %@", messageReceipt]];
}

- (void)onAgentStateChangedWithAgentUserId:(NSString *)agentUserId event:(StateChangeEvent *)event {
    self.currentAgentState = event.state;
    [self.chatBackgroundView updateStatusView:self.currentAgentState];
}

- (void)onAgentInterruptedWithAgentUserId:(NSString *)agentUserId event:(InterruptEvent *)event {
    [self addDebugMessage:[NSString stringWithFormat:@"onAgentInterrupted: %@", event]];
}

- (void)onAgentMetricsWithAgentUserId:(NSString *)agentUserId metrics:(Metric *)metrics {
    [self addDebugMessage:[NSString stringWithFormat:@"onAgentMetrics: %@", metrics]];
}

- (void)onAgentErrorWithAgentUserId:(NSString *)agentUserId error:(ModuleError *)error {
    [self addDebugMessage:[NSString stringWithFormat:@"onAgentError: %@", error]];
}

- (void)onTranscriptUpdatedWithAgentUserId:(NSString *)agentUserId transcript:(Transcript *)transcript {
    NSUInteger existingIndex = [self.transcripts indexOfObjectPassingTest:^BOOL(Transcript * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.turnId == transcript.turnId && obj.type == transcript.type && [obj.userId isEqualToString:transcript.userId];
    }];
    if (existingIndex != NSNotFound) {
        [self.transcripts replaceObjectAtIndex:existingIndex withObject:transcript];
    } else {
        [self.transcripts addObject:transcript];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.chatBackgroundView.tableView reloadData];
        if (self.transcripts.count > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.transcripts.count - 1 inSection:0];
            [self.chatBackgroundView.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    });
}

- (void)onDebugLogWithLog:(NSString *)log {
    [self addDebugMessage:log];
}

@end

//
//  ChatSessionView.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ChatSessionView.h"
#import "TranscriptMessageCell.h"
#import <Masonry/Masonry.h>

static inline UIColor *VAHexColor(NSUInteger hexValue, CGFloat alpha) {
    return [UIColor colorWithRed:((hexValue >> 16) & 0xFF) / 255.0
                           green:((hexValue >> 8) & 0xFF) / 255.0
                            blue:(hexValue & 0xFF) / 255.0
                           alpha:alpha];
}

@interface ChatSessionView ()

@property (nonatomic, strong, readwrite) UITableView *tableView;
@property (nonatomic, strong, readwrite) AgentStateView *statusView;
@property (nonatomic, strong) UIView *controlBarView;
@property (nonatomic, strong, readwrite) UIButton *micButton;
@property (nonatomic, strong, readwrite) UIButton *endCallButton;

@end

@implementation ChatSessionView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self setupConstraints];
    }
    return self;
}

- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    
    // TableView for transcripts
    self.tableView = [[UITableView alloc] init];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = VAHexColor(0x1E293B, 0.5);
    self.tableView.layer.cornerRadius = 12;
    self.tableView.layer.borderWidth = 0.5;
    self.tableView.layer.borderColor = VAHexColor(0x334155, 0.5).CGColor;
    self.tableView.clipsToBounds = YES;
    [self.tableView registerClass:[TranscriptMessageCell class] forCellReuseIdentifier:@"TranscriptMessageCell"];
    [self addSubview:self.tableView];
    
    // Status View
    self.statusView = [[AgentStateView alloc] init];
    [self addSubview:self.statusView];
    
    // Control Bar
    self.controlBarView = [[UIView alloc] init];
    self.controlBarView.backgroundColor = VAHexColor(0x1E293B, 0.8);
    self.controlBarView.layer.cornerRadius = 12;
    self.controlBarView.layer.borderWidth = 0.5;
    self.controlBarView.layer.borderColor = VAHexColor(0x334155, 0.5).CGColor;
    [self addSubview:self.controlBarView];
    
    // Mic Button
    self.micButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.micButton setImage:[UIImage systemImageNamed:@"mic.fill"] forState:UIControlStateNormal];
    self.micButton.tintColor = VAHexColor(0xCBD5E1, 1.0);
    self.micButton.backgroundColor = VAHexColor(0x334155, 1.0);
    self.micButton.layer.cornerRadius = 22;
    [self.controlBarView addSubview:self.micButton];
    
    // End Call Button
    self.endCallButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.endCallButton setTitle:@"Stop Agent" forState:UIControlStateNormal];
    [self.endCallButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.endCallButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.endCallButton.backgroundColor = VAHexColor(0xDC2626, 1.0);
    self.endCallButton.layer.cornerRadius = 8;
    [self.controlBarView addSubview:self.endCallButton];
}

- (void)setupConstraints {
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self);
        make.left.right.equalTo(self).inset(20);
        make.bottom.equalTo(self.statusView.mas_top).offset(-8);
    }];
    
    [self.statusView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self).inset(20);
        make.bottom.equalTo(self.controlBarView.mas_top).offset(-8);
        make.height.mas_equalTo(40);
    }];
    
    [self.controlBarView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self).inset(20);
        make.bottom.equalTo(self.mas_safeAreaLayoutGuideBottom).offset(-20);
        make.height.mas_equalTo(60);
    }];
    
    [self.endCallButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.controlBarView);
        make.right.equalTo(self.controlBarView).offset(-12);
        make.height.mas_equalTo(36);
        make.width.mas_equalTo(120);
    }];

    [self.micButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.controlBarView);
        make.right.equalTo(self.endCallButton.mas_left).offset(-12);
        make.width.height.mas_equalTo(44);
    }];
}

- (void)updateMicButtonState:(BOOL)isMuted {
    NSString *imageName = isMuted ? @"mic.slash.fill" : @"mic.fill";
    [self.micButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    self.micButton.tintColor = isMuted ? VAHexColor(0xF87171, 1.0) : VAHexColor(0xCBD5E1, 1.0);
    self.micButton.backgroundColor = isMuted ? VAHexColor(0xEF4444, 0.2) : VAHexColor(0x334155, 1.0);
}

- (void)updateStatusView:(NSInteger)state {
    [self.statusView updateState:state];
}

- (void)reloadData {
    [self.tableView reloadData];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    NSInteger rowCount = [self.dataSource numberOfTranscriptsInChatSessionView:self];
    if (rowCount > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowCount - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

// MARK: - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataSource numberOfTranscriptsInChatSessionView:self];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TranscriptMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TranscriptMessageCell" forIndexPath:indexPath];
    Transcript *transcript = [self.dataSource chatSessionView:self transcriptAtIndex:indexPath.row];
    [cell configureWithTranscript:transcript];
    return cell;
}

// MARK: - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

@end

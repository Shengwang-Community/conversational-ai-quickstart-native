//
//  ChatBackgroundView.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ChatBackgroundView.h"
#import "TranscriptCell.h"
#import <Masonry/Masonry.h>

@interface ChatBackgroundView ()

@property (nonatomic, strong, readwrite) UITableView *tableView;
@property (nonatomic, strong, readwrite) AgentStateView *statusView;
@property (nonatomic, strong) UIView *controlBarView;
@property (nonatomic, strong, readwrite) UIButton *micButton;
@property (nonatomic, strong, readwrite) UIButton *endCallButton;

@end

@implementation ChatBackgroundView

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
    self.tableView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.tableView.layer.cornerRadius = 12;
    self.tableView.layer.borderWidth = 0.5;
    self.tableView.layer.borderColor = [UIColor separatorColor].CGColor;
    self.tableView.clipsToBounds = YES;
    [self.tableView registerClass:[TranscriptCell class] forCellReuseIdentifier:@"TranscriptCell"];
    [self addSubview:self.tableView];
    
    // Status View
    self.statusView = [[AgentStateView alloc] init];
    [self addSubview:self.statusView];
    
    // Control Bar
    self.controlBarView = [[UIView alloc] init];
    self.controlBarView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.controlBarView.layer.cornerRadius = 12;
    self.controlBarView.layer.borderWidth = 0.5;
    self.controlBarView.layer.borderColor = [UIColor separatorColor].CGColor;
    [self addSubview:self.controlBarView];
    
    // Mic Button
    self.micButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.micButton setImage:[UIImage systemImageNamed:@"mic.fill"] forState:UIControlStateNormal];
    self.micButton.tintColor = [UIColor whiteColor];
    self.micButton.backgroundColor = [UIColor systemBlueColor];
    self.micButton.layer.cornerRadius = 22;
    [self.controlBarView addSubview:self.micButton];
    
    // End Call Button
    self.endCallButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.endCallButton setTitle:@"Stop Agent" forState:UIControlStateNormal];
    self.endCallButton.tintColor = [UIColor whiteColor];
    self.endCallButton.backgroundColor = [UIColor redColor];
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
}

- (void)updateStatusView:(NSInteger)state {
    [self.statusView updateState:state];
}

- (void)reloadData {
    [self.tableView reloadData];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    NSInteger rowCount = [self.dataSource numberOfTranscriptsInChatBackgroundView:self];
    if (rowCount > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowCount - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

// MARK: - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataSource numberOfTranscriptsInChatBackgroundView:self];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TranscriptCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TranscriptCell" forIndexPath:indexPath];
    Transcript *transcript = [self.dataSource chatBackgroundView:self transcriptAtIndex:indexPath.row];
    [cell configureWithTranscript:transcript];
    return cell;
}

// MARK: - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

@end

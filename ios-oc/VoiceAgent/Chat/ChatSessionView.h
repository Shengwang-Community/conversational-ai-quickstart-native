//
//  ChatSessionView.h
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import <UIKit/UIKit.h>
#import "AgentStateView.h"
#import "VoiceAgent-Swift.h"

NS_ASSUME_NONNULL_BEGIN

@class ChatSessionView;

@protocol ChatSessionViewDataSource <NSObject>

- (NSInteger)numberOfTranscriptsInChatSessionView:(ChatSessionView *)view;
- (Transcript *_Nullable)chatSessionView:(ChatSessionView *)view transcriptAtIndex:(NSInteger)index;

@end

@interface ChatSessionView : UIView <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, weak) id<ChatSessionViewDataSource> dataSource;
@property(nonatomic, strong, readonly) UITableView *tableView;
@property(nonatomic, strong, readonly) AgentStateView *statusView;
@property(nonatomic, strong, readonly) UIButton *micButton;
@property(nonatomic, strong, readonly) UIButton *endCallButton;

- (void)updateMicButtonState:(BOOL)isMuted;
- (void)updateStatusView:(NSInteger)state; // AgentState enum value
- (void)reloadData;
- (void)scrollToBottomAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

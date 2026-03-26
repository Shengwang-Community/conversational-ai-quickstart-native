//
//  ConfigBackgroundView.h
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConfigBackgroundView : UIView

@property(nonatomic, strong, readonly) UITextField *channelNameTextField;
@property(nonatomic, strong, readonly) UIButton *startButton;

- (void)updateButtonState:(BOOL)isEnabled;

@end

NS_ASSUME_NONNULL_END

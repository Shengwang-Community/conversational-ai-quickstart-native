//
//  ConfigBackgroundView.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ConfigBackgroundView.h"
#import <Masonry/Masonry.h>

@interface ConfigBackgroundView ()

@property (nonatomic, strong, readwrite) UITextField *channelNameTextField;
@property (nonatomic, strong, readwrite) UIButton *startButton;

@end

@implementation ConfigBackgroundView

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
    
    // Hidden input kept only to minimize xcodeproj churn
    self.channelNameTextField = [[UITextField alloc] init];
    self.channelNameTextField.hidden = YES;
    self.channelNameTextField.borderStyle = UITextBorderStyleRoundedRect;
    [self addSubview:self.channelNameTextField];
    
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"Start Agent" forState:UIControlStateNormal];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.startButton setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] 
                            forState:UIControlStateDisabled];
    self.startButton.backgroundColor = [UIColor systemBlueColor];
    self.startButton.layer.cornerRadius = 8;
    self.startButton.enabled = YES;
    [self addSubview:self.startButton];
}

- (void)setupConstraints {
    [self.channelNameTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.equalTo(self);
        make.width.height.mas_equalTo(0);
    }];
    
    [self.startButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self).inset(20);
        make.bottom.equalTo(self.mas_safeAreaLayoutGuideBottom).offset(-20);
        make.height.mas_equalTo(48);
    }];
}

- (void)updateButtonState:(BOOL)isEnabled {
    self.startButton.enabled = isEnabled;
    self.startButton.backgroundColor = isEnabled ? 
        [UIColor systemBlueColor] : 
        [[UIColor systemGrayColor] colorWithAlphaComponent:0.6];
}

@end

//
//  ConnectionStartView.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ConnectionStartView.h"
#import <Masonry/Masonry.h>

static inline UIColor *VAHexColor(NSUInteger hexValue, CGFloat alpha) {
    return [UIColor colorWithRed:((hexValue >> 16) & 0xFF) / 255.0
                           green:((hexValue >> 8) & 0xFF) / 255.0
                            blue:(hexValue & 0xFF) / 255.0
                           alpha:alpha];
}

@interface ConnectionStartView ()

@property (nonatomic, strong, readwrite) UIButton *startButton;

@end

@implementation ConnectionStartView

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
    
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"Start Agent" forState:UIControlStateNormal];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.startButton setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] 
                            forState:UIControlStateDisabled];
    self.startButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.startButton.backgroundColor = VAHexColor(0x2563EB, 1.0);
    self.startButton.layer.cornerRadius = 8;
    self.startButton.enabled = YES;
    [self addSubview:self.startButton];
}

- (void)setupConstraints {
    [self.startButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self).inset(20);
        make.bottom.equalTo(self.mas_safeAreaLayoutGuideBottom).offset(-20);
        make.height.mas_equalTo(48);
    }];
}

- (void)updateButtonState:(BOOL)isEnabled {
    self.startButton.enabled = isEnabled;
    self.startButton.backgroundColor = isEnabled ? 
        VAHexColor(0x2563EB, 1.0) : 
        VAHexColor(0x334155, 1.0);
}

@end

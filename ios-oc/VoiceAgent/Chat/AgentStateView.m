//
//  AgentStateView.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "AgentStateView.h"
#import <Masonry/Masonry.h>

static inline UIColor *VAHexColor(NSUInteger hexValue, CGFloat alpha) {
    return [UIColor colorWithRed:((hexValue >> 16) & 0xFF) / 255.0
                           green:((hexValue >> 8) & 0xFF) / 255.0
                            blue:(hexValue & 0xFF) / 255.0
                           alpha:alpha];
}

@interface AgentStateView ()

@property (nonatomic, strong) UILabel *statusLabel;

@end

@implementation AgentStateView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self setupConstraints];
        self.hidden = YES;
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = VAHexColor(0x1E293B, 0.8);
    self.layer.cornerRadius = 12;
    self.layer.borderWidth = 0.5;
    self.layer.borderColor = VAHexColor(0x334155, 0.5).CGColor;
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textColor = VAHexColor(0xCBD5E1, 1.0);
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.statusLabel];
}

- (void)setupConstraints {
    [self.statusLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self).inset(8);
    }];
}

- (void)updateState:(NSInteger)state {
    if (state == 5) { // unknown
        self.hidden = YES;
        return;
    }
    
    self.hidden = NO;
    NSString *statusText;
    switch (state) {
        case 0: // idle
            statusText = @"Idle";
            self.backgroundColor = VAHexColor(0x64748B, 0.25);
            break;
        case 1: // silent
            statusText = @"Silent";
            self.backgroundColor = VAHexColor(0x475569, 0.25);
            break;
        case 2: // listening
            statusText = @"Listening";
            self.backgroundColor = VAHexColor(0x10B981, 0.2);
            break;
        case 3: // thinking
            statusText = @"Thinking";
            self.backgroundColor = VAHexColor(0xF59E0B, 0.2);
            break;
        case 4: // speaking
            statusText = @"Speaking";
            self.backgroundColor = VAHexColor(0x3B82F6, 0.2);
            break;
        default:
            statusText = @"";
            self.backgroundColor = VAHexColor(0x1E293B, 0.8);
            break;
    }
    self.statusLabel.text = statusText;
}

@end

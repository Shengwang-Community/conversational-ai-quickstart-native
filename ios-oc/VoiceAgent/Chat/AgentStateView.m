//
//  AgentStateView.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "AgentStateView.h"
#import <Masonry/Masonry.h>

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
    self.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.layer.cornerRadius = 12;
    self.layer.borderWidth = 0.5;
    self.layer.borderColor = [UIColor separatorColor].CGColor;
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textColor = [UIColor labelColor];
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
            statusText = @"空闲中";
            break;
        case 1: // silent
            statusText = @"静默中";
            break;
        case 2: // listening
            statusText = @"正在聆听";
            break;
        case 3: // thinking
            statusText = @"思考中";
            break;
        case 4: // speaking
            statusText = @"正在说话";
            break;
        default:
            statusText = @"";
            break;
    }
    self.statusLabel.text = statusText;
}

@end

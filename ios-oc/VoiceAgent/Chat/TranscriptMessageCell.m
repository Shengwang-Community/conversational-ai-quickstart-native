//
//  TranscriptMessageCell.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "TranscriptMessageCell.h"
#import <Masonry/Masonry.h>
#import "VoiceAgent-Swift.h"

static inline UIColor *VAHexColor(NSUInteger hexValue, CGFloat alpha) {
    return [UIColor colorWithRed:((hexValue >> 16) & 0xFF) / 255.0
                           green:((hexValue >> 8) & 0xFF) / 255.0
                            blue:(hexValue & 0xFF) / 255.0
                           alpha:alpha];
}

@interface TranscriptMessageCell ()

@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UILabel *avatarLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) MASConstraint *bubbleLeading;
@property (nonatomic, strong) MASConstraint *bubbleTrailing;
@property (nonatomic, strong) MASConstraint *avatarLeading;
@property (nonatomic, strong) MASConstraint *avatarTrailing;

@end

@implementation TranscriptMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    
    self.avatarView = [[UIView alloc] init];
    self.avatarView.layer.cornerRadius = 16;
    [self.contentView addSubview:self.avatarView];
    
    self.avatarLabel = [[UILabel alloc] init];
    self.avatarLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.avatarLabel.textColor = [UIColor whiteColor];
    self.avatarLabel.textAlignment = NSTextAlignmentCenter;
    [self.avatarView addSubview:self.avatarLabel];
    
    self.bubbleView = [[UIView alloc] init];
    self.bubbleView.layer.cornerRadius = 16;
    [self.contentView addSubview:self.bubbleView];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.font = [UIFont systemFontOfSize:14];
    self.messageLabel.numberOfLines = 0;
    [self.bubbleView addSubview:self.messageLabel];
    
    [self.avatarView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(4);
        make.width.height.mas_equalTo(32);
        self.avatarLeading = make.left.equalTo(self.contentView).offset(16);
        self.avatarTrailing = make.right.equalTo(self.contentView).offset(-16);
    }];
    [self.avatarTrailing deactivate];
    
    [self.avatarLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.avatarView);
    }];
    
    [self.bubbleView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(4);
        make.bottom.equalTo(self.contentView).offset(-4);
        make.width.lessThanOrEqualTo(self.contentView).multipliedBy(0.75);
        self.bubbleLeading = make.left.equalTo(self.avatarView.mas_right).offset(8);
        self.bubbleTrailing = make.right.equalTo(self.avatarView.mas_left).offset(-8);
    }];
    [self.bubbleTrailing deactivate];

    [self.messageLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.bubbleView).inset(12);
    }];
}

- (void)configureWithTranscript:(id)transcript {
    Transcript *t = (Transcript *)transcript;
    BOOL isAgent = t.type == TranscriptTypeAgent;
    self.avatarView.backgroundColor = isAgent ? VAHexColor(0x3B82F6, 1.0) : VAHexColor(0x10B981, 1.0);
    self.avatarLabel.text = isAgent ? @"AI" : @"Me";
    self.bubbleView.backgroundColor = isAgent ? VAHexColor(0x334155, 1.0) : VAHexColor(0x2563EB, 1.0);
    self.messageLabel.textColor = isAgent ? VAHexColor(0xF1F5F9, 1.0) : [UIColor whiteColor];
    self.messageLabel.text = t.text;

    if (isAgent) {
        [self.avatarTrailing deactivate];
        [self.bubbleTrailing deactivate];
        [self.avatarLeading activate];
        [self.bubbleLeading activate];
    } else {
        [self.avatarLeading deactivate];
        [self.bubbleLeading deactivate];
        [self.avatarTrailing activate];
        [self.bubbleTrailing activate];
    }
}

@end

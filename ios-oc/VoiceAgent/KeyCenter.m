//
//  KeyCenter.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "KeyCenter.h"

static NSString *const AG_APP_ID = @"";
static NSString *const AG_APP_CERTIFICATE = @"";
static NSString *const LLM_API_KEY = @"";
static NSString *const LLM_URL = @"https://api.deepseek.com/v1/chat/completions";
static NSString *const LLM_MODEL = @"deepseek-chat";
static NSString *const TTS_BYTEDANCE_APP_ID = @"";
static NSString *const TTS_BYTEDANCE_TOKEN = @"";

@implementation KeyCenter

+ (NSString *)AG_APP_ID {
    return AG_APP_ID;
}

+ (NSString *)AG_APP_CERTIFICATE {
    return AG_APP_CERTIFICATE;
}

+ (NSString *)LLM_API_KEY {
    return LLM_API_KEY;
}

+ (NSString *)LLM_URL {
    return LLM_URL;
}

+ (NSString *)LLM_MODEL {
    return LLM_MODEL;
}

+ (NSString *)TTS_BYTEDANCE_APP_ID {
    return TTS_BYTEDANCE_APP_ID;
}

+ (NSString *)TTS_BYTEDANCE_TOKEN {
    return TTS_BYTEDANCE_TOKEN;
}

@end

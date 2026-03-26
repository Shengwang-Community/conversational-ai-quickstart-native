//
//  KeyCenter.h
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KeyCenter : NSObject

/**
 Agora Key
 get from Agora Console
 */
+ (NSString *)AG_APP_ID;
+ (NSString *)AG_APP_CERTIFICATE;
+ (NSString *)LLM_API_KEY;
+ (NSString *)LLM_URL;
+ (NSString *)LLM_MODEL;
+ (NSString *)TTS_BYTEDANCE_APP_ID;
+ (NSString *)TTS_BYTEDANCE_TOKEN;

@end

NS_ASSUME_NONNULL_END

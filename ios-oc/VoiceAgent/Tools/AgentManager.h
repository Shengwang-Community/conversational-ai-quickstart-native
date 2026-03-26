//
//  AgentManager.h
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AgentManager : NSObject

+ (void)startAgentWithParameter:(NSDictionary<NSString *, id> *)parameter
                          token:(NSString *)token
                     completion:(void (^)(NSString *_Nullable agentId, NSError *_Nullable error))completion;

+ (void)stopAgentWithAgentId:(NSString *)agentId
                       token:(NSString *)token
                  completion:(void (^)(NSError *_Nullable error))completion;

+ (void)generateTokenWithChannelName:(NSString *)channelName
                                 uid:(NSString *)uid
                              expire:(NSInteger)expire
                               types:(NSArray<NSNumber *> *)types
                             success:(void (^)(NSString *_Nullable token))success;

// 便捷方法，使用默认 expire = 86400
+ (void)generateTokenWithChannelName:(NSString *)channelName
                                 uid:(NSString *)uid
                               types:(NSArray<NSNumber *> *)types
                             success:(void (^)(NSString *_Nullable token))success;

@end

NS_ASSUME_NONNULL_END

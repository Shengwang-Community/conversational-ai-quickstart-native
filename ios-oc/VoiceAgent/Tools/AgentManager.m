//
//  AgentManager.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "AgentManager.h"
#import "KeyCenter.h"

@implementation AgentManager

static NSString * const API_BASE_URL = @"https://api.agora.io/cn/api/conversational-ai-agent/v2/projects";

+ (void)startAgentWithParameter:(NSDictionary<NSString *, id> *)parameter 
                          token:(NSString *)token
                      completion:(void (^)(NSString * _Nullable agentId, NSError * _Nullable error))completion {
    NSString *appId = [KeyCenter AG_APP_ID];
    NSString *urlString = [NSString stringWithFormat:@"%@/%@/join", API_BASE_URL, appId];
    
    [self postRequestWithURLString:urlString 
                             params:parameter 
                             token:token
                            domain:@"startAgent" 
                         completion:^(NSDictionary * _Nullable responseDict, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        
        NSString *agentId = responseDict[@"agent_id"];
        if (agentId && [agentId isKindOfClass:[NSString class]] && agentId.length > 0) {
            if (completion) {
                completion(agentId, nil);
            }
        } else {
            if (completion) {
                NSString *errorMsg = [NSString stringWithFormat:@"Failed to parse agent_id from response: %@", responseDict];
                NSError *finalError = [NSError errorWithDomain:@"startAgent" 
                                                          code:-1 
                                                      userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                completion(nil, finalError);
            }
        }
    }];
}

+ (void)stopAgentWithAgentId:(NSString *)agentId 
                       token:(NSString *)token
                  completion:(void (^)(NSError * _Nullable error))completion {
    NSString *appId = [KeyCenter AG_APP_ID];
    NSString *urlString = [NSString stringWithFormat:@"%@/%@/agents/%@/leave", API_BASE_URL, appId, agentId];
    
    [self postRequestWithURLString:urlString 
                             params:@{} 
                             token:token
                            domain:@"stopAgent" 
                         completion:^(NSDictionary * _Nullable responseDict, NSError * _Nullable error) {
        if (completion) {
            completion(error);
        }
    }];
}

+ (void)generateTokenWithChannelName:(NSString *)channelName
                                  uid:(NSString *)uid
                               types:(NSArray<NSNumber *> *)types
                             success:(void (^)(NSString * _Nullable token))success {
    [self generateTokenWithChannelName:channelName uid:uid expire:86400 types:types success:success];
}

+ (void)generateTokenWithChannelName:(NSString *)channelName
                                  uid:(NSString *)uid
                              expire:(NSInteger)expire
                               types:(NSArray<NSNumber *> *)types
                             success:(void (^)(NSString * _Nullable token))success {
    NSDictionary *params = @{
        @"appCertificate": [KeyCenter AG_APP_CERTIFICATE],
        @"appId": [KeyCenter AG_APP_ID],
        @"channelName": channelName,
        @"expire": @(expire),
        @"src": @"iOS",
        @"ts": @0,
        @"types": types,
        @"uid": uid
    };
    
    NSString *urlString = @"https://service.apprtc.cn/toolbox/v2/token/generate";
    
    [self postRequestWithoutAuthWithURLString:urlString 
                                        params:params 
                                       domain:@"generateToken" 
                                    completion:^(NSDictionary * _Nullable responseDict, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[AgentManager] generateToken failed: %@", error.localizedDescription);
            if (success) {
                success(nil);
            }
            return;
        }
        
        NSNumber *code = responseDict[@"code"];
        if (code && [code isKindOfClass:[NSNumber class]] && code.integerValue != 0) {
            NSString *msg = responseDict[@"msg"] ?: @"Unknown error";
            NSLog(@"[AgentManager] generateToken failed: code=%@, msg=%@", code, msg);
            if (success) {
                success(nil);
            }
            return;
        }
        
        NSDictionary *data = responseDict[@"data"];
        NSString *token = nil;
        if ([data isKindOfClass:[NSDictionary class]]) {
            token = data[@"token"];
            if (![token isKindOfClass:[NSString class]]) {
                token = nil;
            }
        }
        if (success) {
            success(token);
        }
    }];
}

#pragma mark - Private Methods

+ (void)postRequestWithURLString:(NSString *)urlString 
                           params:(NSDictionary<NSString *, id> *)params 
                            token:(NSString *)token
                          domain:(NSString *)domain 
                       completion:(void (^)(NSDictionary * _Nullable responseDict, NSError * _Nullable error))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:domain 
                                                 code:-1 
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}];
            completion(nil, error);
        }
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSDictionary<NSString *, NSString *> *headers = [self generateHeaderWithToken:token];
    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    
    if (params) {
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params 
                                                           options:0 
                                                             error:&jsonError];
        if (jsonError) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:domain 
                                                     code:-1 
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"JSON serialization error: %@", jsonError.localizedDescription]}];
                completion(nil, error);
            }
            return;
        }
        request.HTTPBody = jsonData;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                  completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *finalError = [NSError errorWithDomain:domain 
                                                          code:-1 
                                                      userInfo:@{NSLocalizedDescriptionKey: error.localizedDescription}];
                completion(nil, finalError);
            }
            return;
        }
        
        if (!data) {
            if (completion) {
                NSError *finalError = [NSError errorWithDomain:domain 
                                                          code:-1 
                                                      userInfo:@{NSLocalizedDescriptionKey: @"No data received"}];
                completion(nil, finalError);
            }
            return;
        }
        
        NSError *jsonError;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data 
                                                                     options:0 
                                                                       error:&jsonError];
        if (jsonError) {
            if (completion) {
                NSError *finalError = [NSError errorWithDomain:domain 
                                                          code:-1 
                                                      userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"JSON parsing error: %@", jsonError.localizedDescription]}];
                completion(nil, finalError);
            }
            return;
        }
        
        if (completion) {
            completion(responseDict, nil);
        }
    }];
    
    [task resume];
}

+ (NSDictionary<NSString *, NSString *> *)generateHeaderWithToken:(NSString *)token {
    NSDictionary<NSString *, NSString *> *headers = @{
        @"Content-Type": @"application/json; charset=utf-8",
        @"Authorization": [NSString stringWithFormat:@"agora token=%@", token]
    };
    
    return headers;
}

+ (void)postRequestWithoutAuthWithURLString:(NSString *)urlString 
                                      params:(NSDictionary<NSString *, id> *)params 
                                     domain:(NSString *)domain 
                                  completion:(void (^)(NSDictionary * _Nullable responseDict, NSError * _Nullable error))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:domain 
                                                 code:-1 
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}];
            completion(nil, error);
        }
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    if (params) {
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params 
                                                           options:NSJSONWritingSortedKeys 
                                                             error:&jsonError];
        if (jsonError) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:domain 
                                                     code:-1 
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"JSON serialization error: %@", jsonError.localizedDescription]}];
                completion(nil, error);
            }
            return;
        }
        request.HTTPBody = jsonData;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                  completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *finalError = [NSError errorWithDomain:domain 
                                                          code:-1 
                                                      userInfo:@{NSLocalizedDescriptionKey: error.localizedDescription}];
                completion(nil, finalError);
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse && (httpResponse.statusCode < 200 || httpResponse.statusCode > 201)) {
            if (completion) {
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP error status code: %ld", (long)httpResponse.statusCode];
                NSError *finalError = [NSError errorWithDomain:domain 
                                                          code:-1 
                                                      userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                completion(nil, finalError);
            }
            return;
        }
        
        if (!data) {
            if (completion) {
                NSError *finalError = [NSError errorWithDomain:domain 
                                                          code:-1 
                                                      userInfo:@{NSLocalizedDescriptionKey: @"No data received"}];
                completion(nil, finalError);
            }
            return;
        }
        
        NSError *jsonError;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data 
                                                                     options:0 
                                                                       error:&jsonError];
        if (jsonError) {
            if (completion) {
                NSError *finalError = [NSError errorWithDomain:domain 
                                                          code:-1 
                                                      userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"JSON parsing error: %@", jsonError.localizedDescription]}];
                completion(nil, finalError);
            }
            return;
        }
        
        if (completion) {
            completion(responseDict, nil);
        }
    }];
    
    [task resume];
}

@end

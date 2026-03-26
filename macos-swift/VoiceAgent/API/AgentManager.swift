//
//  AgentManager.swift
//  VoiceAgent
//
//  Created on 2025
//  Copyright © 2025 Agora. All rights reserved.
//

import Foundation

// MARK: - Agent Starter
/// Unified interface for starting/stopping AI agents
/// Supports both local server and Agora API
class AgentManager {
    private static let apiBaseURL = "https://api.agora.io/cn/api/conversational-ai-agent/v2/projects"
    
    // MARK: - Public Methods
    
    static func startAgent(
        channelName: String,
        agentRtcUid: String,
        agentToken: String,
        authToken: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let urlString = "\(apiBaseURL)/\(KeyCenter.AGORA_APP_ID)/join/"
        let headers = [
            "Authorization": "agora token=\(authToken)"
        ]

        HTTPClient.post(
            urlString: urlString,
            params: buildPayload(
                channelName: channelName,
                agentRtcUid: agentRtcUid,
                agentToken: agentToken
            ),
            headers: headers
        ) { result in
            switch result {
            case .success(let json):
                if let agentId = json["agent_id"] as? String {
                    print("[AgentStarter] Agent started successfully, agentId: \(agentId)")
                    completion(.success(agentId))
                } else {
                    let error = NSError(
                        domain: "AgentStarter",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse agentId"]
                    )
                    completion(.failure(error))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    static func stopAgent(
        agentId: String,
        authToken: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let urlString = "\(apiBaseURL)/\(KeyCenter.AGORA_APP_ID)/agents/\(agentId)/leave"
        let headers = [
            "Authorization": "agora token=\(authToken)"
        ]

        HTTPClient.post(
            urlString: urlString,
            params: nil,
            headers: headers
        ) { result in
            switch result {
            case .success:
                print("[AgentStarter] Agent stopped successfully")
                completion(.success(()))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private static func buildPayload(
        channelName: String,
        agentRtcUid: String,
        agentToken: String
    ) -> [String: Any] {
        [
            "name": channelName,
            "properties": [
                "channel": channelName,
                "token": agentToken,
                "agent_rtc_uid": agentRtcUid,
                "remote_rtc_uids": ["*"],
                "enable_string_uid": true,
                "idle_timeout": 120,
                "advanced_features": [
                    "enable_rtm": true
                ],
                "asr": [
                    "vendor": "fengming",
                    "language": "zh-CN"
                ],
                "llm": [
                    "url": KeyCenter.LLM_URL,
                    "api_key": KeyCenter.LLM_API_KEY,
                    "vendor": "aliyun",
                    "system_messages": [
                        [
                            "role": "system",
                            "content": "你是一名有帮助的 AI 助手。"
                        ]
                    ],
                    "greeting_message": "你好！我是你的 AI 助手，有什么可以帮你？",
                    "failure_message": "抱歉，我暂时处理不了你的请求，请稍后再试。",
                    "params": [
                        "model": KeyCenter.LLM_MODEL
                    ]
                ],
                "tts": [
                    "vendor": "bytedance",
                    "params": [
                        "token": KeyCenter.TTS_BYTEDANCE_TOKEN,
                        "app_id": KeyCenter.TTS_BYTEDANCE_APP_ID,
                        "cluster": "volcano_tts",
                        "voice_type": "BV700_streaming",
                        "speed_ratio": 1.0,
                        "volume_ratio": 1.0,
                        "pitch_ratio": 1.0
                    ]
                ],
                "parameters": [
                    "data_channel": "rtm",
                    "enable_error_message": true
                ]
            ]
        ]
    }

    static func checkServerHealth(completion: @escaping (Bool) -> Void) {
        let urlString = "\(apiBaseURL)/\(KeyCenter.AGORA_APP_ID)"
        HTTPClient.get(urlString: urlString) { result in
            switch result {
            case .success:
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }
}

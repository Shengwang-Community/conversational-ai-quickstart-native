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
                    "vendor": "microsoft",
                    "language": "zh-CN",
                    "params": [
                        "key": KeyCenter.STT_MICROSOFT_KEY,
                        "region": KeyCenter.STT_MICROSOFT_REGION
                    ]
                ],
                "llm": [
                    "url": KeyCenter.LLM_URL,
                    "api_key": KeyCenter.LLM_API_KEY,
                    "system_messages": [
                        [
                            "role": "system",
                            "content": "You are a helpful AI assistant."
                        ]
                    ],
                    "greeting_message": "Hello! I am your AI assistant. How can I help you?",
                    "failure_message": "I'm sorry, I'm having trouble processing your request.",
                    "params": [
                        "model": KeyCenter.LLM_MODEL
                    ]
                ],
                "tts": [
                    "vendor": "minimax",
                    "params": [
                        "key": KeyCenter.TTS_MINIMAX_KEY,
                        "model": KeyCenter.TTS_MINIMAX_MODEL,
                        "voice_setting": [
                            "voice_id": KeyCenter.TTS_MINIMAX_VOICE_ID,
                            "speed": 1.0
                        ],
                        "group_id": KeyCenter.TTS_MINIMAX_GROUP_ID
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

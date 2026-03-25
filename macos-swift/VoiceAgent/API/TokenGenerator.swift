//
//  TokenGenerator.swift
//  VoiceAgent
//
//  Created on 2025
//  Copyright © 2025 Agora. All rights reserved.
//

import Foundation

// MARK: - Token Type
enum AgoraTokenType: Int {
    case rtc = 1
    case rtm = 2
    case chat = 3
}

// MARK: - Token Generator
/// Generate Agora RTC and RTM tokens via Toolbox Server API
class TokenGenerator {
    
    /// Generate token
    /// - Parameters:
    ///   - channelName: Channel name (use empty string for RTM-only token)
    ///   - uid: User ID
    ///   - expire: Token expiration time in seconds (default: 24 hours)
    ///   - types: Token types to generate (default: [.rtc, .rtm])
    ///   - success: Success callback with token string
    static func generateToken(
        channelName: String,
        uid: String,
        expire: Int = 86400,
        types: [AgoraTokenType] = [.rtc, .rtm],
        success: @escaping (String?) -> Void
    ) {
        let params: [String: Any] = [
            "appCertificate": KeyCenter.AGORA_APP_CERTIFICATE,
            "appId": KeyCenter.AGORA_APP_ID,
            "channelName": channelName,
            "expire": expire,
            "src": "macOS",
            "ts": Int(Date().timeIntervalSince1970 * 1000),
            "types": types.map { $0.rawValue },
            "uid": uid
        ]
        
        let url = "https://service.apprtc.cn/toolbox/v2/token/generate"
        
        // Use HTTPClient for unified request handling
        HTTPClient.post(
            urlString: url,
            params: params,
            success: { response in
                if let data = response["data"] as? [String: String],
                   let token = data["token"] {
                    print("[TokenGenerator] ✅ Token generated successfully for uid: \(uid)")
                    success(token)
                } else {
                    print("[TokenGenerator] ❌ Failed to parse token from response")
                    success(nil)
                }
            },
            failure: { error in
                print("[TokenGenerator] ❌ Token generation failed: \(error)")
                success(nil)
            }
        )
    }
}

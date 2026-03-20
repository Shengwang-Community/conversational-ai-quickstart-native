//
//  KeyCenter.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import Foundation

class KeyCenter {
    // Agora Configuration
    static let AG_APP_ID: String = ""
    static let AG_APP_CERTIFICATE: String = ""

    // LLM - DeepSeek
    static let LLM_API_KEY: String = ""
    static let LLM_URL: String = "https://api.deepseek.com/v1/chat/completions"
    static let LLM_MODEL: String = "deepseek-chat"

    // STT - Microsoft Azure
    static let STT_MICROSOFT_KEY: String = ""
    static let STT_MICROSOFT_REGION: String = "chinaeast2"

    // TTS - MiniMax
    static let TTS_MINIMAX_KEY: String = ""
    static let TTS_MINIMAX_MODEL: String = "speech-01-turbo"
    static let TTS_MINIMAX_VOICE_ID: String = "male-qn-qingse"
    static let TTS_MINIMAX_GROUP_ID: String = ""
}

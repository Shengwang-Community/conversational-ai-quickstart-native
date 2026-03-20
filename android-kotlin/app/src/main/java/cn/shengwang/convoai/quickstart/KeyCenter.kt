package cn.shengwang.convoai.quickstart

import cn.shengwang.convoai.quickstart.BuildConfig

object KeyCenter {
    // Shengwang App Credentials
    val APP_ID: String = BuildConfig.APP_ID
    val APP_CERTIFICATE: String = BuildConfig.APP_CERTIFICATE

    // LLM Configuration
    val LLM_API_KEY: String = BuildConfig.LLM_API_KEY
    val LLM_URL: String = BuildConfig.LLM_URL
    val LLM_MODEL: String = BuildConfig.LLM_MODEL

    // STT Configuration
    val STT_MICROSOFT_KEY: String = BuildConfig.STT_MICROSOFT_KEY
    val STT_MICROSOFT_REGION: String = BuildConfig.STT_MICROSOFT_REGION

    // TTS Configuration
    val TTS_MINIMAX_KEY: String = BuildConfig.TTS_MINIMAX_KEY
    val TTS_MINIMAX_MODEL: String = BuildConfig.TTS_MINIMAX_MODEL
    val TTS_MINIMAX_VOICE_ID: String = BuildConfig.TTS_MINIMAX_VOICE_ID
    val TTS_MINIMAX_GROUP_ID: String = BuildConfig.TTS_MINIMAX_GROUP_ID
}

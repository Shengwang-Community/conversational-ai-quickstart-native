package cn.shengwang.convoai.quickstart.api

import cn.shengwang.convoai.quickstart.KeyCenter
import cn.shengwang.convoai.quickstart.api.net.SecureOkHttpClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

/**
 * Agent Starter
 *
 * Starts/stops Conversational AI agents via Shengwang REST API.
 * Uses app-credentials auth mode: Authorization header is "agora token=<convoai_token>"
 * Pipeline (STT/LLM/TTS) is configured inline in the request body.
 */
object AgentStarter {
    private const val JSON_MEDIA_TYPE = "application/json; charset=utf-8"
    private const val API_BASE_URL = "https://api.agora.io/cn/api/conversational-ai-agent/v2/projects"
    private const val DEFAULT_AGENT_RTC_UID = "1009527"

    private val okHttpClient: OkHttpClient by lazy {
        SecureOkHttpClient.create()
            .build()
    }

    /**
     * Start an agent with inline STT/LLM/TTS pipeline configuration.
     *
     * @param channelName Channel name for the agent
     * @param agentRtcUid Agent RTC UID (optional, defaults to "1009527")
     * @param agentToken Token for the agent to join the RTC channel
     * @param authToken ConvoAI token for REST API authorization (app-credentials mode)
     * @return Result containing agentId or exception
     */
    suspend fun startAgentAsync(
        channelName: String,
        agentRtcUid: String = DEFAULT_AGENT_RTC_UID,
        agentToken: String,
        authToken: String
    ): Result<String> = withContext(Dispatchers.IO) {
        try {
            val projectId = KeyCenter.APP_ID
            val url = "$API_BASE_URL/$projectId/join/"

            val requestBody = buildJsonPayload(
                name = channelName,
                channel = channelName,
                agentRtcUid = agentRtcUid,
                token = agentToken,
                remoteRtcUids = listOf("*")
            )

            val request = Request.Builder()
                .url(url)
                .addHeader("Content-Type", JSON_MEDIA_TYPE)
                .addHeader("Authorization", "agora token=$authToken")
                .post(requestBody.toString().toRequestBody(JSON_MEDIA_TYPE.toMediaType()))
                .build()

            val response = okHttpClient.newCall(request).execute()

            if (!response.isSuccessful) {
                val errorBody = response.body.string()
                throw RuntimeException("Start agent error: httpCode=${response.code}, httpMsg=$errorBody")
            }

            val body = response.body.string()
            val bodyJson = JSONObject(body)
            val agentId = bodyJson.optString("agent_id", "")

            if (agentId.isBlank()) {
                throw RuntimeException("Failed to parse agentId from response: $body")
            }

            Result.success(agentId)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Build JSON payload with inline STT/LLM/TTS pipeline configuration.
     * Matches the Shengwang Conversational AI REST API v2 format.
     */
    private fun buildJsonPayload(
        name: String,
        channel: String,
        agentRtcUid: String,
        token: String,
        remoteRtcUids: List<String>
    ): JSONObject {
        return JSONObject().apply {
            put("name", name)
            put("properties", JSONObject().apply {
                put("channel", channel)
                put("token", token)
                put("agent_rtc_uid", agentRtcUid)
                put("remote_rtc_uids", JSONArray(remoteRtcUids))
                put("enable_string_uid", true)
                put("idle_timeout", 120)

                // Advanced features
                put("advanced_features", JSONObject().apply {
                    put("enable_rtm", true)
                })

                // STT - Microsoft Azure
                put("asr", JSONObject().apply {
                    put("vendor", "microsoft")
                    put("language", "zh-CN")
                    put("params", JSONObject().apply {
                        put("key", KeyCenter.STT_MICROSOFT_KEY)
                        put("region", KeyCenter.STT_MICROSOFT_REGION)
                    })
                })

                // LLM - DeepSeek (OpenAI compatible)
                put("llm", JSONObject().apply {
                    put("url", KeyCenter.LLM_URL)
                    put("api_key", KeyCenter.LLM_API_KEY)
                    put("system_messages", JSONArray().apply {
                        put(JSONObject().apply {
                            put("role", "system")
                            put("content", "You are a helpful AI assistant.")
                        })
                    })
                    put("greeting_message", "Hello! I am your AI assistant. How can I help you?")
                    put("failure_message", "I'm sorry, I'm having trouble processing your request.")
                    put("params", JSONObject().apply {
                        put("model", KeyCenter.LLM_MODEL)
                    })
                })

                // TTS - MiniMax
                put("tts", JSONObject().apply {
                    put("vendor", "minimax")
                    put("params", JSONObject().apply {
                        put("key", KeyCenter.TTS_MINIMAX_KEY)
                        put("model", KeyCenter.TTS_MINIMAX_MODEL)
                        put("voice_setting", JSONObject().apply {
                            put("voice_id", KeyCenter.TTS_MINIMAX_VOICE_ID)
                            put("speed", 1.0)
                        })
                        put("group_id", KeyCenter.TTS_MINIMAX_GROUP_ID)
                    })
                })

                // Parameters
                put("parameters", JSONObject().apply {
                    put("data_channel", "rtm")
                    put("enable_error_message", true)
                })
            })
        }
    }

    /**
     * Stop an agent
     *
     * @param agentId Agent ID to stop
     * @param authToken ConvoAI token for REST API authorization
     * @return Result containing success or exception
     */
    suspend fun stopAgentAsync(
        agentId: String,
        authToken: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val projectId = KeyCenter.APP_ID
            val url = "$API_BASE_URL/$projectId/agents/$agentId/leave"

            val request = Request.Builder()
                .url(url)
                .addHeader("Authorization", "agora token=$authToken")
                .post("".toRequestBody("application/json; charset=utf-8".toMediaType()))
                .build()

            val response = okHttpClient.newCall(request).execute()

            if (!response.isSuccessful) {
                val errorBody = response.body.string()
                throw RuntimeException("Stop agent error: httpCode=${response.code}, httpMsg=$errorBody")
            }

            response.body.close()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

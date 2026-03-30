package cn.shengwang.convoai.quickstart.api;

import cn.shengwang.convoai.quickstart.KeyCenter;
import cn.shengwang.convoai.quickstart.api.net.SecureOkHttpClient;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Agent Starter
 *
 * Starts/stops Conversational AI agents via ShengWang REST API.
 * Uses HTTP token auth mode: Authorization header is "agora token=<convoai_token>".
 * Pipeline (ASR/LLM/TTS) is configured inline in the request body.
 */
public class AgentStarter {
    private static final String JSON_MEDIA_TYPE = "application/json; charset=utf-8";
    private static final String AGORA_API_BASE_URL = "https://api.agora.io/cn/api/conversational-ai-agent/v2/projects";
    private static final String DEFAULT_AGENT_RTC_UID = "1009527";

    private static final OkHttpClient okHttpClient = SecureOkHttpClient.create().build();
    private static final ExecutorService executorService = Executors.newCachedThreadPool();

    /**
     * Start an agent with inline ASR/LLM/TTS pipeline configuration.
     *
     * @param channelName Channel name for the agent
     * @param agentRtcUid Agent RTC UID
     * @param agentToken Token for the agent to join the RTC channel
     * @param authToken Agora token for REST API authorization
     * @param remoteRtcUid Current user RTC UID that the agent should subscribe to
     * @param callback Callback for result
     */
    public static void startAgentAsync(
        String channelName,
        String agentRtcUid,
        String agentToken,
        String authToken,
        String remoteRtcUid,
        AgentStartCallback callback
    ) {
        executorService.execute(() -> {
            try {
                String projectId = KeyCenter.APP_ID;
                String url = AGORA_API_BASE_URL + "/" + projectId + "/join/";

                JSONObject requestBody = buildJsonPayload(
                    channelName,
                    channelName,
                    agentRtcUid,
                    agentToken,
                    Collections.singletonList(remoteRtcUid)
                );

                Request request = new Request.Builder()
                    .url(url)
                    .addHeader("Content-Type", JSON_MEDIA_TYPE)
                    .addHeader("Authorization", "agora token=" + authToken)
                    .post(RequestBody.create(
                        requestBody.toString(),
                        MediaType.parse(JSON_MEDIA_TYPE)
                    ))
                    .build();

                Response response = okHttpClient.newCall(request).execute();

                if (!response.isSuccessful()) {
                    String errorBody = response.body() != null ? response.body().string() : response.message();
                    throw new RuntimeException("Start agent error: httpCode=" + response.code() + ", httpMsg=" + errorBody);
                }

                String body = response.body() != null ? response.body().string() : null;
                if (body == null) {
                    throw new RuntimeException("Response body is null");
                }

                JSONObject bodyJson = new JSONObject(body);
                String agentId = bodyJson.optString("agent_id", "");
                if (agentId.isEmpty()) {
                    throw new RuntimeException("Failed to parse agentId from response: " + body);
                }

                callback.onSuccess(agentId);
            } catch (Exception e) {
                callback.onFailure(e);
            }
        });
    }

    public static void startAgentAsync(
        String channelName,
        String remoteRtcUid,
        String agentToken,
        String authToken,
        AgentStartCallback callback
    ) {
        startAgentAsync(
            channelName,
            DEFAULT_AGENT_RTC_UID,
            agentToken,
            authToken,
            remoteRtcUid,
            callback
        );
    }

    private static JSONObject buildJsonPayload(
        String name,
        String channel,
        String agentRtcUid,
        String token,
        List<String> remoteRtcUids
    ) throws JSONException {
        return new JSONObject()
            .put("name", name)
            .put("properties", new JSONObject()
                .put("channel", channel)
                .put("token", token)
                .put("agent_rtc_uid", agentRtcUid)
                .put("remote_rtc_uids", new JSONArray(remoteRtcUids))
                .put("enable_string_uid", false)
                .put("idle_timeout", 120)
                .put("advanced_features", new JSONObject()
                    .put("enable_rtm", true))
                .put("asr", new JSONObject()
                    .put("vendor", "fengming")
                    .put("language", "zh-CN"))
                .put("llm", new JSONObject()
                    .put("url", KeyCenter.LLM_URL)
                    .put("api_key", KeyCenter.LLM_API_KEY)
                    .put("vendor", "aliyun")
                    .put("system_messages", new JSONArray()
                        .put(new JSONObject()
                            .put("role", "system")
                            .put("content", "你是一名有帮助的 AI 助手。")))
                    .put("greeting_message", "你好！我是你的 AI 助手，有什么可以帮你？")
                    .put("failure_message", "抱歉，我暂时处理不了你的请求，请稍后再试。")
                    .put("params", new JSONObject()
                        .put("model", KeyCenter.LLM_MODEL)))
                .put("tts", new JSONObject()
                    .put("vendor", "bytedance")
                    .put("params", new JSONObject()
                        .put("token", KeyCenter.TTS_BYTEDANCE_TOKEN)
                        .put("app_id", KeyCenter.TTS_BYTEDANCE_APP_ID)
                        .put("cluster", "volcano_tts")
                        .put("voice_type", "BV700_streaming")
                        .put("speed_ratio", 1.0)
                        .put("volume_ratio", 1.0)
                        .put("pitch_ratio", 1.0)))
                .put("parameters", new JSONObject()
                    .put("data_channel", "rtm")
                    .put("enable_error_message", true)));
    }

    /**
     * Stop an agent.
     *
     * @param agentId Agent ID to stop
     * @param authToken Agora token for REST API authorization
     * @param callback Callback for result
     */
    public static void stopAgentAsync(String agentId, String authToken, AgentStopCallback callback) {
        executorService.execute(() -> {
            try {
                String projectId = KeyCenter.APP_ID;
                String url = AGORA_API_BASE_URL + "/" + projectId + "/agents/" + agentId + "/leave";

                Request request = new Request.Builder()
                    .url(url)
                    .addHeader("Authorization", "agora token=" + authToken)
                    .post(RequestBody.create("", MediaType.parse(JSON_MEDIA_TYPE)))
                    .build();

                Response response = okHttpClient.newCall(request).execute();

                if (!response.isSuccessful()) {
                    String errorBody = response.body() != null ? response.body().string() : response.message();
                    throw new RuntimeException("Stop agent error: httpCode=" + response.code() + ", httpMsg=" + errorBody);
                }

                if (response.body() != null) {
                    response.body().close();
                }

                callback.onSuccess();
            } catch (Exception e) {
                callback.onFailure(e);
            }
        });
    }

    /**
     * Check if the server is available.
     */
    public static void checkServerHealth(ServerHealthCallback callback) {
        executorService.execute(() -> callback.onResult(true));
    }

    public interface AgentStartCallback {
        void onSuccess(String agentId);

        void onFailure(Exception exception);
    }

    public interface AgentStopCallback {
        void onSuccess();

        void onFailure(Exception exception);
    }

    public interface ServerHealthCallback {
        void onResult(boolean isAvailable);

        void onFailure(Exception exception);
    }
}

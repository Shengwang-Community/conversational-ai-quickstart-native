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
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Token Generator - Generates Agora tokens for RTC and RTM
 * <p>
 * ⚠️ WARNING: DO NOT USE IN PRODUCTION ⚠️
 * <p>
 * This class is provided purely for demonstration purposes to make it easier to run the example
 * app without setting up a backend server immediately.
 * <p>
 * Security Risks:
 * 1. Exposes your App ID and App Certificate in client-side code.
 * 2. The token generation endpoint used here is a public demo service that may be
 *    rate-limited, unstable, or shut down at any time.
 * <p>
 * Production Requirement:
 * In a real production app, you MUST generate tokens on your own secure backend server.
 * Your client app should request tokens from your backend, which then generates them
 * using the Agora Server SDKs.
 * <p>
 * @see <a href="https://docs.agora.io/en/video-calling/get-started/authentication-workflow">Authentication Workflow</a>
 */
public class TokenGenerator {
    private static final String TOOLBOX_SERVER_HOST = "https://service.apprtc.cn/toolbox";

    private static final ExecutorService executorService = Executors.newCachedThreadPool();
    private static final OkHttpClient okHttpClient = SecureOkHttpClient.create().build();

    private static long expireSecond = -1;

    /**
     * Set token expiration time in seconds
     * @param seconds Expiration time in seconds, -1 for default (24 hours)
     */
    public static void setExpireSecond(long seconds) {
        expireSecond = seconds;
    }

    /**
     * Generate tokens (callback-based)
     * <p>
     * ⚠️ Warning: For demo use only. Do not use in production.
     *
     * @param channelName Channel name
     * @param uid User ID
     * @param tokenTypes Token types (default: RTC and RTM)
     * @param success Success callback
     * @param failure Failure callback (optional)
     */
    public static void generateTokens(
        String channelName,
        String uid,
        AgoraTokenType[] tokenTypes,
        TokenCallback success,
        TokenErrorCallback failure
    ) {
        executorService.execute(() -> {
            try {
                String token = fetchToken(channelName, uid, tokenTypes);
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                    success.onSuccess(token);
                });
            } catch (Exception e) {
                if (failure != null) {
                    new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                        failure.onFailure(e);
                    });
                }
            }
        });
    }

    /**
     * Generate tokens with default types (RTC and RTM)
     * <p>
     * ⚠️ Warning: For demo use only. Do not use in production.
     */
    public static void generateTokens(
        String channelName,
        String uid,
        TokenCallback success,
        TokenErrorCallback failure
    ) {
        generateTokens(
            channelName,
            uid,
            new AgoraTokenType[]{AgoraTokenType.RTC, AgoraTokenType.RTM},
            success,
            failure
        );
    }

    /**
     * Generate tokens asynchronously (callback-based)
     * <p>
     * ⚠️ Warning: For demo use only. Do not use in production.
     *
     * @param channelName Channel name
     * @param uid User ID
     * @param tokenTypes Token types (default: RTC and RTM)
     * @param callback Result callback
     */
    public static void generateTokensAsync(
        String channelName,
        String uid,
        AgoraTokenType[] tokenTypes,
        TokenResultCallback callback
    ) {
        executorService.execute(() -> {
            try {
                String token = fetchToken(channelName, uid, tokenTypes);
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                    callback.onResult(token, null);
                });
            } catch (Exception e) {
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                    callback.onResult(null, e);
                });
            }
        });
    }

    /**
     * Generate tokens asynchronously with default types (RTC and RTM)
     * <p>
     * ⚠️ Warning: For demo use only. Do not use in production.
     */
    public static void generateTokensAsync(
        String channelName,
        String uid,
        TokenResultCallback callback
    ) {
        generateTokensAsync(
            channelName,
            uid,
            new AgoraTokenType[]{AgoraTokenType.RTC, AgoraTokenType.RTM},
            callback
        );
    }

    private static String fetchToken(
        String channelName,
        String uid,
        AgoraTokenType[] tokenTypes
    ) throws IOException, JSONException {
        JSONObject postBody = buildJsonRequest(channelName, uid, tokenTypes);
        Request request = buildHttpRequest(postBody);
        return executeRequest(request);
    }

    private static JSONObject buildJsonRequest(
        String channelName,
        String uid,
        AgoraTokenType[] tokenTypes
    ) throws JSONException {
        JSONObject jsonObject = new JSONObject();
        jsonObject.put("appId", KeyCenter.APP_ID);
        jsonObject.put("appCertificate", KeyCenter.APP_CERTIFICATE);
        jsonObject.put("channelName", channelName);
        jsonObject.put("expire", expireSecond > 0 ? expireSecond : 60 * 60 * 24);
        jsonObject.put("src", "Android");
        jsonObject.put("ts", String.valueOf(System.currentTimeMillis()));

        if (tokenTypes.length == 1) {
            jsonObject.put("type", tokenTypes[0].getValue());
        } else {
            JSONArray typesArray = new JSONArray();
            for (AgoraTokenType tokenType : tokenTypes) {
                typesArray.put(tokenType.getValue());
            }
            jsonObject.put("types", typesArray);
        }

        jsonObject.put("uid", uid);
        return jsonObject;
    }

    private static Request buildHttpRequest(JSONObject postBody) {
        // ⚠️ This endpoint is for demonstration purposes only.
        // In production, use your own backend server to generate tokens.
        String url = TOOLBOX_SERVER_HOST + "/v2/token/generate";

        return new Request.Builder()
            .url(url)
            .addHeader("Content-Type", "application/json")
            .post(RequestBody.create(
                postBody.toString(),
                MediaType.parse("*")
            ))
            .build();
    }

    private static String executeRequest(Request request) throws IOException, JSONException {
        Response response = okHttpClient.newCall(request).execute();

        // Read response body first to get detailed error information
        String body = response.body() != null ? response.body().string() : null;

        if (!response.isSuccessful()) {
            String errorMsg = "Fetch token error: httpCode=" + response.code() + ", httpMsg=" + response.message();
            if (body != null && !body.isEmpty()) {
                try {
                    JSONObject errorJson = new JSONObject(body);
                    errorMsg += ", responseBody=" + errorJson.toString(2);
                } catch (JSONException e) {
                    errorMsg += ", responseBody=" + body;
                }
            }
            throw new RuntimeException(errorMsg);
        }

        if (body == null || body.isEmpty()) {
            throw new RuntimeException("Response body is null or empty");
        }

        JSONObject bodyJson = new JSONObject(body);
        int code = bodyJson.optInt("code", -1);
        if (code != 0) {
            String msg = bodyJson.optString("msg", bodyJson.optString("message", "Unknown error"));
            throw new RuntimeException(
                "Fetch token error: code=" + code + ", msg=" + msg + ", responseBody=" + bodyJson.toString(2)
            );
        }

        return bodyJson.getJSONObject("data").getString("token");
    }

    /**
     * Token type enumeration
     */
    public enum AgoraTokenType {
        RTC(1),
        RTM(2),
        CHAT(3);

        private final int value;

        AgoraTokenType(int value) {
            this.value = value;
        }

        public int getValue() {
            return value;
        }
    }

    /**
     * Callback interface for token generation success
     */
    public interface TokenCallback {
        void onSuccess(String token);
    }

    /**
     * Callback interface for token generation failure
     */
    public interface TokenErrorCallback {
        void onFailure(Exception exception);
    }

    /**
     * Callback interface for token generation result (success or failure)
     */
    public interface TokenResultCallback {
        /**
         * Called when token generation completes
         * @param token Generated token if successful, null if failed
         * @param exception Exception if failed, null if successful
         */
        void onResult(String token, Exception exception);
    }
}

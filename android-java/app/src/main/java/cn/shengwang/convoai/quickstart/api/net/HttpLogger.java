package cn.shengwang.convoai.quickstart.api.net;

import android.util.Log;

import okhttp3.HttpUrl;
import okhttp3.Interceptor;
import okhttp3.MediaType;
import okhttp3.Request;
import okhttp3.Response;
import okio.Buffer;
import okio.BufferedSource;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.nio.charset.Charset;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * HttpLogger - Interceptor for logging HTTP requests and responses
 */
public class HttpLogger implements Interceptor {
    private static final Set<String> SENSITIVE_HEADERS = new HashSet<>(Arrays.asList(
            "auth", "token", "cert", "secret", "appId", "app_id"
    ));

    private static final Set<String> SENSITIVE_PARAMS = new HashSet<>(Arrays.asList(
            "auth", "token", "password", "cert", "secret", "phone", "appId", "app_id"
    ));

    // Excluded API paths
    private static final Set<String> EXCLUDE_PATHS = new HashSet<>(Arrays.asList(
            "/heartbeat",  // Heartbeat API
            "/ping",       // Ping API
            "sip/status"   // sip ping
    ));

    // Excluded Content-Types
    private static final Set<String> EXCLUDE_CONTENT_TYPES = new HashSet<>(Arrays.asList(
            "multipart/form-data",    // File upload
            "application/octet-stream", // Binary stream
            "image/*",
            "file",
            "audio/*",                // Audio files
            "video/*"                 // Video files
    ));

    // Paths containing these keywords will also be checked for content type exclusion
    private static final Set<String> SENSITIVE_PATH_KEYWORDS = new HashSet<>(Arrays.asList(
            "upload", "file", "media"
    ));

    @Override
    public Response intercept(Chain chain) throws IOException {
        Request request = chain.request();
        HttpUrl url = request.url();
        String requestId = UUID.randomUUID().toString().substring(0, 8);

        // Check if should completely skip logging or only log results
        boolean shouldSkipCompletely = shouldSkipLoggingCompletely(request);
        boolean logResultOnly = shouldLogResultOnly(request);

        // If not completely skipped and not only logging results, log the request
        if (!shouldSkipCompletely && !logResultOnly) {
            String logContent = buildLogContent(request);
            Log.d("[" + requestId + "]-Request", logContent);
        } else if (logResultOnly) {
            Log.d("[" + requestId + "]-Request", "Large file upload request: " + request.method() + " " + request.url());
        }

        // Execute request
        long startNs = System.nanoTime();
        Response response = chain.proceed(request);

        // If not completely skipping logging, log the response
        if (!shouldSkipCompletely) {
            logResponse(response, startNs, url, requestId);
        }

        return response;
    }

    private String buildLogContent(Request request) throws IOException {
        StringBuilder logContent = new StringBuilder();

        // Start request info
        logContent.append("curl -X ").append(request.method());

        // Add headers
        java.util.List<String> headers = new java.util.ArrayList<>();
        if (request.body() != null && request.body().contentType() != null) {
            headers.add("Content-Type:" + request.body().contentType().toString());
        }
        for (String name : request.headers().names()) {
            if (!"content-type".equalsIgnoreCase(name)) {
                headers.add(name + ":" + request.header(name));
            }
        }

        if (!headers.isEmpty()) {
            logContent.append(" -H \"");
            for (int i = 0; i < headers.size(); i++) {
                if (i > 0) {
                    logContent.append(";");
                }
                logContent.append(headers.get(i));
            }
            logContent.append("\"");
        }

        // Add request body
        if (request.body() != null) {
            Buffer buffer = new Buffer();
            request.body().writeTo(buffer);
            Charset charset = request.body().contentType() != null
                    ? request.body().contentType().charset()
                    : Charset.defaultCharset();
            String bodyString = buffer.readString(charset);

            // Format JSON body
            String formattedBody = formatJsonString(bodyString);
            logContent.append(" -d '").append(formattedBody).append("'");
        }

        // Add URL
        String urlString = buildUrlString(request.url());
        logContent.append(" \"").append(urlString).append("\"");

        return logContent.toString();
    }

    private String formatJsonString(String input) {
        try {
            String trimmed = input.trim();
            if (trimmed.startsWith("{")) {
                return new JSONObject(input).toString(4);
            } else if (trimmed.startsWith("[")) {
                return new JSONArray(input).toString(4);
            } else {
                return input;
            }
        } catch (JSONException e) {
            return input;
        }
    }

    private String buildUrlString(HttpUrl url) {
        StringBuilder urlBuilder = new StringBuilder();
        urlBuilder.append(url.scheme()).append("://").append(url.host());
        if (url.port() != 80 && url.port() != 443) {
            urlBuilder.append(":").append(url.port());
        }
        urlBuilder.append(url.encodedPath());

        if (!url.queryParameterNames().isEmpty()) {
            urlBuilder.append("?");
            boolean first = true;
            for (String name : url.queryParameterNames()) {
                if (!first) {
                    urlBuilder.append("&");
                }
                String value = url.queryParameter(name);
                urlBuilder.append(name).append("=").append(value);
                first = false;
            }
        }
        return urlBuilder.toString();
    }

    /**
     * Determine if logging should be completely skipped
     */
    private boolean shouldSkipLoggingCompletely(Request request) {
        String path = request.url().encodedPath();
        for (String excludePath : EXCLUDE_PATHS) {
            if (path.contains(excludePath)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Determine if only results should be logged without request body
     */
    private boolean shouldLogResultOnly(Request request) {
        String path = request.url().encodedPath().toLowerCase();
        for (String keyword : SENSITIVE_PATH_KEYWORDS) {
            if (path.contains(keyword)) {
                return true;
            }
        }

        if (request.body() != null && request.body().contentType() != null) {
            String contentTypeString = request.body().contentType().toString();
            for (String type : EXCLUDE_CONTENT_TYPES) {
                if (type.endsWith("/*")) {
                    String prefix = type.substring(0, type.length() - 2);
                    if (contentTypeString.startsWith(prefix)) {
                        return true;
                    }
                } else {
                    if (contentTypeString.equals(type)) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    private void logResponse(Response response, long startNs, HttpUrl url, String requestId) throws IOException {
        long tookMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNs);
        okhttp3.ResponseBody responseBody = response.body();
        if (responseBody == null) {
            return;
        }

        long contentLength = responseBody.contentLength();
        String bodySize = contentLength != -1L ? contentLength + "-byte" : "unknown-length";

        StringBuilder logContent = new StringBuilder();
        logContent.append(response.code()).append(" ").append(response.message())
                .append(" for ").append(buildUrlString(url))
                .append(" (").append(tookMs).append("ms");
        if (response.networkResponse() != null && response.networkResponse() != response) {
            logContent.append(", ").append(bodySize).append(" body");
        }
        logContent.append(")");

        for (String name : response.headers().names()) {
            logContent.append("\n").append(name).append(": ").append(response.header(name));
        }

        MediaType contentType = responseBody.contentType();
        if (contentType != null &&
                "application".equals(contentType.type()) &&
                (contentType.subtype().contains("json") || contentType.subtype().contains("xml"))) {
            BufferedSource source = responseBody.source();
            source.request(Long.MAX_VALUE);
            Buffer buffer = source.buffer();
            Charset charset = contentType.charset() != null ? contentType.charset() : Charset.defaultCharset();
            if (contentLength != 0L) {
                logContent.append("\n\n");
                String bodyString = buffer.clone().readString(charset);
                logContent.append(formatJsonString(bodyString));
            }
        }

        Log.d("[" + requestId + "]-Response", logContent.toString());
    }
}


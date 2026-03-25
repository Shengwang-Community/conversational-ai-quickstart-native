// TokenGenerator.cpp: Generate Agora tokens via Toolbox Server API
// Using HttpClient (libcurl) + nlohmann/json
//

#include "../general/pch.h"
#include "TokenGenerator.h"
#include "HttpClient.h"
#include "../KeyCenter.h"
#include "../tools/Logger.h"

#include <nlohmann/json.hpp>
#include <chrono>

using json = nlohmann::json;

// Helper Functions

static int64_t GetCurrentTimestampMs() {
    auto now = std::chrono::system_clock::now();
    auto duration = now.time_since_epoch();
    return std::chrono::duration_cast<std::chrono::milliseconds>(duration).count();
}

// TokenGenerator Implementation

void TokenGenerator::GenerateToken(
    const std::string& channelName,
    const std::string& uid,
    int expire,
    const std::vector<AgoraTokenType>& types,
    TokenGenerateCallback callback
) {
    LOG_INFO("[TokenGenerator] Generating token for channel: " + channelName + ", uid: " + uid);

    // Build JSON request body using nlohmann/json
    json::array_t typesArray;
    for (const auto& type : types) {
        typesArray.push_back(static_cast<int>(type));
    }

    json requestBody = {
        {"appCertificate", KeyCenter::AGORA_APP_CERTIFICATE},
        {"appId", KeyCenter::AGORA_APP_ID},
        {"channelName", channelName},
        {"expire", expire},
        {"src", "Windows"},
        {"ts", GetCurrentTimestampMs()},
        {"uid", uid},
        {"types", typesArray}
    };

    std::string requestBodyStr = requestBody.dump();
    LOG_INFO("[TokenGenerator] Request body: " + requestBodyStr);

    // Build URL
    std::string urlString = std::string(TOOLBOX_SERVER_URL) + "/v2/token/generate";

    // Prepare headers
    std::map<std::string, std::string> headers;
    headers["Content-Type"] = "application/json";

    // ✅ Use HttpClient (libcurl) - automatically handles redirects!
    HttpClient client;
    client.SetTimeout(15);

    client.PostAsync(urlString, requestBodyStr, headers,
        [callback, channelName, uid](bool success, const std::string& response, int statusCode) {
            LOG_INFO("[TokenGenerator] Response status: " + std::to_string(statusCode));

            if (!success) {
                LOG_ERROR("[TokenGenerator] Request failed: " + response);
                if (callback) {
                    callback(false, "", response);
                }
                return;
            }

            // Parse JSON response
            try {
                json responseJson = json::parse(response);

                // Check for token in response
                if (responseJson.contains("data") && responseJson["data"].is_object()) {
                    json data = responseJson["data"];
                    
                    if (data.contains("token") && data["token"].is_string()) {
                        std::string token = data["token"].get<std::string>();
                        LOG_INFO("[TokenGenerator] Token generated successfully");
                        
                        if (callback) {
                            callback(true, token, "");
                        }
                        return;
                    }
                }

                // Token not found in response
                std::string errorMsg = "token not found in response";
                LOG_ERROR("[TokenGenerator] " + errorMsg);
                if (callback) {
                    callback(false, "", errorMsg);
                }

            } catch (const std::exception& e) {
                std::string errorMsg = std::string("Failed to parse response: ") + e.what();
                LOG_ERROR("[TokenGenerator] " + errorMsg);
                if (callback) {
                    callback(false, "", errorMsg);
                }
            }
        }
    );
}

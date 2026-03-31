#include "../general/pch.h"
#include "AgentManager.h"
#include "HttpClient.h"
#include "../KeyCenter.h"
#include "../tools/Logger.h"

#include <nlohmann/json.hpp>
#include <sstream>

using json = nlohmann::json;

namespace {
constexpr const char* API_BASE_URL = "https://api.agora.io/cn/api/conversational-ai-agent/v2/projects";
}

std::string AgentManager::GenerateAuthorization(const std::string& authToken) {
    return "agora token=" + authToken;
}

void AgentManager::StartAgent(
    const std::string& channelName,
    const std::string& agentRtcUid,
    const std::string& agentToken,
    const std::string& authToken,
    AgentCallback callback
) {
    LOG_INFO("[AgentManager] Starting agent for channel: " + channelName + ", UID: " + agentRtcUid);

    std::string urlString = std::string(API_BASE_URL) + "/" +
                           std::string(KeyCenter::AGORA_APP_ID) + "/join/";
    
    LOG_INFO("[AgentManager] Request URL: " + urlString);

    json payload = {
        {"name", channelName},
        {"properties", {
            {"channel", channelName},
            {"agent_rtc_uid", agentRtcUid},
            {"remote_rtc_uids", json::array({"*"})},
            {"token", agentToken},
            {"enable_string_uid", true},
            {"idle_timeout", 120},
            {"advanced_features", {
                {"enable_rtm", true}
            }},
            {"asr", {
                {"vendor", "fengming"},
                {"language", "zh-CN"}
            }},
            {"llm", {
                {"url", KeyCenter::LLM_URL},
                {"api_key", KeyCenter::LLM_API_KEY},
                {"vendor", "aliyun"},
                // Use simple ASCII-only strings here to avoid encoding issues
                {"system_messages", json::array({
                    {
                        {"role", "system"},
                        {"content", "You are a helpful AI assistant."}
                    }
                })},
                {"greeting_message", "Hello! I am your AI assistant. How can I help you today?"},
                {"failure_message", "Sorry, I am not able to process your request right now. Please try again later."},
                {"params", {
                    {"model", KeyCenter::LLM_MODEL}
                }}
            }},
            {"tts", {
                {"vendor", "bytedance"},
                {"params", {
                    {"token", KeyCenter::TTS_BYTEDANCE_TOKEN},
                    {"app_id", KeyCenter::TTS_BYTEDANCE_APP_ID},
                    {"cluster", "volcano_tts"},
                    {"voice_type", "BV700_streaming"},
                    {"speed_ratio", 1.0},
                    {"volume_ratio", 1.0},
                    {"pitch_ratio", 1.0}
                }}
            }},
            {"parameters", {
                {"data_channel", "rtm"},
                {"enable_error_message", true}
            }}
        }}
    };

    std::string requestBodyStr = payload.dump();
    LOG_INFO("[AgentManager] Request body: " + requestBodyStr);

    // Prepare headers
    std::map<std::string, std::string> headers;
    headers["Content-Type"] = "application/json; charset=utf-8";
    headers["Authorization"] = GenerateAuthorization(authToken);

    HttpClient client;
    client.SetTimeout(30);
    
    client.PostAsync(urlString, requestBodyStr, headers,
        [callback](bool success, const std::string& response, int statusCode) {
            if (!success) {
                LOG_ERROR("[AgentManager] Request failed: " + response);
                if (callback) {
                    callback(false, response);
                }
                return;
            }
            
            // Parse JSON response using nlohmann/json
            try {
                json responseJson = json::parse(response);
                
                if (responseJson.contains("agent_id") && responseJson["agent_id"].is_string()) {
                    std::string agentId = responseJson["agent_id"].get<std::string>();
                    LOG_INFO("[AgentManager] Agent started, ID: " + agentId);
                    
                    if (callback) {
                        callback(true, agentId);
                    }
                } else {
                    std::string errorMsg = "agent_id not found in response";
                    LOG_ERROR("[AgentManager] " + errorMsg);
                    if (callback) {
                        callback(false, errorMsg);
                    }
                }
            } catch (const std::exception& e) {
                std::string errorMsg = std::string("Failed to parse response: ") + e.what();
                LOG_ERROR("[AgentManager] " + errorMsg);
                if (callback) {
                    callback(false, errorMsg);
                }
            }
        }
    );
}

void AgentManager::StopAgent(
    const std::string& agentId,
    const std::string& authToken,
    AgentCallback callback
) {
    LOG_INFO("[AgentManager] Stopping agent: " + agentId);

    std::string urlString = std::string(API_BASE_URL) + "/" +
                           std::string(KeyCenter::AGORA_APP_ID) + "/agents/" +
                           agentId + "/leave";
    
    LOG_INFO("[AgentManager] Stop URL: " + urlString);

    // Prepare headers
    std::map<std::string, std::string> headers;
    headers["Content-Type"] = "application/json; charset=utf-8";
    headers["Authorization"] = GenerateAuthorization(authToken);

    HttpClient client;
    client.SetTimeout(30);
    
    client.PostAsync(urlString, "", headers,
        [callback](bool success, const std::string& response, int statusCode) {
            if (!success) {
                LOG_ERROR("[AgentManager] Stop request failed: " + response);
                if (callback) {
                    callback(false, response);
                }
                return;
            }
            
            LOG_INFO("[AgentManager] Agent stopped");
            if (callback) {
                callback(true, "Agent stopped");
            }
        }
    );
}

void AgentManager::CheckServerHealth(AgentCallback callback) {
    std::string urlString = std::string(API_BASE_URL) + "/" + std::string(KeyCenter::AGORA_APP_ID);
    std::map<std::string, std::string> headers;
    
    HttpClient client;
    client.SetTimeout(5);
    
    client.PostAsync(urlString, "", headers,
        [callback](bool success, const std::string& response, int statusCode) {
            if (callback) {
                callback(success && statusCode == 200, response);
            }
        }
    );
}

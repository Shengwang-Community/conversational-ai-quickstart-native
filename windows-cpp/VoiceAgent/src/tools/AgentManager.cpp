#include "AgentManager.h"

#include "../KeyCenter.h"
#include "Logger.h"
#include "NetworkManager.h"

#include <chrono>
#include <map>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace {
constexpr const char* kApiBaseURL = "https://api.agora.io/cn/api/conversational-ai-agent/v2/projects";

std::string buildAgentName(const std::string& channelName, const std::string& agentRtcUid)
{
    const auto now = std::chrono::system_clock::now().time_since_epoch();
    const auto seconds = std::chrono::duration_cast<std::chrono::seconds>(now).count();
    return "agent_" + channelName + "_" + agentRtcUid + "_" + std::to_string(seconds);
}

json buildStartAgentPayload(const std::string& channelName, const std::string& agentRtcUid, const std::string& agentToken)
{
    return {
        {"name", buildAgentName(channelName, agentRtcUid)},
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
                {"language", "zh-CN"},
                {"vendor", "fengming"}
            }},
            {"llm", {
                {"url", KeyCenter::LLM_URL},
                {"api_key", KeyCenter::LLM_API_KEY},
                {"vendor", "aliyun"},
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
}
}

void AgentManager::startAgent(
    const std::string& channelName,
    const std::string& agentRtcUid,
    const std::string& agentToken,
    const std::string& userToken,
    AgentCallback callback
)
{
    const std::string url = std::string(kApiBaseURL) + "/" + KeyCenter::AGORA_APP_ID + "/join";
    std::map<std::string, std::string> headers = {
        {"Content-Type", "application/json; charset=utf-8"},
        {"Authorization", generateAuthorization(userToken)}
    };

    NetworkManager::shared().postJSON(url, buildStartAgentPayload(channelName, agentRtcUid, agentToken).dump(), headers, 30,
        [callback](bool success, const std::string& responseOrError, int) {
            if (!success) {
                if (callback) {
                    callback(false, responseOrError);
                }
                return;
            }

            try {
                const auto response = json::parse(responseOrError);
                const auto agentId = response.at("agent_id").get<std::string>();
                if (callback) {
                    callback(true, agentId);
                }
            } catch (const std::exception& error) {
                if (callback) {
                    callback(false, error.what());
                }
            }
        });
}

void AgentManager::stopAgent(
    const std::string& agentId,
    const std::string& userToken,
    AgentCallback callback
)
{
    const std::string url = std::string(kApiBaseURL) + "/" + KeyCenter::AGORA_APP_ID + "/agents/" + agentId + "/leave";
    std::map<std::string, std::string> headers = {
        {"Content-Type", "application/json; charset=utf-8"},
        {"Authorization", generateAuthorization(userToken)}
    };

    NetworkManager::shared().postJSON(url, "{}", headers, 30,
        [callback](bool success, const std::string& responseOrError, int) {
            if (callback) {
                callback(success, success ? "Agent stopped" : responseOrError);
            }
        });
}

std::string AgentManager::generateAuthorization(const std::string& userToken)
{
    return "agora token=" + userToken;
}

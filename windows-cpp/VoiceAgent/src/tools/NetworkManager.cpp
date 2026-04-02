#include "NetworkManager.h"

#include "../KeyCenter.h"
#include "../api/HttpClient.h"
#include "Logger.h"

#include <chrono>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

NetworkManager& NetworkManager::shared()
{
    static NetworkManager instance;
    return instance;
}

void NetworkManager::generateToken(
    const std::string& channelName,
    const std::string& userId,
    int expire,
    const std::vector<AgoraTokenType>& types,
    TokenGenerateCallback callback
) const
{
    json::array_t typeValues;
    for (const auto& type : types) {
        typeValues.push_back(static_cast<int>(type));
    }

    json requestBody = {
        {"appCertificate", KeyCenter::AGORA_APP_CERTIFICATE},
        {"appId", KeyCenter::AGORA_APP_ID},
        {"channelName", channelName},
        {"expire", expire},
        {"src", "Windows"},
        {"ts", currentTimestampMs()},
        {"types", typeValues},
        {"uid", userId}
    };

    std::map<std::string, std::string> headers;
    headers["Content-Type"] = "application/json";

    postJSON(TOOLBOX_SERVER_URL, requestBody.dump(), headers, 15,
        [callback](bool success, const std::string& responseOrError, int) {
            if (!success) {
                if (callback) {
                    callback(false, "", responseOrError);
                }
                return;
            }

            try {
                const auto response = json::parse(responseOrError);
                const auto& data = response.at("data");
                const auto token = data.at("token").get<std::string>();
                if (callback) {
                    callback(true, token, "");
                }
            } catch (const std::exception& error) {
                if (callback) {
                    callback(false, "", error.what());
                }
            }
        });
}

void NetworkManager::postJSON(
    const std::string& url,
    const std::string& requestBody,
    const std::map<std::string, std::string>& headers,
    int timeoutSeconds,
    NetworkCallback callback
) const
{
    HttpClient client;
    client.SetTimeout(timeoutSeconds);
    client.PostAsync(url, requestBody, headers, std::move(callback));
}

int64_t NetworkManager::currentTimestampMs()
{
    const auto now = std::chrono::system_clock::now();
    return std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
}

#pragma once

#include <functional>
#include <map>
#include <string>
#include <vector>

enum class AgoraTokenType {
    RTC = 1,
    RTM = 2,
    CHAT = 3
};

using TokenGenerateCallback = std::function<void(bool success, const std::string& token, const std::string& errorMessage)>;
using NetworkCallback = std::function<void(bool success, const std::string& responseOrError, int statusCode)>;

class NetworkManager {
public:
    static NetworkManager& shared();

    void generateToken(
        const std::string& channelName,
        const std::string& userId,
        int expire,
        const std::vector<AgoraTokenType>& types,
        TokenGenerateCallback callback
    ) const;

    void postJSON(
        const std::string& url,
        const std::string& requestBody,
        const std::map<std::string, std::string>& headers,
        int timeoutSeconds,
        NetworkCallback callback
    ) const;

private:
    NetworkManager() = default;
    static int64_t currentTimestampMs();
    static constexpr const char* TOOLBOX_SERVER_URL = "https://service.apprtc.cn/toolbox/v2/token/generate";
};

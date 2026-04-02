#pragma once

#include <functional>
#include <string>

using AgentCallback = std::function<void(bool success, const std::string& agentIdOrError)>;

class AgentManager {
public:
    static void startAgent(
        const std::string& channelName,
        const std::string& agentRtcUid,
        const std::string& agentToken,
        const std::string& userToken,
        AgentCallback callback = nullptr
    );

    static void stopAgent(
        const std::string& agentId,
        const std::string& userToken,
        AgentCallback callback = nullptr
    );

private:
    static std::string generateAuthorization(const std::string& userToken);
};

#pragma once

#include <string>
#include <functional>

// Agent operation callback
using AgentCallback = std::function<void(bool success, const std::string& agentIdOrError)>;

class AgentManager {
public:
    static void StartAgent(
        const std::string& channelName,
        const std::string& agentRtcUid,
        const std::string& agentToken,
        const std::string& authToken,
        AgentCallback callback = nullptr
    );
    
    static void StopAgent(
        const std::string& agentId,
        const std::string& authToken,
        AgentCallback callback = nullptr
    );
    
    static void CheckServerHealth(AgentCallback callback = nullptr);
    
private:
    static std::string GenerateAuthorization(const std::string& authToken);
};

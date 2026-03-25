#pragma once

#include <string>
#include <vector>
#include <functional>

// Token Type
enum class AgoraTokenType {
    RTC = 1,
    RTM = 2,
    CHAT = 3
};

// Token generation callback
using TokenGenerateCallback = std::function<void(bool success, const std::string& token, const std::string& errorMsg)>;

// Token Generator
// Generate Agora RTC and RTM tokens via Toolbox Server API
class TokenGenerator {
public:
    /// Generate token
    /// @param channelName Channel name (use empty string for RTM-only token)
    /// @param uid User ID
    /// @param expire Token expiration time in seconds (default: 24 hours)
    /// @param types Token types to generate (default: RTC and RTM)
    /// @param callback Callback with success flag, token, and error message
    static void GenerateToken(
        const std::string& channelName,
        const std::string& uid,
        int expire = 86400,
        const std::vector<AgoraTokenType>& types = {AgoraTokenType::RTC, AgoraTokenType::RTM},
        TokenGenerateCallback callback = nullptr
    );
    
private:
    // Toolbox Server for Token Generation
    static constexpr const char* TOOLBOX_SERVER_URL = "https://toolbox.bj2.agoralab.co";
    
    // HTTP POST request helper
    static void PostRequest(
        const std::string& url,
        const std::string& jsonBody,
        std::function<void(bool success, const std::string& response, const std::string& error)> callback
    );
};


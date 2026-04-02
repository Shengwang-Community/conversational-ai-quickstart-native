//
// ConversationalAIAPI.cpp: Simplified transcript parser
//

#include "../general/pch.h"
#include "ConversationalAIAPI.h"
#include "../tools/Logger.h"

#include <nlohmann/json.hpp>
#include <sstream>
#include <algorithm>
#include <chrono>

using json = nlohmann::json;

namespace {
void EmitLog(const std::vector<IConversationalAIAPIEventHandler*>& handlers, const std::string& log) {
    for (auto handler : handlers) {
        if (handler) {
            handler->OnDebugLog(log);
        }
    }
}

ModuleType ModuleTypeFromValue(const std::string& value) {
    if (value == "llm") {
        return ModuleType::LLM;
    }
    if (value == "mllm") {
        return ModuleType::MLLM;
    }
    if (value == "tts") {
        return ModuleType::TTS;
    }
    if (value == "context") {
        return ModuleType::Context;
    }
    return ModuleType::Unknown;
}

std::string ModuleTypeToString(ModuleType type) {
    switch (type) {
        case ModuleType::LLM:
            return "llm";
        case ModuleType::MLLM:
            return "mllm";
        case ModuleType::TTS:
            return "tts";
        case ModuleType::Context:
            return "context";
        case ModuleType::Unknown:
        default:
            return "unknown";
    }
}
}

// ============================================================================
// MessageParser Implementation
// ============================================================================

MessageParser::MessageParser() : m_maxMessageAge(5 * 60 * 1000) {  // 5 minutes
}

MessageParser::~MessageParser() {
    m_messageMap.clear();
    m_lastAccessMap.clear();
}

int64_t MessageParser::GetCurrentTimeMs() {
    auto now = std::chrono::system_clock::now();
    auto duration = now.time_since_epoch();
    return std::chrono::duration_cast<std::chrono::milliseconds>(duration).count();
}

std::string MessageParser::Base64Decode(const std::string& encoded) {
    static const std::string base64_chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    std::string decoded;
    std::vector<int> T(256, -1);
    for (int i = 0; i < 64; i++) {
        T[base64_chars[i]] = i;
    }
    
    int val = 0, valb = -8;
    for (unsigned char c : encoded) {
        if (c == '=') break;
        if (T[c] == -1) continue;
        val = (val << 6) + T[c];
        valb += 6;
        if (valb >= 0) {
            decoded.push_back(char((val >> valb) & 0xFF));
            valb -= 8;
        }
    }
    return decoded;
}

void MessageParser::CleanExpiredMessages() {
    int64_t currentTime = GetCurrentTimeMs();
    std::vector<std::string> expiredIds;
    
    for (const auto& pair : m_lastAccessMap) {
        if (currentTime - pair.second > m_maxMessageAge) {
            expiredIds.push_back(pair.first);
        }
    }
    
    for (const auto& id : expiredIds) {
        m_messageMap.erase(id);
        m_lastAccessMap.erase(id);
    }
}

std::string MessageParser::ParseStreamMessage(const std::string& message) {
    try {
        // Clean up expired messages
        CleanExpiredMessages();
        
        // Split message by '|'
        std::vector<std::string> parts;
        std::stringstream ss(message);
        std::string part;
        while (std::getline(ss, part, '|')) {
            parts.push_back(part);
        }
        
        if (parts.size() != 4) {
            LOG_ERROR("[MessageParser] Invalid message format, expected 4 parts");
            return "";
        }
        
        std::string messageId = parts[0];
        int partIndex = std::stoi(parts[1]);
        int totalParts = std::stoi(parts[2]);
        std::string base64Content = parts[3];
        
        // Validate partIndex and totalParts
        if (partIndex < 1 || partIndex > totalParts) {
            LOG_ERROR("[MessageParser] partIndex out of range");
            return "";
        }
        
        // Update last access time
        m_lastAccessMap[messageId] = GetCurrentTimeMs();
        
        // Store message part
        m_messageMap[messageId][partIndex] = base64Content;
        
        // Check if all parts are received
        if (static_cast<int>(m_messageMap[messageId].size()) == totalParts) {
            // All parts received, merge in order
            std::string completeMessage;
            for (int i = 1; i <= totalParts; i++) {
                auto it = m_messageMap[messageId].find(i);
                if (it == m_messageMap[messageId].end()) {
                    LOG_ERROR("[MessageParser] Missing part " + std::to_string(i));
                    return "";
                }
                completeMessage += it->second;
            }
            
            // Decode Base64
            std::string jsonString = Base64Decode(completeMessage);
            
            // Clean up processed message
            m_messageMap.erase(messageId);
            m_lastAccessMap.erase(messageId);
            
            return jsonString;
        }
        
        // Message is incomplete
        return "";
        
    } catch (const std::exception& e) {
        LOG_ERROR("[MessageParser] ParseStreamMessage error: " + std::string(e.what()));
        return "";
    }
}

// ============================================================================
// ConversationalAIAPI Implementation
// ============================================================================

ConversationalAIAPI::ConversationalAIAPI(const ConversationalAIAPIConfig& config)
    : m_config(config)
    , m_audioScenario(agora::rtc::AUDIO_SCENARIO_AI_CLIENT)
    , m_hasInterruptEvent(false)
    , m_hasStateChangeEvent(false) {
    LOG_INFO("[ConversationalAIAPI] Initialized");
    NotifyDebugLog("[ConversationalAIAPI] Initialized");
}

ConversationalAIAPI::~ConversationalAIAPI() {
    Destroy();
}

void ConversationalAIAPI::Destroy() {
    m_handlers.clear();
    m_transcriptCache.clear();
    m_publishCallbacks.clear();
    m_subscribeCallbacks.clear();
    m_unsubscribeCallbacks.clear();
    LOG_INFO("[ConversationalAIAPI] Destroyed");
}

void ConversationalAIAPI::Chat(const std::string& agentUserId, const ChatMessage& message, std::function<void(const ConversationalAIAPIError*)> completion) {
    if (message.GetMessageType() == ChatMessageType::Text) {
        const auto& textMessage = static_cast<const TextMessage&>(message);
        nlohmann::json payload = {
            {"priority", textMessage.priority == Priority::Interrupt ? "INTERRUPT" : (textMessage.priority == Priority::Append ? "APPEND" : "IGNORE")},
            {"interruptable", textMessage.interruptable},
            {"message", textMessage.text}
        };
        PublishToUserChannel(agentUserId, payload.dump(), "user.transcription", std::move(completion));
        return;
    }

    if (message.GetMessageType() == ChatMessageType::Image) {
        const auto& imageMessage = static_cast<const ImageMessage&>(message);
        nlohmann::json payload = {
            {"uuid", imageMessage.uuid},
            {"image_url", imageMessage.url},
            {"image_base64", imageMessage.base64}
        };
        PublishToUserChannel(agentUserId, payload.dump(), "image.upload", std::move(completion));
        return;
    }

    static const ConversationalAIAPIError error(ConversationalAIAPIErrorType::Unknown, -1, "unsupported chat message type");
    if (completion) {
        completion(&error);
    }
}

void ConversationalAIAPI::Interrupt(const std::string& agentUserId, std::function<void(const ConversationalAIAPIError*)> completion) {
    PublishToUserChannel(agentUserId, "{\"customType\":\"message.interrupt\"}", "message.interrupt", std::move(completion));
}

void ConversationalAIAPI::AddHandler(IConversationalAIAPIEventHandler* handler) {
    if (handler && std::find(m_handlers.begin(), m_handlers.end(), handler) == m_handlers.end()) {
        m_handlers.push_back(handler);
    }
}

void ConversationalAIAPI::RemoveHandler(IConversationalAIAPIEventHandler* handler) {
    auto it = std::find(m_handlers.begin(), m_handlers.end(), handler);
    if (it != m_handlers.end()) {
        m_handlers.erase(it);
    }
}

void ConversationalAIAPI::ClearCache() {
    m_transcriptCache.clear();
    m_hasInterruptEvent = false;
    m_hasStateChangeEvent = false;
    LOG_INFO("[ConversationalAIAPI] Cache cleared");
    NotifyDebugLog("[ConversationalAIAPI] Cache cleared");
}

void ConversationalAIAPI::LoadAudioSettings() {
    LoadAudioSettings(agora::rtc::AUDIO_SCENARIO_AI_CLIENT);
}

void ConversationalAIAPI::LoadAudioSettings(agora::rtc::AUDIO_SCENARIO_TYPE scenario) {
    m_audioScenario = scenario;
    if (m_config.rtcEngine) {
        m_config.rtcEngine->setAudioScenario(scenario);
        SetAudioConfigParameters();
        NotifyDebugLog("[ConversationalAIAPI] loadAudioSettings applied");
    } else {
        NotifyDebugLog("[ConversationalAIAPI] loadAudioSettings skipped: rtcEngine is null");
    }
}

void ConversationalAIAPI::SetAudioConfigParameters() {
    if (!m_config.rtcEngine) {
        return;
    }

    const char* audioParameters[] = {
        "{\"che.audio.aec.split_srate_for_48k\":16000}",
        "{\"che.audio.sf.enabled\":true}",
        "{\"che.audio.sf.stftType\":6}",
        "{\"che.audio.sf.ainlpLowLatencyFlag\":1}",
        "{\"che.audio.sf.ainsLowLatencyFlag\":1}",
        "{\"che.audio.sf.procChainMode\":1}",
        "{\"che.audio.sf.nlpDynamicMode\":1}",
        "{\"che.audio.sf.nlpAlgRoute\":1}",
        "{\"che.audio.sf.ainlpModelPref\":10}",
        "{\"che.audio.sf.nsngAlgRoute\":12}",
        "{\"che.audio.sf.ainsModelPref\":10}",
        "{\"che.audio.sf.nsngPredefAgg\":11}",
        "{\"che.audio.agc.enable\":false}"
    };

    for (const char* parameter : audioParameters) {
        const int result = m_config.rtcEngine->setParameters(parameter);
        NotifyDebugLog("[ConversationalAIAPI] setParameters ret=" + std::to_string(result) + " payload=" + parameter);
    }
}

void ConversationalAIAPI::SubscribeMessage(const std::string& channelName, std::function<void(const ConversationalAIAPIError*)> completion) {
    if (!m_config.rtmClient) {
        static const ConversationalAIAPIError error(ConversationalAIAPIErrorType::Unknown, -1, "rtmClient is not initialized");
        if (completion) {
            completion(&error);
        }
        return;
    }

    ClearCache();
    agora::rtm::SubscribeOptions options{};
    options.withMessage = true;
    options.withPresence = true;
    options.withMetadata = false;
    options.withLock = false;

    uint64_t requestId = 0;
    m_config.rtmClient->subscribe(channelName.c_str(), options, requestId);
    if (completion) {
        m_subscribeCallbacks[requestId] = std::move(completion);
    }
}

void ConversationalAIAPI::UnsubscribeMessage(const std::string& channelName, std::function<void(const ConversationalAIAPIError*)> completion) {
    if (!m_config.rtmClient) {
        static const ConversationalAIAPIError error(ConversationalAIAPIErrorType::Unknown, -1, "rtmClient is not initialized");
        if (completion) {
            completion(&error);
        }
        return;
    }

    uint64_t requestId = 0;
    m_config.rtmClient->unsubscribe(channelName.c_str(), requestId);
    if (completion) {
        m_unsubscribeCallbacks[requestId] = std::move(completion);
    }
}

void ConversationalAIAPI::OnSubscribeResult(uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode) {
    auto callbackIt = m_subscribeCallbacks.find(requestId);
    if (callbackIt == m_subscribeCallbacks.end()) {
        return;
    }

    auto completion = std::move(callbackIt->second);
    m_subscribeCallbacks.erase(callbackIt);

    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        if (completion) {
            completion(nullptr);
        }
        return;
    }

    const ConversationalAIAPIError error(
        ConversationalAIAPIErrorType::RtmError,
        static_cast<int>(errorCode),
        std::string("subscribe failed for channel=") + (channelName ? channelName : "")
    );
    if (completion) {
        completion(&error);
    }
}

void ConversationalAIAPI::OnPublishResult(uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode) {
    auto callbackIt = m_publishCallbacks.find(requestId);
    if (callbackIt == m_publishCallbacks.end()) {
        return;
    }

    auto completion = std::move(callbackIt->second);
    m_publishCallbacks.erase(callbackIt);

    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        if (completion) {
            completion(nullptr);
        }
        return;
    }

    const ConversationalAIAPIError error(
        ConversationalAIAPIErrorType::RtmError,
        static_cast<int>(errorCode),
        "publish failed"
    );
    if (completion) {
        completion(&error);
    }
}

void ConversationalAIAPI::OnUnsubscribeResult(uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode) {
    auto callbackIt = m_unsubscribeCallbacks.find(requestId);
    if (callbackIt == m_unsubscribeCallbacks.end()) {
        return;
    }

    auto completion = std::move(callbackIt->second);
    m_unsubscribeCallbacks.erase(callbackIt);

    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        if (completion) {
            completion(nullptr);
        }
        return;
    }

    const ConversationalAIAPIError error(
        ConversationalAIAPIErrorType::RtmError,
        static_cast<int>(errorCode),
        std::string("unsubscribe failed for channel=") + (channelName ? channelName : "")
    );
    if (completion) {
        completion(&error);
    }
}

std::string ConversationalAIAPI::GenerateCacheKey(int turnId, TranscriptType type) {
    // Use turnId + type as cache key
    return std::to_string(turnId) + "_" + std::to_string(static_cast<int>(type));
}

void ConversationalAIAPI::HandleSplitMessage(const std::string& message, const std::string& fromUserId) {
    std::string jsonString = m_messageParser.ParseStreamMessage(message);
    if (!jsonString.empty()) {
        ParseAndDispatchMessage(jsonString, fromUserId);
    }
}

void ConversationalAIAPI::HandleMessage(const std::string& jsonString, const std::string& fromUserId) {
    ParseAndDispatchMessage(jsonString, fromUserId);
}

void ConversationalAIAPI::ParseAndDispatchMessage(const std::string& jsonString, const std::string& userId) {
    try {
        json jsonValue = json::parse(jsonString);
        
        if (!jsonValue.is_object() || !jsonValue.contains("object")) {
            return;
        }

        std::string messageType = jsonValue["object"].get<std::string>();
        
        // Convert JSON to map for easier handling
        std::map<std::string, std::string> messageData;
        for (auto& [key, value] : jsonValue.items()) {
            if (value.is_string()) {
                messageData[key] = value.get<std::string>();
            } else if (value.is_number_integer()) {
                messageData[key] = std::to_string(value.get<int64_t>());
            } else if (value.is_number_float()) {
                messageData[key] = std::to_string(value.get<double>());
            } else if (value.is_boolean()) {
                messageData[key] = value.get<bool>() ? "true" : "false";
            }
        }

        LOG_INFO("[ConversationalAIAPI] Received message type: " + messageType);

        // Dispatch based on message type
        if (messageType == "assistant.transcription") {
            HandleAssistantMessage(userId, messageData);
        } else if (messageType == "user.transcription") {
            HandleUserMessage(userId, messageData);
        } else if (messageType == "message.interrupt") {
            HandleInterruptMessage(userId, messageData);
        } else if (messageType == "message.state") {
            HandleStateMessage(userId, messageData);
        } else if (messageType == "message.metrics") {
            HandleMetricsMessage(userId, messageData);
        } else if (messageType == "message.error") {
            std::string rawMessage = "";
            if (jsonValue.contains("message") && jsonValue["message"].is_string()) {
                rawMessage = jsonValue["message"].get<std::string>();
            }
            HandleErrorMessage(userId, rawMessage, messageData);
        } else {
            LOG_INFO("[ConversationalAIAPI] Unknown message type: " + messageType);
            NotifyDebugLog("[ConversationalAIAPI] Unknown message type: " + messageType);
        }

    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] Parse error: " + std::string(e.what()));
        NotifyDebugLog("[ConversationalAIAPI] Parse error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleAssistantMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        auto textIt = messageData.find("text");
        auto turnIdIt = messageData.find("turn_id");
        auto turnStatusIt = messageData.find("turn_status");
        auto userIdIt = messageData.find("user_id");
        
        // Ignore empty text
        if (textIt == messageData.end() || textIt->second.empty()) {
            LOG_INFO("[ConversationalAIAPI] assistant.transcription: empty text, ignored");
            return;
        }
        
        if (turnIdIt == messageData.end()) {
            return;
        }
        
        int turnId = std::stoi(turnIdIt->second);
        std::string text = textIt->second;
        std::string agentUserId = (userIdIt != messageData.end()) ? userIdIt->second : "";
        
        // Parse turn_status as int: 0=in-progress, 1=end, 2=interrupted
        TranscriptStatus status = TranscriptStatus::InProgress;
        if (turnStatusIt != messageData.end()) {
            int turnStatusInt = std::stoi(turnStatusIt->second);
            switch (turnStatusInt) {
                case 0: status = TranscriptStatus::InProgress; break;
                case 1: status = TranscriptStatus::End; break;
                case 2: status = TranscriptStatus::Interrupted; break;
                default: status = TranscriptStatus::Unknown; break;
            }
        }
        
        // Discard messages with Unknown status
        if (status == TranscriptStatus::Unknown) {
            LOG_INFO("[ConversationalAIAPI] assistant.transcription: unknown turn_status, ignored");
            return;
        }
        
        // Check if this turn was interrupted
        if (m_hasInterruptEvent && m_lastInterruptEvent.turnId == turnId) {
            LOG_INFO("[ConversationalAIAPI] assistant.transcription: turn " + std::to_string(turnId) + " was interrupted, ignored");
            return;
        }
        
        LOG_INFO("[ConversationalAIAPI] assistant.transcription: turnId=" + std::to_string(turnId) + 
                 ", text=\"" + text.substr(0, 50) + "...\", status=" + std::to_string(static_cast<int>(status)));
        
        // Update or add transcript using turnId + type as key
        std::string cacheKey = GenerateCacheKey(turnId, TranscriptType::Agent);
        
        auto it = m_transcriptCache.find(cacheKey);
        if (it != m_transcriptCache.end()) {
            it->second.text = text;
            it->second.status = status;
        } else {
            Transcript transcript(turnId, agentUserId, text, status, TranscriptType::Agent);
            m_transcriptCache[cacheKey] = transcript;
        }
        
        NotifyTranscriptUpdated(userId, m_transcriptCache[cacheKey]);
        
    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleAssistantMessage error: " + std::string(e.what()));
        NotifyDebugLog("[ConversationalAIAPI] HandleAssistantMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleUserMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        auto textIt = messageData.find("text");
        auto turnIdIt = messageData.find("turn_id");
        auto userIdIt = messageData.find("user_id");
        auto finalIt = messageData.find("final");
        
        // Ignore empty text
        if (textIt == messageData.end() || textIt->second.empty()) {
            LOG_INFO("[ConversationalAIAPI] user.transcription: empty text, ignored");
            return;
        }
        
        if (turnIdIt == messageData.end()) {
            return;
        }
        
        int turnId = std::stoi(turnIdIt->second);
        std::string text = textIt->second;
        std::string transcriptUserId = (userIdIt != messageData.end()) ? userIdIt->second : "";
        
        // Check final field
        bool isFinal = false;
        if (finalIt != messageData.end()) {
            isFinal = (finalIt->second == "true" || finalIt->second == "1");
        }
        TranscriptStatus status = isFinal ? TranscriptStatus::End : TranscriptStatus::InProgress;
        
        LOG_INFO("[ConversationalAIAPI] user.transcription: turnId=" + std::to_string(turnId) + 
                 ", text=\"" + text.substr(0, 50) + "...\", isFinal=" + (isFinal ? "true" : "false"));
        
        // Update or add transcript using turnId + type as key
        std::string cacheKey = GenerateCacheKey(turnId, TranscriptType::User);
        
        auto it = m_transcriptCache.find(cacheKey);
        if (it != m_transcriptCache.end()) {
            it->second.text = text;
            it->second.status = status;
        } else {
            Transcript transcript(turnId, transcriptUserId, text, status, TranscriptType::User);
            m_transcriptCache[cacheKey] = transcript;
        }
        
        NotifyTranscriptUpdated(userId, m_transcriptCache[cacheKey]);
        
    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleUserMessage error: " + std::string(e.what()));
        NotifyDebugLog("[ConversationalAIAPI] HandleUserMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleInterruptMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        auto turnIdIt = messageData.find("turn_id");
        auto startMsIt = messageData.find("start_ms");
        
        if (turnIdIt == messageData.end()) {
            return;
        }
        
        int turnId = std::stoi(turnIdIt->second);
        int64_t startMs = (startMsIt != messageData.end()) ? std::stoll(startMsIt->second) : 0;
        
        // Record interrupt event
        m_lastInterruptEvent = InterruptEvent(turnId, startMs);
        m_hasInterruptEvent = true;
        
        LOG_INFO("[ConversationalAIAPI] message.interrupt: turnId=" + std::to_string(turnId) + 
                 ", timestamp=" + std::to_string(startMs));
        
    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleInterruptMessage error: " + std::string(e.what()));
        NotifyDebugLog("[ConversationalAIAPI] HandleInterruptMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleStateMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        auto stateIt = messageData.find("state");
        auto turnIdIt = messageData.find("turn_id");
        auto tsMsIt = messageData.find("ts_ms");
        auto timestampIt = messageData.find("timestamp");
        
        if (stateIt == messageData.end()) {
            return;
        }
        
        int turnId = (turnIdIt != messageData.end()) ? std::stoi(turnIdIt->second) : 0;
        int64_t timestamp = 0;
        if (tsMsIt != messageData.end()) {
            timestamp = std::stoll(tsMsIt->second);
        } else if (timestampIt != messageData.end()) {
            timestamp = std::stoll(timestampIt->second);
        }
        
        // Filter outdated state updates
        if (m_hasStateChangeEvent) {
            // Check if turnId is less than current stateChangeEvent turnId
            if (turnId < m_lastStateChangeEvent.turnId) {
                return;
            }
            // Check if timestamp is less than or equal to current stateChangeEvent timestamp
            if (timestamp <= m_lastStateChangeEvent.timestamp) {
                return;
            }
        }
        
        std::string stateStr = stateIt->second;
        AgentState state = AgentState::Unknown;
        if (stateStr == "idle") state = AgentState::Idle;
        else if (stateStr == "silent") state = AgentState::Silent;
        else if (stateStr == "listening") state = AgentState::Listening;
        else if (stateStr == "thinking") state = AgentState::Thinking;
        else if (stateStr == "speaking") state = AgentState::Speaking;
        
        // Update last state change event
        m_lastStateChangeEvent = StateChangeEvent(state, turnId, timestamp);
        m_hasStateChangeEvent = true;
        
        LOG_INFO("[ConversationalAIAPI] message.state: state=" + stateStr + 
                 ", turnId=" + std::to_string(turnId) + ", timestamp=" + std::to_string(timestamp));
        
        NotifyStateChanged(userId, m_lastStateChangeEvent);
        
    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleStateMessage error: " + std::string(e.what()));
        NotifyDebugLog("[ConversationalAIAPI] HandleStateMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleMetricsMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        std::string module = "";
        auto moduleIt = messageData.find("module");
        if (moduleIt != messageData.end()) {
            module = moduleIt->second;
        }

        ModuleType metricType = ModuleTypeFromValue(module);
        if (metricType == ModuleType::Unknown && !module.empty()) {
            NotifyDebugLog("[ConversationalAIAPI] Unknown metric module: " + module);
        }

        std::string metricName = "unknown";
        auto metricNameIt = messageData.find("metric_name");
        if (metricNameIt != messageData.end() && !metricNameIt->second.empty()) {
            metricName = metricNameIt->second;
        }

        double latencyMs = 0.0;
        auto latencyIt = messageData.find("latency_ms");
        if (latencyIt != messageData.end()) {
            latencyMs = std::stod(latencyIt->second);
        }

        int64_t sendTs = 0;
        auto sendTsIt = messageData.find("send_ts");
        if (sendTsIt != messageData.end()) {
            sendTs = std::stoll(sendTsIt->second);
        }

        Metric metric(metricType, metricName, latencyMs, sendTs);
        LOG_INFO("[ConversationalAIAPI] message.metrics module=" + ModuleTypeToString(metric.type) +
                 ", name=" + metric.name + ", value=" + std::to_string(metric.value) +
                 ", timestamp=" + std::to_string(metric.timestamp));
        NotifyDebugLog("[ConversationalAIAPI] message.metrics module=" + ModuleTypeToString(metric.type) +
                       ", name=" + metric.name + ", value=" + std::to_string(metric.value) +
                       ", timestamp=" + std::to_string(metric.timestamp));
        NotifyAgentMetrics(userId, metric);
    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleMetricsMessage error: " + std::string(e.what()));
        NotifyDebugLog("[ConversationalAIAPI] HandleMetricsMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleErrorMessage(
    const std::string& userId,
    const std::string& rawMessage,
    const std::map<std::string, std::string>& messageData
) {
    try {
        std::string module = "";
        auto moduleIt = messageData.find("module");
        if (moduleIt != messageData.end()) {
            module = moduleIt->second;
        }

        int code = -1;
        auto codeIt = messageData.find("code");
        if (codeIt != messageData.end()) {
            code = std::stoi(codeIt->second);
        }

        int64_t timestamp = 0;
        auto tsIt = messageData.find("send_ts");
        if (tsIt != messageData.end()) {
            timestamp = std::stoll(tsIt->second);
        }

        std::string message = rawMessage.empty() ? "Unknown error" : rawMessage;

        ModuleError agentError(module, code, message, timestamp);
        LOG_ERROR("[ConversationalAIAPI] message.error module=" + module + ", code=" + std::to_string(code) + ", message=" + message);
        NotifyDebugLog("[ConversationalAIAPI] message.error module=" + module + ", code=" + std::to_string(code) + ", message=" + message);
        NotifyAgentError(userId, agentError);

        if (module == "context") {
            MessageError messageError(module, code, message, timestamp);
            NotifyMessageError(userId, messageError);
        }
    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleErrorMessage error: " + std::string(e.what()));
        NotifyDebugLog("[ConversationalAIAPI] HandleErrorMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::NotifyTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) {
    for (auto handler : m_handlers) {
        if (handler) {
            handler->OnTranscriptUpdated(agentUserId, transcript);
        }
    }
}

void ConversationalAIAPI::NotifyStateChanged(const std::string& agentUserId, const StateChangeEvent& event) {
    for (auto handler : m_handlers) {
        if (handler) {
            handler->OnAgentStateChanged(agentUserId, event);
        }
    }
}

void ConversationalAIAPI::NotifyAgentMetrics(const std::string& agentUserId, const Metric& metric) {
    for (auto handler : m_handlers) {
        if (handler) {
            handler->OnAgentMetrics(agentUserId, metric);
        }
    }
}

void ConversationalAIAPI::NotifyAgentError(const std::string& agentUserId, const ModuleError& error) {
    for (auto handler : m_handlers) {
        if (handler) {
            handler->OnAgentError(agentUserId, error);
        }
    }
}

void ConversationalAIAPI::NotifyMessageError(const std::string& agentUserId, const MessageError& error) {
    for (auto handler : m_handlers) {
        if (handler) {
            handler->OnMessageError(agentUserId, error);
        }
    }
}

void ConversationalAIAPI::NotifyDebugLog(const std::string& log) {
    EmitLog(m_handlers, log);
}

void ConversationalAIAPI::PublishToUserChannel(
    const std::string& userId,
    const std::string& message,
    const char* customType,
    std::function<void(const ConversationalAIAPIError*)> completion
) {
    if (!m_config.rtmClient) {
        static const ConversationalAIAPIError error(ConversationalAIAPIErrorType::Unknown, -1, "rtmClient is not initialized");
        if (completion) {
            completion(&error);
        }
        return;
    }

    agora::rtm::PublishOptions options{};
    options.messageType = agora::rtm::RTM_MESSAGE_TYPE_STRING;
    options.channelType = agora::rtm::RTM_CHANNEL_TYPE_USER;
    options.customType = customType;

    uint64_t requestId = 0;
    if (completion) {
        m_publishCallbacks[requestId] = std::move(completion);
    }
    m_config.rtmClient->publish(userId.c_str(), message.c_str(), message.size(), options, requestId);
}

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

ConversationalAIAPI::ConversationalAIAPI() 
    : m_hasInterruptEvent(false)
    , m_hasStateChangeEvent(false) {
    LOG_INFO("[ConversationalAIAPI] Initialized");
}

ConversationalAIAPI::~ConversationalAIAPI() {
    m_handlers.clear();
    m_transcriptCache.clear();
    LOG_INFO("[ConversationalAIAPI] Destroyed");
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
        } else {
            LOG_INFO("[ConversationalAIAPI] Unknown message type: " + messageType);
        }

    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] Parse error: " + std::string(e.what()));
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
    }
}

void ConversationalAIAPI::HandleStateMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        auto stateIt = messageData.find("state");
        auto turnIdIt = messageData.find("turn_id");
        auto tsMsIt = messageData.find("ts_ms");
        
        if (stateIt == messageData.end()) {
            return;
        }
        
        int turnId = (turnIdIt != messageData.end()) ? std::stoi(turnIdIt->second) : 0;
        int64_t timestamp = (tsMsIt != messageData.end()) ? std::stoll(tsMsIt->second) : 0;
        
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

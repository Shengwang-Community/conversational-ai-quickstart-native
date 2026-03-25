//
// ConversationalAIAPI.h: Simplified transcript parser
//
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <map>
#include <cstdint>

// Enums

enum class TranscriptStatus {
    InProgress = 0,
    End = 1,
    Interrupted = 2,
    Unknown = 3
};

enum class TranscriptType {
    Agent = 0,
    User = 1
};

enum class AgentState {
    Idle = 0,
    Silent = 1,
    Listening = 2,
    Thinking = 3,
    Speaking = 4,
    Unknown = 5
};

// Data Models

struct Transcript {
    int turnId;
    std::string userId;
    std::string text;
    TranscriptStatus status;
    TranscriptType type;
    
    Transcript() : turnId(0), status(TranscriptStatus::InProgress), type(TranscriptType::Agent) {}
    Transcript(int tid, const std::string& uid, const std::string& txt, TranscriptStatus st, TranscriptType tp)
        : turnId(tid), userId(uid), text(txt), status(st), type(tp) {}
};

struct StateChangeEvent {
    AgentState state;
    int turnId;
    int64_t timestamp;
    
    StateChangeEvent() : state(AgentState::Unknown), turnId(0), timestamp(0) {}
    StateChangeEvent(AgentState s, int tid, int64_t ts)
        : state(s), turnId(tid), timestamp(ts) {}
};

struct InterruptEvent {
    int turnId;
    int64_t timestamp;
    
    InterruptEvent() : turnId(0), timestamp(0) {}
    InterruptEvent(int tid, int64_t ts) : turnId(tid), timestamp(ts) {}
};

// Event Handler Protocol

class IConversationalAIAPIEventHandler {
public:
    virtual ~IConversationalAIAPIEventHandler() = default;
    virtual void OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event) = 0;
    virtual void OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) = 0;
};

// Message Parser - handles split messages

class MessageParser {
public:
    MessageParser();
    ~MessageParser();
    
    /// Parse stream message that may be split into multiple parts
    /// Message format: messageId|partIndex|totalParts|base64Content
    /// @return Parsed JSON string or empty if message is incomplete
    std::string ParseStreamMessage(const std::string& message);
    
    /// Clear expired messages
    void CleanExpiredMessages();

private:
    // Map<messageId, Map<partIndex, content>>
    std::map<std::string, std::map<int, std::string>> m_messageMap;
    std::map<std::string, int64_t> m_lastAccessMap;
    int64_t m_maxMessageAge;  // 5 minutes in milliseconds
    
    std::string Base64Decode(const std::string& encoded);
    int64_t GetCurrentTimeMs();
};

// ConversationalAI API - Simplified version

class ConversationalAIAPI {
public:
    ConversationalAIAPI();
    ~ConversationalAIAPI();
    
    void AddHandler(IConversationalAIAPIEventHandler* handler);
    void RemoveHandler(IConversationalAIAPIEventHandler* handler);
    
    /// Handle RTM message that may be split into parts (format: messageId|partIndex|totalParts|base64Content)
    /// Use this when RTM messages are split due to size limits
    void HandleSplitMessage(const std::string& message, const std::string& fromUserId);
    
    /// Handle RTM message that is already complete JSON
    /// Use this when RTM messages are not split
    void HandleMessage(const std::string& jsonString, const std::string& fromUserId);
    
    /// Clear all cached data
    void ClearCache();
    
private:
    void ParseAndDispatchMessage(const std::string& jsonString, const std::string& userId);
    void HandleAssistantMessage(const std::string& userId, const std::map<std::string, std::string>& messageData);
    void HandleUserMessage(const std::string& userId, const std::map<std::string, std::string>& messageData);
    void HandleInterruptMessage(const std::string& userId, const std::map<std::string, std::string>& messageData);
    void HandleStateMessage(const std::string& userId, const std::map<std::string, std::string>& messageData);
    void NotifyTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript);
    void NotifyStateChanged(const std::string& agentUserId, const StateChangeEvent& event);
    
    // Generate cache key using turnId + type
    std::string GenerateCacheKey(int turnId, TranscriptType type);
    
    std::vector<IConversationalAIAPIEventHandler*> m_handlers;
    std::map<std::string, Transcript> m_transcriptCache;
    
    // Message parser for split messages
    MessageParser m_messageParser;
    
    // Last interrupt event (for filtering interrupted turns)
    InterruptEvent m_lastInterruptEvent;
    bool m_hasInterruptEvent;
    
    // Last state change event (for filtering outdated state updates)
    StateChangeEvent m_lastStateChangeEvent;
    bool m_hasStateChangeEvent;
};

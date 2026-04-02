//
// ConversationalAIAPI.h: Simplified transcript parser
//
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <map>
#include <cstdint>
#include <IAgoraRtcEngine.h>
#include <IAgoraRtmClient.h>

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

struct MessageError {
    std::string module;
    int code;
    std::string message;
    int64_t timestamp;

    MessageError() : code(-1), timestamp(0) {}
    MessageError(const std::string& moduleName, int errorCode, const std::string& errorMessage, int64_t ts)
        : module(moduleName), code(errorCode), message(errorMessage), timestamp(ts) {}
};

struct ModuleError {
    std::string module;
    int code;
    std::string message;
    int64_t timestamp;

    ModuleError() : code(-1), timestamp(0) {}
    ModuleError(const std::string& moduleName, int errorCode, const std::string& errorMessage, int64_t ts)
        : module(moduleName), code(errorCode), message(errorMessage), timestamp(ts) {}
};

enum class ConversationalAIAPIErrorType {
    Unknown = 0,
    RtmError = 1
};

enum class Priority {
    Interrupt = 0,
    Append = 1,
    Ignore = 2
};

enum class ChatMessageType {
    Text = 0,
    Image = 1,
    Unknown = 2
};

struct ConversationalAIAPIError {
    ConversationalAIAPIErrorType type;
    int code;
    std::string message;

    ConversationalAIAPIError()
        : type(ConversationalAIAPIErrorType::Unknown), code(-1) {}

    ConversationalAIAPIError(ConversationalAIAPIErrorType errorType, int errorCode, const std::string& errorMessage)
        : type(errorType), code(errorCode), message(errorMessage) {}
};

class ChatMessage {
public:
    virtual ~ChatMessage() = default;
    virtual ChatMessageType GetMessageType() const = 0;
};

class TextMessage : public ChatMessage {
public:
    Priority priority;
    bool interruptable;
    std::string text;

    TextMessage(
        Priority messagePriority = Priority::Interrupt,
        bool responseInterruptable = true,
        const std::string& messageText = ""
    ) : priority(messagePriority), interruptable(responseInterruptable), text(messageText) {}

    ChatMessageType GetMessageType() const override { return ChatMessageType::Text; }
};

class ImageMessage : public ChatMessage {
public:
    std::string uuid;
    std::string url;
    std::string base64;

    ImageMessage(const std::string& imageUuid, const std::string& imageUrl = "", const std::string& imageBase64 = "")
        : uuid(imageUuid), url(imageUrl), base64(imageBase64) {}

    ChatMessageType GetMessageType() const override { return ChatMessageType::Image; }
};

struct ConversationalAIAPIConfig {
    agora::rtc::IRtcEngine* rtcEngine;
    agora::rtm::IRtmClient* rtmClient;
    bool enableLog;

    ConversationalAIAPIConfig(
        agora::rtc::IRtcEngine* rtc = nullptr,
        agora::rtm::IRtmClient* rtm = nullptr,
        bool shouldEnableLog = true
    ) : rtcEngine(rtc), rtmClient(rtm), enableLog(shouldEnableLog) {}
};

// Event Handler Protocol

class IConversationalAIAPIEventHandler {
public:
    virtual ~IConversationalAIAPIEventHandler() = default;
    virtual void OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event) = 0;
    virtual void OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) = 0;
    virtual void OnAgentError(const std::string& agentUserId, const ModuleError& error) {}
    virtual void OnMessageError(const std::string& agentUserId, const MessageError& error) {}
    virtual void OnDebugLog(const std::string& log) {}
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
    explicit ConversationalAIAPI(const ConversationalAIAPIConfig& config = {});
    ~ConversationalAIAPI();
    
    void AddHandler(IConversationalAIAPIEventHandler* handler);
    void RemoveHandler(IConversationalAIAPIEventHandler* handler);
    void Destroy();
    void Chat(const std::string& agentUserId, const ChatMessage& message, std::function<void(const ConversationalAIAPIError*)> completion);
    void Interrupt(const std::string& agentUserId, std::function<void(const ConversationalAIAPIError*)> completion);

    void LoadAudioSettings();
    void LoadAudioSettings(agora::rtc::AUDIO_SCENARIO_TYPE scenario);
    void SubscribeMessage(const std::string& channelName, std::function<void(const ConversationalAIAPIError*)> completion);
    void UnsubscribeMessage(const std::string& channelName, std::function<void(const ConversationalAIAPIError*)> completion);
    void OnPublishResult(uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode);
    void OnSubscribeResult(uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode);
    void OnUnsubscribeResult(uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode);
    
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
    void HandleErrorMessage(const std::string& userId, const std::string& rawMessage, const std::map<std::string, std::string>& messageData);
    void NotifyTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript);
    void NotifyStateChanged(const std::string& agentUserId, const StateChangeEvent& event);
    void NotifyAgentError(const std::string& agentUserId, const ModuleError& error);
    void NotifyMessageError(const std::string& agentUserId, const MessageError& error);
    void NotifyDebugLog(const std::string& log);
    void PublishToUserChannel(
        const std::string& userId,
        const std::string& message,
        const char* customType,
        std::function<void(const ConversationalAIAPIError*)> completion
    );
    
    // Generate cache key using turnId + type
    std::string GenerateCacheKey(int turnId, TranscriptType type);
    
    std::vector<IConversationalAIAPIEventHandler*> m_handlers;
    std::map<std::string, Transcript> m_transcriptCache;
    ConversationalAIAPIConfig m_config;
    agora::rtc::AUDIO_SCENARIO_TYPE m_audioScenario;
    std::map<uint64_t, std::function<void(const ConversationalAIAPIError*)>> m_publishCallbacks;
    std::map<uint64_t, std::function<void(const ConversationalAIAPIError*)>> m_subscribeCallbacks;
    std::map<uint64_t, std::function<void(const ConversationalAIAPIError*)>> m_unsubscribeCallbacks;
    
    // Message parser for split messages
    MessageParser m_messageParser;
    
    // Last interrupt event (for filtering interrupted turns)
    InterruptEvent m_lastInterruptEvent;
    bool m_hasInterruptEvent;
    
    // Last state change event (for filtering outdated state updates)
    StateChangeEvent m_lastStateChangeEvent;
    bool m_hasStateChangeEvent;

    void SetAudioConfigParameters();
};

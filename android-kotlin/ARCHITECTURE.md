# Architecture — Conversational AI Quickstart Android

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer (Activity)                   │
│  AgentChatActivity + XML Layout + ViewBinding           │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │
│  │Log Panel│ │Status Bar│ │Transcript│ │  Controls  │  │
│  └─────────┘ └──────────┘ └──────────┘ └────────────┘  │
│         ▲          ▲           ▲            │            │
│         └──────────┴───────────┴────────────┘            │
│                    StateFlow observation                  │
├─────────────────────────────────────────────────────────┤
│                ViewModel Layer                           │
│  AgentChatViewModel                                      │
│  ┌──────────────────────────────────────────────────┐   │
│  │ uiState: ConnectionState + isMuted               │   │
│  │ agentState: AgentState                            │   │
│  │ transcriptList: List<Transcript>                  │   │
│  │ debugLogList: List<String>                        │   │
│  └──────────────────────────────────────────────────┘   │
│         │              │              │                   │
│    RTC Engine     RTM Client    ConversationalAIAPI      │
├─────────────────────────────────────────────────────────┤
│              SDK & API Layer                              │
│  ┌──────────┐ ┌──────────┐ ┌────────────────────────┐   │
│  │ RTC SDK  │ │ RTM SDK  │ │ ConversationalAIAPI    │   │
│  │ (Audio)  │ │(Messaging)│ │(Event parsing+transcript│  │
│  └──────────┘ └──────────┘ │       +chat)            │   │
│         │              │   └────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│              Network Layer                               │
│  ┌──────────────┐  ┌──────────────┐                      │
│  │ AgentStarter  │  │TokenGenerator│                      │
│  │ (REST API)    │  │ (Demo Token) │                      │
│  └──────────────┘  └──────────────┘                      │
│         │                   │                            │
│    ShengWang REST API     Demo Token Service                 │
└─────────────────────────────────────────────────────────┘
```

## Module Dependencies

```
AgentChatActivity
    └── AgentChatViewModel
            ├── RtcEngineEx (ShengWang RTC SDK)
            ├── RtmClient (ShengWang RTM SDK)
            ├── ConversationalAIAPIImpl
            │       ├── RtcEngine (audio config)
            │       ├── RtmClient (message subscription/parsing)
            │       ├── MessageParser (JSON parsing)
            │       └── TranscriptController (transcript rendering)
            ├── AgentStarter (REST API calls)
            │       └── SecureOkHttpClient (OkHttp config)
            └── TokenGenerator (Token generation)
                    └── SecureOkHttpClient

KeyCenter (BuildConfig → constant mapping)
    └── Referenced by AgentStarter / TokenGenerator / ViewModel
```

## Core Data Flows

### 1. Connection Flow (User taps Start Agent)

```
User taps Start Agent
    │
    ▼
Check microphone permission
    │
    ▼
generateUserToken()  ──→  TokenGenerator  ──→  Demo Token Service
    │                                              │
    ▼                                              ▼
joinRtcChannel(token)                        Returns unified token
    │                                         (shared by RTC + RTM)
    ▼
loginRtm(token)
    │
    ▼
Both ready (rtcJoined && rtmLoggedIn)
    │
    ├── subscribeMessage(channelName)  ──→  RTM subscribe to channel
    │
    ├── generateTokensAsync(agentUid)  ──→  agentToken
    │
    ├── generateTokensAsync(agentUid)  ──→  authToken (REST API auth)
    │
    └── AgentStarter.startAgentAsync()
            │
            ▼
        POST /v2/projects/{appId}/join/
        Authorization: agora token=<authToken>
        Body: {
          name, properties: {
            channel, token, agent_rtc_uid,
            remote_rtc_uids: ["*"],
            enable_string_uid: true,
            idle_timeout: 120,
            advanced_features: { enable_rtm: true },
            asr: { vendor: "fengming", language: "zh-CN" },
            llm: { vendor: "aliyun", url, api_key, system_messages, greeting_message, failure_message, params: { model } },
            tts: { vendor: "bytedance", params: { token, app_id, cluster, voice_type, speed_ratio, volume_ratio, pitch_ratio, emotion } },
            parameters: { data_channel: "rtm", enable_error_message: true }
          }
        }
            │
            ▼
        Returns agent_id → saved to ViewModel
```

### 2. Real-time Communication Data Flow

```
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│ User Device  │ RTC Audio│ ShengWang Cloud│ RTC Audio│  AI Agent    │
│              │ ◄───────►│              │ ◄───────►│              │
│  RTC Engine  │          │  RTC Service │          │  RTC Client  │
└──────────────┘          └──────────────┘          └──────────────┘

┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│ User Device  │ RTM Msg  │ ShengWang Cloud│ RTM Msg  │  AI Agent    │
│              │ ◄───────►│              │ ◄───────►│              │
│  RTM Client  │          │  RTM Service │          │  RTM Client  │
└──────────────┘          └──────────────┘          └──────────────┘
```

### 3. ConversationalAIAPI Event Callbacks

RTM message subscription, parsing, and dispatching are encapsulated in ConversationalAIAPI. The business layer only needs to register callbacks:

```
ConversationalAIAPI (handles RTM messages internally)
    │
    ▼
IConversationalAIAPIEventHandler callbacks:
    │
    ├── onAgentStateChanged()          → Agent state change (IDLE/LISTENING/THINKING/SPEAKING/SILENT)
    ├── onTranscriptUpdated()          → Transcript content update (Word/Text mode)
    ├── onAgentMetrics()               → Performance metrics (LLM/MLLM/TTS latency, etc.)
    ├── onAgentError()                 → Agent module error (ModuleError: type + code + message)
    ├── onAgentInterrupted()           → Agent interrupted (InterruptEvent: turnId + timestamp)
    ├── onMessageError()               → Message send error (MessageError: chatMessageType + code)
    ├── onMessageReceiptUpdated()      → Message receipt (MessageReceipt: type + chatMessageType + turnId)
    ├── onAgentVoiceprintStateChanged()→ Voiceprint state change (VoiceprintStatus enum)
    └── onDebugLog()                   → Debug log
    │
    ▼
ViewModel updates StateFlow → Activity observes → UI update
```

### 4. Message Sending

```
User sends message:
    │
    ├── TextMessage(priority, responseInterruptable, text)
    │       → chat(agentUserId, textMessage) → sent via RTM
    │
    ├── ImageMessage(uuid, imageUrl / imageBase64)
    │       → chat(agentUserId, imageMessage) → sent via RTM
    │       ⚠️ imageBase64 total message < 32KB (RTM limit)
    │
    └── interrupt(agentUserId) → interrupt Agent's current speech
```

### 5. Transcript Data Flow

```
RTM message (assistant.transcription / user.transcription)
    │
    ▼
TranscriptController
    │
    ├── Parse turn_id, text, status, type
    ├── Word mode: word-by-word rendering
    ├── Text mode: full-text rendering
    │
    ▼
IConversationTranscriptCallback.onTranscriptUpdated()
    │
    ▼
ConversationalAIAPIEventHandler.onTranscriptUpdated()
    │
    ▼
ViewModel.addTranscript(transcript)
    │
    ├── Deduplicate/update by turnId + type
    │
    ▼
_transcriptList StateFlow update
    │
    ▼
Activity RecyclerView refresh
    │
    ├── TranscriptType.AGENT → left-aligned bubble + "AI" avatar
    └── TranscriptType.USER  → right-aligned bubble + "Me" avatar
```

## Token Flow

The project generates tokens three times, all via Demo Token Service (`TokenGenerator.generateTokensAsync`):

| Token | Purpose | Generation Params | Usage |
|-------|---------|-------------------|-------|
| userToken | User joins RTC channel + logs in RTM | `uid=userId`, `channelName=""` | `joinRtcChannel()` / `loginRtm()` |
| agentToken | Agent's credential to join RTC channel | `uid=agentUid`, `channelName=current channel` | startAgent request body `properties.token` |
| authToken | REST API request authentication | `uid=agentUid`, `channelName=current channel` | Request header `Authorization: agora token=<authToken>` |

> Note: `userId` and `agentUid` are randomly generated (100000-999999) in `AgentChatViewModel.companion`, guaranteed unique. agentToken and authToken share the same generation params; they are generated separately for semantic clarity. userToken's channelName is an empty string, producing a channel-unbound universal Token.

```
TokenGenerator.generateTokensAsync()
    │
    ▼
POST https://service.apprtc.cn/toolbox/v2/token/generate
Body: { appId, appCertificate, channelName, uid, types: [1,2], expire }
    │
    ▼
Response: { code: 0, data: { token: "007..." } }
```

> ⚠️ Demo Token Service is for development/testing only. Production must use your own server for token generation.

## Agent Lifecycle

```
                    ┌─────────┐
                    │  IDLE   │
                    └────┬────┘
                         │ startAgent()
                         ▼
                    ┌─────────┐
                    │LISTENING│◄──────────────┐
                    └────┬────┘               │
                         │ Voice detected     │ TTS playback complete
                         ▼                    │
                    ┌─────────┐          ┌────┴────┐
                    │THINKING │─────────►│SPEAKING │
                    └─────────┘ LLM resp └────┬────┘
                                              │ User interrupts
                                              ▼
                                         ┌─────────┐
                                         │ SILENT  │
                                         └────┬────┘
                                              │
                                              ▼
                                         Back to LISTENING
```

State is transmitted via RTM messages. `_agentState: MutableStateFlow<AgentState>` in ViewModel drives UI updates.

Idle timeout: `idle_timeout: 120` seconds — Agent auto-disconnects after no interaction.

## Resource Cleanup

### hangup() (User-initiated stop)

```
1. unsubscribeMessage(channelName)    ← RTM unsubscribe
2. AgentStarter.stopAgentAsync()      ← REST API stop Agent
3. leaveRtcChannel()                  ← Leave RTC channel
4. Reset state: agentId=null, authToken=null, connectionState=Idle,
                transcriptList=empty, agentState=IDLE
```

### onCleared() (ViewModel destroyed)

```
1. leaveRtcChannel()
2. logoutRtm()
3. removeEventListener(rtmEventListener)
4. rtcEngine=null, rtmClient=null
```

### ConversationalAIAPI.destroy()

```
1. removeHandler(covRtcHandler)       ← Remove RTC callback
2. removeEventListener(covRtmMsgProxy) ← Remove RTM listener
3. unSubscribeAll()                    ← Clear all event subscriptions
4. transcriptController.release()      ← Release transcript controller
```

## Configuration Injection

```
env.properties (git ignored)
    │
    ▼ Gradle buildConfigField
    │
BuildConfig.AGORA_APP_ID / LLM_API_KEY / TTS_BYTEDANCE_TOKEN / ...
    │
    ▼
KeyCenter (constant mapping)
    │
    ├── AgentStarter (builds REST API request body: full STT/LLM/TTS config)
    └── TokenGenerator (generates Token: appId + appCertificate)
```

See the "Configuration Fields" section in `AGENTS.md` for the full list.

## Threading Model

| Operation | Thread | Notes |
|-----------|--------|-------|
| Token generation / REST API calls | `Dispatchers.IO` | OkHttp synchronous calls |
| RTM callbacks | RTM internal thread | Switched to main via `viewModelScope.launch` |
| RTC callbacks | RTC internal thread | Switched to main via `viewModelScope.launch` |
| StateFlow updates | Main | Unified on main thread in ViewModel |
| UI observation | Main | `lifecycleScope.launch` collects StateFlow |

## Audio Configuration

`ConversationalAIAPI.loadAudioSettings()` is called during init (before joinChannel):

- Scenario: `AUDIO_SCENARIO_AI_CLIENT` (optimized for AI conversation); Avatar mode uses `AUDIO_SCENARIO_DEFAULT`
- AI noise reduction: loads `ai_echo_cancellation_extension` + `ai_noise_suppression_extension`
- Audio params: dynamically adjusted AEC/NS based on audio route (speaker/headset/bluetooth)
- Auto-reconfigured on route change (`onAudioRouteChanged` callback)

## ConversationalAIAPI Data Models

### Message Types

| Type | Class | Description |
|------|-------|-------------|
| Text | `TextMessage` | priority + responseInterruptable + text |
| Image | `ImageMessage` | uuid + imageUrl / imageBase64 (< 32KB) |

### Priority

| Level | Behavior |
|-------|----------|
| `INTERRUPT` | Immediately interrupt current interaction |
| `APPEND` | Queue until current interaction completes |
| `IGNORE` | Process only when Agent is idle, otherwise discard |

### Voiceprint Status (VoiceprintStatus)

`DISABLE` → `UNREGISTER` → `REGISTERING` → `REGISTER_SUCCESS` / `REGISTER_FAIL` / `REGISTER_DUPLICATE`

### Transcript Status (TranscriptStatus)

`IN_PROGRESS` → `END` / `INTERRUPTED`

## Documentation Navigation

| Document | Description |
|----------|-------------|
| AGENTS.md | AI Agent development guidelines and project constraints |
| ARCHITECTURE.md | This document — technical architecture details |
| README.md | Quick start and usage guide |

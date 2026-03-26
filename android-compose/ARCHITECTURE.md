# Architecture — Conversational AI Quickstart Android Compose

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────┐
│                UI Layer (Compose)                       │
│  MainActivity + AgentChatScreen                         │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │
│  │Log Panel│ │Status Bar│ │Transcript│ │  Controls  │  │
│  └─────────┘ └──────────┘ └──────────┘ └────────────┘  │
│                StateFlow / SharedFlow collection        │
├─────────────────────────────────────────────────────────┤
│                ViewModel Layer                          │
│  AgentChatViewModel                                     │
│  ┌──────────────────────────────────────────────────┐   │
│  │ uiState: ConnectionState + isMuted               │   │
│  │ agentState: AgentState                           │   │
│  │ transcriptList: List<Transcript>                 │   │
│  │ debugLogList: List<String>                       │   │
│  │ agentError: SharedFlow<ModuleError>              │   │
│  └──────────────────────────────────────────────────┘   │
│         │              │              │                  │
│    RTC Engine     RTM Client    ConversationalAIAPI     │
├─────────────────────────────────────────────────────────┤
│              SDK & API Layer                            │
│  ┌──────────┐ ┌──────────┐ ┌────────────────────────┐  │
│  │ RTC SDK  │ │ RTM SDK  │ │ ConversationalAIAPI    │  │
│  │ (Audio)  │ │(Messaging)│ │(Event parsing+transcript│ │
│  └──────────┘ └──────────┘ │       +chat)            │  │
│         │              │   └────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│              Network Layer                              │
│  ┌──────────────┐  ┌──────────────┐                     │
│  │ AgentStarter │  │TokenGenerator│                     │
│  │ (REST API)   │  │ (Demo Token) │                     │
│  └──────────────┘  └──────────────┘                     │
│         │                   │                           │
│   ShengWang REST API    Demo Token Service              │
└─────────────────────────────────────────────────────────┘
```

## Module Dependencies

```text
MainActivity
    └── AgentChatScreen
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

```text
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
            tts: { vendor: "bytedance", params: { token, app_id, cluster, voice_type, speed_ratio, volume_ratio, pitch_ratio } },
            parameters: { data_channel: "rtm", enable_error_message: true }
          }
        }
            │
            ▼
        Returns agent_id → saved to ViewModel
```

### 2. Real-time Communication Data Flow

```text
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

RTM message subscription, parsing, and dispatching are encapsulated in `ConversationalAIAPI`. The business layer only needs to register callbacks:

```text
ConversationalAIAPI (handles RTM messages internally)
    │
    ▼
IConversationalAIAPIEventHandler callbacks:
    │
    ├── onAgentStateChanged()          → Agent state change (IDLE/LISTENING/THINKING/SPEAKING/SILENT)
    ├── onTranscriptUpdated()          → Transcript content update
    ├── onAgentMetrics()               → Performance metrics
    ├── onAgentError()                 → Agent module error
    ├── onAgentInterrupted()           → Agent interrupted
    ├── onMessageError()               → Message send error
    ├── onMessageReceiptUpdated()      → Message receipt
    ├── onAgentVoiceprintStateChanged()-> Voiceprint state change
    └── onDebugLog()                   → Debug log
    │
    ▼
ViewModel updates StateFlow / SharedFlow
    │
    ▼
Compose collects state → UI recomposition
```

### 4. Transcript Data Flow

```text
RTM message (assistant.transcription / user.transcription)
    │
    ▼
TranscriptController
    │
    ├── Parse turn_id, text, status, type
    ├── Word mode: incremental rendering
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
AgentChatScreen recomposes
    │
    ├── TranscriptType.AGENT → left-aligned bubble + "AI" avatar
    └── TranscriptType.USER  → right-aligned bubble + "Me" avatar
```

### 5. UI State Rendering Flow

```text
ViewModel state update
    │
    ├── uiState        → Start / Connecting / Retry / Mute / Stop buttons
    ├── agentState     → bottom status dot + text color
    ├── transcriptList → transcript card content
    ├── debugLogList   → log card content
    └── agentError     → toast feedback
```

## Token Flow

The project generates tokens three times, all via Demo Token Service (`TokenGenerator.generateTokensAsync`):

| Token | Purpose | Generation Params | Usage |
|-------|---------|-------------------|-------|
| userToken | User joins RTC channel + logs in RTM | `uid=userId`, `channelName=""` | `joinRtcChannel()` / `loginRtm()` |
| agentToken | Agent's credential to join RTC channel | `uid=agentUid`, `channelName=current channel` | startAgent request body `properties.token` |
| authToken | REST API request authentication | `uid=agentUid`, `channelName=current channel` | Request header `Authorization: agora token=<authToken>` |

> Note: `userId` and `agentUid` are randomly generated (6-digit integers) in `AgentChatViewModel.companion`. `agentToken` and `authToken` share the same generation params but are generated separately for semantic clarity. `userToken` uses an empty `channelName`, producing a universal token for the current demo flow.

```text
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

```text
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

### Hangup Path

When the user taps `Stop Agent`:

- Unsubscribe RTM message channel via `conversationalAIAPI.unsubscribeMessage()`
- Stop Agent via `AgentStarter.stopAgentAsync(agentId, authToken)`
- Leave RTC channel
- Reset:
  - `connectionState`
  - `transcriptList`
  - `agentState`
  - `authToken`

### ViewModel onCleared()

When the screen is destroyed:

- Leave RTC channel
- Logout RTM
- Remove RTM event listener
- Clear local RTC / RTM references

`RtcEngine.destroy()` is still intentionally not called in this quickstart; the current implementation only nulls references on cleanup.

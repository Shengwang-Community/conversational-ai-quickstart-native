# Conversational AI Quickstart macOS Swift — AI Assistant Guide

## How to Use This Project

This is a complete, runnable macOS demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly. Modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, ConversationalAIAPI integration) and adapt them into the existing codebase.

## How to Switch AI Providers

The STT/LLM/TTS vendor configuration lives in two places that must be changed together:

1. `VoiceAgent/KeyCenter.swift` — API keys and user-configurable IDs
2. `VoiceAgent/ViewController.swift` → `startAgent()` — the parameter dictionary that specifies vendor names and maps `KeyCenter` values into the request body

To switch a provider:
- Change the `"vendor"` value in the `startAgent()` dictionary
- Update the `"params"` sub-dictionary to match the new vendor's required fields
- Add/update the corresponding values in `KeyCenter.swift`

Supported vendors for STT/TTS/LLM change over time. Refer to the [创建对话式智能体 API 文档](https://doc.shengwang.cn/doc/convoai/restful/convoai/operations/start-agent) for the up-to-date list of supported vendors and their required parameters.

LLM: Any OpenAI-compatible API — change `LLM_URL` and `LLM_MODEL` in `KeyCenter.swift`.

## Project Overview

Conversational AI Quickstart — macOS real-time voice conversation desktop client.

The client directly calls ShengWang RESTful API to start/stop Agent, with STT, LLM, and TTS configuration embedded in the request body, authenticated via HTTP token (`Authorization: agora token=<token>`). The current implementation uses the user RTC/RTM token as the REST auth token. This auth mode requires APP_CERTIFICATE to be enabled.

Current quickstart scope is limited to voice session startup, transcript display, state rendering, mute, and stop. It does not expose text or image message sending UI.

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Swift |
| UI Framework | AppKit + programmatic views + SnapKit |
| App Structure | `AppDelegate` + single `ViewController` |
| Build Tool | Xcode + CocoaPods |
| State Management | `ViewController` instance state |
| Networking | `URLSession` |
| RTC SDK | ShengWang RTC SDK (`ShengwangRtcEngine_macOS` 4.6.0) |
| RTM SDK | ShengWang RTM SDK (`AgoraRtm/RtmKit` 2.2.6) |
| ConversationalAIAPI | Built-in module, do not modify |

For runtime structure, see `ARCHITECTURE.md`. For entry files, see `README.md`.

## Core Modules

### ViewController

- Main controller for the whole desktop demo
- Manages `ConnectionStartView`, `ChatSessionView`, and `LogView`
- Holds session state directly as instance properties:
  - `channelName`, `userToken`, `agentToken`, `agentId`
  - `userUid`, `agentUid`
  - `transcripts`, `isMuted`, `rtmLoggedIn`, `isActive`
- Auto flow: generate user token → login RTM → join RTC → subscribe ConvoAI → generate agent token → start agent
- Random channel name format is `channel_macos_<6-digit-random>`

### AgentManager

- `startAgent()`: POST `/join/`, request body carries full pipeline config
  - STT: Fengming ASR
  - LLM: Aliyun-compatible configuration pointing to the DeepSeek OpenAI-compatible endpoint
  - TTS: ByteDance / Volcengine
  - Advanced features: `enable_rtm: true`, `enable_string_uid: true`, `idle_timeout: 120`
  - Remote UIDs: `remote_rtc_uids: ["*"]`
- `stopAgent()`: POST `/agents/{agentId}/leave`
- Authentication: `Authorization: agora token=<userToken>`

### NetworkManager (Demo Only)

- Generates RTC/RTM tokens via demo service at `https://service.apprtc.cn/toolbox/v2/token/generate`
- Sends `appId`, `appCertificate`, `channelName`, `uid`, `types` (1=RTC, 2=RTM) in POST body
- Returns a unified token usable for both RTC and RTM
- **Requires APP_CERTIFICATE**: the demo token service needs `appCertificate` to generate valid tokens
- Also wraps generic JSON HTTP POST/GET requests used by `AgentManager`
- Demo only — production must use your own backend for token generation

### ConversationalAIAPI

- Wraps RTM message subscription/parsing
- The quickstart currently reacts to:
  - `onAgentStateChanged`
  - `onTranscriptUpdated`
  - `onAgentError`
- Render mode is `.words`
- Initialized after both RTC and RTM engines are ready

## Configuration

### Configuration Flow

```
KeyCenter.swift → ViewController / AgentManager / NetworkManager
```

Static credentials are read directly from `KeyCenter.swift`. `ViewController` builds the start-agent payload from those values, while `NetworkManager` uses `APP_ID` + `APP_CERTIFICATE` for demo token generation.

### Configuration Fields (KeyCenter.swift)

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `AGORA_APP_ID` | ShengWang App ID | ✅ | — |
| `AGORA_APP_CERTIFICATE` | ShengWang App Certificate (must be enabled) | ✅ | — |
| `LLM_API_KEY` | DeepSeek API Key | ✅ | — |
| `LLM_URL` | OpenAI-compatible endpoint URL | | `https://api.deepseek.com/v1/chat/completions` |
| `LLM_MODEL` | Model name | | `deepseek-chat` |
| `TTS_BYTEDANCE_APP_ID` | Volcengine TTS App ID | ✅ | — |
| `TTS_BYTEDANCE_TOKEN` | Volcengine TTS access token | ✅ | — |

### APP_CERTIFICATE Must Be Enabled

This project uses HTTP token auth (`Authorization: agora token=<token>`) for REST API calls, and the demo token service sends `appCertificate` to generate valid RTC/RTM tokens. Both require the App Certificate to be enabled.

Make sure to:
1. Enable the primary certificate for your App ID in the [ShengWang Console](https://console.shengwang.cn/)
2. Fill in the certificate value in `KeyCenter.swift` under `AGORA_APP_CERTIFICATE`

### Build-Time Validation

There is no automatic build-time validation in this target. Missing or invalid values in `KeyCenter.swift` usually fail at runtime during token generation, SDK initialization, or REST calls.

## API Endpoints

Client directly calls ShengWang REST API (Demo mode):

| Endpoint | Method | Auth Header | Description |
|----------|--------|-------------|-------------|
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/join/` | POST | `Authorization: agora token=<userToken>` | Start Agent |
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | `Authorization: agora token=<userToken>` | Stop Agent |

Token generated via Demo service (must be replaced with your own backend in production):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `service.apprtc.cn/toolbox/v2/token/generate` | POST | Generate RTC/RTM Token (requires appId + appCertificate) |

If you need to point to a different backend, change the URL strings in `VoiceAgent/Tools/AgentManager.swift` and `VoiceAgent/Tools/NetworkManager.swift`.

### Start Agent Request Body Structure

```json
{
  "name": "agent_<channel>_<agentUid>_<timestamp>",
  "properties": {
    "channel": "<channel>",
    "token": "<agentToken>",
    "agent_rtc_uid": "<agentUid>",
    "remote_rtc_uids": ["*"],
    "enable_string_uid": true,
    "idle_timeout": 120,
    "advanced_features": { "enable_rtm": true },
    "asr": {
      "vendor": "fengming",
      "language": "zh-CN"
    },
    "llm": {
      "vendor": "aliyun",
      "url": "<LLM_URL>",
      "api_key": "<LLM_API_KEY>",
      "system_messages": [{ "role": "system", "content": "You are a helpful AI assistant." }],
      "greeting_message": "Hello! I am your AI assistant. How can I help you today?",
      "failure_message": "Sorry, I am not able to process your request right now. Please try again later.",
      "params": { "model": "<LLM_MODEL>" }
    },
    "tts": {
      "vendor": "bytedance",
      "params": {
        "token": "<TTS_BYTEDANCE_TOKEN>",
        "app_id": "<TTS_BYTEDANCE_APP_ID>",
        "cluster": "volcano_tts",
        "voice_type": "BV700_streaming",
        "speed_ratio": 1.0,
        "volume_ratio": 1.0,
        "pitch_ratio": 1.0
      }
    },
    "parameters": { "data_channel": "rtm", "enable_error_message": true }
  }
}
```

### Token Generation Request Body

```json
{
  "appId": "<AGORA_APP_ID>",
  "appCertificate": "<AGORA_APP_CERTIFICATE>",
  "channelName": "<channel>",
  "uid": "<uid>",
  "types": [1, 2],
  "expire": 86400,
  "src": "iOS",
  "ts": 0
}
```

## Data Flow

```
User Action → ViewController → ShengWang SDK (RTC/RTM)
                  ↓
        ConversationalAIAPI callbacks
                  ↓
       ViewController property update
                  ↓
             AppKit view update
```

## Event Flow

1. User taps Start Agent → `channelName` is generated in `ViewController`
2. Generate `userToken` for the current channel and current `userUid`
3. Login RTM with `userToken`
4. Join RTC channel with `userToken`
5. On RTC join success, subscribe to ConvoAI RTM messages for `channelName`
6. Generate `agentToken` for `agentUid`
7. Call `AgentManager.startAgent(parameter, userToken)` to start Agent
8. ConversationalAIAPI receives agent state / transcript events via RTM → `ViewController` updates desktop UI
9. User taps Stop Agent → unsubscribe ConvoAI → stop agent → leave RTC → logout RTM → clear local state

## How to Change Request Parameters

The agent start request body is built in `VoiceAgent/ViewController.swift` → `startAgent()` as a nested dictionary. Key sections:

| Section | What it controls | Where in the dictionary |
|---------|------------------|-------------------------|
| `asr` | Speech-to-text vendor, language, credentials | `properties.asr` |
| `llm` | LLM endpoint, model, system prompt, greeting/failure messages | `properties.llm` |
| `tts` | Text-to-speech vendor, voice, speed | `properties.tts` |
| `parameters` | Data channel (`rtm`), error message toggle | `properties.parameters` |
| `advanced_features` | RTM enable flag | `properties.advanced_features` |
| Top-level | Channel name, agent UID, idle timeout, token | `properties.*` |

To modify request parameters: edit the `parameter` dictionary in `startAgent()`. Static values should stay in `KeyCenter.swift`; structural changes should be made in the dictionary itself.

## Key Constraints

1. **APP_CERTIFICATE required**: This project uses token-based REST auth and demo token generation. `AGORA_APP_CERTIFICATE` must be enabled in the ShengWang console and configured in `KeyCenter.swift`.
2. **Demo Mode**: Config is stored in `KeyCenter.swift`; the client directly calls REST API and the demo token service.
3. **Production**: Sensitive info (`appCertificate`, LLM/STT/TTS keys) must move to your backend; the client should only fetch token/session info from your own server.
4. **Token Generation**: `NetworkManager.generateToken()` is demo-only; production must use your own server.
5. **Resource Cleanup**: RTC leave, RTM logout, ConvoAI unsubscribe, and local UI state reset all happen during `stopSession()`.
6. **Permissions**: The app requires microphone access for voice conversation, and `NSMicrophoneUsageDescription` is configured in `VoiceAgent/Info.plist`.
7. **ConversationalAIAPI is read-only**: All files under `VoiceAgent/ConversationalAIAPI/` are standalone components — **do not modify directly**. To reuse in other projects, copy the entire directory.
8. **Workspace Setup**: `KeyCenter.swift` is local configuration. Keep using `KeyCenter.swift.example` as the template when setting up a fresh checkout.

## File Naming

- Swift source files: `PascalCase.swift`
- AppKit view classes: `*View.swift`, `*Cell.swift`, `ViewController.swift`
- Utility files: `*Manager.swift`, `KeyCenter.swift`

## Documentation Navigation

| Document | Description |
|----------|-------------|
| AGENTS.md | AI Agent development guidelines and project constraints |
| ARCHITECTURE.md | Technical architecture details (modules, state ownership, runtime flow) |
| README.md | Quick start and usage guide |

# Conversational AI Quickstart iOS Objective-C — AI Assistant Guide

## How to Use This Project

This is a complete, runnable iOS Objective-C demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly. Modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, ConversationalAIAPI integration) and adapt them into the existing codebase.

## How to Switch AI Providers

The STT/LLM/TTS vendor configuration lives in two places that must be changed together:

1. `KeyCenter.h/.m` — API keys and user-configurable IDs
2. `ViewController.m` → `startAgentParameter` — the parameter dictionary that specifies vendor names and maps `KeyCenter` values into the request body

To switch a provider:
- Change the `"vendor"` value in `startAgentParameter`
- Update the `"params"` sub-dictionary to match the new vendor's required fields
- Add/update the corresponding values in `KeyCenter.m`

Supported vendors for STT/TTS/LLM change over time. Refer to the [创建对话式智能体 API 文档](https://doc.shengwang.cn/doc/convoai/restful/convoai/operations/start-agent) for the up-to-date list of supported vendors and their required parameters.

LLM: Any OpenAI-compatible API — change `LLM_URL` and `LLM_MODEL` in `KeyCenter.m`.

## Project Overview

Conversational AI Quickstart — iOS real-time voice conversation client built with Objective-C and UIKit.

The client directly calls ShengWang RESTful API to start/stop Agent, with STT, LLM, and TTS configuration embedded in the request body, authenticated via HTTP token (`Authorization: agora token=<token>`). This implementation generates a dedicated `authToken` before the REST start/stop call. This auth mode requires APP_CERTIFICATE to be enabled.

Current quickstart scope is limited to voice session startup, transcript display, state rendering, mute, and stop. It does not expose text or image message sending UI.

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Objective-C |
| UI Framework | UIKit + programmatic views + Masonry |
| App Structure | `main.m` + `AppDelegate` + `SceneDelegate` + single `ViewController` |
| Build Tool | Xcode + CocoaPods |
| State Management | `ViewController` instance properties |
| Networking | `NSURLSession` |
| RTC SDK | ShengWang RTC SDK (`AgoraRtcEngine_iOS` 4.5.1) |
| RTM SDK | ShengWang RTM SDK (`AgoraRtm/RtmKit` 2.2.6) |
| ConversationalAIAPI | Built-in Swift module bridged into Objective-C, do not modify |

For runtime structure, see `ARCHITECTURE.md`. For entry files, see `README.md`.

## Core Modules

### ViewController

- Main controller for the whole demo
- Manages `ConnectionStartView`, `ChatSessionView`, and the always-visible debug log panel
- Holds session state directly as Objective-C properties:
  - `channel`, `userToken`, `agentToken`, `authToken`, `agentId`
  - `uid`, `agentUid`
  - `transcripts`, `isMicMuted`, `currentAgentState`, `rtcJoined`, `rtmLoggedIn`
- Auto flow: generate user token → login RTM → join RTC → subscribe ConvoAI → generate agent token → generate auth token → start agent
- Random channel name format is `channel_oc_<6-digit-random>`

### AgentManager

- `startAgentWithParameter:token:`: POST `/join`, request body carries full pipeline config
  - STT: Fengming ASR
  - LLM: Aliyun-compatible configuration pointing to the DeepSeek OpenAI-compatible endpoint
  - TTS: ByteDance / Volcengine
  - Advanced features: `enable_rtm: true`, `enable_string_uid: true`, `idle_timeout: 120`
  - Remote UIDs: `remote_rtc_uids: ["*"]`
- `stopAgentWithAgentId:token:`: POST `/agents/{agentId}/leave`
- `generateTokenWithChannelName:uid:types:` wraps demo token generation
- Authentication: `Authorization: agora token=<authToken>`

### Token Generation (Demo Only)

- Implemented inside `Tools/AgentManager.m`
- Calls `https://service.apprtc.cn/toolbox/v2/token/generate`
- Sends `appId`, `appCertificate`, `channelName`, `uid`, `types` (1=RTC, 2=RTM) in POST body
- Returns a unified token usable for both RTC and RTM
- **Requires APP_CERTIFICATE**: the demo token service needs `appCertificate` to generate valid tokens
- Demo only — production must use your own backend for token generation

### ConversationalAIAPI

- Wraps RTM message subscription/parsing
- Objective-C consumes the shared Swift parser through `VoiceAgent-Swift.h`
- The quickstart currently reacts to:
  - `onAgentStateChanged`
  - `onTranscriptUpdated`
  - `onAgentError`
- Render mode is `TranscriptRenderModeWords`

## Configuration

### Configuration Flow

```
KeyCenter.m → ViewController / AgentManager
```

Static credentials are read directly from `KeyCenter.m`. `ViewController` builds the start-agent payload from those values, while `AgentManager` uses `AG_APP_ID` + `AG_APP_CERTIFICATE` for demo token generation and REST calls.

### Configuration Fields (KeyCenter.m)

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `AG_APP_ID` | ShengWang App ID | ✅ | — |
| `AG_APP_CERTIFICATE` | ShengWang App Certificate (must be enabled) | ✅ | — |
| `LLM_API_KEY` | DeepSeek API Key | ✅ | — |
| `LLM_URL` | OpenAI-compatible endpoint URL | | `https://api.deepseek.com/v1/chat/completions` |
| `LLM_MODEL` | Model name | | `deepseek-chat` |
| `TTS_BYTEDANCE_APP_ID` | Volcengine TTS App ID | ✅ | — |
| `TTS_BYTEDANCE_TOKEN` | Volcengine TTS access token | ✅ | — |

### APP_CERTIFICATE Must Be Enabled

This project uses HTTP token auth (`Authorization: agora token=<token>`) for REST API calls, and the demo token service sends `appCertificate` to generate valid RTC/RTM tokens. Both require the App Certificate to be enabled.

Make sure to:
1. Enable the primary certificate for your App ID in the [ShengWang Console](https://console.shengwang.cn/)
2. Fill in the certificate value in `KeyCenter.m` under `AG_APP_CERTIFICATE`

### Build-Time Validation

There is no automatic build-time validation in this target. Missing or invalid values in `KeyCenter.m` usually fail at runtime during token generation, SDK initialization, or REST calls.

## API Endpoints

Client directly calls ShengWang REST API (Demo mode):

| Endpoint | Method | Auth Header | Description |
|----------|--------|-------------|-------------|
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/join` | POST | `Authorization: agora token=<authToken>` | Start Agent |
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | `Authorization: agora token=<authToken>` | Stop Agent |

Token generated via Demo service (must be replaced with your own backend in production):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `service.apprtc.cn/toolbox/v2/token/generate` | POST | Generate RTC/RTM Token (requires appId + appCertificate) |

If you need to point to a different backend, change the URL strings in `Tools/AgentManager.m`.

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
  "appId": "<AG_APP_ID>",
  "appCertificate": "<AG_APP_CERTIFICATE>",
  "channelName": "<channel-or-empty-string>",
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
             UIKit view update
```

## Event Flow

1. User taps Start → `channel` is generated in `ViewController`
2. Generate `userToken` with empty `channelName` and current `uid`
3. Login RTM with `userToken`
4. Join RTC channel with `userToken`
5. Subscribe to ConvoAI RTM messages for `channel`
6. Generate `agentToken` for `agentUid`
7. Generate a dedicated `authToken` for the same `channel` and `agentUid`
8. Call `AgentManager startAgentWithParameter:token:` with `authToken` to start Agent
9. ConversationalAIAPI receives agent state / transcript events via RTM → `ViewController` updates UI
10. User taps Stop → stop agent → leave RTC → logout RTM → unsubscribe ConvoAI → clear local state

## How to Change Request Parameters

The agent start request body is built in `ViewController.m` → `startAgentParameter` as a nested dictionary. Key sections:

| Section | What it controls | Where in the dictionary |
|---------|------------------|-------------------------|
| `asr` | Speech-to-text vendor, language, credentials | `properties.asr` |
| `llm` | LLM endpoint, model, system prompt, greeting/failure messages | `properties.llm` |
| `tts` | Text-to-speech vendor, voice, speed | `properties.tts` |
| `parameters` | Data channel (`rtm`), error message toggle | `properties.parameters` |
| `advanced_features` | RTM enable flag | `properties.advanced_features` |
| Top-level | Channel name, agent UID, idle timeout, token | `properties.*` |

To modify request parameters: edit `startAgentParameter`. Static values should stay in `KeyCenter.m`; structural changes should be made in the dictionary itself.

## Key Constraints

1. **APP_CERTIFICATE required**: This project uses token-based REST auth and demo token generation. `AG_APP_CERTIFICATE` must be enabled in the ShengWang console and configured in `KeyCenter.m`.
2. **Demo Mode**: Config is stored in `KeyCenter.m`; the client directly calls REST API and the demo token service.
3. **Production**: Sensitive info (`appCertificate`, LLM/STT/TTS keys) must move to your backend; the client should only fetch token/session info from your own server.
4. **Token Generation**: `AgentManager generateTokenWithChannelName:...` is demo-only; production must use your own server.
5. **Resource Cleanup**: RTC leave, RTM logout, ConvoAI unsubscribe, and local UI state reset all happen during `endCall`.
6. **Permissions**: The app requires microphone access for voice conversation.
7. **ConversationalAIAPI is read-only**: All files under `VoiceAgent/ConversationalAIAPI/` are standalone components — **do not modify directly**. To reuse in other projects, copy the entire directory.
8. **Server Overrides**: If you point the app to a local backend, use the host machine IP, not `localhost` or `127.0.0.1`, when testing on a real device.

## File Naming

- Objective-C headers: `PascalCase.h`
- Objective-C implementations: `PascalCase.m`
- UIKit view classes: `*View.h/.m`, `*Cell.h/.m`, `ViewController.h/.m`
- Utility files: `*Manager.h/.m`, `KeyCenter.h/.m`

## Documentation Navigation

| Document | Description |
|----------|-------------|
| AGENTS.md | AI Agent development guidelines and project constraints |
| ARCHITECTURE.md | Technical architecture details (modules, state ownership, runtime flow) |
| README.md | Quick start and usage guide |

# Conversational AI Quickstart Flutter — AI Assistant Guide

## How to Use This Project

This is a complete, runnable Flutter demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly and modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, RTC/RTM integration, REST startup flow) and adapt them into the existing codebase.
- This Flutter quickstart only supports `android/` and `ios/`; web and desktop are out of scope.

## Project Identity

- Dart package name: `shengwang_convoai_quickstart_flutter`
- Android namespace / applicationId: `cn.shengwang.convoai.quickstart.flutter`
- iOS bundle identifier: `cn.shengwang.convoai.quickstart.flutter`
- Android / iOS display name: `Shengwang Conversational AI`

If native Android or iOS scaffold files are missing, regenerate only the supported platforms with:

```bash
flutter create --platforms=android,ios .
```

## How to Switch AI Providers

The STT/LLM/TTS vendor configuration lives in two places that must be changed together:

1. `lib/services/keycenter.dart` — reads credentials from `assets/env.properties` and falls back to `--dart-define`
2. `lib/services/agent_starter.dart` → `_buildJsonPayload()` — the JSON builder that specifies vendor names and maps `KeyCenter` values into the request body

To switch a provider:

- Change the `"vendor"` value in `_buildJsonPayload()`
- Update the corresponding `"params"` sub-object to match the new vendor's required fields
- Add or update the matching values in `assets/env.properties`
- If the new provider needs extra config keys, add them to both `KeyCenter` parsing and the example env file

Supported vendors for STT/TTS/LLM change over time. Refer to the [创建对话式智能体 API 文档](https://doc.shengwang.cn/doc/convoai/restful/convoai/operations/start-agent) for the latest supported vendors and required parameters.

LLM: Any OpenAI-compatible API can be used by changing `LLM_URL` and `LLM_MODEL`.

## Project Overview

Conversational AI Quickstart — Flutter real-time voice conversation client.

The client directly calls ShengWang RESTful API to start and stop Agent, with STT (Speech-to-Text), LLM (Large Language Model), and TTS (Text-to-Speech) configuration embedded in the request body, authenticated via HTTP token (`Authorization: agora token=<token>`). This auth mode requires `APP_CERTIFICATE` to be enabled.

Current quickstart scope is limited to voice session startup, transcript display, state rendering, mute, and stop. It does not expose text or image message sending UI.

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Dart |
| UI Framework | Flutter + Material 3 |
| Platforms | Android / iOS |
| iOS Deployment Target | 13.0 |
| Build Tool | Flutter CLI + Gradle + CocoaPods |
| State Management | `StatefulWidget` + `setState` |
| Networking | `http` (1.x) |
| RTC SDK | ShengWang RTC SDK (`agora_rtc_engine` 6.x) |
| RTM SDK | ShengWang RTM SDK (`agora_rtm` 2.2.6) |
| Permissions | `permission_handler` (11.x) |
| Config Loading | `rootBundle` + `String.fromEnvironment` fallback |

For runtime structure, see `ARCHITECTURE.md`. For entry files, see `README.md`.

## Core Modules

### AgentChatPage

- Owns `RtcEngine` and `RtmClient` lifecycle
- Manages local UI state directly in the page:
  - `connectionState` — `idle / connecting / connected / error`
  - `agentStateText` — Agent state (`idle / silent / listening / thinking / speaking`)
  - `isMuted` — microphone mute state
  - `debugLogs` — rolling log list (max 20 entries)
  - `transcriptMgr.items` — transcript list shown in chat bubbles
- Auto flow: permission check → RTC init → generate `userToken` → join RTC → RTM init/login/subscribe → generate `agentToken` + `authToken` → start Agent
- `userUid` is a random 6-digit integer generated at page startup
- `agentUid` is another random 6-digit integer generated at page startup and guaranteed not to equal `userUid`
- `channelName` format is `channel_kotlin_<6-digit-random>`

### AgentStarter

- `startAgent()`: POST `/join/`, request body carries full pipeline config
  - STT: Fengming ASR
  - LLM: 阿里云百炼千问（DashScope OpenAI-compatible endpoint）
  - TTS: 火山引擎（token + app_id + cluster + voice_type）
  - Advanced features: `enable_rtm: true`, `data_channel: "rtm"`, `enable_string_uid: false`, `idle_timeout: 120`
  - Remote UIDs: `remote_rtc_uids: ["<currentUserUid>"]`
- `stopAgent()`: POST `/agents/{agentId}/leave`
- Authentication: `Authorization: agora token=<authToken>` (requires `APP_CERTIFICATE` enabled)
- Handles 301/302/307/308 redirects and masks sensitive values in debug output

### TokenGenerator (Demo Only)

- Generates RTC/RTM tokens via demo service at `https://service.apprtc.cn/toolbox/v2/token/generate`
- Sends `appId`, `appCertificate`, `channelName`, `uid`, `types` (`1=RTC`, `2=RTM`) in POST body
- Returns a unified token used for:
  - user RTC join + RTM login
  - agent RTC credential
  - REST API auth header
- **Requires APP_CERTIFICATE**: the demo token service needs `appCertificate` to generate valid tokens
- Demo only — production must use your own backend for token generation

### AgentEventParser

- Parses RTM presence events into Agent state changes
- Only reacts to:
  - current channel
  - `RtmChannelType.message`
  - `remoteStateChanged`
- Uses `turn_id` and timestamp to ignore older state events
- Parses `message.error` payloads from RTM data messages

### TranscriptManager

- Parses `assistant.transcription` and `user.transcription`
- Upserts transcript items by `turn_id` (fallback `message_id`) + speaker type
- Tracks transcript status:
  - `inProgress`
  - `end`
  - `interrupted`
  - `unknown`

### PermissionService

- Requests microphone permission on mobile
- If denied, shows a local dialog that guides the user to system settings

## Configuration

### Configuration Flow

```text
assets/env.properties / --dart-define
  → KeyCenter
  → TokenGenerator / AgentStarter / AgentChatPage
```

Unlike the Android Kotlin version, Flutter currently does not fail the build on missing config. Missing values surface as runtime failures when token generation or agent startup is attempted.

### Configuration Fields

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `APP_ID` | ShengWang App ID | yes | — |
| `APP_CERTIFICATE` | ShengWang App Certificate (must be enabled) | yes | — |
| `LLM_API_KEY` | DashScope API Key | yes | — |
| `LLM_URL` | Qwen OpenAI-compatible endpoint URL | no | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` |
| `LLM_MODEL` | Qwen model name | no | `qwen-plus` |
| `TTS_BYTEDANCE_APP_ID` | Volcengine TTS App ID | yes | — |
| `TTS_BYTEDANCE_TOKEN` | Volcengine TTS access token | yes | — |

`KeyCenter` also accepts legacy-style keys such as `agora.appId`, `agora.appCertificate`, and similar variants from the same `env.properties` file.

### APP_CERTIFICATE Must Be Enabled

This project uses HTTP token auth (`Authorization: agora token=<token>`) for REST API calls, and the demo `TokenGenerator` sends `appCertificate` to the token service. Both require the App Certificate to be enabled. If `APP_CERTIFICATE` is empty or the certificate is not enabled in the ShengWang console, token generation and REST API calls will fail.

Make sure to:

1. Enable the primary certificate for your App ID in the [ShengWang Console](https://console.shengwang.cn/)
2. Fill in the certificate value in `assets/env.properties` under `APP_CERTIFICATE`

## API Endpoints

Client directly calls ShengWang REST API (demo mode):

| Endpoint | Method | Auth Header | Description |
|----------|--------|-------------|-------------|
| `api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects/{appId}/join/` | POST | `Authorization: agora token=<authToken>` | Start Agent |
| `api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | `Authorization: agora token=<authToken>` | Stop Agent |

Token generated via demo service (must be replaced with your own backend in production):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `service.apprtc.cn/toolbox/v2/token/generate` | POST | Generate RTC/RTM token (requires `appId` + `appCertificate`) |

## Native Project Notes

- Android entry activity lives at `android/app/src/main/kotlin/cn/shengwang/convoai/quickstart/flutter/MainActivity.kt`
- Android launcher label is `Shengwang Conversational AI`
- iOS `CFBundleName` is `shengwang_convoai_quickstart_flutter`
- iOS `CFBundleDisplayName` is `Shengwang Conversational AI`
- Flutter `.metadata` currently records only `android` and `ios` as supported platforms

### Start Agent Request Body Structure

```json
{
  "name": "<channelName>",
  "properties": {
    "channel": "<channelName>",
    "token": "<agentToken>",
    "agent_rtc_uid": "<agentRtcUid>",
    "remote_rtc_uids": ["<currentUserUid>"],
    "enable_string_uid": false,
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
      "system_messages": [{ "role": "system", "content": "你是一名有帮助的 AI 助手。" }],
      "greeting_message": "你好！我是你的 AI 助手，有什么可以帮你？",
      "failure_message": "抱歉，我暂时处理不了你的请求，请稍后再试。",
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
  "appId": "<APP_ID>",
  "appCertificate": "<APP_CERTIFICATE>",
  "channelName": "<channelName>",
  "uid": "<uid>",
  "types": [1, 2],
  "expire": 86400,
  "src": "Flutter",
  "ts": "<timestamp>"
}
```

## Data Flow

```text
User Action → AgentChatPage → ShengWang SDK (RTC / RTM)
                    ↓
      AgentEventParser / TranscriptManager
                    ↓
              setState() → UI update
```

## Event Flow

1. User taps Start Agent → check platform and microphone permission
2. Initialize RTC Engine
3. Generate `userToken` (channelName is the current random channel, uid is `userUid`)
4. Join RTC channel
5. Initialize RTM client → login RTM → subscribe message channel
6. Generate `agentToken` and `authToken` (same channel, uid is `agentUid`)
7. POST `/join/` to start Agent
8. Receive RTM presence / message events → update transcript list, agent state, and logs

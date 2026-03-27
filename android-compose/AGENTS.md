# Conversational AI Quickstart Android Compose — AI Assistant Guide

## How to Use This Project

This is a complete, runnable Android demo for real-time voice conversation with an AI agent, built with Jetpack Compose.

- If you don't have an existing project, use this project directly and modify it based on user requirements.
- If you already have a project, reuse the key parts here: connection flow, Compose UI structure, and `ConversationalAIAPI` integration.

## How to Switch AI Providers

The STT/LLM/TTS vendor configuration lives in two places that must be changed together:

1. `KeyCenter.kt` (reads from `env.properties` via BuildConfig) — provider credentials and configurable IDs
2. `AgentStarter.kt` → `buildJsonPayload()` — the JSON builder that specifies vendor names and maps `KeyCenter` values into the request body

To switch a provider:

- Change the `"vendor"` value in `buildJsonPayload()`
- Update the `"params"` sub-object to match the new vendor's required fields
- Add/update the corresponding values in `env.properties`

Supported vendors for STT/TTS/LLM change over time. Refer to the [创建对话式智能体 API 文档](https://doc.shengwang.cn/doc/convoai/restful/convoai/operations/start-agent) for the up-to-date list of supported vendors and required parameters.

LLM remains OpenAI-compatible by design — change `LLM_URL` and `LLM_MODEL` to swap endpoints/models.

## Project Overview

Conversational AI Quickstart — Android real-time voice conversation client built with Compose.

The client directly calls ShengWang RESTful API to start/stop Agent, with STT (Speech-to-Text), LLM (Large Language Model), and TTS (Text-to-Speech) configuration in the request body, authenticated via HTTP token (`Authorization: agora token=<token>`). This auth mode requires `APP_CERTIFICATE` to be enabled.

Current quickstart scope is limited to voice session startup, transcript display, state rendering, mute, and stop. It does not expose text or image message sending UI.

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Kotlin |
| UI Framework | Jetpack Compose + Material 3 |
| Min SDK | API 26 (Android 8.0) |
| Target SDK | API 36 |
| Build Tool | Gradle (Kotlin DSL) |
| State Management | ViewModel + StateFlow + SharedFlow |
| Networking | OkHttp 5.0.0-alpha.14 |
| RTC SDK | ShengWang RTC SDK (`io.agora.rtc:full-sdk:4.5.1`) |
| RTM SDK | ShengWang RTM SDK (`io.agora:agora-rtm-lite:2.2.6`) |
| Coroutines | Kotlin Coroutines 1.9.0 |
| Navigation | Single-activity Compose screen |
| ConversationalAIAPI | Built-in module, do not modify |

For runtime structure, see `ARCHITECTURE.md`. For entry files, see `README.md`.

## Core Modules

### MainActivity + AgentChatScreen

- `MainActivity` hosts the Compose theme and `AgentChatScreen`
- `AgentChatScreen` renders the full quickstart UI:
  - Title / subtitle
  - Debug log card
  - Transcript card
  - Agent status bar
  - `Start Agent` / `Mute` / `Stop Agent` controls
- Collects:
  - `uiState`
  - `agentState`
  - `transcriptList`
  - `debugLogList`

### AgentChatViewModel

- Manages RTC Engine and RTM Client lifecycle
- Subscribes to RTM messages via `ConversationalAIAPI`
- Exposes:
  - `uiState: StateFlow<ConversationUiState>` — connection state + mute state
  - `agentState: StateFlow<AgentState>` — Agent state (`IDLE/SILENT/LISTENING/THINKING/SPEAKING`)
  - `transcriptList: StateFlow<List<Transcript>>` — transcript list
  - `debugLogList: StateFlow<List<String>>` — debug logs
- Auto flow: join RTC + login RTM → both ready → generate tokens → start Agent
- `userId` / `agentUid` are randomly generated in the companion object
- `channelName` format: `channel_compose_<6-digit-random>`

### AgentStarter

- `startAgentAsync()`: POST `/join/`, request body carries full three-stage pipeline config
  - STT: Fengming ASR
  - LLM: 阿里云百炼千问（DashScope OpenAI-compatible endpoint）
  - TTS: 火山引擎（token + app_id + cluster + voice_type）
  - Advanced features: `enable_rtm: true`, `data_channel: "rtm"`, `enable_string_uid: false`, `idle_timeout: 120`
  - Remote UIDs: `remote_rtc_uids: ["<currentUserUid>"]`
- `stopAgentAsync()`: POST `/agents/{agentId}/leave`
- Authentication: `Authorization: agora token=<authToken>`

### TokenGenerator (Demo Only)

- Generates RTC/RTM tokens via demo service at `https://service.apprtc.cn/toolbox/v2/token/generate`
- Sends `appId`, `appCertificate`, `channelName`, `uid`, `types` (1=RTC, 2=RTM) in POST body
- Returns a unified token usable for both RTC and RTM
- **Requires APP_CERTIFICATE**
- Demo only — production must use your own backend

### ConversationalAIAPI

- Wraps RTM message subscription/parsing
- The quickstart currently reacts to:
  - `onAgentStateChanged`
  - `onTranscriptUpdated`
  - `onAgentError` (logged through ViewModel state/logs)
  - `onDebugLog`
- Audio settings: `loadAudioSettings(AUDIO_SCENARIO_AI_CLIENT)` must be called before joinChannel

## Configuration

### Configuration Flow

```text
env.properties → Gradle buildConfigField → BuildConfig → KeyCenter → AgentStarter / TokenGenerator
```

Gradle validates all required properties at build time. If any are missing or empty, the build fails with a clear error message listing the missing fields.

### Configuration Fields (env.properties)

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `APP_ID` | ShengWang App ID | ✅ | — |
| `APP_CERTIFICATE` | ShengWang App Certificate (must be enabled) | ✅ | — |
| `LLM_API_KEY` | DashScope API Key | ✅ | — |
| `LLM_URL` | Qwen OpenAI-compatible endpoint URL | | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` |
| `LLM_MODEL` | Qwen model name | | `qwen-plus` |
| `TTS_BYTEDANCE_APP_ID` | Volcengine TTS App ID | ✅ | — |
| `TTS_BYTEDANCE_TOKEN` | Volcengine TTS access token | ✅ | — |

### APP_CERTIFICATE Must Be Enabled

This project uses HTTP token auth (`Authorization: agora token=<token>`) for REST API calls, and the demo `TokenGenerator` sends `appCertificate` to the token service. Both require the App Certificate to be enabled in the ShengWang console. If `APP_CERTIFICATE` is empty or the certificate is not enabled, token generation and REST API calls will fail.

Make sure to:

1. Enable the primary certificate for your App ID in the [ShengWang Console](https://console.shengwang.cn/)
2. Fill in the certificate value in `env.properties` under `APP_CERTIFICATE`

### Build-Time Validation

`build.gradle.kts` validates the following properties are non-empty at build time:

- `APP_ID`
- `APP_CERTIFICATE`
- `LLM_API_KEY`
- `TTS_BYTEDANCE_APP_ID`
- `TTS_BYTEDANCE_TOKEN`

## API Endpoints

Client directly calls ShengWang REST API (Demo mode):

| Endpoint | Method | Auth Header | Description |
|----------|--------|-------------|-------------|
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/join/` | POST | `Authorization: agora token=<authToken>` | Start Agent |
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | `Authorization: agora token=<authToken>` | Stop Agent |

Token generated via Demo service (must be replaced with your own backend in production):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `service.apprtc.cn/toolbox/v2/token/generate` | POST | Generate RTC/RTM Token (requires appId + appCertificate) |

## Start Agent Request Body Structure

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

## Data Flow

```text
User Action → Compose UI → ViewModel → ShengWang SDK (RTC/RTM)
                           ↓
                    StateFlow / SharedFlow ← ConversationalAIAPI event callbacks
                           ↓
                    Compose re-collects state → UI update
```

## Event Flow

### Startup Flow

1. User taps Start Agent → check microphone permission
2. Generate userToken (unified for RTC+RTM, channelName is empty string, uid=userId)
3. Parallel: join RTC channel + login RTM (both use the same userToken)
4. Both ready → subscribeMessage(channelName) → generate agentToken + authToken (uid=agentUid, channelName=current channel)
5. Call `AgentStarter.startAgentAsync(channelName, agentRtcUid, agentToken, authToken, remoteRtcUid)` to start Agent, where `remoteRtcUid` is the current user RTC UID
6. ConversationalAIAPI receives Agent events via RTM → update StateFlow / SharedFlow → UI responds
7. User taps Stop → unsubscribeMessage → `AgentStarter.stopAgentAsync(agentId, authToken)` → leave RTC → clean up state

### Runtime Callback Flow

```text
RTM message → ConversationalAIAPI → EventHandler callbacks
                                   ├── onAgentStateChanged
                                   ├── onTranscriptUpdated
                                   ├── onAgentError
                                   └── onDebugLog
                                   ↓
                              ViewModel state update
                                   ↓
                              AgentChatScreen recomposes
```

## UI Rules

- Preserve:
  - Title / subtitle
  - Dark gradient background
  - Log card
  - Transcript card
  - Bottom status bar
  - `Start Agent` / `Mute` / `Stop Agent` controls
- Agent transcript stays left-aligned with `AI` avatar; user transcript stays right-aligned with `Me` avatar
- Status colors should stay semantically distinct for idle, listening, thinking, speaking, and silent

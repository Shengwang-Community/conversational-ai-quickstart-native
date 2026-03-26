# Conversational AI Quickstart Android Java — AI Assistant Guide

## How to Use This Project

This is a complete, runnable Android demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly and modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, XML UI structure, and `convoaiApi` integration) and adapt them into the existing codebase.

## How to Switch AI Providers

The STT / LLM / TTS provider configuration lives in two places that must be changed together:

1. `KeyCenter.java` — reads from `env.properties` via `BuildConfig`
2. `AgentStarter.java` → `buildJsonPayload()` — the JSON builder that writes vendor names and maps `KeyCenter` values into the request body

To switch a provider:

- Change the `"vendor"` value inside `buildJsonPayload()`
- Update the corresponding `"params"` or top-level provider fields to match that vendor
- Add or update the matching values in `env.properties` so they flow through `BuildConfig` → `KeyCenter`

Supported providers change over time. Refer to the official [创建对话式智能体 API 文档](https://doc.shengwang.cn/doc/convoai/restful/convoai/operations/start-agent) for the current vendor list and required parameters.

LLM uses an OpenAI-compatible endpoint. Change `LLM_URL` and `LLM_MODEL` in `env.properties` when switching Qwen-compatible models or endpoints.

## Project Overview

Conversational AI Quickstart — Android Java real-time voice conversation client.

The client directly calls ShengWang RESTful API to start and stop Agent, with STT (Speech-to-Text), LLM (Large Language Model), and TTS (Text-to-Speech) configuration embedded in the request body. Authentication uses HTTP token mode:

```text
Authorization: agora token=<token>
```

This auth mode requires `APP_CERTIFICATE` to be enabled in the ShengWang console.

Current quickstart scope is limited to voice session startup, transcript display, state rendering, mute, and stop. It does not expose text or image message sending UI.

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Java + read-only Kotlin `convoaiApi` module |
| UI Framework | View + XML Layout + ViewBinding |
| Min SDK | API 26 (Android 8.0) |
| Target SDK | API 36 |
| Build Tool | Gradle (Groovy DSL) |
| State Management | ViewModel + LiveData |
| Networking | OkHttp 5.0.0-alpha.14 |
| RTC SDK | ShengWang RTC SDK (`io.agora.rtc:full-sdk:4.5.1`) |
| RTM SDK | ShengWang RTM SDK (`io.agora:agora-rtm-lite:2.2.6`) |
| ConversationalAIAPI | Built-in module, do not modify |

For runtime structure, see `ARCHITECTURE.md`. For entry files, see `README.md`.

## Core Modules

### AgentChatViewModel

- Manages RTC Engine and RTM Client lifecycle
- Subscribes to RTM messages via `ConversationalAIAPI`, parses Agent state and transcripts
- Exposes four UI-facing LiveData streams:
  - `uiState: LiveData<ConversationUiState>` — connection state (`Idle / Connecting / Connected / Error`) + mute
  - `agentState: LiveData<AgentState>` — Agent state (`IDLE / LISTENING / THINKING / SPEAKING / SILENT`)
  - `transcriptList: LiveData<List<Transcript>>` — transcript list (deduplicated by `turnId + type`)
  - `debugLogList: LiveData<List<String>>` — debug logs (keeps the latest 20)
- Auto flow: `joinRtc + loginRtm → both ready → generate agentToken + authToken → startAgent`
- Uses Kotlin-aligned UID generation:
  - `userId` is a random 6-digit integer (`100000..999999`)
  - `agentUid` is a random 6-digit integer and is guaranteed not to equal `userId`
- Channel name format: `channel_java_<6-digit-random>`

### AgentStarter

- `startAgentAsync()` sends `POST /join/` with a full inline three-stage pipeline body
  - ASR: Fengming
  - LLM: Aliyun / Qwen-compatible endpoint
  - TTS: ByteDance / Volcengine
  - Advanced fields: `enable_rtm: true`, `data_channel: "rtm"`, `enable_string_uid: true`, `idle_timeout: 120`
  - Remote UIDs: `remote_rtc_uids: ["*"]`
- `stopAgentAsync()` sends `POST /agents/{agentId}/leave`
- Authentication: `Authorization: agora token=<authToken>`

### TokenGenerator (Demo Only)

- Generates RTC / RTM tokens via the demo service at `https://service.apprtc.cn/toolbox/v2/token/generate`
- Sends `appId`, `appCertificate`, `channelName`, `uid`, `types` (1 = RTC, 2 = RTM) in the POST body
- Returns a unified token that can be used for both RTC and RTM
- Requires `APP_CERTIFICATE`
- Demo only — production must replace this with your own backend token service

### ConversationalAIAPI

- Wraps RTM message subscription and parsing
- The quickstart currently reacts to:
  - `onAgentStateChanged`
  - `onTranscriptUpdated`
  - `onAgentError` (logged through ViewModel state/logs)
  - `onDebugLog`
- Audio settings are loaded with `AUDIO_SCENARIO_AI_CLIENT`

## Configuration

### Configuration Flow

```text
env.properties → Gradle buildConfigField → BuildConfig → KeyCenter → AgentStarter / TokenGenerator / ViewModel
```

Gradle validates required properties at build time. If any are missing or empty, the build fails with a clear error message.

### Configuration Fields (`env.properties`)

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `APP_ID` | ShengWang App ID | ✅ | — |
| `APP_CERTIFICATE` | ShengWang App Certificate (must be enabled) | ✅ | — |
| `LLM_API_KEY` | DashScope API Key | ✅ | — |
| `LLM_URL` | Qwen OpenAI-compatible endpoint URL |  | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` |
| `LLM_MODEL` | Qwen model name |  | `qwen-plus` |
| `TTS_BYTEDANCE_APP_ID` | Volcengine TTS App ID | ✅ | — |
| `TTS_BYTEDANCE_TOKEN` | Volcengine TTS access token | ✅ | — |

### APP_CERTIFICATE Must Be Enabled

This project uses HTTP token auth for REST API calls, and the demo `TokenGenerator` sends `appCertificate` to the token service. Both require the App Certificate to be enabled. If `APP_CERTIFICATE` is empty or certificate is not enabled in the ShengWang console, token generation and REST API calls will fail.

### Build-Time Validation

`app/build.gradle` validates these properties are non-empty:

- `APP_ID`
- `APP_CERTIFICATE`
- `LLM_API_KEY`
- `TTS_BYTEDANCE_APP_ID`
- `TTS_BYTEDANCE_TOKEN`

## API Endpoints

Client directly calls ShengWang REST API in Demo mode:

| Endpoint | Method | Auth Header | Description |
|----------|--------|-------------|-------------|
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/join/` | POST | `Authorization: agora token=<authToken>` | Start Agent |
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | `Authorization: agora token=<authToken>` | Stop Agent |

Demo token service endpoint:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `service.apprtc.cn/toolbox/v2/token/generate` | POST | Generate RTC / RTM token (requires `appId + appCertificate`) |

### Start Agent Request Body Structure

```json
{
  "name": "<channelName>",
  "properties": {
    "channel": "<channelName>",
    "token": "<agentToken>",
    "agent_rtc_uid": "<agentRtcUid>",
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

## Key Constraints

1. `APP_CERTIFICATE` is required for both token generation and REST auth
2. This project is Demo mode only; production must move all sensitive values to a backend
3. `TokenGenerator.java` is Demo-only; do not use it in production
4. `app/src/main/java/io/agora/convoai/convoaiApi/` is read-only
5. Keep Java business and UI code in Java unless explicitly asked to migrate the Java variant

## Documentation Navigation

| Document | Description |
|----------|-------------|
| `AGENTS.md` | This document — AI agent development guidelines and project constraints |
| `ARCHITECTURE.md` | Technical architecture details (data flows, threading, lifecycle) |
| `README.md` | Quick start and usage guide |

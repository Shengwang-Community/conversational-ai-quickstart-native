# Conversational AI Quickstart React Native — AI Assistant Guide

## How to Use This Project

This is a complete, runnable React Native demo for real-time voice conversation with an AI agent.

- If you do not have an existing React Native project, use this project directly and modify it based on your requirements.
- If you already have a project, refer to the key parts of this quickstart and adapt them into your codebase:
  - configuration loading
  - RTC lifecycle
  - DataStream message parsing
  - Agent start / stop REST flow
  - single-screen voice conversation UI

Current scope is limited to voice session startup, transcript display, agent state rendering, mute, and stop. It does not include text input, image messaging, backend-owned token generation, or multi-screen business flow.

## Project Identity

- React Native app name: `shengwang_convoai_quickstart_reactnative`
- App display name: `Shengwang Conversational AI`
- Android namespace: `cn.shengwang.convoai.quickstart`
- Android applicationId: `cn.shengwang.convoai.quickstart.reactnative`
- Android entry activity: `android/app/src/main/java/cn/shengwang/convoai/quickstart/MainActivity.kt`
- iOS target name: `reactnative`

## Project Overview

Conversational AI Quickstart — React Native real-time voice conversation client.

The client directly calls ShengWang RESTful API to start and stop the Agent. STT, LLM, and TTS configuration are embedded in the `/join` request body and authenticated via HTTP token:

```text
Authorization: agora token=<token>
```

This auth mode requires `APP_CERTIFICATE` to be enabled.

React Native currently uses:

- RTC for audio transport
- RTC DataStream for transcript / state / error messages

This quickstart does not depend on a separate React Native RTM integration.
It also does not require Metro at runtime; Metro remains only as the bundler used during native build steps.

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | TypeScript |
| UI Framework | React Native 0.84 + React 19.2.3 |
| State Management | Zustand |
| RTC SDK | `react-native-agora` 4.5.3 |
| Config | `react-native-config` |
| Permissions | `react-native-permissions` + `PermissionsAndroid` |
| Safe Area | `react-native-safe-area-context` |
| Networking | built-in `fetch` |
| Test Setup | Jest + `react-test-renderer` |

For runtime structure, see `ARCHITECTURE.md`. For setup and usage, see `README.md`.

## Core Modules

### AgentChatPage

- Single-screen UI entry
- Renders:
  - title / subtitle
  - log card
  - transcript panel
  - action bar
- Requests microphone permission before starting a session
- Calls store actions:
  - `initRtcEngine()`
  - `startConnection()`
  - `stopAgent()`
  - `toggleMute()`

### AgentChatStore

- Central business logic and state container
- Owns:
  - RTC engine lifecycle
  - RTC join / leave
  - DataStream creation
  - transcript updates
  - agent state updates
  - rolling debug logs
- Exposes UI state:
  - `connectionState`
  - `agentState`
  - `isMuted`
  - `transcripts`
  - `logs`
  - `agentId`
- Handles DataStream message types:
  - `assistant.transcription`
  - `user.transcription`
  - `message.state`
  - `message.interrupt`
  - `message.error`

### AgentStarter

- `startAgentAsync()`: POST `/join`
- `stopAgentAsync()`: POST `/agents/{agentId}/leave`
- Inlines current pipeline configuration:
  - ASR: `fengming`
  - LLM: `aliyun`
  - TTS: `bytedance`
- Uses:
  - `data_channel: "datastream"`
  - `enable_error_message: true`
  - `advanced_features.enable_rtm: false`
- Masks sensitive values in logs and follows redirects

### TokenGenerator (Demo Only)

- Calls the demo token service at:
  - `https://service.apprtc.cn/toolbox/v2/token/generate`
- Sends:
  - `appId`
  - `appCertificate`
  - `channelName`
  - `uid`
  - `types`
- Returns a unified token string
- Demo only — production must replace this with backend-generated tokens

### MessageParser

- Parses RTC DataStream payloads in the format:

```text
messageId|partIndex|totalParts|base64Content
```

- Reassembles split messages
- Decodes Base64 payloads
- Parses JSON payloads
- Cleans up expired fragments after 5 minutes

### KeyCenter

- Reads values from `react-native-config`
- Provides:
  - `APP_ID`
  - `APP_CERTIFICATE`
  - `LLM_API_KEY`
  - `LLM_URL`
  - `LLM_MODEL`
  - `TTS_BYTEDANCE_APP_ID`
  - `TTS_BYTEDANCE_TOKEN`

## Configuration

### Configuration Flow

```text
.env
  → react-native-config
    → KeyCenter
      → TokenGenerator / AgentStarter / AgentChatStore
```

### Configuration Fields

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `APP_ID` | ShengWang App ID | yes | — |
| `APP_CERTIFICATE` | ShengWang App Certificate | yes | — |
| `LLM_API_KEY` | DashScope API Key | yes | — |
| `LLM_URL` | OpenAI-compatible LLM endpoint | no | DashScope-compatible URL |
| `LLM_MODEL` | LLM model name | no | `qwen-plus` |
| `TTS_BYTEDANCE_APP_ID` | Volcengine TTS App ID | yes | — |
| `TTS_BYTEDANCE_TOKEN` | Volcengine TTS token | yes | — |

`KeyCenter` also accepts legacy aliases such as `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE`.

### APP_CERTIFICATE Must Be Enabled

This project uses HTTP token auth for REST API requests and sends `appCertificate` to the demo token service. If `APP_CERTIFICATE` is missing or not enabled in the ShengWang console, token generation and Agent startup will fail.

## API Endpoints

Client directly calls ShengWang REST API in demo mode:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects/{appId}/join` | POST | Start Agent |
| `api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | Stop Agent |

Token generation endpoint:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `service.apprtc.cn/toolbox/v2/token/generate` | POST | Generate unified token |

## How to Switch AI Providers

The provider configuration lives in two places that must stay aligned:

1. `.env` — credential values
2. `src/api/AgentStarter.ts` → `buildJsonPayload()` — provider names and request-body shape

To switch providers:

- change the `vendor` value in `buildJsonPayload()`
- update the nested `params` object to match the target provider
- add or update the required keys in `.env`
- if new keys are needed, update `react-native-config.d.ts` and `src/utils/KeyCenter.ts`

Supported vendors can change over time. Refer to the official Conversational AI REST API docs for the latest request contract.

## Key Constraints

1. This is a demo. Sensitive keys are configured client-side for convenience.
2. Production must move token generation and Agent startup to a backend.
3. React Native uses RTC DataStream for message delivery in this quickstart.
4. `MessageParser` and store-side message handling are part of the app flow and should be kept consistent with the actual DataStream payload contract.
5. Missing `.env` values do not fail the build; most errors surface at runtime during token generation or Agent startup.
6. The app requires microphone and network permissions.

## Documentation Navigation

| Document | Description |
|----------|-------------|
| `README.md` | Setup, run, and usage guide |
| `AGENTS.md` | AI assistant / contributor implementation guide |
| `ARCHITECTURE.md` | Runtime shape, state flow, and connection flow |
| `CLAUDE.md` | Redirects Claude-style tooling to `AGENTS.md` |

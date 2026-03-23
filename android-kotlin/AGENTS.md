# Conversational AI Quickstart Android — AI Assistant Guide

## Conversation Modes

| Mode | Trigger | Strategy |
|------|---------|----------|
| workflow | Contains feat/fix/refactor/chore, or explicit dev tasks | Start workflow, enforce state management |
| continue | "Continue/resume", or unfinished PROJECT_STATE.md exists | Read state file, restore context |
| general | Technical questions, code explanations, general inquiries | Direct answer, no workflow |

## How to Use This Project

This is a complete, runnable Android demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly. Modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, ConversationalAIAPI integration) and adapt them into the existing codebase.

## How to Switch AI Providers

The STT/LLM/TTS vendor configuration lives in two places that must be changed together:

1. `KeyCenter.kt` (reads from `env.properties` via BuildConfig) — API keys and user-configurable IDs
2. `AgentStarter.kt` → `buildJsonPayload()` — the JSON builder that specifies vendor names and maps KeyCenter values into the request body

To switch a provider:
- Change the `"vendor"` value in `buildJsonPayload()` (e.g., `"microsoft"` → `"deepgram"` for STT)
- Update the `"params"` sub-object to match the new vendor's required fields
- Add/update the corresponding values in `env.properties` (which flow through BuildConfig → KeyCenter)

Supported vendors for STT/TTS/LLM change over time. Refer to the [创建对话式智能体 API 文档](https://doc.shengwang.cn/doc/convoai/restful/convoai/operations/start-agent) for the up-to-date list of supported vendors and their required parameters.

LLM: Any OpenAI-compatible API — change `LLM_URL` and `LLM_MODEL` in `env.properties`.

## Project Overview

Conversational AI Quickstart — Android real-time voice conversation client.

The client directly calls ShengWang RESTful API to start/stop Agent, with STT (Speech-to-Text), LLM (Large Language Model), and TTS (Text-to-Speech) configuration in the request body, authenticated via `agora token`.

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Kotlin |
| UI Framework | View + XML Layout + ViewBinding |
| Min SDK | API 26 (Android 8.0) |
| Target SDK | API 36 |
| Build Tool | Gradle (Kotlin DSL) |
| State Management | ViewModel + StateFlow |
| Networking | OkHttp |
| RTC SDK | ShengWang RTC SDK for Android (`io.agora.rtc:full-sdk:4.5.1`) |
| RTM SDK | ShengWang RTM SDK for Android (`io.agora:agora-rtm-lite:2.2.6`) |
| Coroutines | Kotlin Coroutines |
| Navigation | Navigation Component (SafeArgs) |
| ConversationalAIAPI | Built-in, do not modify |

## Project Structure

```
app/src/main/java/
├── cn/shengwang/convoai/quickstart/   # Business code
│   ├── ui/                            # UI Layer
│   │   ├── AgentChatActivity.kt          # Main screen (logs, transcripts, controls)
│   │   ├── AgentChatViewModel.kt         # ViewModel (RTC/RTM/Agent lifecycle)
│   │   ├── CommonDialog.kt              # Common dialog
│   │   └── common/                      # Base classes
│   │       ├── BaseActivity.kt
│   │       ├── BaseDialogFragment.kt
│   │       └── BaseFragment.kt
│   ├── api/                           # Network Layer
│   │   ├── AgentStarter.kt              # Agent REST API (start/stop)
│   │   ├── TokenGenerator.kt            # Token generation (Demo only)
│   │   └── net/                         # OkHttp configuration
│   │       ├── HttpLogger.kt
│   │       └── SecureOkHttpClient.kt
│   ├── tools/                         # Utilities
│   │   ├── PermissionHelp.kt            # Permission handling
│   │   └── Base64Encoding.kt
│   ├── KeyCenter.kt                   # Config center (BuildConfig → constants)
│   └── AgentApp.kt                    # Application
├── io/agora/convoai/convoaiApi/       # Conversational AI SDK wrapper (do not modify)
│   ├── IConversationalAIAPI.kt          # Interface definitions + data models
│   ├── ConversationalAIAPIImpl.kt       # Implementation (RTM message parsing → event callbacks)
│   ├── ConversationalAIUtils.kt         # Utility methods
│   └── subRender/                       # Subtitle rendering
│       ├── MessageParser.kt
│       └── TranscriptController.kt
```

## Core Modules

### AgentChatViewModel

- Manages RTC Engine and RTM Client lifecycle
- Subscribes to RTM messages via ConversationalAIAPI, parses Agent state and transcripts
- Exposes four StateFlows:
  - `uiState: StateFlow<ConversationUiState>` — connection state (Idle/Connecting/Connected/Error) + mute
  - `agentState: StateFlow<AgentState>` — Agent state (IDLE/SILENT/LISTENING/THINKING/SPEAKING)
  - `transcriptList: StateFlow<List<Transcript>>` — transcript list (deduplicated/updated by turnId + type)
  - `debugLogList: StateFlow<List<String>>` — debug logs (max 20 entries)
- Auto flow: joinRTC + loginRTM → both ready → generateToken → startAgent
- `userId` / `agentUid` randomly generated in companion object, channelName format `channel_kotlin_{random}`

### AgentStarter

- `startAgentAsync()`: POST `/join/`, request body carries full Pipeline config
  - STT: Microsoft Azure (key + region)
  - LLM: OpenAI-compatible endpoint (url + api_key + model + system_messages)
  - TTS: MiniMax (key + model + voice_id + group_id)
  - Advanced features: `enable_rtm: true`, `data_channel: "rtm"`, `enable_string_uid: true`, `idle_timeout: 120`
  - Remote UIDs: `remote_rtc_uids: ["*"]`
- `stopAgentAsync()`: POST `/agents/{agentId}/leave`
- Authentication: `Authorization: agora token=<authToken>`

### ConversationalAIAPI

- Wraps RTM message subscription/parsing
- Event callbacks (`IConversationalAIAPIEventHandler`):
  - `onAgentStateChanged` — Agent state change
  - `onTranscriptUpdated` — Transcript content update
  - `onAgentMetrics` — Performance metrics (LLM/TTS latency, etc.)
  - `onAgentError` — Agent module error
  - `onAgentInterrupted` — Agent interrupted
  - `onMessageError` — Message send error
  - `onMessageReceiptUpdated` — Message receipt
  - `onAgentVoiceprintStateChanged` — Voiceprint state change
  - `onDebugLog` — Debug log
- Message sending: `chat(agentUserId, TextMessage/ImageMessage)` + `interrupt(agentUserId)`
- Audio settings: `loadAudioSettings(AUDIO_SCENARIO_AI_CLIENT)` (must be called before joinChannel)

## Configuration Fields (env.properties)

| Field | Description | Required |
|-------|-------------|----------|
| `APP_ID` | ShengWang App ID | ✅ |
| `APP_CERTIFICATE` | ShengWang App Certificate | ✅ |
| `LLM_API_KEY` | LLM API Key | ✅ |
| `LLM_URL` | LLM endpoint URL (default: DeepSeek) | ✅ |
| `LLM_MODEL` | LLM model name (default: deepseek-chat) | ✅ |
| `STT_MICROSOFT_KEY` | Microsoft Azure STT Key | ✅ |
| `STT_MICROSOFT_REGION` | Azure region (default: chinaeast2) | |
| `TTS_MINIMAX_KEY` | MiniMax TTS Key | ✅ |
| `TTS_MINIMAX_MODEL` | TTS model (default: speech-01-turbo) | |
| `TTS_MINIMAX_VOICE_ID` | Voice ID (default: male-qn-qingse) | |
| `TTS_MINIMAX_GROUP_ID` | MiniMax Group ID | ✅ |

## API Endpoints

Client directly calls ShengWang REST API (Demo mode):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/join/` | POST | Start Agent |
| `api.agora.io/cn/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | Stop Agent |

Token generated via Demo service (must be replaced with your own backend in production):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `service.apprtc.cn/toolbox/v2/token/generate` | POST | Generate RTC/RTM Token |

## Data Flow

```
User Action → ViewModel → ShengWang SDK (RTC/RTM)
                  ↓
            StateFlow ← ConversationalAIAPI event callbacks
                  ↓
            Activity observes → UI update
```

## Event Flow

1. User taps Start Agent → check microphone permission
2. Generate userToken (unified for RTC+RTM, channelName is empty)
3. Parallel: join RTC channel + login RTM
4. Both ready → subscribeMessage → generate agentToken + authToken
5. Call `AgentStarter.startAgentAsync()` to start Agent
6. ConversationalAIAPI receives Agent events via RTM → update StateFlow → UI responds
7. User taps Stop → unsubscribeMessage → `AgentStarter.stopAgentAsync()` → leave RTC → clean up state

## How to Change Request Parameters

The agent start request body is built in `AgentStarter.kt` → `buildJsonPayload()` as a nested `JSONObject`. Key sections:

| Section | What it controls | Where in the JSON |
|---------|-----------------|-------------------|
| `asr` | Speech-to-text vendor, language, credentials | `properties.asr` |
| `llm` | LLM endpoint, model, system prompt, greeting/failure messages | `properties.llm` |
| `tts` | Text-to-speech vendor, voice, speed | `properties.tts` |
| `parameters` | Data channel (`rtm`), error message toggle | `properties.parameters` |
| `advanced_features` | RTM enable flag | `properties.advanced_features` |
| Top-level | Channel name, agent UID, idle timeout, token | `properties.*` |

To modify request parameters: edit `buildJsonPayload()` in `AgentStarter.kt`. Static values (API keys, model names) should stay in `KeyCenter.kt`; structural changes (adding fields, changing nesting) go directly in the JSON builder.

## Key Constraints

1. **Demo Mode**: Config injected via `env.properties` → BuildConfig, client directly calls REST API
2. **Production**: Sensitive info (appCertificate, LLM/STT/TTS keys) must be on backend; client only fetches Token and starts Agent through backend
3. **Token Generation**: `TokenGenerator.kt` is Demo-only; production must use your own server
4. **Resource Cleanup**: RTC/RTM resources fully released in `hangup()` and `onCleared()`; ConversationalAIAPI released via `destroy()`
5. **Permissions**: Requires `RECORD_AUDIO` and `INTERNET` permissions
6. **ConversationalAIAPI is read-only**: All files under `convoaiApi/` are standalone components — **do not modify directly**. To use in other projects, copy the entire `convoaiApi/` directory. See `convoaiApi/README.md` for usage
7. **Audio Settings**: `loadAudioSettings()` must be called before `joinChannel()`; Avatar mode uses `AUDIO_SCENARIO_DEFAULT`

## Installed Skills

| Skill | Path | Purpose |
|-------|------|---------|
| `find-skills` | `.agents/skills/find-skills/` | Search and install open-source agent skills (`npx skills find/add`) |
| `voice-ai-integration` | `.agents/skills/voice-ai-integration/` | ShengWang product integration: ConvoAI, RTC, RTM, Cloud Recording, Token generation |
| `update-docs` | `.agents/skills/update-docs/` | Documentation update workflow (Next.js based, for reference only) |

## File Naming

- Kotlin files: `PascalCase.kt`
- Resource files: `snake_case.xml`
- Layout files: `activity_*.xml` / `item_*.xml` / `dialog_*.xml`

## Git Commit Format

```
<type>(<scope>): <summary>
```

type: `feat` / `fix` / `docs` / `refactor` / `perf` / `test` / `chore`

## Workflow Guidelines

### State Management

- Maintain `PROJECT_STATE.md` in workflow mode
- Commit immediately after completing each todo (atomic commits)

### Quality Review

- Review generated code for: logical correctness, type safety, edge cases
- Pay special attention to: memory leaks (Activity lifecycle), permission handling, thread safety (coroutine Dispatchers)

### Context Management

When exceeding 10 conversation turns or large code changes:
1. Pause current task
2. Update PROJECT_STATE.md
3. Commit all uncommitted changes
4. Suggest switching to a new conversation

## Documentation Navigation

| Document | Description |
|----------|-------------|
| AGENTS.md | AI Agent development guidelines and project constraints |
| ARCHITECTURE.md | This document — technical architecture details |
| README.md | Quick start and usage guide |

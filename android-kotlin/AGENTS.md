# AGENTS.md — Android Kotlin

## Conversation Modes

| Mode | Trigger | Strategy |
|------|---------|----------|
| workflow | Contains feat/fix/refactor/chore, or explicit dev tasks | Start workflow, enforce state management |
| continue | "Continue/resume", or unfinished PROJECT_STATE.md exists | Read state file, restore context |
| general | Technical questions, code explanations, general inquiries | Direct answer, no workflow |

## Project Overview

ShengWang Conversational AI Android Demo — real-time voice conversation Android client.

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
| RTM SDK | ShengWang RTM SDK for Android (`io.agora:agora-rtm:2.2.3`) |
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
| AGENTS.md | This document — AI Agent development guidelines and project constraints |
| ARCHITECTURE.md | Technical architecture details |
| README.md | Quick start and usage guide |
| `.doc/` | Internal reference docs (design specs, Pipeline architecture, Token flow, etc.) |

# Architecture — Conversational AI Quickstart Flutter

## Architecture Overview

This quickstart is a single-screen voice conversation demo built with Flutter and Material 3.

Project identity:

- Dart package name: `shengwang_convoai_quickstart_flutter`
- Android namespace / applicationId: `cn.shengwang.convoai.quickstart.flutter`
- iOS bundle identifier: `cn.shengwang.convoai.quickstart.flutter`
- Supported native platforms: Android / iOS only

Current scope:

- Start Agent
- RTC join + RTM login
- Real-time transcript rendering
- Agent status rendering
- Mute / unmute
- Stop Agent and cleanup

Out of scope for this quickstart:

- Text or image message sending UI
- Multi-screen business flow
- Backend-owned token / agent startup flow
- Any runtime outside Android / iOS

## Page Layout

The page is intentionally single-screen and is organized into these regions:

- title and subtitle
- log panel
- transcript panel
- bottom agent status bar
- start / retry / mute / stop controls

The content area beneath the title is split into:

- a flexible log panel
- a flexible transcript panel

Both panels expand to fill the available viewport height above the action bar.

## Project Structure

```text
lib/
├── main.dart                     # App entry, theme setup, config preload
├── agent_chat_page.dart          # Single-page UI + RTC/RTM lifecycle + state
└── services/
    ├── agent_event_parser.dart   # RTM presence / error message parsing
    ├── agent_starter.dart        # Agent start/stop REST API wrapper
    ├── keycenter.dart            # .env config loader
    ├── permission_service.dart   # Microphone permission helper
    ├── token_generator.dart      # Demo RTC/RTM/auth token generator
    └── transcript_manager.dart   # Transcript parsing and upsert logic

assets/
└── .env.example                  # Example configuration template

android/
└── app/src/main/kotlin/cn/shengwang/convoai/quickstart/flutter/MainActivity.kt

ios/
└── Runner/Info.plist            # Display name / bundle metadata
```

## Runtime Shape

```text
AgentChatPage / RtcEngine / RtmClient /
TokenGenerator / AgentStarter /
AgentEventParser / TranscriptManager
```

Unlike the Android Kotlin version, Flutter does not introduce a separate ViewModel layer. The page owns state directly and updates UI with `setState()`.

## Connection Flow (User taps Start Agent)

```text
Tap Start Agent
  → reject non-mobile platforms
  → check microphone permission
  → initialize RTC engine
  → generate userToken
  → join RTC
  → initialize RTM client
  → login RTM
  → subscribe RTM channel
  → generate agentToken + authToken
  → POST /join/ with inline ASR / LLM / TTS config
  → save agentId + authToken
  → connectionState = connected
```

Flutter-specific conventions:

- `userUid` is a random 6-digit integer generated at page startup
- `agentUid` is another random 6-digit integer generated at page startup and guaranteed not to equal `userUid`
- `channelName` format is `channel_kotlin_<6-digit-random>`
- REST auth header is `Authorization: agora token=<authToken>`
- Flutter project metadata is intentionally limited to `android` and `ios`

## Transcript Data Flow

```text
RTM message
  → AgentChatPage listener
  → TranscriptManager.upsertFromJson(...)
  → transcriptMgr.items update
  → ListView rebuild
```

The current UI renders:

- agent transcript on the left with `AI`
- user transcript on the right with `Me`

Transcript updates with the same `turn_id` replace older content instead of appending duplicates.

## Agent State Flow

```text
RTM presence event
  → AgentEventParser.parsePresenceEvent(...)
  → agentStateText update
  → status bar color + label refresh
```

The parser only accepts newer events for the active channel by comparing:

- `channelName`
- `turn_id`
- event timestamp

## UI State Rendering

```text
connectionState  → Start / Connecting / Retry / Mute / Stop controls
agentStateText   → bottom status bar color + text
transcriptMgr    → transcript panel content
debugLogs        → log panel content
```

Current connection states:

- `idle`
- `connecting`
- `connected`
- `error`

## Token Flow

The quickstart generates three token roles through the demo token service:

| Token | Purpose | Usage |
|-------|---------|-------|
| `userToken` | User RTC join + RTM login | `joinChannel()` / `rtm.login()` |
| `agentToken` | Agent RTC join credential | request body `properties.token` |
| `authToken` | REST API authentication | `Authorization: agora token=<authToken>` |

Notes:

- All three tokens are generated with the current random `channelName`
- `userToken` uses `userUid`
- `agentToken` and `authToken` use `agentUid`
- Production should replace the demo token service with a backend

## Agent Lifecycle

```text
idle
  → listening
  → thinking
  → speaking
  → listening
```

Additional behavior:

- `silent` can appear after interruption
- tapping `Stop Agent` unsubscribes RTM, logs out RTM, stops the Agent, leaves RTC, releases RTC resources, and resets UI back to idle

## Config Contract

```text
assets/.env
  → KeyCenter
  → TokenGenerator / AgentStarter / AgentChatPage
```

Required fields:

- `APP_ID`
- `APP_CERTIFICATE`
- `LLM_API_KEY`
- `TTS_BYTEDANCE_APP_ID`
- `TTS_BYTEDANCE_TOKEN`

Optional fields:

- `LLM_URL`
- `LLM_MODEL`

Current default inline pipeline:

- ASR: `fengming`
- LLM: `aliyun` + `LLM_URL` + `LLM_MODEL`
- TTS: `bytedance`

## Constraints

- This is a demo; token generation and agent startup are client-side for convenience
- Production should move token generation and REST startup to a backend
- Flutter currently has lightweight parser/services instead of a standalone reusable `ConversationalAIAPI` module
- Missing config is not validated at build time and will fail only when the flow runs
- If Android or iOS scaffold files are missing, recover them with `flutter create --platforms=android,ios .`

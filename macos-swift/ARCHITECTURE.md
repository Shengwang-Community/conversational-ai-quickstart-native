# Architecture — Conversational AI Quickstart macOS Swift

## Architecture Overview

This quickstart is a single-window voice conversation demo built with AppKit and programmatic views.

Current scope:

- Start Agent
- RTC join + RTM login
- Real-time transcript rendering
- Agent status rendering
- Mute / unmute
- Stop Agent and cleanup

Out of scope for this quickstart:

- Text or image message sending UI
- Multi-window business flow
- Backend-owned token / agent startup flow

## Page Layout

The window is intentionally single-screen and is organized into these regions:

- title and subtitle
- log panel on the right
- transcript panel
- bottom agent status view
- start / mute / stop controls

## Project Structure

```text
macos-swift/
├── Podfile
├── VoiceAgent/
│   ├── AppDelegate.swift
│   ├── ViewController.swift
│   ├── KeyCenter.swift
│   ├── AppColors.swift
│   ├── Chat/
│   │   ├── ConnectionStartView.swift
│   │   ├── ChatSessionView.swift
│   │   ├── AgentStateView.swift
│   │   └── TranscriptMessageCell.swift
│   ├── Tools/
│   │   ├── AgentManager.swift
│   │   └── NetworkManager.swift
│   └── ConversationalAIAPI/
│       └── ...        # Read-only RTM parsing / transcript component
└── VoiceAgent.xcworkspace
```

## Runtime Shape

```text
ViewController /
RTC / RTM / ConversationalAIAPI /
NetworkManager / AgentManager
```

`ConversationalAIAPI/` is a read-only module that parses RTM payloads and emits agent / transcript callbacks.

## Connection Flow (User taps Start Agent)

```text
Tap Start Agent
  → generate channel
  → generate userToken
  → login RTM
  → join RTC
  → subscribe RTM channel
  → generate agentToken
  → POST /join with inline ASR / LLM / TTS config
  → save agentId
  → show active controls
```

macOS-specific conventions:

- `userUid` and `agentUid` are random integers and do not conflict
- `channelName` format is `channel_macos_<6-digit-random>`
- REST auth header is `Authorization: agora token=<userToken>`

## Transcript Data Flow

```text
RTM message
  → ConversationalAIAPI
  → ViewController.onTranscriptUpdated(...)
  → transcripts update
  → ChatSessionView refreshes transcript rows
```

The current UI renders:

- agent transcript on the left
- user transcript on the right

## UI State Rendering

```text
isActive / button state  → Start / Mute / Stop controls
agent state callback     → AgentStateView status
transcripts              → transcript panel content
log messages             → right-side log panel
isMuted                  → mic button state
```

## Token Flow

The quickstart generates two token roles through the demo token service:

| Token | Purpose | Usage |
|-------|---------|-------|
| `userToken` | User RTC join + RTM login + REST auth | `joinRTCChannel()` / `loginRTM()` / `Authorization` header |
| `agentToken` | Agent RTC join credential | Request body `properties.token` |

Notes:

- `userToken` is generated with the current `channelName`
- this target does not generate a separate `authToken`
- production should replace the demo token service with a backend

## Agent Lifecycle

```text
IDLE
  → LISTENING
  → THINKING
  → SPEAKING
  → LISTENING
```

Additional behavior:

- the initial UI state is unknown until agent events arrive
- tapping Stop unsubscribes RTM, stops the Agent, leaves RTC, logs out RTM, and resets desktop UI state

## Config Contract

```text
KeyCenter.swift
  → ViewController / AgentManager / NetworkManager
```

Required fields:

- `AGORA_APP_ID`
- `AGORA_APP_CERTIFICATE`
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
- `ConversationalAIAPI/` should be copied as-is and not modified in place

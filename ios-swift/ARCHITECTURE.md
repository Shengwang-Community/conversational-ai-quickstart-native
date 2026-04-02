# Architecture — Conversational AI Quickstart iOS Swift

## Architecture Overview

This quickstart is a single-screen voice conversation demo built with UIKit and programmatic views.

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

## Page Layout

The page is intentionally single-screen and is organized into these regions:

- debug log panel at the top
- start view before connection
- transcript list after connection
- agent status view
- mute / stop controls

## Project Structure

```text
ios-swift/
├── Podfile
├── VoiceAgent/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
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
  → generate user token
  → login RTM
  → join RTC
  → subscribe RTM channel
  → generate agentToken
  → POST /join with inline ASR / LLM / TTS config
  → save agentId
  → switch to chat view
```

iOS Swift-specific conventions:

- `uid` and `agentUid` are random integers and do not conflict
- `channel` format is `channel_swift_<6-digit-random>`
- REST auth header is `Authorization: agora token=<token>`

## Transcript Data Flow

```text
RTM message
  → ConversationalAIAPI
  → ViewController.onTranscriptUpdated(...)
  → transcripts update
  → ChatSessionView table reload
```

The current UI renders:

- agent transcript on the left
- user transcript on the right

## UI State Rendering

```text
isLoading / isError  → loading toast / error toast
currentAgentState    → AgentStateView status
transcripts          → transcript table content
debug log text       → top log panel
isMicMuted           → mic button state
```

## Token Flow

The quickstart generates two token roles through the demo token service:

| Token | Purpose | Usage |
|-------|---------|-------|
| `token` | User RTC join + RTM login + REST auth | `joinChannel()` / `loginRTM()` / `Authorization` header |
| `agentToken` | Agent RTC join credential | Request body `properties.token` |

Notes:

- `token` is generated with the current `channel`
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

- `unknown` is the initial UI state before agent events arrive
- tapping Stop unsubscribes RTM, stops the Agent, leaves RTC, logs out RTM, and resets UI state

## Config Contract

```text
KeyCenter.swift
  → ViewController / AgentManager / NetworkManager
```

Required fields:

- `AG_APP_ID`
- `AG_APP_CERTIFICATE`
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

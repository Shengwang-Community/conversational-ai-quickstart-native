# Architecture — Conversational AI Quickstart iOS SwiftUI

## Architecture Overview

This quickstart is a single-screen voice conversation demo built with SwiftUI.

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
ios-swiftui/
├── Podfile
├── VoiceAgent/
│   ├── VoiceAgentApp.swift
│   ├── KeyCenter.swift
│   ├── Chat/
│   │   ├── VoiceAgentRootView.swift
│   │   └── ChatSessionViewModel.swift
│   ├── Tools/
│   │   ├── AgentManager.swift
│   │   └── NetworkManager.swift
│   └── ConversationalAIAPI/
│       └── ...        # Read-only RTM parsing / transcript component
└── VoiceAgent.xcworkspace
```

## Runtime Shape

```text
VoiceAgentRootView / ChatSessionViewModel /
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
  → generate agentToken + authToken
  → POST /join/ with inline ASR / LLM / TTS config
  → save agentId
  → switch to chat view
```

SwiftUI-specific conventions:

- `uid` and `agentUid` are random integers and do not conflict
- `channel` format is `channel_swiftui_<6-digit-random>`
- REST auth header is `Authorization: agora token=<authToken>`

## Transcript Data Flow

```text
RTM message
  → ConversationalAIAPI
  → ChatSessionViewModel.onTranscriptUpdated(...)
  → transcripts update
  → SwiftUI transcript list rerender
```

The current UI renders:

- agent transcript on the left
- user transcript on the right

## UI State Rendering

```text
isLoading / isError      → loading overlay / alert
agentState               → AgentStateView status
transcripts              → transcript list content
debugMessages            → top log panel
isMicMuted               → mic button state
isShowing...View flags   → start view / chat view switching
```

## Token Flow

The quickstart generates three token roles through the demo token service:

| Token | Purpose | Usage |
|-------|---------|-------|
| `userToken` | User RTC join + RTM login | `joinRTCChannel()` / `loginRTM()` |
| `agentToken` | Agent RTC join credential | Request body `properties.token` |
| `authToken` | REST API authentication | `Authorization: agora token=<authToken>` |

Notes:

- `userToken` uses `channelName=""` in the current demo flow
- `agentToken` and `authToken` are generated after RTC / RTM are both ready
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
- tapping Stop Agent stops the Agent, leaves RTC, logs out RTM, unsubscribes RTM, and resets published state

## Config Contract

```text
KeyCenter.swift
  → ChatSessionViewModel / AgentManager / NetworkManager
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

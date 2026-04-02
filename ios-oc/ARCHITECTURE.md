# Architecture — Conversational AI Quickstart iOS Objective-C

## Architecture Overview

This quickstart is a single-screen voice conversation demo built with UIKit and Objective-C.

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
ios-oc/
├── Podfile
├── VoiceAgent/
│   ├── main.m
│   ├── AppDelegate.h/.m
│   ├── SceneDelegate.h/.m
│   ├── ViewController.h/.m
│   ├── KeyCenter.h/.m
│   ├── Chat/
│   │   ├── ConnectionStartView.h/.m
│   │   ├── ChatSessionView.h/.m
│   │   ├── AgentStateView.h/.m
│   │   └── TranscriptMessageCell.h/.m
│   ├── Tools/
│   │   └── AgentManager.h/.m
│   └── ConversationalAIAPI/
│       └── ...        # Read-only RTM parsing / transcript component
└── VoiceAgent.xcworkspace
```

## Runtime Shape

```text
ViewController /
RTC / RTM / ConversationalAIAPI /
AgentManager
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
  → POST /join with inline ASR / LLM / TTS config
  → save agentId
  → switch to chat view
```

Objective-C-specific conventions:

- `uid` and `agentUid` are random integers and do not conflict
- `channel` format is `channel_oc_<6-digit-random>`
- REST auth header is `Authorization: agora token=<authToken>`

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
isLoading / isError   → loading toast / error toast
currentAgentState     → AgentStateView status
transcripts           → transcript table content
debug log text        → top log panel
isMicMuted            → mic button state
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
- `agentToken` and `authToken` are generated after RTC / RTM subscription is ready
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
- tapping Stop stops the Agent, leaves RTC, logs out RTM, unsubscribes RTM, and resets local state

## Config Contract

```text
KeyCenter.h/.m
  → ViewController / AgentManager
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

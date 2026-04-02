# Architecture — Conversational AI Quickstart Windows C++

## Architecture Overview

This quickstart is a single-window voice conversation demo built with MFC.

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
- debug log panel on the right
- transcript panel
- bottom agent status view
- start / mute / stop controls

## Project Structure

```text
windows-cpp/
├── VoiceAgent.sln
├── VoiceAgent/
│   ├── src/
│   │   ├── General/        # App bootstrap
│   │   ├── ui/             # MainFrm
│   │   ├── Chat/           # ConnectionStartView / ChatSessionView / AgentStateView
│   │   ├── tools/          # AgentManager / NetworkManager / Logger / StringUtils
│   │   ├── api/            # HttpClient
│   │   ├── KeyCenter.h
│   │   └── ConversationalAIAPI/
│   │       └── ...         # Read-only RTM parsing / transcript component
│   ├── project/
│   └── resources/
```

## Runtime Shape

```text
CMainFrame /
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
  → switch to chat session view
```

Windows-specific conventions:

- `m_userUid` and `m_agentUid` are random integers and do not conflict
- channel is generated at session start in `generateRandomChannelName()`
- REST auth header is `Authorization: agora token=<m_userToken>`

## Transcript Data Flow

```text
RTM message
  → ConversationalAIAPI
  → CMainFrame transcript handlers
  → m_transcripts update
  → ChatSessionView refreshes transcript rows
```

The current UI renders:

- agent transcript on the left
- user transcript on the right

## UI State Rendering

```text
session status text     → Start / Launching / Error feedback
current agent state     → AgentStateView status
m_transcripts           → transcript list content
debug log list          → right-side log panel
m_isMicMuted            → mute button state
```

## Token Flow

The quickstart generates two token roles through the demo token service:

| Token | Purpose | Usage |
|-------|---------|-------|
| `m_userToken` | User RTC join + RTM login + REST auth | `joinRTCChannel()` / `loginRTM()` / `Authorization` header |
| `m_agentToken` | Agent RTC join credential | Request body `properties.token` |

Notes:

- `m_userToken` is generated with the current channel
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
- clicking Stop unsubscribes RTM, stops the Agent, leaves RTC, logs out RTM, and resets controller state

## Config Contract

```text
KeyCenter.h
  → AgentManager / NetworkManager / CMainFrame
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

# Architecture — Conversational AI Quickstart React Native

## Architecture Overview

This quickstart is a single-screen React Native voice conversation demo.

Current scope:

- initialize RTC
- request microphone permission
- generate demo tokens
- join RTC
- create RTC DataStream
- start Agent via REST API
- render transcripts
- render Agent state
- mute / unmute microphone
- stop Agent and clean up

Out of scope:

- text input UI
- image message UI
- backend-owned token generation
- server-owned Agent startup flow
- multi-screen app architecture

## Page Layout

The app is intentionally single-screen and split into these regions:

- title section
- log panel
- transcript panel
- bottom action bar

Within the main content area:

- log panel uses roughly 30% of the vertical space
- transcript panel uses roughly 70% of the vertical space

The transcript panel also owns the bottom status strip that shows the current Agent state.

## Project Structure

```text
react-native/
├── App.tsx                          # App entry
├── app.json                         # App name / display name
├── package.json                     # RN scripts and dependencies
├── android/
│   └── app/src/main/java/cn/shengwang/convoai/quickstart/
│       ├── MainActivity.kt
│       └── MainApplication.kt
├── ios/
│   ├── Podfile
│   └── reactnative/
│       └── Info.plist
└── src/
    ├── api/
    │   ├── AgentStarter.ts
    │   └── TokenGenerator.ts
    ├── components/
    │   ├── ActionBar.tsx
    │   ├── AgentChatPage.tsx
    │   ├── LogCard.tsx
    │   └── TranscriptPanel.tsx
    ├── stores/
    │   └── AgentChatStore.ts
    ├── theme/
    │   └── chatTheme.ts
    ├── types/
    │   └── index.ts
    └── utils/
        ├── ChannelNameGenerator.ts
        ├── KeyCenter.ts
        ├── MessageParser.ts
        └── PermissionHelper.ts
```

## Runtime Shape

```text
App
  → AgentChatPage
    → Zustand store
      → RTC engine
      → TokenGenerator
      → AgentStarter
      → MessageParser
```

Unlike Android ViewModel or Flutter `setState()`-driven implementations, React Native centralizes session logic inside a single Zustand store.
Native debug runs in this project load bundled JS assets directly; Metro is retained only for bundle generation during build.

## State Model

`AgentChatStore` is the runtime center of the app.

It exposes:

- `connectionState`
  - `Idle`
  - `Connecting`
  - `Connected`
  - `Error`
- `agentState`
  - `idle`
  - `silent`
  - `listening`
  - `thinking`
  - `speaking`
- `isMuted`
- `transcripts`
- `logs`
- `agentId`

It also keeps non-UI session internals inside the store closure:

- `rtcEngine`
- `rtcJoined`
- `channelName`
- `authToken`
- `dataStreamId`
- `messageParser`
- `userId`
- `agentRtcUid`

## Connection Flow

```text
App mount
  → AgentChatPage calls initRtcEngine()

User taps Start Agent
  → request microphone permission
  → set connectionState = Connecting
  → generate random channelName
  → generate user token
  → join RTC channel
  → onJoinChannelSuccess
    → create RTC DataStream
    → generate agent token
    → generate REST auth token
    → POST /join
    → save agentId + authToken
    → set connectionState = Connected
```

Current conventions:

- channel name format: `channel_reactnative_<6 digits>`
- user RTC UID: random `100000..999999`
- agent RTC UID: another random `100000..999999` that is different from the user UID
- start flow uses `messageTransport: 'datastream'`

## Message Flow

React Native uses RTC DataStream for non-audio messages.

```text
RTC onStreamMessage
  → copy Uint8Array payload
  → async string decode
  → MessageParser.parseStreamMessage(...)
  → InteractionManager.runAfterInteractions(...)
  → handleParsedMessage(...)
  → update logs / transcripts / agent state
```

Supported message types in the current store:

- `assistant.transcription`
- `user.transcription`
- `message.state`
- `message.interrupt`
- `message.error`

Current behavior by message type:

- `assistant.transcription`
  - upserts agent transcript by `turnId + type`
- `user.transcription`
  - upserts user transcript by `turnId + type`
- `message.state`
  - updates `agentState`
- `message.interrupt`
  - currently logged only
- `message.error`
  - writes a formatted Agent error line into the log panel

## Transcript Flow

```text
Parsed DataStream message
  → handleParsedMessage()
  → addTranscript()
  → upsert by (turnId + speaker type)
  → TranscriptPanel FlatList rerender
```

Transcript rendering rules:

- agent transcript appears on the left with `AI`
- user transcript appears on the right with `Me`
- later updates for the same turn replace earlier text instead of appending duplicates

## Log Flow

```text
RTC / token / REST / parser events
  → addLog()
  → keep latest 20 entries
  → LogCard rerender
```

Log color is derived from message content:

- error-like text → red
- success-like text → green
- in-progress / startup-like text → amber
- default → muted text color

## Mute Flow

```text
User taps Mic / Off
  → toggleMute()
  → flip isMuted
  → rtcEngine.adjustRecordingSignalVolume(0 or 100)
```

This only affects the local microphone send volume. It does not stop the session.

## Stop Flow

```text
User taps Stop Agent
  → if agentId exists, POST /leave
  → leave RTC channel
  → clear local session state
  → reset UI back to Idle
```

The current stop path resets:

- `connectionState`
- `agentState`
- `isMuted`
- `transcripts`
- `agentId`
- `channelName`
- `authToken`

## Token Flow

The demo token service provides a unified token string.

Current usage:

| Token Request | UID | Purpose |
|---------------|-----|---------|
| user token | runtime `userId` | RTC join for the local user |
| agent token | runtime `agentRtcUid` | Agent RTC credential in `/join` |
| REST auth token | runtime `userId` | `Authorization: agora token=<token>` header |

All tokens use the same current channel name.

## Agent Start Request Shape

The request body is built in `src/api/AgentStarter.ts`.

Important current values:

- `advanced_features.enable_rtm = false`
- `parameters.data_channel = "datastream"`
- `parameters.enable_error_message = true`
- `parameters.transcript.enable_words = false`
- `enable_string_uid = false`
- `idle_timeout = 120`

Provider defaults:

- ASR: `fengming`
- LLM: `aliyun`
- TTS: `bytedance`

## Config Contract

```text
.env
  → react-native-config
  → KeyCenter
  → runtime modules
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

Unlike Android build-time validation, this React Native quickstart does not fail the build when config is missing. Most configuration mistakes surface during runtime.

## Native Runtime Notes

- Android package namespace: `cn.shengwang.convoai.quickstart`
- Android launcher applicationId: `cn.shengwang.convoai.quickstart.reactnative`
- Android permissions:
  - `INTERNET`
  - `RECORD_AUDIO`
  - `MODIFY_AUDIO_SETTINGS`
- iOS microphone usage text is declared in `ios/reactnative/Info.plist`
- iOS includes `Permission-Microphone` pod from `react-native-permissions`

## Constraints

1. This is a demo; secrets are exposed to the client through native env config for convenience.
2. Production must move token generation and Agent startup to a backend.
3. DataStream parsing and store-side event handling must remain aligned with the actual Agent payload contract.
4. The quickstart is optimized for a simple single-session voice chat flow, not a reusable app framework.

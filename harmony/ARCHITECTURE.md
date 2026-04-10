# Architecture — Conversational AI Quickstart Harmony

## Overview

This quickstart is a single-screen HarmonyOS voice conversation demo.

Current scope:

- request microphone permission
- initialize RTC engine
- initialize RTM client
- generate demo tokens
- join RTC
- login RTM
- subscribe RTM channel
- start Agent via REST API
- render transcripts
- render Agent state
- mute / unmute microphone
- stop Agent and clean up

## Project Structure

```text
harmony/
├── AppScope/
├── build-profile.json5
├── oh-package.json5
└── entry/
    ├── oh-package.json5
    ├── libs/
    │   ├── AgoraRtmSDK.har
    │   └── Agora_Native_SDK_for_HarmonyOS_v4.4.2_FULL.har
    └── src/main/
        ├── ets/
        │   ├── api/
        │   │   ├── AgentStarter.ets
        │   │   ├── HttpClient.ets
        │   │   └── TokenGenerator.ets
        │   ├── common/
        │   │   ├── ChannelNameGenerator.ets
        │   │   ├── KeyCenter.ets
        │   │   ├── Theme.ets
        │   │   └── Types.ets
        │   ├── controller/
        │   │   └── AgentChatController.ets
        │   ├── pages/
        │   │   └── Index.ets
        ├── module.json5
        └── resources/
            └── rawfile/
                └── env.local
```

## Runtime Shape

```text
EntryAbility
  → Index page
    → AgentChatController
      → RtcEngine
      → RtmClient
      → TokenGenerator
      → AgentStarter
```

## Connection Flow

```text
Page appears
  → KeyCenter loads `rawfile/env.local`
  → generate random userId / agentRtcUid
  → initRtcEngine()
  → initRtmClient()

User taps Start Agent
  → request microphone permission
  → set connectionState = Connecting
  → generate random channelName
  → generate user token
  → join RTC channel
  → login RTM + subscribe channel
  → RTC and RTM are both ready
    → generate agent token
    → generate REST auth token
    → POST /join with `data_channel=rtm`
    → save agentId + authToken
    → set connectionState = Connected
```

## Stop Flow

```text
User taps Stop Agent
  → POST /agents/{agentId}/leave
  → leave RTC channel
  → unsubscribe RTM channel
  → logout RTM
  → clear agentId / authToken / channelName
  → reset transcript, mute state, and connection state
```

## Message Flow

Harmony uses:

- audio over RTC
- transcripts / error messages over RTM message events
- agent state over RTM presence events

Supported message types:

- `assistant.transcription`
- `user.transcription`
- `message.state`
- `message.interrupt`
- `message.error`

Transcript updates are upserted by `turnId + type`, so later partial/final packets replace earlier text instead of duplicating it.

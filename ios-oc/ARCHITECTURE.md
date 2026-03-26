# Architecture — Conversational AI Quickstart iOS Objective-C

## Project Structure

```
ios-oc/
├── Podfile                            # CocoaPods dependencies
├── VoiceAgent/
│   ├── main.m                         # App entry
│   ├── AppDelegate.h/.m               # App lifecycle
│   ├── SceneDelegate.h/.m             # Scene lifecycle
│   ├── KeyCenter.h/.m                 # Credentials and provider config
│   ├── ViewController.h/.m            # Main controller (connection flow, UI switching)
│   ├── Chat/
│   │   ├── ConfigBackgroundView.h/.m  # Config page (Start button)
│   │   ├── ChatBackgroundView.h/.m    # Chat page (transcript list, mic, hang up)
│   │   ├── AgentStateView.h/.m        # Agent state view
│   │   └── TranscriptCell.h/.m        # Transcript row
│   ├── ConversationalAIAPI/           # RTM message parsing layer
│   │   ├── ConversationalAIAPI.swift
│   │   ├── ConversationalAIAPIImpl.swift
│   │   └── Transcript/
│   └── Tools/
│       └── AgentManager.h/.m          # Agora REST API + token generation
└── VoiceAgent.xcworkspace/            # ← Open this
```

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| AgoraRtcEngine_iOS | 4.5.1 | Real-time audio |
| AgoraRtm/RtmKit | 2.2.6 | Real-time messaging (lite version, no aosl conflict) |
| Masonry | latest | Auto Layout DSL for Objective-C UI |

## Module Responsibilities

### KeyCenter
Stores all user-configurable credentials (APP_ID, API keys, vendor IDs). Equivalent to a local config file.

### ViewController
Single-page controller managing two views: `ConfigBackgroundView` (pre-connection) and `ChatBackgroundView` (in-call). Orchestrates token generation, RTM login, RTC join, ConvoAI subscription, and agent start/stop.

### AgentManager
Wraps Agora Conversational AI REST API and demo token generation. Handles `start` and `stop` calls with token authentication (`agora token=` header).

### ConversationalAIAPI
Parses RTM messages from the Agora server into typed Swift callbacks. Objective-C consumes those callbacks through the generated Swift bridge and updates UI state.

### Chat Views
- `ConfigBackgroundView` — Start button, shown before connection
- `ChatBackgroundView` — Transcript table view, mic toggle, stop button
- `AgentStateView` — Agent state label view
- `TranscriptCell` — Transcript bubble row

## State Management

`ViewController` holds all runtime state as instance properties:

| Property | Type | Lifecycle |
|----------|------|-----------|
| `uid` | NSInteger | Random at init, fixed for VC lifetime |
| `agentUid` | NSInteger | Random at init, fixed for VC lifetime |
| `channel` | NSString | Generated each time Start is tapped |
| `userToken` | NSString | Generated per connection |
| `agentToken` | NSString | Generated per connection |
| `authToken` | NSString | Generated per connection |
| `agentId` | NSString | Returned from REST API on agent start |
| `transcripts` | NSMutableArray<Transcript *> | Accumulated during call, cleared on hang up |
| `isMicMuted` | BOOL | Toggled by mic button |
| `currentAgentState` | NSInteger | Updated via RTM callbacks |

## Authentication

- RTC/RTM tokens: Generated via external token service using APP_ID + APP_CERTIFICATE
- REST API: Uses the dedicated auth token in header `Authorization: agora token={authToken}`
- No Basic Auth (REST Key/Secret) required

# Architecture — Conversational AI Quickstart macOS

## Project Structure

```
macos-swift/
├── Podfile                            # CocoaPods dependencies
├── VoiceAgent/
│   ├── UI/
│   │   ├── AppDelegate.swift          # App entry
│   │   ├── ViewController.swift       # Main controller (connection flow, UI switching)
│   │   ├── MessageListView.swift      # Transcript list view
│   │   └── LogView.swift              # Debug/log panel
│   ├── API/
│   │   ├── AgentManager.swift         # Agora REST API (start/stop agent)
│   │   ├── TokenGenerator.swift       # Token generation
│   │   └── HTTPClient.swift           # Shared HTTP helper
│   ├── ConversationalAIAPI/           # RTM message parsing layer
│   │   ├── ConversationalAIAPI.swift
│   │   ├── ConversationalAIAPIImpl.swift
│   │   └── Transcript/
│   └── KeyCenter.swift                # Credentials and provider config
└── VoiceAgent.xcworkspace/            # ← Open this
```

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| ShengwangRtcEngine_macOS | 4.6.0 | Real-time audio |
| AgoraRtm/RtmKit | 2.2.6 | Real-time messaging |
| SnapKit | latest | Auto Layout DSL |

## Module Responsibilities

### KeyCenter
Stores all user-configurable credentials (APP_ID, API keys, vendor IDs). Equivalent to `.env`.

### ViewController
Single-page desktop controller managing the log panel, transcript list, control bar, and the connection sequence: token generation → RTM login → RTC join → ConvoAI subscription → agent start.

### AgentManager
Wraps Agora Conversational AI REST API. Handles `start` and `stop` calls with token authentication (`agora token=` header).

### TokenGenerator
Calls the demo token service to produce RTC+RTM tokens from APP_ID + APP_CERTIFICATE.

### ConversationalAIAPI
Parses RTM messages from the Agora server into typed Swift callbacks: `onTranscriptUpdated`, `onAgentStateChanged`, `onAgentMetrics`, `onAgentError`, etc. `ViewController` implements these callbacks to update the desktop UI.

### UI Views
- `MessageListView` — Transcript list
- `LogView` — Debug/log area
- `ViewController` — Main window composition and state ownership

## State Management

`ViewController` holds all state as instance properties:

| Property | Type | Lifecycle |
|----------|------|-----------|
| `userUid` | UInt | Random at init, fixed for controller lifetime |
| `agentUid` | UInt | Random at init, fixed for controller lifetime |
| `channelName` | String | Generated each time Start is tapped |
| `userToken` | String | Generated per connection |
| `agentToken` | String | Generated per connection |
| `authToken` | String | Generated per connection |
| `agentId` | String | Returned from REST API on agent start |
| `transcripts` | [Transcript] | Accumulated during call, cleared on hang up |
| `isMuted` | Bool | Toggled by mic button |
| `rtcJoined` / `rtmLoggedIn` | Bool | Used to gate startup sequence |

## Authentication

- RTC/RTM tokens: Generated via external token service using APP_ID + APP_CERTIFICATE
- REST API: Uses the dedicated auth token in header `Authorization: agora token={authToken}`
- No Basic Auth (REST Key/Secret) required

# Architecture — Conversational AI Quickstart iOS SwiftUI

## Project Structure

```
ios-swiftui/
├── Podfile                            # CocoaPods dependencies
├── VoiceAgent/
│   ├── VoiceAgentApp.swift            # App entry
│   ├── KeyCenter.swift                # Credentials and provider config
│   ├── Chat/
│   │   ├── AgentView.swift            # Main SwiftUI view (config + chat states)
│   │   └── AgentViewModel.swift       # State model and connection flow
│   ├── ConversationalAIAPI/           # RTM message parsing layer
│   │   ├── ConversationalAIAPI.swift
│   │   ├── ConversationalAIAPIImpl.swift
│   │   └── Transcript/
│   └── Tools/
│       ├── AgentManager.swift         # Agora REST API (start/stop agent)
│       └── NetworkManager.swift       # HTTP requests + token generation
└── VoiceAgent.xcworkspace/            # ← Open this
```

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| AgoraRtcEngine_iOS | 4.5.1 | Real-time audio |
| AgoraRtm/RtmKit | 2.2.6 | Real-time messaging (lite version, no aosl conflict) |

## Module Responsibilities

### KeyCenter
Stores all user-configurable credentials (APP_ID, API keys, vendor IDs). Equivalent to `.env`.

### AgentViewModel
Owns the full connection sequence, including token generation, RTM login, RTC join, ConvoAI subscription, and agent start/stop. Also owns the debug log text, transcript list, and chat UI state.

### AgentView
SwiftUI container that switches between the config view and chat view, while keeping the top debug/log area always visible.

### AgentManager
Wraps Agora Conversational AI REST API. Handles `start` and `stop` calls with token authentication (`agora token=` header).

### NetworkManager
Generic HTTP client. Also provides `generateToken()` which calls an external token service to produce RTC+RTM tokens from APP_ID + APP_CERTIFICATE.

### ConversationalAIAPI
Parses RTM messages from the Agora server into typed Swift callbacks: `onTranscriptUpdated`, `onAgentStateChanged`, `onAgentMetrics`, `onAgentError`, etc. `AgentViewModel` implements these callbacks to update SwiftUI state.

## State Management

`AgentViewModel` holds all runtime state as published properties or private instance properties:

| Property | Type | Lifecycle |
|----------|------|-----------|
| `uid` | Int | Random at init, fixed for view model lifetime |
| `agentUid` | Int | Random at init, fixed for view model lifetime |
| `channel` | String | Generated each time Start is tapped |
| `userToken` | String | Generated per connection |
| `agentToken` | String | Generated per connection |
| `authToken` | String | Generated per connection |
| `agentId` | String | Returned from REST API on agent start |
| `transcripts` | [Transcript] | Accumulated during call, cleared on hang up |
| `isMicMuted` | Bool | Toggled by mic button |
| `agentState` | AgentState | Updated via RTM callbacks |
| `debugMessages` | String | Accumulated debug log shown in the top panel |

## Authentication

- RTC/RTM tokens: Generated via external token service using APP_ID + APP_CERTIFICATE
- REST API: Uses the dedicated auth token in header `Authorization: agora token={authToken}`
- No Basic Auth (REST Key/Secret) required

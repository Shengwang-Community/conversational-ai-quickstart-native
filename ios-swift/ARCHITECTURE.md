# Architecture — Conversational AI Quickstart iOS

## Project Structure

```
ios-swift/
├── Podfile                            # CocoaPods dependencies
├── VoiceAgent/
│   ├── AppDelegate.swift              # App entry
│   ├── SceneDelegate.swift            # Scene lifecycle
│   ├── KeyCenter.swift                # Credentials and provider config
│   ├── ViewController.swift            # Main controller (connection flow, UI switching)
│   ├── AppColors.swift                # Color palette (dark theme)
│   ├── Chat/
│   │   ├── ConfigBackgroundView.swift # Config page (Start button)
│   │   ├── ChatBackgroundView.swift   # Chat page (transcript list, mic, hang up)
│   │   └── AgentStateView.swift       # Agent state indicator dot
│   ├── ConversationalAIAPI/           # RTM message parsing layer
│   │   ├── ConversationalAIAPI.swift  # Protocol + data model definitions
│   │   ├── ConversationalAIAPIImpl.swift # RTM message → structured callbacks
│   │   └── Transcript/               # Transcript data models
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
| SnapKit | latest | Auto Layout DSL |

## Module Responsibilities

### KeyCenter
Stores all user-configurable credentials (APP_ID, API keys, voice IDs). Equivalent to `.env` file.

### ViewController
Single-page controller managing two views: `ConfigBackgroundView` (pre-connection) and `ChatBackgroundView` (in-call). Orchestrates the connection sequence: token generation → RTM login → RTC join → agent start.

### AgentManager
Wraps Agora Conversational AI REST API. Handles `start` and `stop` calls with Token007 authentication (`agora token=` header).

### NetworkManager
Generic HTTP client. Also provides `generateToken()` which calls an external token service to produce RTC+RTM tokens from APP_ID + APP_CERTIFICATE.

### ConversationalAIAPI
Parses RTM messages from the Agora server into typed Swift callbacks: `onTranscriptUpdated`, `onAgentStateChanged`, `onAgentMetrics`, `onAgentError`, etc. ViewController implements these callbacks to update UI.

### Chat Views
- `ConfigBackgroundView` — Start button, shown before connection
- `ChatBackgroundView` — Transcript table view, mic toggle, hang up button
- `AgentStateView` — Colored dot with pulse animation indicating agent state (idle/listening/thinking/speaking)

### AppColors
Centralized dark theme color palette. All UI components reference colors from here.

## State Management

ViewController holds all state as instance properties:

| Property | Type | Lifecycle |
|----------|------|-----------|
| `uid` | Int | Random at init, fixed for VC lifetime |
| `agentUid` | Int | Random at init, fixed for VC lifetime |
| `channel` | String | Generated each time Start is tapped |
| `token` | String | Generated per connection |
| `agentToken` | String | Generated per connection |
| `agentId` | String | Returned from REST API on agent start |
| `transcripts` | [Transcript] | Accumulated during call, cleared on hang up |
| `isMicMuted` | Bool | Toggled by mic button |
| `currentAgentState` | AgentState | Updated via RTM callbacks |

## Authentication

- RTC/RTM tokens: Generated via external token service using APP_ID + APP_CERTIFICATE
- REST API: Uses the user's RTC token in header `Authorization: agora token={token}`
- No Basic Auth (REST Key/Secret) required

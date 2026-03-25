# Architecture — Conversational AI Quickstart macOS

## Project Structure

```text
macos-swift/
├── Podfile                              # CocoaPods dependencies
├── AGENTS.md                            # macOS-specific assistant guide
├── ARCHITECTURE.md                      # This file
├── KeyCenter.swift.example              # Credentials template
└── VoiceAgent/
    ├── UI/
    │   ├── AppDelegate.swift            # App entry
    │   ├── ViewController.swift         # Main controller and connection flow
    │   ├── MessageListView.swift        # Transcript list UI
    │   └── LogView.swift                # Right-side log panel
    ├── API/
    │   ├── AgentManager.swift           # Agent start/stop REST wrapper
    │   ├── TokenGenerator.swift         # Demo token service wrapper
    │   └── HTTPClient.swift             # Shared HTTP helper
    └── ConversationalAIAPI/             # RTM message parsing layer
```

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| ShengwangRtcEngine_macOS | 4.6.0 | Real-time audio |
| AgoraRtm | 2.2.6 | Real-time messaging |
| SnapKit | latest | Auto Layout DSL |

## Module Responsibilities

### KeyCenter
Holds Agora credentials and inline provider configuration for LLM, STT, and TTS.

### ViewController
Coordinates the full session lifecycle: token generation, RTM login, RTC join, `ConversationalAIAPI` setup, and agent start/stop. It also owns the AppKit UI state.

### AgentManager
Builds the inline ConvoAI request payload and calls the Agora REST API using token-based auth.

### TokenGenerator
Requests RTC/RTM tokens from the demo token service. This is for development only.

### ConversationalAIAPI
Parses RTM messages into typed transcript and agent-state callbacks. The app consumes those callbacks to update the UI.

## State Management

`ViewController` owns the runtime session state:

| Property | Purpose |
|----------|---------|
| `userUid` | Random local user identifier, generated once |
| `agentUid` | Random agent identifier, generated once |
| `channelName` | Random per-session channel name |
| `userToken` | Token for user RTC/RTM login |
| `agentToken` | Token placed into start-agent request body |
| `authToken` | Token used in REST `Authorization` header |
| `agentId` | Returned from agent start API |
| `rtcJoined` / `rtmLoggedIn` | Used to gate the unified startup sequence |
| `transcripts` | Transcript list rendered in the message view |

## Authentication

- RTC/RTM tokens are generated from `AGORA_APP_ID + AGORA_APP_CERTIFICATE`
- REST API auth uses `Authorization: agora token={authToken}`
- No REST key / secret or pipeline ID is used in the current macOS architecture

## UI Layout

The UI uses a desktop-oriented single-window layout:

- Main transcript pane on the left
- Agent state label under the transcript list
- Log panel pinned on the right
- Bottom control bar for Start / Mute / Stop

This keeps the interaction model close to Windows while the transport and auth model stay aligned with the mobile implementations.

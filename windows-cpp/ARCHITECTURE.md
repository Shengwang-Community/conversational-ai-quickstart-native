# Architecture — Conversational AI Quickstart Windows

## Project Structure

```text
windows-cpp/
├── VoiceAgent.sln                         # Visual Studio solution
├── AGENTS.md                             # Windows-specific assistant guide
├── ARCHITECTURE.md                       # This file
├── KeyCenter.h.example                   # Credentials template
└── VoiceAgent/
    ├── src/
    │   ├── ui/
    │   │   ├── MainFrm.h                # Main frame declaration
    │   │   └── MainFrm.cpp              # Main controller and connection flow
    │   ├── api/
    │   │   ├── AgentManager.h/.cpp      # Agent start/stop REST wrapper
    │   │   ├── TokenGenerator.h/.cpp    # Demo token service wrapper
    │   │   └── HttpClient.h/.cpp        # libcurl wrapper
    │   ├── ConversationalAIAPI/         # RTM message parsing layer
    │   ├── general/                     # App bootstrap / PCH
    │   ├── tools/                       # Logger / string helpers
    │   └── KeyCenter.h                  # Runtime config (created locally)
    ├── project/
    │   └── VoiceAgent.vcxproj           # Visual Studio project
    └── resources/                       # Win32 resources
```

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Agora RTC SDK | project-managed | Real-time audio |
| Agora RTM SDK | project-managed | Real-time messaging |
| libcurl | vcpkg | HTTP transport |
| nlohmann-json | vcpkg | JSON construction/parsing |
| MFC | Visual Studio | Desktop UI framework |

## Module Responsibilities

### KeyCenter
Holds Agora credentials and inline provider configuration for LLM, STT, and TTS.

### MainFrm
Acts as the desktop controller. It owns the RTC engine, RTM client, `ConversationalAIAPI`, UI state, and the session startup/shutdown flow.

### AgentManager
Builds the inline ConvoAI request payload and calls the Agora REST API using token-based auth.

### TokenGenerator
Requests RTC/RTM tokens from the demo token service. This is for development only.

### ConversationalAIAPI
Parses RTM messages into typed transcript and agent-state callbacks. `MainFrm` consumes those callbacks to update the UI.

## State Management

`CMainFrame` owns the runtime session state:

| Property | Purpose |
|----------|---------|
| `m_userUid` | Random local user identifier, generated once |
| `m_agentUid` | Random agent identifier, generated once |
| `m_channelName` | Random per-session channel name |
| `m_userToken` | Token for user RTC/RTM login |
| `m_agentToken` | Token placed into start-agent request body |
| `m_authToken` | Token used in REST `Authorization` header |
| `m_agentId` | Returned from agent start API |
| `m_rtcJoined` / `m_rtmLoggedIn` | Used to gate the unified startup sequence |
| `m_transcripts` | Transcript list rendered in the message panel |

## Authentication

- RTC/RTM tokens are generated from `AGORA_APP_ID + AGORA_APP_CERTIFICATE`
- REST API auth uses `Authorization: agora token={authToken}`
- No REST key / secret or pipeline ID is used in the current Windows architecture

## UI Layout

The UI uses a desktop-oriented single-window layout:

- Transcript list on the left
- Agent status under the transcript area
- Log panel pinned on the right
- Bottom control bar for Start / Mute / Stop

The UI shape stays close to macOS, while the auth and startup architecture stays aligned with the mobile implementations.

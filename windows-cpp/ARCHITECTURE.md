# Architecture — Conversational AI Quickstart Windows

## Project Structure

```
windows-cpp/
├── VoiceAgent.sln                     # Visual Studio solution
├── VoiceAgent/
│   ├── src/
│   │   ├── ui/
│   │   │   ├── MainFrm.h             # Main frame declaration
│   │   │   └── MainFrm.cpp           # Main controller (connection flow, UI switching)
│   │   ├── api/
│   │   │   ├── AgentManager.h/.cpp   # Agora REST API (start/stop agent)
│   │   │   ├── TokenGenerator.h/.cpp # Token generation
│   │   │   └── HttpClient.h/.cpp     # Shared HTTP helper
│   │   ├── ConversationalAIAPI/      # RTM message parsing layer
│   │   │   ├── ConversationalAIAPI.h
│   │   │   └── ConversationalAIAPI.cpp
│   │   ├── General/                  # App bootstrap / PCH
│   │   ├── tools/                    # Logger / string utils
│   │   └── KeyCenter.h               # Credentials and provider config
│   ├── project/                      # Visual Studio project files
│   └── resources/                    # Native resources
```

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Agora RTC SDK | project-managed | Real-time audio |
| Agora RTM SDK | project-managed | Real-time messaging |
| libcurl | vcpkg | HTTP transport |
| nlohmann-json | vcpkg | JSON build/parse |

## Module Responsibilities

### KeyCenter
Stores all user-configurable credentials (APP_ID, API keys, vendor IDs). Equivalent to `.env`.

### MainFrm
Desktop controller that owns the log panel, transcript list, RTC/RTM instances, and startup sequence: token generation → RTM login → RTC join → ConvoAI setup → agent start.

### AgentManager
Wraps Agora Conversational AI REST API. Handles `start` and `stop` calls with token authentication (`agora token=` header).

### TokenGenerator
Calls the demo token service to produce RTC+RTM tokens from APP_ID + APP_CERTIFICATE.

### ConversationalAIAPI
Parses RTM messages from the Agora server into typed C++ callbacks for transcript, state, error, and debug log updates. `MainFrm` implements these callbacks to update the desktop UI.

## State Management

`CMainFrame` holds all runtime state as member fields:

| Property | Type | Lifecycle |
|----------|------|-----------|
| `m_userUid` | unsigned int | Random at init, fixed for window lifetime |
| `m_agentUid` | unsigned int | Random at init, fixed for window lifetime |
| `m_channelName` | std::string | Generated each time Start is clicked |
| `m_userToken` | std::string | Generated per connection |
| `m_agentToken` | std::string | Generated per connection |
| `m_authToken` | std::string | Generated per connection |
| `m_agentId` | std::string | Returned from REST API on agent start |
| `m_transcripts` | std::vector<Transcript> | Accumulated during call, cleared on hang up |
| `m_isMuted` | bool | Toggled by mic button |
| `m_rtcJoined` / `m_rtmLoggedIn` | bool | Used to gate startup sequence |

## Authentication

- RTC/RTM tokens: Generated via external token service using APP_ID + APP_CERTIFICATE
- REST API: Uses the dedicated auth token in header `Authorization: agora token={authToken}`
- No Basic Auth (REST Key/Secret) required

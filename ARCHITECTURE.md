# Conversational AI Quickstart Native — Architecture

## Repo Layout

```
.
├── android-kotlin/          # Android demo (Kotlin)
│   ├── app/
│   │   └── src/main/java/
│   │       ├── cn/shengwang/convoai/quickstart/   # Business code
│   │       │   ├── ui/                            # Activity, ViewModel, dialogs
│   │       │   ├── api/                           # REST API calls, token generation
│   │       │   ├── tools/                         # Permissions, utilities
│   │       │   └── KeyCenter.kt                   # Credentials & provider config
│   │       └── io/agora/convoai/convoaiApi/       # ConversationalAIAPI (read-only)
│   ├── build.gradle.kts                           # Dependencies & SDK versions
│   └── env.example.properties                     # Credential template
│
├── ios-swift/               # iOS demo (Swift)
│   ├── VoiceAgent/
│   │   ├── ViewController.swift                   # Main controller (connection flow)
│   │   ├── KeyCenter.swift                        # Credentials & provider config
│   │   ├── Chat/                                  # UI views
│   │   ├── ConversationalAIAPI/                   # ConversationalAIAPI (read-only)
│   │   └── Tools/                                 # REST API calls, networking
│   └── Podfile                                    # Dependencies & SDK versions
│
├── AGENTS.md                # This repo's agent guide
└── ARCHITECTURE.md          # This file
```

## Key Files by Concern

| Concern | Android | iOS |
|---------|---------|-----|
| Build config / dependencies | `app/build.gradle.kts` | `Podfile` |
| Credentials & provider config | `KeyCenter.kt` + `env.properties` | `KeyCenter.swift` |
| Connection flow & lifecycle | `AgentChatViewModel.kt` | `ViewController.swift` |
| Agent start/stop REST API | `AgentStarter.kt` | `AgentManager.swift` |
| Token generation (demo only) | `TokenGenerator.kt` | `NetworkManager.swift` |
| RTM event parsing (read-only) | `convoaiApi/` | `ConversationalAIAPI/` |
| Main UI | `AgentChatActivity.kt` + XML layouts | `Chat/` views |

## How It Fits Together

Each platform follows the same pattern:

```
User action
  → generate token
    → join RTC channel + login RTM
      → start AI Agent via REST API
        → receive events through ConversationalAIAPI
          → update UI
```

Platform-specific architecture details live in each sub-project's own `ARCHITECTURE.md`.

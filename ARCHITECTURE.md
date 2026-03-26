# Conversational AI Quickstart Native — Architecture

## Repo Layout

```text
.
├── android-compose/         # Android quickstart (Kotlin + Compose)
├── android-java/            # Android quickstart (Java + View/XML)
├── android-kotlin/          # Android quickstart (Kotlin + View/XML)
├── ios-swift/               # iOS quickstart (Swift)
├── README.md                # Repo overview
├── AGENTS.md                # Repo-level agent guide
└── ARCHITECTURE.md          # Repo-level architecture overview
```

Each platform directory owns its own `README.md`, `AGENTS.md`, `ARCHITECTURE.md`, build config, and source layout. Use the platform-level docs for detailed project structure.

## Key Files by Concern

| Concern | Android Compose | Android Java | Android Kotlin | iOS |
|---------|-----------------|--------------|----------------|-----|
| Build config / dependencies | `app/build.gradle.kts` | `app/build.gradle` | `app/build.gradle.kts` | `Podfile` |
| Credentials & provider config | `KeyCenter.kt` + `env.properties` | `KeyCenter.java` + `env.properties` | `KeyCenter.kt` + `env.properties` | `KeyCenter.swift` |
| Connection flow & lifecycle | `AgentChatViewModel.kt` | `AgentChatViewModel.java` | `AgentChatViewModel.kt` | `ViewController.swift` |
| Agent start/stop REST API | `AgentStarter.kt` | `AgentStarter.java` | `AgentStarter.kt` | `AgentManager.swift` |
| Token generation (demo only) | `TokenGenerator.kt` | `TokenGenerator.java` | `TokenGenerator.kt` | `NetworkManager.swift` |
| RTM event parsing (read-only) | `convoaiApi/` | `convoaiApi/` | `convoaiApi/` | `ConversationalAIAPI/` |
| Main UI | `MainActivity.kt` + `AgentChatScreen.kt` | `AgentChatActivity.java` + XML layouts | `AgentChatActivity.kt` + XML layouts | `Chat/` views |

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

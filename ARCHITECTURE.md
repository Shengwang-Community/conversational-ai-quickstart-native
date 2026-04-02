# Conversational AI Quickstart Native — Architecture

## Repo Layout

```text
.
├── android-kotlin/          # Android quickstart (Kotlin + View/XML)
├── android-java/            # Android quickstart (Java + View/XML)
├── android-compose/         # Android quickstart (Kotlin + Compose)
├── ios-swift/               # iOS quickstart (Swift)
├── ios-swiftui/             # iOS quickstart (SwiftUI)
├── ios-oc/                  # iOS quickstart (Objective-C)
├── macos-swift/             # macOS quickstart (Swift)
├── windows-cpp/             # Windows quickstart (C++)
├── flutter/                 # Flutter quickstart (Dart + Flutter, Android/iOS)
├── react-native/            # React Native quickstart (TypeScript, Android/iOS)
├── README.md                # Repo overview
├── AGENTS.md                # Repo-level agent guide
└── ARCHITECTURE.md          # Repo-level architecture overview
```

Each platform directory owns its own `README.md`, `AGENTS.md`, `ARCHITECTURE.md`, build config, and source layout. Use the platform-level docs for detailed project structure.

## Key Files by Concern

| Platform | Build config / dependencies | Credentials & provider config | Connection flow & lifecycle | Agent start/stop REST API | Token generation (demo only) | Event parsing (read-only / reusable) | Main UI |
|----------|-----------------------------|-------------------------------|-----------------------------|----------------------------|------------------------------|--------------------------------------|---------|
| Android Kotlin | `app/build.gradle.kts` | `KeyCenter.kt` + `env.properties` | `AgentChatViewModel.kt` | `AgentStarter.kt` | `TokenGenerator.kt` | `convoaiApi/` | `AgentChatActivity.kt` + XML layouts |
| Android Java | `app/build.gradle` | `KeyCenter.java` + `env.properties` | `AgentChatViewModel.java` | `AgentStarter.java` | `TokenGenerator.java` | `convoaiApi/` | `AgentChatActivity.java` + XML layouts |
| Android Compose | `app/build.gradle.kts` | `KeyCenter.kt` + `env.properties` | `AgentChatViewModel.kt` | `AgentStarter.kt` | `TokenGenerator.kt` | `convoaiApi/` | `MainActivity.kt` + `AgentChatScreen.kt` |
| iOS Swift | `Podfile` | `KeyCenter.swift` | `ViewController.swift` | `Tools/AgentManager.swift` | `Tools/NetworkManager.swift` | `ConversationalAIAPI/` | `Chat/` views |
| iOS SwiftUI | `Podfile` | `KeyCenter.swift` | `Chat/AgentViewModel.swift` + `Chat/AgentView.swift` | `Tools/AgentManager.swift` | `Tools/NetworkManager.swift` | `ConversationalAIAPI/` | `Chat/AgentView.swift` |
| iOS Objective-C | `Podfile` | `KeyCenter.h/.m` | `ViewController.h/.m` | `Tools/AgentManager.h/.m` | `Tools/AgentManager.h/.m` | `ConversationalAIAPI/` | `Chat/` views |
| macOS Swift | `Podfile` | `KeyCenter.swift` | `UI/ViewController.swift` | `API/AgentManager.swift` | `API/TokenGenerator.swift` | `ConversationalAIAPI/` | `UI/ViewController.swift` + `UI/MessageListView.swift` + `UI/LogView.swift` |
| Windows C++ | `VoiceAgent.sln` + project / vcpkg deps | `KeyCenter.h` | `src/ui/MainFrm.cpp` | `src/api/AgentManager.h/.cpp` | `src/api/TokenGenerator.h/.cpp` | `src/ConversationalAIAPI/` | `src/ui/MainFrm.h/.cpp` |
| Flutter | `pubspec.yaml` + native `android/` / `ios/` configs | `assets/.env` + `lib/services/keycenter.dart` | `lib/agent_chat_page.dart` | `lib/services/agent_starter.dart` | `lib/services/token_generator.dart` | `lib/services/agent_event_parser.dart` + `lib/services/transcript_manager.dart` | `lib/main.dart` + `lib/agent_chat_page.dart` |
| React Native | `package.json` + native `android/` / `ios/` configs | `.env` + `src/utils/KeyCenter.ts` | `src/stores/AgentChatStore.ts` + `src/components/AgentChatPage.tsx` | `src/api/AgentStarter.ts` | `src/api/TokenGenerator.ts` | `src/utils/MessageParser.ts` | `App.tsx` + `src/components/AgentChatPage.tsx` |

## How It Fits Together

Each platform follows the same pattern:

```
User action
  → generate token
    → join RTC channel
      → establish the platform message path (RTM / DataStream / parser)
        → start AI Agent via REST API
          → receive Agent events
          → update UI
```

Platform-specific architecture details live in each sub-project's own `ARCHITECTURE.md`.

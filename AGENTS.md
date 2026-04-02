# Conversational AI Quickstart Native — Agent Guide

## What Is This

A minimal, multi-platform quickstart for building a Conversational AI app with Agora/ShengWang SDKs. Each sub-project is a self-contained, runnable demo that connects a user to an AI voice agent in real time.

This repo is meant to be a reference implementation — keep it simple, read the code, and adapt what you need.

## Platforms

| Directory | Platform | Language |
|-----------|----------|----------|
| `android-kotlin/` | Android | Kotlin |
| `android-java/` | Android | Java |
| `android-compose/` | Android | Kotlin + Compose |
| `ios-swift/` | iOS | Swift |
| `ios-swiftui/` | iOS | Swift + SwiftUI |
| `ios-oc/` | iOS | Objective-C |
| `macos-swift/` | macOS | Swift |
| `windows-cpp/` | Windows | C++ |
| `flutter/` | Android / iOS | Dart + Flutter |
| `react-native/` | Android / iOS | TypeScript + React Native |
| `unity/` | Unity | C# + Unity |

Each platform does the same thing with its own idioms. If you need to understand the pattern, either one tells the full story.

## What to Look At

Don't overthink it. The codebase is small on purpose. A few pointers:

- Dependencies and SDK versions → check each platform's build config (`build.gradle` / `build.gradle.kts` / `Podfile` / `pubspec.yaml`)
- Credentials and provider config → look for the `KeyCenter` equivalent in each project
- The connection flow (token → RTC join → message path setup → start agent) → lives in the main ViewModel / ViewController / `AgentChatPage`
- Agent start/stop REST calls → a single API wrapper file per platform
- Message parsing and event callbacks → the platform's reusable parser / API integration module

## Key Constraints

- This is a demo. Sensitive keys are configured client-side for convenience. Production apps must move them to a backend.
- Reusable integration modules such as `ConversationalAIAPI` should be treated as standalone components — do not modify them unless the platform-level docs explicitly say otherwise.
- Each platform's own `AGENTS.md` and `ARCHITECTURE.md` have deeper, platform-specific details if you need them.

# AGENTS.md

## What Is This

A minimal, multi-platform quickstart for building a Conversational AI app with Agora/ShengWang SDKs. Each sub-project is a self-contained, runnable demo that connects a user to an AI voice agent in real time.

This repo is meant to be a reference implementation — keep it simple, read the code, and adapt what you need.

## Platforms

| Directory | Platform | Language |
|-----------|----------|----------|
| `android-kotlin/` | Android | Kotlin |
| `ios-swift/` | iOS | Swift |

Each platform does the same thing with its own idioms. If you need to understand the pattern, either one tells the full story.

## What to Look At

Don't overthink it. The codebase is small on purpose. A few pointers:

- Dependencies and SDK versions → check each platform's build config (`build.gradle.kts` / `Podfile`)
- Credentials and provider config → look for the "KeyCenter" equivalent in each project
- The connection flow (token → RTC join → RTM login → start agent) → lives in the main ViewModel / ViewController
- Agent start/stop REST calls → a single API wrapper file per platform
- RTM message parsing and event callbacks → the `ConversationalAIAPI` module (read-only, reusable across projects)

## Key Constraints

- This is a demo. Sensitive keys are configured client-side for convenience. Production apps must move them to a backend.
- The `ConversationalAIAPI` module in each platform is a standalone component — do not modify it. Copy it as-is if reusing.
- Each platform's own `AGENTS.md` and `ARCHITECTURE.md` have deeper, platform-specific details if you need them.

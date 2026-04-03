# Conversational AI Quickstart Unity — Architecture

## Project Layout

```text
unity/
├── Assets/
│   ├── Agora-RTC-Plugin/          # Imported manually, git ignored
│   ├── Agora-RTM-Plugin/          # Imported manually, git ignored
│   ├── Resources/
│   │   ├── env.example.txt
│   │   ├── env.txt                # Local only
│   │   └── README_ENV.md
│   ├── Scenes/
│   │   └── SampleScene.unity
│   └── Scripts/Quickstart/
│       ├── AgentEventParser.cs
│       ├── AgentStarter.cs
│       ├── AgentStartup.cs
│       ├── EnvConfig.cs
│       ├── TokenGenerator.cs
│       └── TranscriptManager.cs
├── ProjectSettings/
└── README.md
```

## Key Files by Concern

| Concern | File |
|---------|------|
| Unity version / project baseline | `ProjectSettings/ProjectVersion.txt` |
| Credentials and provider config | `Assets/Resources/env.txt` + `Assets/Scripts/Quickstart/EnvConfig.cs` |
| Connection flow and lifecycle | `Assets/Scripts/Quickstart/AgentStartup.cs` |
| Agent start / stop REST API | `Assets/Scripts/Quickstart/AgentStarter.cs` |
| Token generation (demo only) | `Assets/Scripts/Quickstart/TokenGenerator.cs` |
| Agent state and error parsing | `Assets/Scripts/Quickstart/AgentEventParser.cs` |
| Transcript parsing and upsert | `Assets/Scripts/Quickstart/TranscriptManager.cs` |
| Main UI | `Assets/Scenes/SampleScene.unity` |
| Mobile package / app naming | `ProjectSettings/ProjectSettings.asset` |

## Runtime Flow

```text
User clicks Start
  → on Android, request microphone permission if needed
  → load env config
  → generate user token
  → initialize RTC
  → join RTC channel
  → initialize RTM
  → login RTM
  → subscribe RTM channel
  → generate agent token
  → generate REST auth token
  → start agent via REST
  → receive RTM transcript messages
  → upsert transcript list
  → refresh UI
```

## REST Model

The Unity quickstart matches the main quickstart pattern used by Android / Flutter / React Native:

- Client sends inline ASR / LLM / TTS config in the `/join` request body
- REST auth uses `Authorization: agora token=<authToken>`
- Message transport is `rtm`

Current inline provider defaults:

- ASR vendor: `fengming`
- LLM vendor: `aliyun`
- TTS vendor: `bytedance`

## UI Model

`SampleScene.unity` is still a single-scene demo, but the runtime layout is rebuilt by `AgentStartup.cs`.

Scene references:

- `LogText` for runtime status logs
- `TranscriptText` for transcript output
- `StartButton`
- `MuteButton`
- `StopButton`

Runtime behavior:

- Header shows app title and session summary
- Main content shows `Transcript` and `Log`
- Landscape prefers left/right split
- Narrow screens stack transcript over log
- Bottom action bar shows `Start Agent` / `Mute` / `Stop Agent`

## Build Targets

This Unity quickstart is currently oriented to:

- macOS Editor play
- Android device builds
- iOS device builds

Android export can be used with `Export Project` and opened in Android Studio.
iOS export is expected to be opened in Xcode.

## iOS Export Notes

- `ProjectSettings/ProjectSettings.asset` provides the iOS bundle identifier and privacy usage descriptions
- RTC and RTM iOS plugin metadata must keep the iPhone target enabled so the exported app embeds the required frameworks
- After changing bundle identifiers, privacy descriptions, or iOS plugin import settings, regenerate the Xcode project instead of reusing an old export

# Conversational AI Quickstart Unity — AI Assistant Guide

## How to Use This Project

This is a Unity quickstart for real-time voice conversation with an AI agent.

- If you need a runnable Unity demo, use this project directly.
- If you already have a Unity project, copy the core flow and adapt it to your own scene, UI, and lifecycle.

The Unity version follows the same high-level pattern as the other quickstarts:

`Token → RTC join → RTM subscribe → start Agent via REST → render transcripts`

## Project Overview

The client:

- Generates demo RTC / RTM tokens with `TokenGenerator.cs`
- Joins RTC and RTM from `AgentStartup.cs`
- Starts and stops the agent with `AgentStarter.cs`
- Parses transcript events with `TranscriptManager.cs`
- Parses agent state and agent errors with `AgentEventParser.cs`

The current Unity quickstart uses inline provider configuration in the REST request body and HTTP token auth:

- Auth header: `Authorization: agora token=<token>`
- ASR: `fengming`
- LLM: `aliyun`
- TTS: `bytedance`
- Data channel: `rtm`

## How to Switch AI Providers

Provider changes must stay in sync across these two files:

1. `Assets/Scripts/Quickstart/EnvConfig.cs`
2. `Assets/Scripts/Quickstart/AgentStarter.cs`

`EnvConfig.cs` loads provider credentials and defaults.
`AgentStarter.cs` maps them into the JSON request body and sets each `vendor` field.

When changing providers:

- Update the `vendor` value in `AgentStarter.cs`
- Update the matching request payload fields in `AgentStarter.cs`
- Add or rename the corresponding config keys in `EnvConfig.cs`
- Update `Assets/Resources/env.example.txt`

Supported vendors change over time. Refer to the ShengWang Conversational AI REST API docs for the current schema.

## Core Modules

### AgentStartup

- Main Unity entry script for the sample scene
- Owns RTC engine and RTM client lifecycle
- Wires Start / Mute / Stop buttons
- Generates:
  - user RTC / RTM token
  - agent token
  - REST auth token

### AgentStarter

- Sends POST `/join` to start the agent
- Sends POST `/agents/{agentId}/leave` to stop the agent
- Builds inline ASR / LLM / TTS config in the request body
- Uses `Authorization: agora token=<authToken>`

### TokenGenerator

- Calls `https://service.apprtc.cn/toolbox/v2/token/generate`
- Generates a unified token for RTC + RTM
- Demo only; production must move token generation to your backend

### TranscriptManager

- Parses `assistant.transcription` and `user.transcription`
- Upserts transcript items by `turn_id` + type

### EnvConfig

- Loads `Assets/Resources/env.txt`
- Uses the same uppercase env keys as the Android / Flutter / React Native quickstarts

## Configuration

`Assets/Resources/env.txt` uses:

- `APP_ID`
- `APP_CERTIFICATE`
- `LLM_API_KEY`
- `LLM_URL`
- `LLM_MODEL`
- `TTS_BYTEDANCE_APP_ID`
- `TTS_BYTEDANCE_TOKEN`

Defaults:

- `LLM_URL`: `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`
- `LLM_MODEL`: `qwen-plus`

## Constraints

- The Agora Unity RTC and RTM plugin folders are imported manually and should not be edited unless the task is specifically about SDK integration.
- This is a demo. Credentials are stored client-side for convenience. Production apps must move secrets and REST calls to a backend.
- `TokenGenerator.cs` is demo-only and should not be reused in production unchanged.

# Conversational AI Quickstart macOS — AI Assistant Guide

## How to Use This Project

This is a complete, runnable macOS demo for real-time voice conversation with an AI agent.

- If you don't have an existing macOS project, use this project directly and adapt it.
- If you already have a macOS app, focus on the key pieces here: connection flow, AppKit UI layout, and `ConversationalAIAPI` integration.

## How to Change the Server

The demo calls two backend services directly from the client:

1. Agent REST API — defined in `VoiceAgent/API/AgentManager.swift`
   - Base URL defaults to `https://api.agora.io/cn/api/conversational-ai-agent/v2/projects`
   - Start: `POST {baseUrl}/{appId}/join/`
   - Stop: `POST {baseUrl}/{appId}/agents/{agentId}/leave`
   - Auth header: `Authorization: agora token={token}`

2. Token generation service — defined in `VoiceAgent/API/TokenGenerator.swift`
   - URL defaults to `https://service.apprtc.cn/toolbox/v2/token/generate`
   - This is demo-only. Replace it with your own token backend for production.

To point the app to your own backend, edit the URL strings in `AgentManager.swift` and `TokenGenerator.swift`.

## How to Switch AI Providers

Provider configuration is split between:

1. `KeyCenter.swift` — API keys, models, regions, and voice IDs
2. `VoiceAgent/API/AgentManager.swift` — the `buildPayload(...)` request body

To switch vendors:

- Update the provider name in the payload, such as `"microsoft"` or `"minimax"`
- Adjust the nested `params` fields to match the new vendor requirements
- Add or rename the related values in `KeyCenter.swift`

## How the Connection Flow Works

The main flow lives in `VoiceAgent/UI/ViewController.swift`:

1. Generate random `userUid` and `agentUid` once per app lifetime
2. Generate a random `channelName` per session
3. Generate `userToken`
4. Join RTC and log in RTM
5. When both are ready, initialize `ConversationalAIAPI`
6. Generate `agentToken` and `authToken`
7. Start the agent via REST API

This matches the shared token-auth architecture used elsewhere in the repo.

## What NOT to Modify

`VoiceAgent/ConversationalAIAPI/` is a standalone reusable component. Do not modify it unless you are intentionally updating the shared message parsing layer.

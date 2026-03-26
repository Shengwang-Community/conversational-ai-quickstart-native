# Conversational AI Quickstart Windows — AI Assistant Guide

## How to Use This Project

This is a complete, runnable Windows desktop demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly. Modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, ConversationalAIAPI integration) and adapt them into the existing codebase.

## How to Change the Server

The demo calls two backend services directly from the client:

1. Agent REST API (start/stop agent) — defined in `VoiceAgent/src/api/AgentManager.cpp`:
   - `API_BASE_URL` defaults to `https://api.agora.io/cn/api/conversational-ai-agent/v2/projects`
   - Start: `POST {API_BASE_URL}/{appId}/join/`
   - Stop: `POST {API_BASE_URL}/{appId}/agents/{agentId}/leave`
   - Auth header: `Authorization: agora token={token}`

2. Token generation service — defined in `VoiceAgent/src/api/TokenGenerator.cpp`:
   - URL defaults to `https://service.apprtc.cn/toolbox/v2/token/generate`
   - This is a demo-only service. For production, replace it with your own backend token endpoint.

To point to your own backend: modify the URL strings in `AgentManager.cpp` and `TokenGenerator.cpp`. If your backend handles auth differently, also update the generated request headers.

⚠️ Security warning: This demo embeds all API keys (LLM, TTS) directly in the client-side request body for quick demonstration and debugging. For production, move those keys to your own backend service.

## How to Switch AI Providers

The STT/LLM/TTS vendor configuration lives in two places that must be changed together:

1. `VoiceAgent/src/KeyCenter.h` — API keys and user-configurable IDs
2. `VoiceAgent/src/api/AgentManager.cpp` — the payload that specifies vendor names and maps `KeyCenter` values into the request body

To switch a provider:
- Change the `"vendor"` value in the payload
- Update the `"params"` fields to match the new vendor's required fields
- Add/update the corresponding API key in `KeyCenter.h`

## How to Change Request Parameters

The agent start request body is built in `VoiceAgent/src/api/AgentManager.cpp` as a nested JSON payload. Key sections:

| Section | What it controls | Where in the payload |
|---------|------------------|----------------------|
| `asr` | Speech-to-text vendor and language | `properties.asr` |
| `llm` | LLM endpoint, model, system prompt, greeting/failure messages | `properties.llm` |
| `tts` | Text-to-speech vendor and synthesis parameters | `properties.tts` |
| `parameters` | Data channel (`rtm`), error message toggle | `properties.parameters` |
| `advanced_features` | RTM enable flag | `properties.advanced_features` |
| Top-level | Channel name, agent UID, idle timeout, token | `properties.*` |

To modify request parameters: edit the JSON payload in `AgentManager.cpp`. Static values should stay in `KeyCenter.h`; structural changes go directly in the payload.

## What NOT to Modify

The `VoiceAgent/src/ConversationalAIAPI/` directory is a standalone reusable component. Do not modify it. See the local code comments and parser implementation for integration details.

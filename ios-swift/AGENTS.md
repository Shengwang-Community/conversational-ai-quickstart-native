# Conversational AI Quickstart iOS — AI Assistant Guide

## How to Use This Project

This is a complete, runnable iOS demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly. Modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, ConversationalAIAPI integration) and adapt them into the existing codebase.

## How to Change the Server

The demo calls two backend services directly from the client:

1. Agent REST API (start/stop agent) — defined in `Tools/AgentManager.swift`:
   - `API_BASE_URL` defaults to `https://api.agora.io/cn/api/conversational-ai-agent/v2/projects`
   - Start: `POST {API_BASE_URL}/{appId}/join/`
   - Stop: `POST {API_BASE_URL}/{appId}/agents/{agentId}/leave`
   - Auth header: `Authorization: agora token={token}`

2. Token generation service — defined in `Tools/NetworkManager.swift` → `generateToken()`:
   - URL defaults to `https://service.apprtc.cn/toolbox/v2/token/generate`
   - This is a demo-only service. For production, replace it with your own backend token endpoint.

To point to your own backend: modify the URL strings in `AgentManager.swift` and `NetworkManager.swift`. If your backend handles auth differently, also update `AgentManager.generateHeader()`.

## How to Switch AI Providers

The STT/LLM/TTS vendor configuration lives in two places that must be changed together:

1. `KeyCenter.swift` — API keys and user-configurable IDs (key, region, model, voice_id, group_id)
2. `ViewController.swift` → `startAgent()` — the parameter dictionary that specifies vendor names and maps KeyCenter values into the request body

To switch a provider:
- Change the `"vendor"` value in the `startAgent()` dictionary (e.g., `"microsoft"` → `"deepgram"` for STT)
- Update the `"params"` sub-dictionary to match the new vendor's required fields
- Add/update the corresponding API key in `KeyCenter.swift`

Supported STT vendors: `microsoft`, `deepgram`, `ares` (built-in, no key needed)

Supported TTS vendors: `minimax`, `elevenlabs`, `microsoft`, `openai`, `cartesia`

LLM: Any OpenAI-compatible API — change `LLM_URL` and `LLM_MODEL` in `KeyCenter.swift`.

## How to Change Request Parameters

The agent start request body is built in `ViewController.swift` → `startAgent()` as a nested dictionary. Key sections:

| Section | What it controls | Where in the dictionary |
|---------|-----------------|------------------------|
| `asr` | Speech-to-text vendor, language, credentials | `properties.asr` |
| `llm` | LLM endpoint, model, system prompt, greeting/failure messages | `properties.llm` |
| `tts` | Text-to-speech vendor, voice, speed | `properties.tts` |
| `parameters` | Data channel (`rtm`), error message toggle | `properties.parameters` |
| `advanced_features` | RTM enable flag | `properties.advanced_features` |
| Top-level | Channel name, agent UID, idle timeout, token | `properties.*` |

To modify request parameters: edit the `parameter` dictionary in `startAgent()`. Static values (API keys, model names) should stay in `KeyCenter.swift`; structural changes (adding fields, changing nesting) go directly in the dictionary.

## What NOT to Modify

The `ConversationalAIAPI/` directory is a standalone reusable component. Do not modify it. See `ConversationalAIAPI/README.md` for integration details.

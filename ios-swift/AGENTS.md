# iOS Voice Agent - AI Assistant Guide

## Build and Run

```bash
cd ios-swift
pod install
open VoiceAgent.xcworkspace
# Edit KeyCenter.swift, then Run
```

## Configuration

All credentials are in `VoiceAgent/KeyCenter.swift`. Provider details (vendor, URL, model) are hardcoded in `AgentViewController.startAgent()`.

### Agora Credentials (required)

```swift
static let AG_APP_ID: String = "your_app_id"
static let AG_APP_CERTIFICATE: String = "your_app_certificate"
```

### LLM

KeyCenter:
```swift
static let LLM_API_KEY: String = "your_api_key"
```

Switch provider by modifying the `llm` dictionary in `startAgent()`:

| Provider | url | model |
|----------|-----|-------|
| OpenAI | `https://api.openai.com/v1/chat/completions` | `gpt-4o-mini` |
| DeepSeek | `https://api.deepseek.com/v1/chat/completions` | `deepseek-chat` |

Any OpenAI-compatible API works — just change url and model.

### ASR

Currently uses Agora built-in `ares` (no API key needed). To switch to Deepgram, add key to KeyCenter and modify `asr` in `startAgent()`:

```swift
// ares (no key)
"asr": ["language": "en-US", "vendor": "ares"]

// Deepgram
"asr": ["language": "en-US", "vendor": "deepgram", "params": ["key": KeyCenter.ASR_DEEPGRAM_API_KEY]]
```

### TTS

KeyCenter:
```swift
static let TTS_ELEVENLABS_API_KEY: String = "your_key"
static let TTS_ELEVENLABS_VOICE_ID: String = "pNInz6obpgDQGcFmaJgB"
static let TTS_ELEVENLABS_MODEL_ID: String = "eleven_turbo_v2"
```

Supported vendors (modify `tts` in `startAgent()`):

| vendor | Required params |
|--------|----------------|
| `elevenlabs` | key, voice_id, model_id |
| `microsoft` | key, voice |
| `openai` | api_key, voice, model |
| `minimax` | key, voice_id, model |
| `cartesia` | api_key, voice_id, model_id |

### Adding a New Provider

Only API keys and user-configurable IDs go in KeyCenter. Hardcode vendor/URL/model in code.

```swift
// KeyCenter.swift
static let NEW_PROVIDER_API_KEY: String = ""

// AgentViewController.startAgent()
"module": ["vendor": "name", "params": ["key": KeyCenter.NEW_PROVIDER_API_KEY]]
```

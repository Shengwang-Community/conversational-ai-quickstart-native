# iOS Voice Agent - AI Assistant Guide

## Build and Run

```bash
cd ios-swift
pod install
open VoiceAgent.xcworkspace
# Edit KeyCenter.swift, then Run
```

## Configuration

All credentials are in `VoiceAgent/KeyCenter.swift`. Provider details (vendor, URL, model) are configured there and referenced in `AgentViewController.startAgent()`.

### Agora Credentials (required)

```swift
static let AG_APP_ID: String = "your_app_id"
static let AG_APP_CERTIFICATE: String = "your_app_certificate"
```

### LLM — DeepSeek

```swift
static let LLM_API_KEY: String = "your_api_key"
static let LLM_URL: String = "https://api.deepseek.com/v1/chat/completions"
static let LLM_MODEL: String = "deepseek-chat"
```

Any OpenAI-compatible API works — just change URL and model.

### STT — Microsoft Azure

```swift
static let STT_MICROSOFT_KEY: String = "your_microsoft_key"
static let STT_MICROSOFT_REGION: String = "chinaeast2"
```

### TTS — MiniMax

```swift
static let TTS_MINIMAX_KEY: String = "your_minimax_key"
static let TTS_MINIMAX_MODEL: String = "speech-01-turbo"
static let TTS_MINIMAX_VOICE_ID: String = "male-qn-qingse"
static let TTS_MINIMAX_GROUP_ID: String = "your_minimax_group_id"
```

### Switching Providers

Modify `KeyCenter.swift` fields and the corresponding dictionary in `AgentViewController.startAgent()`. Only API keys and user-configurable IDs go in KeyCenter; vendor names are hardcoded in code.

Supported STT vendors: `microsoft`, `deepgram`, `ares` (built-in, no key needed)

Supported TTS vendors: `minimax`, `elevenlabs`, `microsoft`, `openai`, `cartesia`

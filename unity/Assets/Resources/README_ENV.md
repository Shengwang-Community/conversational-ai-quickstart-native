# Unity env.txt

Copy `env.example.txt` to `env.txt` and fill in your own values.

Supported keys:

- `APP_ID`
- `APP_CERTIFICATE`
- `LLM_API_KEY`
- `LLM_URL`
- `LLM_MODEL`
- `TTS_BYTEDANCE_APP_ID`
- `TTS_BYTEDANCE_TOKEN`

The Unity quickstart uses:

- Demo token generation through `service.apprtc.cn/toolbox/v2/token/generate`
- Inline provider configuration in `Assets/Scripts/Quickstart/AgentStarter.cs`
- REST auth header `Authorization: agora token=<token>`

# Conversational AI Quickstart Harmony

HarmonyOS 版对话式 AI 极简示例，提供单页语音会话链路：

- 麦克风权限申请
- Demo Token 生成
- RTC 入会
- RTM 登录与订阅
- RTM 转写/状态消息解析
- ConvoAI Agent 的 `/join` 与 `/leave` REST 调用
- 单页日志、转写和控制栏 UI

## 项目结构

```text
harmony/
├── AppScope/
├── build-profile.json5
├── entry/
│   ├── libs/
│   │   ├── AgoraRtmSDK.har
│   │   └── Agora_Native_SDK_for_HarmonyOS_v4.4.2_FULL.har
│   ├── oh-package.json5
│   └── src/main/
│       ├── ets/
│       │   ├── api/
│       │   ├── common/
│       │   ├── controller/
│       │   ├── pages/
│       └── resources/
└── oh-package.json5
```

## 配置

这里参考了 Flutter 的 `assets/.env.example` 内容风格，但 Harmony `rawfile` 里使用普通文件名 `env.local`，避免点前缀文件运行时读取失败。

可先参考 [env.example.local](/Users/zhangwei/Documents/ai_recipes/conversational-ai-quickstart-native/harmony/entry/src/main/resources/rawfile/env.example.local)，再复制为本地文件 `harmony/entry/src/main/resources/rawfile/env.local` 并填入真实值。

`env.local` 已加入 Harmony 工程的 `.gitignore`。`KeyCenter.ets` 在运行时读取这个文件。

- `APP_ID`
- `APP_CERTIFICATE`
- `LLM_API_KEY`
- `TTS_BYTEDANCE_APP_ID`
- `TTS_BYTEDANCE_TOKEN`

可选项：

- `LLM_URL`
- `LLM_MODEL`

默认 Provider 组合和 `react-native/` 一致：

- ASR: `fengming`
- LLM: `aliyun`
- TTS: `bytedance`

## 运行

1. 在 DevEco Studio 中打开 `harmony/`
2. 执行 `ohpm install`
3. 连接 HarmonyOS 设备或模拟器
4. 运行 `entry` 模块

## 流程摘要

- 初始化：加载 `env.local`，生成随机 `userId` / `agentRtcUid`，初始化 RTC 与 RTM
- 启动：申请麦克风权限，生成 `channelName` 和用户 token，RTC 入会，RTM 登录并订阅，再调用 Agent `/join`
- 运行中：RTC 承载音频，RTM 承载字幕、状态和错误消息
- 停止：调用 Agent `/leave`，退出 RTC，注销 RTM，并重置页面状态

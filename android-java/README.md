# Conversational AI Quickstart — Android Java

## 功能概述

本示例展示了如何在 Android Java 应用中集成声网 Conversational AI，实现与 AI 语音助手的实时对话。

核心能力包括：

- 实时语音交互：通过声网 RTC SDK 与 AI Agent 进行实时音频通信
- 消息传递：通过 RTM 接收 Agent 状态、转录和错误信息
- 实时转录：以聊天气泡形式展示 USER / AGENT 对话内容
- 状态管理：统一管理连接态、静音态、Agent 状态和日志
- 自动流程：完成 token 生成、RTC 加入、RTM 登录、Agent 启动
- 单页体验：日志、状态、转录和控制按钮全部集中在同一页面

## 前置条件

- Android SDK API Level 26（Android 8.0）或更高
- 声网开发者账号 [Console](https://console.shengwang.cn/)
- 已开通 **实时消息 RTM**
- 已创建声网项目并获取 App ID 和 App Certificate

## 快速开始

### 1. 克隆并进入项目

```bash
git clone https://github.com/AgoraIO-Community/conversational-ai-quickstart-native.git
cd conversational-ai-quickstart-native/android-java
```

### 2. 配置 `env.properties`

复制示例文件：

```bash
cp env.example.properties env.properties
```

填写你的实际配置：

```properties
APP_ID=your_shengwang_app_id
APP_CERTIFICATE=your_shengwang_app_certificate
LLM_API_KEY=sk-your_dashscope_api_key
TTS_BYTEDANCE_APP_ID=your_bytedance_app_id
TTS_BYTEDANCE_TOKEN=your_bytedance_access_token
```

可选配置：

```properties
LLM_URL=https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions
LLM_MODEL=qwen-plus
```

配置说明：

- `APP_ID`：声网 App ID
- `APP_CERTIFICATE`：声网 App Certificate
- `LLM_API_KEY`：阿里云百炼 DashScope API Key
- `LLM_URL`：LLM OpenAI-compatible 接口地址，默认 DashScope
- `LLM_MODEL`：LLM 模型名，默认 `qwen-plus`
- `TTS_BYTEDANCE_APP_ID`：火山引擎 TTS App ID
- `TTS_BYTEDANCE_TOKEN`：火山引擎 TTS Access Token

当前默认三段式 pipeline：

- ASR：`fengming`
- LLM：`aliyun + qwen`
- TTS：`bytedance`

### 3. 打开 Android Studio

- 使用 Android Studio 打开 `android-java/`
- 等待 Gradle 同步完成

## 启动方式

Java 版直接在客户端调用声网 RESTful API 启动 Agent：

- 鉴权头：`Authorization: agora token=<token>`
- 请求体：内联 `asr / llm / tts` 三段式配置

这适合快速体验，但仅限 Demo / 开发测试。

## 生产环境注意事项

⚠️ 以下能力在本示例中均为方便体验而放在客户端，仅适用于开发测试：

- `TokenGenerator.java` 直接使用 Demo Token 服务
- `AgentStarter.java` 直接从客户端请求 REST API
- `env.properties` 保存了敏感凭证

生产环境必须改为：

- 服务端生成 RTC / RTM / REST 鉴权 token
- 服务端保存 `APP_CERTIFICATE`、LLM/TTS 凭证
- 客户端通过业务后端启动 Agent，而不是直连 REST API

## 界面与交互

`AgentChatActivity.java` 当前界面包括：

- 深色渐变背景
- 顶部标题 / 副标题
- 深色日志面板，按 success / warning / error 着色
- 聊天气泡转录列表
- 底部 Agent 状态点 + 状态文字
- `Start Agent / Connecting... / Retry` 按钮态
- 麦克风正常态 / 静音态视觉区分

## 关键文件

- `app/src/main/java/cn/shengwang/convoai/quickstart/ui/AgentChatActivity.java`
  主界面，负责日志、状态、转录和按钮交互
- `app/src/main/java/cn/shengwang/convoai/quickstart/ui/AgentChatViewModel.java`
  RTC / RTM / Agent 生命周期与状态管理
- `app/src/main/java/cn/shengwang/convoai/quickstart/api/AgentStarter.java`
  Agent start/stop REST API，包含内联三段式 pipeline 配置
- `app/src/main/java/cn/shengwang/convoai/quickstart/api/TokenGenerator.java`
  Demo token 生成器，仅用于开发测试
- `app/src/main/java/io/agora/convoai/convoaiApi/`
  声网 ConversationalAIAPI 封装，禁止修改

## 快速验证

1. 运行应用并进入 Agent Chat 页面
2. 点击 `Start Agent`
3. 确认按钮进入 `Connecting...`
4. RTC 和 RTM 成功后，Agent 自动启动
5. 启动成功后显示麦克风和 `Stop Agent`
6. 说话后应看到左右对齐的转录气泡
7. 点击 `Stop Agent` 后应回到初始态

## License

See [LICENSE](../LICENSE).

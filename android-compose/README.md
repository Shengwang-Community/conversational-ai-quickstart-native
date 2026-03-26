# Conversational AI Quickstart — Android Compose

## 功能概述

### 解决的问题

本示例项目展示了如何在 Android 应用（Jetpack Compose）中集成声网 Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过声网 RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过声网 RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容
- **状态管理**：统一管理连接状态、Agent 状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成 Token 生成、RTC 加入、RTM 登录、Agent 启动
- **Compose UI**：使用单页 Compose 界面展示日志、状态、转录和控制按钮

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话内容
- 教育培训：构建语音交互式教学应用

### 前置条件

- Android SDK API Level 26（Android 8.0）或更高
- 声网开发者账号 [Console](https://console.shengwang.cn/)
- 已在声网控制台开通 **实时消息 RTM** 功能
- 已创建声网项目并获取 App ID 和 App Certificate

## 快速开始

### 依赖安装

1. **克隆项目**：

```bash
git clone https://github.com/AgoraIO-Community/conversational-ai-quickstart-native.git
cd conversational-ai-quickstart-native/android-compose
```

2. **配置 Android 项目**：
   - 使用 Android Studio 打开项目
   - 复制 `env.example.properties` 为 `env.properties`：

```bash
cp env.example.properties env.properties
```

   - 编辑 `env.properties`，填入你的实际配置值：

```properties
APP_ID=your_shengwang_app_id
APP_CERTIFICATE=your_shengwang_app_certificate
LLM_API_KEY=sk-your_dashscope_api_key
TTS_BYTEDANCE_APP_ID=your_bytedance_app_id
TTS_BYTEDANCE_TOKEN=your_bytedance_access_token
```

**配置项说明**：

- `APP_ID`：声网 App ID（必需）
- `APP_CERTIFICATE`：声网 App Certificate（必需，用于 Token 生成和 REST API 认证）
- `LLM_API_KEY`：阿里云百炼 DashScope API Key（必需）
- `LLM_URL`：LLM OpenAI-compatible 接口地址（可选，默认 `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`）
- `LLM_MODEL`：LLM 模型名称（可选，默认 `qwen-plus`）
- `TTS_BYTEDANCE_APP_ID`：火山引擎 TTS App ID（必需）
- `TTS_BYTEDANCE_TOKEN`：火山引擎 TTS Token（必需）
- 默认三段式 pipeline 为 `fengming + qwen + bytedance`

**获取方式**：

- 声网 App ID / App Certificate：[开通服务](https://doc.shengwang.cn/doc/convoai/restful/get-started/enable-service)
- LLM API Key：[阿里云百炼](https://help.aliyun.com/zh/model-studio/get-api-key)
- TTS 凭证：[火山引擎豆包语音文档](https://www.volcengine.com/docs/6561/105873)

**注意**：

- `env.properties` 包含敏感信息，不会提交到版本控制系统
- 每次启动时会自动生成随机 `channelName`，格式为 `channel_compose_XXXXXX`
- `TokenGenerator.kt` 仅用于演示和开发测试，生产环境必须由自有服务端生成 Token
- 本项目使用 HTTP token 鉴权（`Authorization: agora token=<token>`），必须启用 `APP_CERTIFICATE`

3. **配置 Agent 启动方式**：

默认无需额外设置。Compose 客户端会直接调用声网 RESTful API 启动 Agent，适合快速体验和功能验证。

**重要说明**：

- 此方式仅用于演示和开发测试，不推荐用于生产环境
- 生产环境必须由业务后端接管 `appCertificate` 与 LLM/TTS 凭证
- 客户端应通过业务后端获取 Token，并由后端调用声网 REST API 启动 Agent

## 默认技术基线

- **UI Framework**：Jetpack Compose + Material 3
- **RTC SDK**：`io.agora.rtc:full-sdk:4.5.1`
- **RTM SDK**：`io.agora:agora-rtm-lite:2.2.6`
- **Networking**：OkHttp 5.0.0-alpha.14
- **State Management**：ViewModel + StateFlow

## 三段式 Pipeline

`AgentStarter.kt` 默认使用与 `android-kotlin` 一致的三段式配置：

- **ASR**：Shengwang Fengming（`vendor=fengming`, `language=zh-CN`）
- **LLM**：阿里云百炼千问（DashScope OpenAI-compatible）
- **TTS**：火山引擎 / ByteDance（`vendor=bytedance`）

请求体中的关键参数包括：

- `advanced_features.enable_rtm = true`
- `parameters.data_channel = "rtm"`
- `enable_string_uid = true`
- `idle_timeout = 120`
- `remote_rtc_uids = ["*"]`

## 测试验证

### 执行时机

代码与文档改造可以先完成；真正的测试与验收请在你填写好有效 key 后进行。

### 填写 key 后的验证

1. 运行：

```bash
./gradlew :app:testDebugUnitTest :app:assembleDebug
```

2. 手动体验：
   - 进入 `MainActivity` / `AgentChatScreen`
   - 页面从上到下依次为：标题、副标题、日志区域、转录区域、状态条、控制按钮
   - 初始显示 `Start Agent`
   - 点击后按钮变为 `Connecting...`
   - RTC/RTM 完成后自动启动 Agent
   - 成功后显示 `Mute + Stop Agent`
   - 失败时按钮切换为 `Retry`
   - 聊天气泡按 `AI` 左侧、`Me` 右侧显示
   - 底部状态条显示 Agent 当前状态颜色与文案

### 功能验证清单

- [ ] 构建成功，通过 `testDebugUnitTest` 和 `assembleDebug`
- [ ] RTC 加入成功
- [ ] RTM 登录成功
- [ ] Agent 启动成功
- [ ] 日志颜色随成功/失败/进行中状态变化
- [ ] 转录气泡与头像样式正确
- [ ] 状态点和状态文案颜色正确
- [ ] 静音/取消静音正常
- [ ] 停止功能正常

## 项目结构

```text
android-compose/
├── app/
│   ├── src/main/
│   │   ├── java/io/agora/convoai/example/startup/
│   │   │   ├── ui/                 # Compose UI 和 ViewModel
│   │   │   ├── api/                # AgentStarter / TokenGenerator / OkHttp
│   │   │   ├── tools/              # PermissionHelp 等工具
│   │   │   └── KeyCenter.kt        # BuildConfig -> 常量配置
│   │   ├── res/                    # Android 资源
│   │   └── java/io/agora/convoai/convoaiApi/
│   │       └── ...                 # ConversationalAIAPI（只读，禁止修改）
├── env.example.properties          # 配置模板
├── README.md                       # 本文档
├── AGENTS.md                       # Compose 平台协作说明
└── ARCHITECTURE.md                 # Compose 平台架构说明
```

## License

See [LICENSE](./LICENSE).

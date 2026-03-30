# Conversational AI Quickstart — Flutter

## 项目标识

- Dart package name：`shengwang_convoai_quickstart_flutter`
- Android `namespace` / `applicationId`：`cn.shengwang.convoai.quickstart.flutter`
- iOS `PRODUCT_BUNDLE_IDENTIFIER`：`cn.shengwang.convoai.quickstart.flutter`
- Android / iOS 显示名：`Shengwang Conversational AI`

## 功能概述

### 解决的问题

本示例项目展示了如何在 Flutter 应用中集成声网 Conversational AI（对话式 AI）能力，实现与 AI 语音助手的实时对话交互。当前代码主要覆盖以下能力：

- **实时语音交互**：通过声网 RTC SDK 实现与 AI Agent 的实时音频通信
- **消息传递与状态同步**：通过声网 RTM SDK 接收 Agent 状态和错误事件
- **实时转录显示**：支持显示用户和 Agent 的实时转录内容，并按 `turn_id` 更新同一轮消息
- **状态管理**：统一管理连接状态、Agent 状态、静音状态、日志状态
- **自动启动流程**：自动完成权限申请、RTC 加入、RTM 登录、Agent 启动
- **单页体验**：标题、日志、转录、状态栏、控制按钮都在同一页面中完成

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 的对话字幕
- 语音互动产品：开发需要实时语音对话的应用或原型
- 教育培训：构建语音交互式教学或陪练应用

### 前置条件

- 已安装 Flutter 开发环境，推荐 Flutter 3.x
- 已具备 Android 或 iOS 真机 / 模拟器运行环境
- 声网开发者账号：[Console](https://console.shengwang.cn/)
- 已在声网控制台开通 **实时消息 RTM** 功能
- 已创建声网项目并获取 `App ID` 与 `App Certificate`
- 已准备当前默认三段式配置所需凭证：
  - `LLM_API_KEY`（阿里云百炼 DashScope）
  - `TTS_BYTEDANCE_APP_ID`
  - `TTS_BYTEDANCE_TOKEN`

## 快速开始

### 依赖安装

1. **克隆项目并进入 Flutter 子目录**：

```bash
git clone https://github.com/Shengwang-Community/conversational-ai-quickstart-native.git
cd conversational-ai-quickstart-native/flutter
```

2. **配置 Flutter 项目**：

复制 `assets/.env.example` 为 `assets/.env`：

```bash
cp assets/.env.example assets/.env
```

编辑 `assets/.env`，填入你的实际配置值：

```properties
APP_ID=your_shengwang_app_id
APP_CERTIFICATE=your_shengwang_app_certificate
LLM_API_KEY=sk-your_dashscope_api_key
TTS_BYTEDANCE_APP_ID=your_bytedance_app_id
TTS_BYTEDANCE_TOKEN=your_bytedance_access_token
```

**配置项说明**：

- `APP_ID`：你的声网 App ID（必需）
- `APP_CERTIFICATE`：你的 App Certificate（必需，用于 Token 生成和 REST API 认证）
- `LLM_API_KEY`：LLM API Key（必需，当前默认接阿里云百炼 DashScope）
- `LLM_URL`：LLM API 地址（可选，默认 `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`）
- `LLM_MODEL`：LLM 模型名称（可选，默认 `qwen-plus`）
- `TTS_BYTEDANCE_APP_ID`：火山引擎 TTS App ID（必需）
- `TTS_BYTEDANCE_TOKEN`：火山引擎 TTS Access Token（必需）
- 当前火山引擎 TTS 其余参数直接写在代码里：`cluster=volcano_tts`、`voice_type=BV700_streaming`、`speed_ratio=1.0`、`volume_ratio=1.0`、`pitch_ratio=1.0`
- 凤鸣 ASR 为当前默认供应商，示例里不需要额外字段

**获取方式**：

- 声网 App ID / App Certificate：在声网控制台创建项目并开通对话式 AI 引擎服务后获取
- `LLM_API_KEY`：在 [阿里云百炼](https://help.aliyun.com/zh/model-studio/get-api-key) 获取
- `TTS_BYTEDANCE_APP_ID` / `TTS_BYTEDANCE_TOKEN`：在 [火山引擎豆包语音文档](https://www.volcengine.com/docs/6561/105873) 对应控制台获取

**注意**：

- `assets/.env` 已在 `.gitignore` 中忽略，请不要提交真实凭证
- 应用启动时会读取 `assets/.env`
- 当前 Demo 中：
  - `userUid` 每次启动随机生成 6 位整数
  - `agentUid` 每次启动随机生成 6 位整数，且不会与 `userUid` 冲突
  - `channelName` 每次启动自动生成，格式为 `channel_kotlin_<6位随机数>`
- ⚠️ **重要**：`lib/services/token_generator.dart` 中的 Token 生成逻辑仅用于演示和开发测试，**生产环境必须改为服务端生成**

3. **安装依赖并运行**：

```bash
flutter pub get
flutter run
```

### 平台支持

- 当前仅支持移动端：**Android / iOS**
- iOS 工程当前 `Podfile` 最低版本为 **iOS 13.0**
- Web / Desktop 不在本示例支持范围内，运行时会直接提示当前平台不支持 RTC/RTM 插件
- Flutter 项目元数据也已收口为仅 `android` 与 `ios`

如果本地原生脚手架文件缺失，可使用 Flutter 官方修复命令重新生成：

```bash
flutter create --platforms=android,ios .
```

### 配置 Agent 启动方式

默认配置下，无需额外设置。Flutter 客户端会直接调用声网 RESTful API 启动 Agent，并在请求体中内联 ASR / LLM / TTS 三段式配置，适合快速体验功能。

**使用前提**：

- 确保已正确配置 `assets/.env`
- 确保控制台已启用 `App Certificate`

**适用场景**：

- 快速体验
- 功能验证
- 本地调试

⚠️ **重要说明**：

- 此方式**仅用于快速体验和开发测试**，**不推荐用于生产环境**
- 直接在客户端调用声网 RESTful API 会暴露 `APP_CERTIFICATE`、LLM API Key、TTS 凭证，存在安全风险

⚠️ **生产环境要求**：

- **必须将敏感信息放到后端**：`APP_CERTIFICATE`、`LLM_API_KEY`、`TTS_BYTEDANCE_TOKEN` 等不得保存在客户端
- **客户端通过后端获取 Token**：由业务服务端使用 `appCertificate` 生成 Token 后返回客户端
- **客户端通过后端启动 Agent**：由业务服务端拼装 `asr / llm / tts` 请求体并调用声网 RESTful API
- **客户端只保留最薄的一层会话 UI 和 RTC/RTM 接入逻辑**

## 测试验证

### 快速体验流程

1. **页面结构**（`AgentChatPage`）：

- 运行应用后进入单页聊天界面
- 页面从上到下依次为：
  - 标题与副标题
  - 日志区域
  - 转录列表区域
  - 底部 Agent 状态栏
  - 启动 / 静音 / 停止控制区

2. **启动 Agent**：

- 点击 `Start Agent`
- 按钮进入禁用态，文案变为 `Connecting...`
- 应用会自动执行以下流程：
  - 检查平台是否为 Android / iOS
  - 请求麦克风权限
  - 初始化 RTC Engine
  - 生成 `userToken`
  - 加入 RTC 频道
  - 初始化并登录 RTM
  - 订阅当前随机频道
  - 生成 `agentToken` 与 `authToken`
  - 调用 `/join/` 启动 Agent
- 如果中途失败，按钮会切换为 `Retry`
- Agent 启动成功后：
  - `Start Agent` 按钮隐藏
  - 显示圆形麦克风按钮和 `Stop Agent` 按钮
  - 默认自动开麦

3. **对话交互**：

- 用户消息右对齐显示，头像为 `Me`
- Agent 消息左对齐显示，头像为 `AI`
- 底部状态栏会随 Agent 状态变化显示 `Idle / Listening / Thinking / Speaking / Silent`
- 点击麦克风按钮可静音 / 取消静音，本质是切换录音音量 `0 / 100`
- 点击 `Stop Agent` 会取消 RTM 订阅、登出 RTM、停止 Agent、离开 RTC，并将页面重置回初始状态

### 功能验证清单

- ✅ RTC 频道加入成功
- ✅ RTM 登录成功
- ✅ Agent 启动成功
- ✅ 日志区域持续输出关键步骤
- ✅ 转录内容实时更新且同轮消息会被覆盖刷新
- ✅ Agent 状态指示正常
- ✅ 静音 / 取消静音功能正常
- ✅ 停止功能正常
- ✅ 失败后可重试

## 关键文件

- `lib/main.dart`：应用入口，负责加载配置并初始化主题
- `lib/agent_chat_page.dart`：主页面，包含 RTC/RTM 生命周期、页面状态、控制按钮和 UI 渲染
- `lib/services/keycenter.dart`：配置加载，读取 `assets/.env`
- `lib/services/agent_starter.dart`：Agent 启停 API 封装，内联默认 `asr / llm / tts` 配置，并对日志做脱敏
- `lib/services/token_generator.dart`：通过演示服务生成 RTC / RTM / REST 所需 Token
- `lib/services/agent_event_parser.dart`：解析 RTM presence 与 `message.error`
- `lib/services/transcript_manager.dart`：解析转录消息并按 `turn_id` 更新列表
- `lib/services/permission_service.dart`：麦克风权限申请与设置页引导
- `AGENTS.md`：Flutter 版本的 AI 助手接入说明
- `ARCHITECTURE.md`：Flutter 版本的运行结构与数据流说明

## 原生工程标识

- Android：
  - `namespace` / `applicationId`：`cn.shengwang.convoai.quickstart.flutter`
  - Activity 入口：`android/app/src/main/kotlin/cn/shengwang/convoai/quickstart/flutter/MainActivity.kt`
- iOS：
  - `PRODUCT_BUNDLE_IDENTIFIER`：`cn.shengwang.convoai.quickstart.flutter`
  - `CFBundleName`：`shengwang_convoai_quickstart_flutter`
  - `CFBundleDisplayName`：`Shengwang Conversational AI`

## License

See [LICENSE](../LICENSE).

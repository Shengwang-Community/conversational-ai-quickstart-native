# Conversational AI Quickstart — React Native

## 项目标识

- React Native app name：`shengwang_convoai_quickstart_reactnative`
- Android `namespace`：`cn.shengwang.convoai.quickstart`
- Android `applicationId`：`cn.shengwang.convoai.quickstart.reactnative`
- iOS `PRODUCT_BUNDLE_IDENTIFIER`：`cn.shengwang.convoai.quickstart.reactnative`
- Android / iOS 显示名：`Shengwang Conversational AI`

## 功能概述

### 解决的问题

本示例项目展示了如何在 React Native 应用中集成声网 Conversational AI（对话式 AI）能力，实现与 AI 语音助手的实时对话交互。当前代码主要覆盖以下能力：

- **实时语音交互**：通过声网 RTC SDK 实现与 AI Agent 的实时音频通信
- **消息传递与状态同步**：通过 RTC DataStream 接收 Agent 状态、错误事件和转录消息
- **实时转录显示**：支持显示用户和 Agent 的实时转录内容，并按 `turn_id` 更新同一轮消息
- **状态管理**：统一管理连接状态、Agent 状态、静音状态、日志状态
- **自动启动流程**：自动完成权限申请、RTC 加入、DataStream 创建、Agent 启动
- **单页体验**：标题、日志、转录、状态栏、控制按钮都在同一页面中完成

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 的对话字幕
- 语音互动产品：开发需要实时语音对话的应用或原型
- 教育培训：构建语音交互式教学或陪练应用

### 前置条件

- 已安装 React Native 开发环境，推荐 Node.js 22.11+
- 已具备 Android 或 iOS 真机 / 模拟器运行环境
- 声网开发者账号：[Console](https://console.shengwang.cn/)
- 已创建声网项目并获取 `App ID` 与 `App Certificate`
- React Native 当前示例使用 **RTC DataStream** 作为消息通道，不要求额外引入 RTM SDK
- 已准备当前默认三段式配置所需凭证：
  - `LLM_API_KEY`（阿里云百炼 DashScope）
  - `TTS_BYTEDANCE_APP_ID`
  - `TTS_BYTEDANCE_TOKEN`

## 快速开始

### 依赖安装

1. **克隆项目并进入 React Native 子目录**：

```bash
git clone https://github.com/Shengwang-Community/conversational-ai-quickstart-native.git
cd conversational-ai-quickstart-native/react-native
```

2. **安装依赖**：

```bash
npm install
```

3. **配置 React Native 项目**：

复制 `.env.example` 为 `.env`：

```bash
cp .env.example .env
```

编辑 `.env`，填入你的实际配置值：

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

- `.env` 已在 `.gitignore` 中忽略，请不要提交真实凭证
- 当前项目使用 `react-native-config` 直接读取 `.env`
- 修改 `.env` 后，需要重新运行 App 使原生配置重新生效
- 当前 Demo 中：
  - `USER_ID` 固定为 `1001086`
  - `AGENT_RTC_UID` 固定为 `1009527`
  - `channelName` 每次启动自动生成，格式为 `channel_reactnative_<6位随机数>`
- ⚠️ **重要**：`src/api/TokenGenerator.ts` 中的 Token 生成逻辑仅用于演示和开发测试，**生产环境必须改为服务端生成**

4. **安装 iOS 依赖**（仅 iOS 开发需要）：

```bash
cd ios
pod update
cd ..
```

5. **运行项目**：

```bash
npm run android
```

或：

```bash
npm run ios
```

如果使用 iOS 真机，建议打开 `ios/reactnative.xcworkspace` 在 Xcode 中完成签名配置后再运行。

如需手动启动 Metro bundler，可选执行：

```bash
npm start
```

但当前工程默认运行方式不依赖 Metro；Metro 仅作为 React Native 构建 bundle 时使用的打包工具保留。

### 平台支持

- 当前仅支持移动端：**Android / iOS**
- 本示例基于 **React Native CLI**，不支持 Expo
- 当前项目依赖 **React Native 0.84**
- Android 当前 `minSdkVersion` 为 **24**，`targetSdkVersion` 为 **36**
- Android ABI 当前仅保留：`armeabi-v7a`、`arm64-v8a`
- iOS 工程当前 `IPHONEOS_DEPLOYMENT_TARGET` 为 **15.1**
- Web / Desktop 不在本示例支持范围内
- Android `x86 / x86_64` 模拟器 ABI 不在当前包体支持范围内
- Android 当前会为 `debug` 变体一并打包 JS bundle，因此从 Android Studio 直接运行时**不依赖 Metro**
- iOS 当前会在 `debug` 下强制打包 `main.jsbundle`，因此从 Xcode 直接运行时**不依赖 Metro**
- Metro 配置与依赖仍然保留，因为 Android / iOS 构建 bundle 时仍然会使用 Metro 完成打包

### 配置 Agent 启动方式

默认配置下，无需额外设置。React Native 客户端会直接调用声网 RESTful API 启动 Agent，并在请求体中内联 ASR / LLM / TTS 三段式配置，适合快速体验功能。

**使用前提**：

- 确保已正确配置 `.env`
- 确保控制台已启用 `App Certificate`
- 当前消息链路使用 RTC DataStream，因此 `/join` 请求体会保留 `data_channel=datastream`

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
- **客户端只保留最薄的一层会话 UI 和 RTC/DataStream 接入逻辑**

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
- 按钮进入连接态，文案变为 `Connecting...`
- 应用会自动执行以下流程：
  - 请求麦克风权限
  - 初始化 RTC Engine
  - 生成随机 `channelName`
  - 生成 `userToken`
  - 加入 RTC 频道
  - 创建 RTC DataStream
  - 生成 `agentToken` 与 `authToken`
  - 调用 `/join` 启动 Agent
- 如果启动失败，页面会进入 `Error` 状态
- Agent 启动成功后：
  - `Start Agent` 按钮隐藏
  - 显示静音按钮和 `Stop Agent` 按钮
  - 默认自动开麦

3. **对话交互**：

- 用户消息右对齐显示，头像为 `Me`
- Agent 消息左对齐显示，头像为 `AI`
- 底部状态栏会随 Agent 状态变化显示 `Idle / Listening / Thinking / Speaking / Silent`
- 点击静音按钮可静音 / 取消静音，本质是切换录音音量 `0 / 100`
- 点击 `Stop Agent` 会停止 Agent、离开 RTC，并将页面重置回初始状态

### 功能验证清单

- ✅ RTC 频道加入成功
- ✅ RTC DataStream 创建成功
- ✅ Agent 启动成功
- ✅ 日志区域持续输出关键步骤
- ✅ 转录内容实时更新且同轮消息会被覆盖刷新
- ✅ Agent 状态指示正常
- ✅ `message.error` 会写入日志区域
- ✅ 静音 / 取消静音功能正常
- ✅ 停止功能正常

## 关键文件

- `App.tsx`：应用入口，负责挂载 `SafeAreaProvider`、状态栏和主页面
- `src/components/AgentChatPage.tsx`：主页面，组合标题、日志、转录和控制按钮
- `src/stores/AgentChatStore.ts`：核心状态与业务流程，包含 RTC 生命周期、DataStream 解析分发、日志与转录更新
- `src/api/AgentStarter.ts`：Agent 启停 API 封装，内联默认 `asr / llm / tts` 配置，并对日志做脱敏
- `src/api/TokenGenerator.ts`：通过演示服务生成 RTC / REST 所需 Token
- `src/utils/MessageParser.ts`：解析 DataStream 分片消息并还原 JSON 载荷
- `src/utils/KeyCenter.ts`：读取 `react-native-config` 暴露的环境变量并提供默认值
- `src/utils/PermissionHelper.ts`：麦克风权限申请
- `react-native-config.d.ts`：为 `react-native-config` 提供 TypeScript 类型声明
- `AGENTS.md`：React Native 版本的 AI 助手接入说明
- `ARCHITECTURE.md`：React Native 版本的运行结构与数据流说明

## 原生工程标识

- Android：
  - `namespace`：`cn.shengwang.convoai.quickstart`
  - `applicationId`：`cn.shengwang.convoai.quickstart.reactnative`
  - Activity 入口：`android/app/src/main/java/cn/shengwang/convoai/quickstart/MainActivity.kt`
- iOS：
  - `PRODUCT_BUNDLE_IDENTIFIER`：`cn.shengwang.convoai.quickstart.reactnative`
  - `CFBundleName`：`reactnative`
  - `CFBundleDisplayName`：`Shengwang Conversational AI`

## License

See [LICENSE](../LICENSE).

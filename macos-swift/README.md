# Conversational AI Quickstart — macOS Swift

## 功能概述

### 解决的问题

本示例项目展示了如何在 macOS 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、RTM 登录、Agent 启动等流程
- **统一界面**：所有功能（日志、状态、转录、控制按钮）集成在同一个页面

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri 的桌面语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- macOS 10.13 或更高版本
- Xcode 14.0 或更高版本
- CocoaPods 1.11.0 或更高版本
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已在 Agora 控制台开通 **实时消息 RTM** 功能（必需）
- 已创建 Agora 项目并获取 App ID 和 App Certificate

## 快速开始

1. **克隆项目**：
```bash
git clone https://github.com/AgoraIO-Community/conversational-ai-quickstart-native.git
cd conversational-ai-quickstart-native/macos-swift
```

2. **安装 CocoaPods 依赖**：
```bash
pod install
```

3. **配置 macOS 项目**：
   - 使用 Xcode 打开 `VoiceAgent.xcworkspace`（注意：不是 `.xcodeproj`）
   - 配置 Agora Key：

   复制 `KeyCenter.swift.example` 文件为 `VoiceAgent/KeyCenter.swift`：
   ```bash
   cp KeyCenter.swift.example VoiceAgent/KeyCenter.swift
   ```

   编辑 `VoiceAgent/KeyCenter.swift` 文件，填入你的实际配置值：
   ```swift
   struct KeyCenter {
       static let AGORA_APP_ID = "your_app_id"
       static let AGORA_APP_CERTIFICATE = "your_app_certificate"
       static let LLM_API_KEY = "your_llm_api_key"
       static let LLM_URL = "https://api.deepseek.com/v1/chat/completions"
       static let LLM_MODEL = "deepseek-chat"
       static let TTS_BYTEDANCE_APP_ID = "your_bytedance_app_id"
       static let TTS_BYTEDANCE_TOKEN = "your_bytedance_token"
   }
   ```

   **配置项说明**：
   - `AGORA_APP_ID`：你的 Agora App ID（必需）
   - `AGORA_APP_CERTIFICATE`：你的 App Certificate（必需，用于 Token 生成和 REST 鉴权）
   - `LLM_API_KEY` / `LLM_URL` / `LLM_MODEL`：LLM 配置
   - `TTS_BYTEDANCE_APP_ID` / `TTS_BYTEDANCE_TOKEN`：火山引擎 / 字节跳动 TTS 配置

   **获取方式**：
   - 体验声网对话式 AI 引擎前，你需要先在声网控制台创建项目并开通对话式 AI 引擎服务，获取 App ID 和 App Certificate。[开通服务](https://doc.shengwang.cn/doc/convoai/restful/get-started/enable-service)

   **运行应用程序**
   - 点击 Start Agent 即可体验功能。

   **注意**：
   - 当前Demo**仅用于快速体验和开发测试**，**不推荐用于生产环境**，真实业务场景中，**不应该**直接在前端请求 Agora RESTful API，而应该通过自己的业务后台服务器中转。
   - **API Key 等敏感信息应放在服务端**，不应暴露在客户端代码中
   - 客户端只请求自己的业务后台接口，业务后台再调用 Agora RESTful API

## 相关资源

### API 文档链接

- [Agora RTC macOS SDK 文档](https://doc.shengwang.cn/doc/rtc/macos/landing-page)
- [Agora RTM iOS SDK 文档](https://doc.shengwang.cn/doc/rtm2/ios/landing-page)（macOS 使用相同 API）
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Conversational AI iOS 客户端组件 文档](https://doc.shengwang.cn/api-ref/convoai/ios/ios-component/overview)

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [提交工单联系声网技术支持](https://ticket.shengwang.cn/)

---

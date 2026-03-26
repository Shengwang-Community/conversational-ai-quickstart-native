# Conversational AI Quickstart — iOS Objective-C

## 功能概述

### 解决的问题

本示例项目展示了如何在 iOS Objective-C 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、RTM 登录、Agent 启动、页面跳转等流程

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- iOS 13.0 或更高版本
- Xcode 14.0 或更高版本
- CocoaPods 1.11.0 或更高版本
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已在 Agora 控制台开通 **实时消息 RTM** 功能（必需）
- 已创建 Agora 项目并获取 App ID 和 App Certificate

## 快速开始

1. **克隆项目**：

```bash
git clone https://github.com/alienzh/Agora-AI-Recipes-Starter.git
cd Agora-AI-Recipes-Starter/ios-oc
```

2. **安装 CocoaPods 依赖**：

```bash
pod install
```

3. **配置 iOS 项目**：
   - 使用 Xcode 打开 `VoiceAgent.xcworkspace`（注意：不是 `.xcodeproj`）
   - 配置 Agora Key：

   编辑 `VoiceAgent/KeyCenter.m` 文件，填入你的实际配置值：

   ```objc
   #import "KeyCenter.h"

   @implementation KeyCenter

   + (NSString *)AG_APP_ID {
       return @"your_app_id";
   }

   + (NSString *)AG_APP_CERTIFICATE {
       return @"your_app_certificate";
   }

   + (NSString *)LLM_API_KEY {
       return @"your_llm_api_key";
   }

   + (NSString *)LLM_URL {
       return @"https://api.deepseek.com/v1/chat/completions";
   }

   + (NSString *)LLM_MODEL {
       return @"deepseek-chat";
   }

   + (NSString *)TTS_BYTEDANCE_APP_ID {
       return @"your_bytedance_app_id";
   }

   + (NSString *)TTS_BYTEDANCE_TOKEN {
       return @"your_bytedance_token";
   }

   @end
   ```

   **配置项说明**：
   - `AG_APP_ID`：你的 Agora App ID（必需）
   - `AG_APP_CERTIFICATE`：你的 App Certificate（必需，用于 Token 生成和 REST 鉴权）
   - `LLM_API_KEY` / `LLM_URL` / `LLM_MODEL`：LLM 配置
   - `TTS_BYTEDANCE_APP_ID` / `TTS_BYTEDANCE_TOKEN`：火山引擎 / 字节跳动 TTS 配置

   **获取方式**：
   - 体验声网对话式 AI 引擎前，你需要先在声网控制台创建项目并开通对话式 AI 引擎服务，获取 App ID、客户 ID 和客户密钥等调用 RESTful API 时所需的参数。[开通服务](https://doc.shengwang.cn/doc/convoai/restful/get-started/enable-service)
   **运行应用程序**
   - 点击 Start Agent 即可体验功能。

   **注意**：
   - 当前Demo**仅用于快速体验和开发测试**，**不推荐用于生产环境**，真实业务场景中，**不应该**直接在前端请求 Agora RESTful API，而应该通过自己的业务后台服务器中转。
   - **API Key 等敏感信息应放在服务端**，不应暴露在客户端代码中
   - 客户端只请求自己的业务后台接口，业务后台再调用 Agora RESTful API
   - 业务后台负责保管和管理 REST Key、REST Secret 等敏感信息

## 测试验证

### 快速体验流程

1. **配置页面**（`ViewController` 中的 `ConfigBackgroundView`）：
   - 运行应用，进入配置页面
   - 点击"Start Agent"按钮
   - 自动切换到聊天页面

2. **聊天页面**（`ViewController` 中的 `ChatBackgroundView`）：
   - 自动生成用户token
   - 自动启动RTM
   - 自动启动RTC
   - 自动启动ConvoAI组件
   - 自动生成agentToken
   - 自动启动Agent
   - 显示 Agent 状态
   - 实时显示 USER 和 AGENT 的转录内容
   - 可以开始与 AI Agent 对话
   - 支持静音/取消静音功能
   - 点击挂断按钮返回配置页面

### 功能验证清单

- ✅ RTC 频道加入成功（查看状态消息）
- ✅ RTM 登录成功（查看状态消息）
- ✅ Agent 启动成功
- ✅ 音频传输正常（能够听到 AI 回复）
- ✅ 转录功能正常（显示 USER 和 AGENT 的转录内容及状态）
- ✅ 静音/取消静音功能正常
- ✅ 挂断功能正常（返回配置页面）

## 项目结构

```
ios-oc/
├── VoiceAgent/
│   ├── main.m                           # 应用入口
│   ├── AppDelegate.h/.m                 # 应用代理
│   ├── SceneDelegate.h/.m               # Scene 代理
│   ├── KeyCenter.h/.m                   # 配置中心（需要填写）
│   ├── ViewController.h/.m              # 主视图控制器（包含配置和聊天功能）
│   ├── Chat/                            # 聊天相关 UI
│   │   ├── ConfigBackgroundView.h/.m   # 配置页面视图（频道名称输入、启动按钮）
│   │   ├── ChatBackgroundView.h/.m     # 聊天页面视图（转录列表、状态、控制按钮）
│   │   ├── AgentStateView.h/.m          # Agent 状态视图
│   │   └── TranscriptCell.h/.m          # 转录单元格
│   ├── ConversationalAIAPI/             # Conversational AI API（Swift，通过桥接使用）
│   │   ├── ConversationalAIAPI.swift
│   │   ├── ConversationalAIAPIImpl.swift
│   │   └── Transcript/
│   ├── Tools/                           # 工具类
│   │   ├── AgentManager.h/.m            # Agent 管理器
│   ├── Assets.xcassets/                 # 资源文件
│   ├── Base.lproj/                      # Storyboard 文件
│   └── Info.plist                       # 应用配置
├── Podfile                              # CocoaPods 依赖配置
├── AGENTS.md                            # Agent 指导文件
├── ARCHITECTURE.md                      # 结构说明文件
├── Podfile.lock                         # CocoaPods 锁定文件
├── VoiceAgent.xcworkspace/              # Xcode 工作空间
└── README.md                            # 本文档
```

## 相关资源

### API 文档链接

- [Agora RTC iOS SDK 文档](https://doc.shengwang.cn/doc/rtc/ios/landing-page)
- [Agora RTM iOS SDK 文档](https://doc.shengwang.cn/doc/rtm2/ios/landing-page)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Conversational AI iOS 客户端组件 文档](https://doc.shengwang.cn/api-ref/convoai/ios/ios-component/overview)

### 相关 Recipes

- [Agora Recipes 主页](https://github.com/AgoraIO-Community)
- 其他 Agora 示例项目

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/agora)

---

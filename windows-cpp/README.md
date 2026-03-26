# Conversational AI Quickstart — Windows C++

## 功能概述

### 解决的问题

本示例项目展示了如何在 Windows 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、RTM 登录、Agent 启动等流程
- **统一界面**：所有功能（日志、状态、转录、控制按钮）集成在同一个页面

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发桌面语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- Windows 10 或更高版本
- Visual Studio 2019 或更高版本（需安装 C++ 桌面开发工作负载）
- vcpkg 包管理器
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已在 Agora 控制台开通 **实时消息 RTM** 功能（必需）
- 已创建 Agora 项目并获取 App ID 和 App Certificate

## 快速开始

1. **克隆项目**：
```bash
git clone https://github.com/AgoraIO-Community/conversational-ai-quickstart-native.git
cd conversational-ai-quickstart-native/windows-cpp
```

2. **安装 vcpkg 依赖**：
```powershell
# 进入项目目录
cd VoiceAgent

# 运行依赖安装脚本
.\install_dependencies.ps1
```

3. **配置 Windows 项目**：
   - 使用 Visual Studio 打开 `VoiceAgent.sln`
   - 配置 Agora Key：

   复制 `KeyCenter.h.example` 文件为 `KeyCenter.h`：
   ```powershell
   copy KeyCenter.h.example VoiceAgent\src\KeyCenter.h
   ```

   编辑 `VoiceAgent\src\KeyCenter.h` 文件，填入你的实际配置值：
   ```cpp
   struct KeyCenter {
       static constexpr const char* AGORA_APP_ID = "your_app_id";
       static constexpr const char* AGORA_APP_CERTIFICATE = "your_app_certificate";
       static constexpr const char* LLM_API_KEY = "your_llm_api_key";
       static constexpr const char* LLM_URL = "https://api.deepseek.com/v1/chat/completions";
       static constexpr const char* LLM_MODEL = "deepseek-chat";
       static constexpr const char* TTS_BYTEDANCE_APP_ID = "your_bytedance_app_id";
       static constexpr const char* TTS_BYTEDANCE_TOKEN = "your_bytedance_token";
   };
   ```

   **配置项说明**：
   - `AGORA_APP_ID`：你的 Agora App ID（必需）
   - `AGORA_APP_CERTIFICATE`：你的 App Certificate（必需，用于 Token 生成和 REST 鉴权）
   - `LLM_API_KEY` / `LLM_URL` / `LLM_MODEL`：LLM 配置
   - `TTS_BYTEDANCE_APP_ID` / `TTS_BYTEDANCE_TOKEN`：火山引擎 / 字节跳动 TTS 配置

   **获取方式**：
   - 体验声网对话式 AI 引擎前，你需要先在声网控制台创建项目并开通对话式 AI 引擎服务，获取 App ID 和 App Certificate。[开通服务](https://doc.shengwang.cn/doc/convoai/restful/get-started/enable-service)

   **运行应用程序**
   - 按 `F5` 启动应用即可体验功能。

   **注意**：
   - 当前Demo**仅用于快速体验和开发测试**，**不推荐用于生产环境**，真实业务场景中，**不应该**直接在前端请求 Agora RESTful API，而应该通过自己的业务后台服务器中转。
   - **API Key 等敏感信息应放在服务端**，不应暴露在客户端代码中
   - 客户端只请求自己的业务后台接口，业务后台再调用 Agora RESTful API

## 测试验证

### 快速体验流程

1. **Agent Chat 页面**（`MainFrm`）：
   - 在 Visual Studio 中按 `F5` 运行应用
   - 页面布局从左到右依次为：
     - **消息区域**：显示 USER 和 AGENT 的对话转录内容
     - **Agent 状态**：显示在消息列表右下角，显示当前 Agent 的状态
     - **日志区域**：右侧固定宽度区域，显示 Agent 启动相关的状态消息
   - **控制按钮**：底部初始显示"Start Agent"按钮
   
2. **启动 Agent**：
   - 点击"Start Agent"按钮
   - 按钮禁用，应用自动：
     - 生成随机 channelName
     - 自动生成用户 token
     - 加入 RTC 频道并登录 RTM
     - 自动启动 ConvoAI 组件
     - 自动生成 agentToken 和 authToken
     - 自动启动 Agent
   - Agent 启动成功后：
     - "Start Agent"按钮隐藏
     - 显示"Mute"和"Stop Agent"按钮
     - 可以开始与 AI Agent 对话

3. **对话交互**：
   - 实时显示 USER 和 AGENT 的转录内容
   - 支持静音/取消静音功能
   - 点击"Stop Agent"按钮结束对话并断开连接

### 功能验证清单

- ✅ RTC 频道加入成功（查看日志区域的状态消息）
- ✅ RTM 登录成功（查看日志区域的状态消息）
- ✅ Agent 启动成功（按钮状态变化，显示 Mute 和 Stop Agent 按钮）
- ✅ 音频传输正常（能够听到 AI 回复）
- ✅ 转录功能正常（显示 USER 和 AGENT 的转录内容及状态）
- ✅ 静音/取消静音功能正常
- ✅ 停止功能正常（断开连接，按钮恢复为 Start Agent）

## 项目结构

```
windows-cpp/
├── VoiceAgent/
│   ├── src/
│   │   ├── ui/                           # UI 相关代码
│   │   │   ├── MainFrm.h                        # 主界面头文件
│   │   │   └── MainFrm.cpp                      # 主界面（包含 RTC 和 RTM 逻辑）
│   │   ├── api/                          # API 相关代码
│   │   │   ├── AgentManager.h/cpp               # Agent 启动/停止 API
│   │   │   ├── TokenGenerator.h/cpp             # Token 生成（仅用于测试）
│   │   │   └── HttpClient.h/cpp                 # HTTP 请求封装
│   │   ├── ConversationalAIAPI/          # 实时字幕组件
│   │   ├── general/                      # 通用代码
│   │   │   ├── pch.h/cpp                        # 预编译头
│   │   │   └── VoiceAgent.h/cpp                 # 应用入口
│   │   ├── tools/                        # 工具类
│   │   │   ├── Logger.h/cpp                     # 日志工具
│   │   │   └── StringUtils.h                    # 字符串工具
│   │   └── KeyCenter.h                   # 配置中心（需要创建，不提交到版本控制）
│   ├── project/
│   │   └── VoiceAgent.vcxproj            # Visual Studio 项目文件
│   ├── resources/                        # 资源文件
│   ├── rtcLib/                           # Agora RTC SDK
│   └── rtmLib/                           # Agora RTM SDK
├── VoiceAgent.sln                        # Visual Studio 解决方案
├── AGENTS.md                             # Agent 指导文件
├── ARCHITECTURE.md                       # 结构说明文件
├── KeyCenter.h.example                   # 配置文件示例
└── README.md                             # 本文档
```

**主要文件说明**：
- `MainFrm.cpp`：主界面，包含日志显示、Agent 状态、转录列表和控制按钮，直接管理 RTC/RTM SDK
- `AgentManager.cpp`：Agent 启动 API 封装，使用 `agora token=<token>` 鉴权，并内联 STT/LLM/TTS 配置
- `TokenGenerator.cpp`：Token 生成工具（仅用于开发测试，生产环境需使用服务端生成）

## 相关资源

### API 文档链接

- [Agora RTC Windows SDK 文档](https://doc.shengwang.cn/doc/rtc/windows/landing-page)
- [Agora RTM Windows SDK 文档](https://doc.shengwang.cn/doc/rtm2/windows/landing-page)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)

### 相关 Recipes

- [Agora Recipes 主页](https://github.com/AgoraIO-Community)
- 其他 Agora 示例项目

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/agora)

---

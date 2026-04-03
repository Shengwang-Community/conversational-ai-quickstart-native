# Unity Agent Starter

## 功能概述

Unity 版本延续仓库里其他 quickstart 的模式：客户端生成 Demo Token，加入 RTC / RTM，然后通过 ShengWang Conversational AI REST API 启动内联配置的 Agent。

- 实时语音交互：RTC
- 消息与转录展示：RTM
- 单场景 UI：响应式 Transcript / Log 双面板 + 底部控制栏
- Agent 配置方式：请求体内联 ASR / LLM / TTS provider
- REST 鉴权方式：`Authorization: agora token=<token>`

## 前置条件

- 团结 / Unity `2022.3.61t11`
- 已开通 Agora / 声网服务，获取 App ID 与 App Certificate
- 已开通 RTM 服务
- 已准备 LLM 与 TTS 所需的 provider 配置

当前项目按以下方式使用：

- macOS 编辑器中可直接 `Play` 调试
- Android / iOS 真机可直接运行
- Android 可导出 Gradle 工程后用 Android Studio 编译
- iOS 可导出 Xcode 工程后用 Xcode 编译

当前不面向 Windows / OpenHarmony / Android 模拟器流程。

## 快速开始

### 1. 导入 Agora Unity SDK

本项目依赖 Agora Unity SDK，但 SDK 文件不包含在仓库中，需要手动导入：

1. 下载 SDK
   - [Agora Video SDK for Unity](https://docs.agora.io/cn/video-calling/get-started/get-started-sdk?platform=unity)
   - [Agora RTM SDK for Unity](https://docs.agora.io/cn/signaling/get-started/get-started-sdk?platform=unity)
2. 导入到项目
   - 将 `Agora-RTC-Plugin` 放入 `Assets/`
   - 将 `Agora-RTM-Plugin` 放入 `Assets/`
3. 验证导入
   - 确保 `Assets/Agora-RTC-Plugin/` 和 `Assets/Agora-RTM-Plugin/` 存在
   - Unity 完成重新编译且 `SampleScene` 无脚本丢失

这两个 SDK 目录已在 `unity/.gitignore` 中忽略，不会提交到仓库。

### 2. 配置环境变量

复制示例文件：

```bash
cp Assets/Resources/env.example.txt Assets/Resources/env.txt
```

填写配置：

```properties
APP_ID=your_shengwang_app_id
APP_CERTIFICATE=your_shengwang_app_certificate
LLM_API_KEY=sk-your_dashscope_api_key
LLM_URL=https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions
LLM_MODEL=qwen-plus
TTS_BYTEDANCE_APP_ID=your_bytedance_app_id
TTS_BYTEDANCE_TOKEN=your_bytedance_access_token
```

统一使用这组键名：

- `APP_ID`
- `APP_CERTIFICATE`
- `LLM_API_KEY`
- `LLM_URL`
- `LLM_MODEL`
- `TTS_BYTEDANCE_APP_ID`
- `TTS_BYTEDANCE_TOKEN`

`env.txt` 含敏感信息，已被 `.gitignore` 忽略。

### 3. 打开示例场景

打开 `Assets/Scenes/SampleScene.unity`。场景中已经绑定好 `AgentStartup`、日志文本、字幕文本和三个按钮。

### 4. 在编辑器中运行

进入 Play Mode，点击 `Start Agent`。

启动流程：

1. 生成用户 RTC / RTM Token
2. 初始化 RTC 并加入频道
3. 初始化 RTM、登录并订阅频道
4. 生成 Agent Token
5. 生成 REST Auth Token
6. 通过 REST API 启动内联配置的 Agent

当前界面会在运行时由 `AgentStartup.cs` 重新布局：

- 顶部显示产品名与会话摘要
- 中间显示 `Transcript` 与 `Log`
- 横屏优先左右分栏，窄屏上下堆叠
- 底部显示 `Start Agent` / `Mute` / `Stop Agent`

### 5. Android 真机运行

1. `File > Build Settings` 里切到 `Android`
2. 连接 Android 真机
3. 首次点击 `Start Agent` 时，应用会先申请麦克风权限
4. 授权后自动继续启动 RTC / RTM / Agent 流程

当前项目按真机配置收口，仅保留 ARM Android 构建路径，不建议使用 Android 模拟器。

### 6. 导出 Android 工程到 Android Studio

1. `File > Build Settings`
2. 选择 `Android`
3. 勾选 `导出项目`（英文界面为 `Export Project`）
4. 点击 `Build`
5. 选择一个空目录，例如 `android-export/`
6. 使用 Android Studio 打开导出的工程并编译 APK

当前 Android 默认配置：

- Package Name: `cn.shengwang.convoai.quickstart.unity`
- App Name: `quick start unity`
- 架构：包含 `ARM64`

### 7. 导出 iOS 工程到 Xcode

1. `File > Build Settings`
2. 选择 `iOS`
3. 点击 `Build`
4. 选择一个空目录导出 Xcode 工程
5. 用 Xcode 打开导出的 `Unity-iPhone.xcodeproj`
6. 在 Xcode `Signing & Capabilities` 中勾选自动签名并选择你的 Team
7. 以 debug 方式运行到真机

当前 iOS 默认配置：

- Bundle Identifier: `cn.shengwang.convoai.quickstart.unity`
- App Name: `quick start unity`
- `NSMicrophoneUsageDescription` 由 Unity Player Settings 写入导出工程
- `NSCameraUsageDescription` 由 Unity Player Settings / 插件导出后处理写入导出工程
- RTC / RTM iOS frameworks 需要随导出工程一起嵌入到最终 app 包内

iOS 注意事项：

- 修改 iOS 包名、权限描述或插件导入设置后，请删除旧导出目录并重新导出 Xcode 工程
- 如果 Xcode 仍显示旧的 Bundle Identifier，通常说明打开的是旧导出工程
- 如果启动时提示缺少隐私描述或 framework 未加载，请优先确认使用的是最新重新导出的工程

## 当前内联 Provider 配置

`Assets/Scripts/Quickstart/AgentStarter.cs` 当前默认写死为：

- ASR: `fengming`
- LLM: `aliyun`，通过 `LLM_URL` + `LLM_MODEL` + `LLM_API_KEY`
- TTS: `bytedance`，通过 `TTS_BYTEDANCE_APP_ID` + `TTS_BYTEDANCE_TOKEN`
- 数据通道：`rtm`

如果要切换 provider，需要同时修改：

1. `Assets/Scripts/Quickstart/EnvConfig.cs`
2. `Assets/Scripts/Quickstart/AgentStarter.cs`

## 安全说明

- `TokenGenerator.cs` 仅用于演示和开发测试，生产环境必须改为服务端生成 Token。
- 当前 REST API 由客户端直接调用，仅适用于 quickstart / demo。生产环境应改为服务端代调用。
- `Authorization: agora token=<token>` 依赖 App Certificate 已启用。

## 文件结构

```text
unity/
├── Assets/
│   ├── Agora-RTC-Plugin/                # 需手动导入
│   ├── Agora-RTM-Plugin/                # 需手动导入
│   ├── Resources/
│   │   ├── env.example.txt
│   │   ├── env.txt                      # 本地创建，git ignored
│   │   └── README_ENV.md
│   ├── Scenes/
│   │   └── SampleScene.unity
│   └── Scripts/Quickstart/
│       ├── AgentEventParser.cs
│       ├── EnvConfig.cs
│       ├── TokenGenerator.cs
│       ├── AgentStarter.cs
│       ├── AgentStartup.cs
│       └── TranscriptManager.cs
├── ProjectSettings/
└── README.md
```

## 相关资源

- [Agora Unity RTC SDK 文档](https://docs.agora.io/cn/video-calling/overview/product-overview?platform=unity)
- [Agora Unity RTM SDK 文档](https://docs.agora.io/cn/signaling/overview/product-overview?platform=unity)
- [Conversational AI RESTful API 文档](https://docs.agora.io/cn/conversational-ai/develop/restful-api)

# Unity Agent Starter

## 功能概述

Unity 版本延续仓库里其他 quickstart 的模式：客户端生成 Demo Token，加入 RTC / RTM，然后通过 ShengWang Conversational AI REST API 启动内联配置的 Agent。

- 实时语音交互：RTC
- 消息与转录展示：RTM
- 单场景 UI：顶部日志、中部字幕、底部按钮
- Agent 配置方式：请求体内联 ASR / LLM / TTS provider
- REST 鉴权方式：`Authorization: agora token=<token>`

## 前置条件

- 已开通 Agora / 声网服务，获取 App ID 与 App Certificate
- 已开通 RTM 服务
- 已准备 LLM 与 TTS 所需的 provider 配置

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

### 4. 运行

进入 Play Mode，点击“启动 Agent”。

启动流程：

1. 生成用户 RTC / RTM Token
2. 初始化 RTC 并加入频道
3. 初始化 RTM、登录并订阅频道
4. 生成 Agent Token
5. 生成 REST Auth Token
6. 通过 REST API 启动内联配置的 Agent

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

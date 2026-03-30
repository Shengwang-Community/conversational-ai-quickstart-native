//
//  ChatSessionViewModel.swift
//  VoiceAgent
//

import Foundation
import SwiftUI
import AgoraRtcKit
import AgoraRtmKit

class ChatSessionViewModel: NSObject, ObservableObject {
    @Published var isShowingConnectionStartView = true
    @Published var isShowingChatSessionView = false
    @Published var isLoading = false
    @Published var isError = false
    @Published var initializationError: Error?
    @Published var transcripts: [Transcript] = []
    @Published var isMicMuted = false
    @Published var debugMessages = "Waiting for connection...\n"
    @Published var agentState: AgentState = .unknown

    private let uid = Int.random(in: 100000...999999)
    private let agentUid = Int.random(in: 100000...999999)
    private var channel = ""
    private var userToken = ""
    private var agentToken = ""
    private var authToken = ""
    private var agentId = ""

    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?

    override init() {
        super.init()
        initializeEngines()
    }

    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async {
            self.debugMessages += "[\(timestamp)] \(message)\n"
        }
    }

    private func clearDebugMessages() {
        debugMessages = "Waiting for connection...\n"
    }

    private func randomChannelName() -> String {
        "channel_swiftui_\(Int.random(in: 100000...999999))"
    }

    private func initializeEngines() {
        initializeRTM()
        initializeRTC()
        initializeConvoAIAPI()
    }

    private func initializeRTM() {
        let config = AgoraRtmClientConfig(appId: KeyCenter.AG_APP_ID, userId: "\(uid)")
        config.areaCode = [.CN, .NA]
        config.presenceTimeout = 30
        config.heartbeatInterval = 10
        config.useStringUserId = true

        do {
            self.rtmEngine = try AgoraRtmClientKit(config, delegate: self)
            addDebugMessage("RTM Client 初始化成功")
        } catch {
            addDebugMessage("RTM Client 初始化失败: \(error.localizedDescription)")
        }
    }

    private func initializeRTC() {
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AG_APP_ID
        config.channelProfile = .liveBroadcasting
        config.audioScenario = .aiClient
        let engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        engine.enableVideo()
        engine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        engine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        self.rtcEngine = engine
        addDebugMessage("RTC Engine 初始化成功")
    }

    private func initializeConvoAIAPI() {
        guard let rtcEngine, let rtmEngine else { return }
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: true)
        let api = ConversationalAIAPIImpl(config: config)
        api.addHandler(handler: self)
        self.convoAIAPI = api
    }

    func startConnection() {
        channel = randomChannelName()
        isLoading = true
        isError = false

        Task {
            do {
                try await generateUserToken()
                try await loginRTM()
                try await joinRTCChannel()
                try await subscribeConvoAIMessage()
                try await generateAgentToken()
                try await generateAuthToken()
                try await startAgent()

                await MainActor.run {
                    self.isLoading = false
                    self.isShowingConnectionStartView = false
                    self.isShowingChatSessionView = true
                }
            } catch {
                await MainActor.run {
                    self.initializationError = error
                    self.isLoading = false
                    self.isError = true
                }
            }
        }
    }

    private func generateUserToken() async throws {
        addDebugMessage("获取 Token 调用中...")
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: "", uid: "\(uid)", types: [.rtc, .rtm]) { token in
                guard let token else {
                    self.addDebugMessage("获取 Token 调用失败")
                    continuation.resume(throwing: NSError(domain: "generateUserToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 token 失败"]))
                    return
                }
                self.userToken = token
                self.addDebugMessage("获取 Token 调用成功")
                continuation.resume()
            }
        }
    }

    private func generateAgentToken() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(agentUid)", types: [.rtc, .rtm]) { token in
                guard let token else {
                    self.addDebugMessage("Agent Token 调用失败")
                    continuation.resume(throwing: NSError(domain: "generateAgentToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 agent token 失败"]))
                    return
                }
                self.agentToken = token
                self.addDebugMessage("Agent Token 调用成功")
                continuation.resume()
            }
        }
    }

    private func generateAuthToken() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(agentUid)", types: [.rtc, .rtm]) { token in
                guard let token else {
                    self.addDebugMessage("Auth Token 调用失败")
                    continuation.resume(throwing: NSError(domain: "generateAuthToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 auth token 失败"]))
                    return
                }
                self.authToken = token
                self.addDebugMessage("Auth Token 调用成功")
                continuation.resume()
            }
        }
    }

    @MainActor
    private func loginRTM() async throws {
        guard let rtmEngine else {
            throw NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM engine 未初始化"])
        }
        addDebugMessage("RTM Login 调用中...")
        return try await withCheckedThrowingContinuation { continuation in
            rtmEngine.login(userToken) { _, error in
                if let error {
                    self.addDebugMessage("RTM Login 调用失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    self.addDebugMessage("RTM Login 调用成功")
                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    private func joinRTCChannel() async throws {
        guard let rtcEngine else {
            throw NSError(domain: "joinRTCChannel", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTC engine 未初始化"])
        }
        addDebugMessage("joinChannel 调用中...")
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        let result = rtcEngine.joinChannel(byToken: userToken, channelId: channel, uid: UInt(uid), mediaOptions: options)
        guard result == 0 else {
            addDebugMessage("joinChannel 调用失败: ret=\(result)")
            throw NSError(domain: "joinRTCChannel", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "加入 RTC 频道失败"])
        }
        addDebugMessage("joinChannel 调用成功: ret=\(result)")
    }

    @MainActor
    private func subscribeConvoAIMessage() async throws {
        guard let convoAIAPI else {
            throw NSError(domain: "subscribeConvoAIMessage", code: -1, userInfo: [NSLocalizedDescriptionKey: "ConvoAI API 未初始化"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            convoAIAPI.subscribeMessage(channelName: channel) { error in
                if let error {
                    self.addDebugMessage("订阅消息失败: \(error.message)")
                    continuation.resume(throwing: NSError(domain: "subscribeConvoAIMessage", code: error.code, userInfo: [NSLocalizedDescriptionKey: error.message]))
                } else {
                    self.addDebugMessage("订阅消息成功")
                    continuation.resume()
                }
            }
        }
    }

    private func startAgentParameter() -> [String: Any] {
        [
            "name": "agent_\(channel)_\(agentUid)_\(Int(Date().timeIntervalSince1970))",
            "properties": [
                "channel": channel,
                "agent_rtc_uid": "\(agentUid)",
                "remote_rtc_uids": ["*"],
                "token": agentToken,
                "enable_string_uid": true,
                "idle_timeout": 120,
                "advanced_features": [
                    "enable_rtm": true
                ],
                "asr": [
                    "language": "zh-CN",
                    "vendor": "fengming"
                ],
                "llm": [
                    "url": KeyCenter.LLM_URL,
                    "api_key": KeyCenter.LLM_API_KEY,
                    "vendor": "aliyun",
                    "system_messages": [
                        ["role": "system", "content": "你是一名有帮助的 AI 助手。"]
                    ],
                    "greeting_message": "你好！我是你的 AI 助手，有什么可以帮你？",
                    "failure_message": "抱歉，我暂时处理不了你的请求，请稍后再试。",
                    "params": [
                        "model": KeyCenter.LLM_MODEL
                    ]
                ],
                "tts": [
                    "vendor": "bytedance",
                    "params": [
                        "token": KeyCenter.TTS_BYTEDANCE_TOKEN,
                        "app_id": KeyCenter.TTS_BYTEDANCE_APP_ID,
                        "cluster": "volcano_tts",
                        "voice_type": "BV700_streaming",
                        "speed_ratio": 1.0,
                        "volume_ratio": 1.0,
                        "pitch_ratio": 1.0
                    ]
                ],
                "parameters": [
                    "data_channel": "rtm",
                    "enable_error_message": true
                ]
            ]
        ]
    }

    private func startAgent() async throws {
        addDebugMessage("Agent Start 调用中...")
        return try await withCheckedThrowingContinuation { continuation in
            AgentManager.startAgent(parameter: startAgentParameter(), token: authToken) { agentId, error in
                if let error {
                    self.addDebugMessage("Agent Start 调用失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                guard let agentId else {
                    continuation.resume(throwing: NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "未返回 agentId"]))
                    return
                }
                self.agentId = agentId
                self.addDebugMessage("Agent Start 调用成功 (agentId: \(agentId))")
                continuation.resume()
            }
        }
    }

    func toggleMicrophone() {
        isMicMuted.toggle()
        rtcEngine?.adjustRecordingSignalVolume(isMicMuted ? 0 : 100)
    }

    func endCall() {
        if !agentId.isEmpty && !authToken.isEmpty {
            AgentManager.stopAgent(agentId: agentId, token: authToken, completion: nil)
        }
        resetConnectionState()
    }

    private func resetConnectionState() {
        rtcEngine?.leaveChannel()
        rtmEngine?.logout()
        convoAIAPI?.unsubscribeMessage(channelName: channel, completion: { error in
            if let error {
                self.addDebugMessage("unsubscribe FAIL: \(error.message)")
            }
        })
        isShowingChatSessionView = false
        isShowingConnectionStartView = true
        transcripts.removeAll()
        isMicMuted = false
        agentId = ""
        userToken = ""
        agentToken = ""
        authToken = ""
        agentState = .unknown
        clearDebugMessages()
    }
}

extension ChatSessionViewModel: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        addDebugMessage("onJoinChannelSuccess")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        addDebugMessage("onUserJoined: \(uid)")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        addDebugMessage("onUserOffline: \(uid)")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        addDebugMessage("onError: \(errorCode.rawValue)")
    }
}

extension ChatSessionViewModel: AgoraRtmClientDelegate {
    func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveLinkStateEvent event: AgoraRtmLinkStateEvent) {
        addDebugMessage("RTM link state: \(event.currentState.rawValue)")
    }
}

extension ChatSessionViewModel: ConversationalAIAPIEventHandler {
    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
        addDebugMessage("onAgentVoiceprintStateChanged: \(event)")
    }

    func onMessageError(agentUserId: String, error: MessageError) {
        addDebugMessage("onMessageError: \(error)")
    }

    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        addDebugMessage("onMessageReceiptUpdated: \(messageReceipt)")
    }

    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        DispatchQueue.main.async {
            self.agentState = event.state
        }
    }

    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        addDebugMessage("onAgentInterrupted: \(event)")
    }

    func onAgentMetrics(agentUserId: String, metrics: Metric) {
        addDebugMessage("onAgentMetrics: \(metrics)")
    }

    func onAgentError(agentUserId: String, error: ModuleError) {
        addDebugMessage("onAgentError: \(error)")
    }

    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        DispatchQueue.main.async {
            if let index = self.transcripts.firstIndex(where: {
                $0.turnId == transcript.turnId &&
                $0.type.rawValue == transcript.type.rawValue &&
                $0.userId == transcript.userId
            }) {
                self.transcripts[index] = transcript
            } else {
                self.transcripts.append(transcript)
            }
        }
    }

    func onDebugLog(log: String) {
        addDebugMessage(log)
    }
}

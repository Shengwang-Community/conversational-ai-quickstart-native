//
//  ViewController.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit
import AgoraRtcKit
import AgoraRtmKit

class ViewController: UIViewController {
    // MARK: - UI Components
    private let connectionStartView = ConnectionStartView()
    private let chatSessionView = ChatSessionView()
    private let debugInfoTextView = UITextView()
    
    // MARK: - State
    private let uid = Int.random(in: 1000...9999999)
    private var channel: String = ""
    private var transcripts: [Transcript] = []
    private var isMicMuted: Bool = false
    private var isLoading: Bool = false
    private var isError: Bool = false
    private var initializationError: Error?
    private var currentAgentState: AgentState = .unknown
    
    // MARK: - Agora Components
    private var token: String = ""
    private var agentToken: String = ""
    private var agentId: String = ""
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    private let agentUid = Int.random(in: 10000000...99999999)
    
    // MARK: - Toast
    private var loadingToast: UIView?
    
    // MARK: - Debug Info Helper
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let debugMessage = "[\(timestamp)] \(message)\n"
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.debugInfoTextView.text += debugMessage
            
            // Auto-scroll to bottom
            let bottom = NSRange(location: self.debugInfoTextView.text.count - 1, length: 1)
            self.debugInfoTextView.scrollRangeToVisible(bottom)
        }
    }
    
    private func clearDebugMessages() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.debugInfoTextView.text = "Waiting for connection...\n"
        }
    }
    
    // MARK: - Lifecycle
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        setupConstraints()
        initializeEngines()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = AppColors.bgPrimary
        
        // Debug Info TextView (always visible)
        debugInfoTextView.isEditable = false
        debugInfoTextView.isSelectable = true
        debugInfoTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        debugInfoTextView.textColor = AppColors.textSecondary
        debugInfoTextView.backgroundColor = AppColors.bgLogContent
        debugInfoTextView.layer.cornerRadius = 12
        debugInfoTextView.layer.borderWidth = 0.5
        debugInfoTextView.layer.borderColor = AppColors.borderDefault.cgColor
        debugInfoTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        debugInfoTextView.text = "Waiting for connection...\n"
        debugInfoTextView.indicatorStyle = .white
        view.addSubview(debugInfoTextView)
        
        // Connection Start View
        view.addSubview(connectionStartView)
        connectionStartView.startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        
        // Chat Session View
        chatSessionView.isHidden = true
        view.addSubview(chatSessionView)
        chatSessionView.tableView.delegate = self
        chatSessionView.tableView.dataSource = self
        chatSessionView.applyTableBackgroundWorkaround()
        chatSessionView.micButton.addTarget(self, action: #selector(toggleMicrophone), for: .touchUpInside)
        chatSessionView.endCallButton.addTarget(self, action: #selector(endCall), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        // Debug Info TextView (always visible at top)
        debugInfoTextView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(120)
        }
        
        // Connection Start View (below debug view)
        connectionStartView.snp.makeConstraints { make in
            make.top.equalTo(debugInfoTextView.snp.bottom).offset(20)
            make.left.right.bottom.equalToSuperview()
        }
        
        // Chat Session View (below debug view)
        chatSessionView.snp.makeConstraints { make in
            make.top.equalTo(debugInfoTextView.snp.bottom).offset(20)
            make.left.right.bottom.equalToSuperview()
        }
    }
    
    // MARK: - Engine Initialization
    private func initializeEngines() {
        initializeRTM()
        initializeRTC()
        initializeConvoAIAPI()
    }
    
    private func initializeRTM() {
        let rtmConfig = AgoraRtmClientConfig(appId: KeyCenter.AG_APP_ID, userId: "\(uid)")
        rtmConfig.areaCode = [.CN, .NA]
        rtmConfig.presenceTimeout = 30
        rtmConfig.heartbeatInterval = 10
        rtmConfig.useStringUserId = true
        
        do {
            let rtmClient = try AgoraRtmClientKit(rtmConfig, delegate: self)
            self.rtmEngine = rtmClient
            print("[Engine Init] RTM initialized successfully")
            addDebugMessage("RTM Client 初始化成功")
        } catch {
            print("[Engine Init] RTM initialization failed: \(error)")
            addDebugMessage("RTM Client 初始化失败")
        }
    }
    
    private func initializeRTC() {
        let rtcConfig = AgoraRtcEngineConfig()
        rtcConfig.appId = KeyCenter.AG_APP_ID
        rtcConfig.channelProfile = .liveBroadcasting
        rtcConfig.audioScenario = .aiClient
        let rtcEngine = AgoraRtcEngineKit.sharedEngine(with: rtcConfig, delegate: self)
        
        rtcEngine.enableVideo()
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        
        let cameraConfig = AgoraCameraCapturerConfiguration()
        cameraConfig.cameraDirection = .rear
        rtcEngine.setCameraCapturerConfiguration(cameraConfig)
        
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        
        self.rtcEngine = rtcEngine
        print("[Engine Init] RTC initialized successfully")
        addDebugMessage("RTC Engine 初始化成功")
    }
    
    private func initializeConvoAIAPI() {
        guard let rtcEngine = self.rtcEngine else {
            print("[Engine Init] RTC engine is nil, cannot init ConvoAI API")
            return
        }
        
        guard let rtmEngine = self.rtmEngine else {
            print("[Engine Init] RTM engine is nil, cannot init ConvoAI API")
            return
        }
        
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: true)
        let convoAIAPI = ConversationalAIAPIImpl(config: config)
        convoAIAPI.addHandler(handler: self)
        
        self.convoAIAPI = convoAIAPI
        print("[Engine Init] ConvoAI API initialized successfully")
    }
    
    // MARK: - Connection Flow
    private func startConnection() {
        isLoading = true
        showLoadingToast()
        
        Task {
            do {
                // 1. 生成用户token
                try await generateUserToken()
                
                // 2. RTM 登录
                try await loginRTM()
                
                // 3. RTC 加入频道
                try await joinRTCChannel()
                
                // 4. 订阅 ConvoAI 消息
                try await subscribeConvoAIMessage()
                
                // 5. 生成agentToken
                try await generateAgentToken()
                
                // 6. 启动agent
                try await startAgent()
                
                await MainActor.run {
                    isLoading = false
                    hideLoadingToast()
                    switchToChatView()
                }
            } catch {
                await MainActor.run {
                    initializationError = error
                    isLoading = false
                    isError = true
                    hideLoadingToast()
                    showErrorToast(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Token Generation
    private func generateUserToken() async throws {
        addDebugMessage("获取 Token 调用中...")
        
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(uid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    self.addDebugMessage("获取 Token 调用失败")
                    continuation.resume(throwing: NSError(domain: "generateUserToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 token 失败，请重试"]))
                    return
                }
                self.token = token
                self.addDebugMessage("获取 Token 调用成功")
                continuation.resume()
            }
        }
    }
    
    private func generateAgentToken() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(agentUid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    continuation.resume(throwing: NSError(domain: "generateAgentToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 token 失败，请重试"]))
                    return
                }
                self.agentToken = token
                continuation.resume()
            }
        }
    }
    
    // MARK: - Channel Connection
    @MainActor
    private func loginRTM() async throws {
        guard let rtmEngine = self.rtmEngine else {
            throw NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM engine 未初始化"])
        }
        
        addDebugMessage("RTM Login 调用中...")
        
        return try await withCheckedThrowingContinuation { continuation in
            rtmEngine.login(token) { res, error in
                if let error = error {
                    self.addDebugMessage("RTM Login 调用失败: \(error.localizedDescription)")
                    continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 登录失败: \(error.localizedDescription)"]))
                } else if let _ = res {
                    self.addDebugMessage("RTM Login 调用成功")
                    continuation.resume()
                } else {
                    self.addDebugMessage("RTM Login 调用失败")
                    continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 登录失败"]))
                }
            }
        }
    }
    
    @MainActor
    private func joinRTCChannel() async throws {
        guard let rtcEngine = self.rtcEngine else {
            throw NSError(domain: "joinRTCChannel", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTC engine 未初始化"])
        }
        
        addDebugMessage("joinChannel 调用中...")
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        let result = rtcEngine.joinChannel(byToken: token, channelId: channel, uid: UInt(uid), mediaOptions: options)
        if result != 0 {
            addDebugMessage("joinChannel 调用失败: ret=\(result)")
            throw NSError(domain: "joinRTCChannel", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "加入 RTC 频道失败，错误码: \(result)"])
        } else {
            addDebugMessage("joinChannel 调用成功: ret=\(result)")
        }
    }
    
    @MainActor
    private func subscribeConvoAIMessage() async throws {
        guard let convoAIAPI = self.convoAIAPI else {
            throw NSError(domain: "subscribeConvoAIMessage", code: -1, userInfo: [NSLocalizedDescriptionKey: "ConvoAI API 未初始化"])
        }
            
        return try await withCheckedThrowingContinuation { continuation in
            convoAIAPI.subscribeMessage(channelName: channel) { err in
                if let error = err {
                    continuation.resume(throwing: NSError(domain: "subscribeConvoAIMessage", code: -1, userInfo: [NSLocalizedDescriptionKey: "订阅消息失败: \(error.message)"]))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Agent Management
    private func startAgent() async throws {
        addDebugMessage("Agent Start 调用中...")
        
        return try await withCheckedThrowingContinuation { continuation in
            let parameter: [String: Any] = [
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
                ] as [String: Any]
            ]
            AgentManager.startAgent(parameter: parameter, token: self.token) { agentId, error in
                if let error = error {
                    self.addDebugMessage("Agent Start 调用失败: \(error.localizedDescription)")
                    continuation.resume(throwing: NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]))
                    return
                }
                
                if let agentId = agentId {
                    self.agentId = agentId
                    self.addDebugMessage("Agent Start 调用成功 (agentId: \(agentId))")
                    continuation.resume()
                } else {
                    self.addDebugMessage("Agent Start 调用失败: 未返回 agentId")
                    continuation.resume(throwing: NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求失败"]))
                }
            }
        }
    }
    
    // MARK: - View Management
    private func switchToChatView() {
        connectionStartView.isHidden = true
        chatSessionView.isHidden = false
    }
    
    private func switchToConfigView() {
        chatSessionView.isHidden = true
        connectionStartView.isHidden = false
    }
    
    private func resetConnectionState() {
        rtcEngine?.leaveChannel()
        rtmEngine?.logout()
        convoAIAPI?.unsubscribeMessage(channelName: channel, completion: { error in
            
        })
        
        switchToConfigView()
        
        transcripts.removeAll()
        chatSessionView.tableView.reloadData()
        clearDebugMessages()
        isMicMuted = false
        currentAgentState = .unknown
        chatSessionView.updateStatusView(state: .unknown)
        agentId = ""
        token = ""
        agentToken = ""
    }
    
    // MARK: - UI Updates
    private func updateAgentStatusView() {
        chatSessionView.updateStatusView(state: currentAgentState)
    }
    
    // MARK: - Actions
    @objc private func startButtonTapped() {
        self.channel = "channel_\(Int(Date().timeIntervalSince1970))"
        startConnection()
    }
    
    @objc private func toggleMicrophone() {
        isMicMuted.toggle()
        chatSessionView.updateMicButtonState(isMuted: isMicMuted)
        rtcEngine?.adjustRecordingSignalVolume(isMicMuted ? 0 : 100)
    }
    
    @objc private func endCall() {
        AgentManager.stopAgent(agentId: agentId, token: token, completion: nil)
        resetConnectionState()
    }
    
    // MARK: - Toast
    private func showLoadingToast() {
        let toast = UIView()
        toast.backgroundColor = AppColors.bgSecondary.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 12
        toast.layer.borderWidth = 0.5
        toast.layer.borderColor = AppColors.borderDefault.cgColor
        view.addSubview(toast)
        
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = AppColors.accentBlue
        indicator.startAnimating()
        toast.addSubview(indicator)
        
        toast.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(100)
        }
        
        indicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        loadingToast = toast
    }
    
    private func hideLoadingToast() {
        loadingToast?.removeFromSuperview()
        loadingToast = nil
    }
    
    private func showErrorToast(_ message: String) {
        let toast = UIView()
        toast.backgroundColor = AppColors.errorRedDark.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 12
        view.addSubview(toast)
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        toast.addSubview(label)
        
        toast.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }
        
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toast.removeFromSuperview()
        }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transcripts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TranscriptMessageCell.reuseIdentifier, for: indexPath) as! TranscriptMessageCell
        cell.configure(with: transcripts[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - AgoraRtcEngineDelegate
extension ViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("[RTC Call Back] didJoinChannel: \(channel), uid: \(uid)")
        addDebugMessage("onJoinChannelSuccess")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("[RTC Call Back] didJoinedOfUid uid: \(uid)")
        addDebugMessage("onUserJoined: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("[RTC Call Back] didOfflineOfUid uid: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("[RTC Call Back] didOccurError: \(errorCode.rawValue)")
        addDebugMessage("onError: \(errorCode.rawValue)")
    }
}

// MARK: - AgoraRtmClientDelegate
extension ViewController: AgoraRtmClientDelegate {
    func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveLinkStateEvent event: AgoraRtmLinkStateEvent) {
        print("<<< [rtmKit:didReceiveLinkStateEvent]")
        switch event.currentState {
        case .connected:
            print("RTM connected successfully")
        case .disconnected:
            print("RTM disconnected")
        case .failed:
            print("RTM connection failed, need to re-login")
        default:
            break
        }
    }
}

// MARK: - ConversationalAIAPIEventHandler
extension ViewController: ConversationalAIAPIEventHandler {
    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
        print("onAgentVoiceprintStateChanged: \(event)")
    }
    
    func onMessageError(agentUserId: String, error: MessageError) {
        print("onMessageError: \(error)")
    }
    
    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        print("onMessageReceiptUpdated: \(messageReceipt)")
    }
    
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        print("onAgentStateChanged: \(event)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentAgentState = event.state
            self.updateAgentStatusView()
        }
    }
    
    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        print("<<< [onAgentInterrupted]")
    }
    
    func onAgentMetrics(agentUserId: String, metrics: Metric) {
        print("<<< [onAgentMetrics] metrics: \(metrics)")
    }
    
    func onAgentError(agentUserId: String, error: ModuleError) {
        print("<<< [onAgentError] error: \(error)")
    }
    
    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.transcripts.firstIndex(where: {
                $0.turnId == transcript.turnId &&
                $0.type.rawValue == transcript.type.rawValue &&
                $0.userId == transcript.userId
            }) {
                self.transcripts[index] = transcript
            } else {
                self.transcripts.append(transcript)
            }
            
            self.chatSessionView.tableView.reloadData()
            
            if !self.transcripts.isEmpty {
                let indexPath = IndexPath(row: self.transcripts.count - 1, section: 0)
                self.chatSessionView.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    func onDebugLog(log: String) {
        print(log)
    }
}

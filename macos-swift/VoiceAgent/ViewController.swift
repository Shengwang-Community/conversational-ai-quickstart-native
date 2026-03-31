//
//  ViewController.swift
//  VoiceAgent
//

import Cocoa
import AgoraRtcKit
import AgoraRtmKit
import SnapKit

class ViewController: NSViewController {
    
    // MARK: - UI Components
    private var logView: LogView!
    private let connectionStartView = ConnectionStartView()
    private let chatSessionView = ChatSessionView()
    
    // MARK: - Agora SDK
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    
    // MARK: - State
    private var channelName = ""
    private var userToken = ""
    private var agentToken = ""
    private var agentId = ""
    private var isActive = false
    private var isMuted = false
    private var transcripts: [Transcript] = []
    private var rtmLoggedIn = false
    
    // MARK: - Constants
    private var userUid: UInt = 0
    private var agentUid: UInt = 0
    private let bottomPanelHeight: CGFloat = 70
    private let padding: CGFloat = 20
    private let logViewWidth: CGFloat = 200
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSDK()
        logToView("Main controller initialized")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        configureWindow()
    }
    
    private func configureWindow() {
        guard let window = view.window else { return }
        window.isRestorable = false
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.minSize = NSSize(width: 800, height: 600)
        window.center()
    }
    
    // MARK: - SDK Setup
    
    private func setupSDK() {
        logView.clear()
        generateRuntimeUids()
        initializeRTC()
        initializeRTM()
        initializeConvoAIAPI()
    }
    
    private func initializeRTC() {
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AGORA_APP_ID
        config.channelProfile = .liveBroadcasting
        config.audioScenario = .aiClient
        
        let engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        engine.enableVideo()
        engine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        engine.setCameraCapturerConfiguration(AgoraCameraCapturerConfiguration())
        engine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        
        self.rtcEngine = engine
        logToView("RTC engine initialized")
    }
    
    private func initializeRTM() {
        let config = AgoraRtmClientConfig(appId: KeyCenter.AGORA_APP_ID, userId: "\(userUid)")
        config.areaCode = [.CN, .NA]
        config.presenceTimeout = 30
        config.heartbeatInterval = 10
        config.useStringUserId = true
        
        do {
            self.rtmEngine = try AgoraRtmClientKit(config, delegate: self)
            logToView("RTM client initialized")
        } catch {
            logToView("RTM client initialization failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Actions
    
    @objc private func startButtonTapped() {
        connectionStartView.updateButtonState(isEnabled: false)
        startSession()
    }
    
    @objc private func stopButtonTapped() {
        chatSessionView.endCallButton.isEnabled = false
        stopSession()
    }
    
    @objc private func muteButtonTapped() {
        isMuted.toggle()
        rtcEngine?.adjustRecordingSignalVolume(isMuted ? 0 : 100)
        chatSessionView.updateMicButtonState(isMuted: isMuted)
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        if convoAIAPI == nil {
            initializeConvoAIAPI()
        }

        channelName = generateRandomChannelName()
        transcripts.removeAll()
        chatSessionView.updateTranscripts(transcripts)
        rtmLoggedIn = false
        chatSessionView.updateStatusView(state: .unknown)
        logToView("Starting session connection")
        
        NetworkManager.shared.generateToken(channelName: channelName, uid: "\(userUid)", types: [.rtc, .rtm]) { [weak self] token in
            guard let self = self, let token = token else {
                self?.logToView("User token request failed")
                self?.showIdleButtons()
                return
            }
            
            self.logToView("User token request succeeded")
            self.userToken = token
            
            self.loginRTM(token: token) { [weak self] success in
                guard let self = self, success else {
                    self?.logToView("RTM login failed")
                    self?.showIdleButtons()
                    return
                }
                
                self.logToView("RTM login succeeded")
                self.rtmLoggedIn = true
                self.joinRTCChannel(token: token)
            }
        }
    }
    
    private func stopSession() {
        logToView("Starting session cleanup")

        if !channelName.isEmpty {
            convoAIAPI?.unsubscribeMessage(channelName: channelName) { [weak self] error in
                if let error {
                    self?.logToView("ConvoAI unsubscribe failed: \(error.message)")
                }
            }
        }
        
        if !agentId.isEmpty, !userToken.isEmpty {
            AgentManager.stopAgent(agentId: agentId, token: userToken) { [weak self] error in
                if let error {
                    self?.logToView("Agent stop failed: \(error.localizedDescription)")
                }
            }
        }
        
        rtcEngine?.leaveChannel()
        rtmEngine?.logout { [weak self] _, errorInfo in
            if let reason = errorInfo?.localizedDescription, !reason.isEmpty {
                self?.logToView("RTM logout failed: \(reason)")
            }
        }
        
        // Reset state
        channelName = ""
        userToken = ""
        agentToken = ""
        agentId = ""
        isActive = false
        isMuted = false
        rtmLoggedIn = false
        transcripts = []
        
        // Update UI
        chatSessionView.updateTranscripts(transcripts)
        chatSessionView.updateMicButtonState(isMuted: false)
        chatSessionView.updateStatusView(state: .unknown)
        showIdleButtons()
        logToView("Session cleaned up")
    }
    
    // MARK: - Channel Operations
    
    private func joinRTCChannel(token: String) {
        guard let rtcEngine = rtcEngine else {
            logToView("joinChannel failed: RTC engine is not initialized")
            return
        }
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        
        let ret = rtcEngine.joinChannel(byToken: token, channelId: channelName, uid: userUid, mediaOptions: options)
        if ret == 0 {
            logToView("joinChannel succeeded")
        } else {
            logToView("joinChannel failed: ret=\(ret)")
            showIdleButtons()
        }
    }
    
    private func loginRTM(token: String, completion: @escaping (Bool) -> Void) {
        guard let rtmEngine = rtmEngine else {
            logToView("RTM login failed: RTM engine is not initialized")
            completion(false)
            return
        }
        
        logToView("RTM login in progress...")
        rtmEngine.login(token) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logToView("RTM login failed: \(error.localizedDescription)")
                }
                completion(error == nil)
            }
        }
    }
    
    private func initializeConvoAIAPI() {
        guard let rtcEngine = rtcEngine else {
            logToView("ConvoAI API initialization failed: RTC engine is not initialized")
            return
        }
        guard let rtmEngine = rtmEngine else {
            logToView("ConvoAI API initialization failed: RTM engine is not initialized")
            return
        }
        
        let config = ConversationalAIAPIConfig(
            rtcEngine: rtcEngine,
            rtmEngine: rtmEngine,
            renderMode: .words,
            enableLog: false
        )
        
        let api = ConversationalAIAPIImpl(config: config)
        api.addHandler(handler: self)
        self.convoAIAPI = api
        logToView("ConvoAI API initialized")
    }

    private func subscribeConvoAIMessage(completion: @escaping (Bool) -> Void) {
        guard let convoAIAPI = self.convoAIAPI else {
            logToView("ConvoAI subscription failed: ConvoAI API is not initialized")
            completion(false)
            return
        }

        logToView("Subscribing to ConvoAI...")

        convoAIAPI.subscribeMessage(channelName: channelName) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logToView("ConvoAI subscription failed: \(error.message)")
                    completion(false)
                } else {
                    self?.logToView("ConvoAI subscribed")
                    completion(true)
                }
            }
        }
    }
    
    private func startAgent() {
        logToView("Requesting agent token...")
        NetworkManager.shared.generateToken(channelName: channelName, uid: "\(agentUid)", types: [.rtc, .rtm]) { [weak self] token in
            guard let self = self, let token = token else {
                self?.logToView("Agent token request failed")
                self?.showIdleButtons()
                return
            }
            
            self.logToView("Agent token request succeeded")
            self.agentToken = token

            let parameter: [String: Any] = [
                "name": "agent_\(self.channelName)_\(self.agentUid)_\(Int(Date().timeIntervalSince1970))",
                "properties": [
                    "channel": self.channelName,
                    "agent_rtc_uid": "\(self.agentUid)",
                    "remote_rtc_uids": ["*"],
                    "token": token,
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
                            ["role": "system", "content": "You are a helpful AI assistant."]
                        ],
                        "greeting_message": "Hello! I am your AI assistant. How can I help you today?",
                        "failure_message": "Sorry, I am not able to process your request right now. Please try again later.",
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

            self.logToView("Agent start in progress...")
            AgentManager.startAgent(parameter: parameter, token: self.userToken) { [weak self] agentId, error in
                guard let self = self else { return }
                if let error = error {
                    self.logToView("Agent start failed: \(error.localizedDescription)")
                    self.stopSession()
                    return
                }

                if let agentId = agentId {
                    self.logToView("Agent start succeeded")
                    self.agentId = agentId
                    self.isActive = true
                    self.showActiveButtons()
                } else {
                    self.logToView("Agent start failed: missing agentId")
                    self.stopSession()
                }
            }
        }
    }

    private func generateRuntimeUids() {
        userUid = UInt.random(in: 100000...999999)
        repeat {
            agentUid = UInt.random(in: 100000...999999)
        } while agentUid == userUid
    }

    private func generateRandomChannelName() -> String {
        channelName = "channel_macos_\(Int.random(in: 100000...999999))"
        return channelName
    }
    
    // MARK: - UI Helpers
    
    private func showIdleButtons() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionStartView.isHidden = false
            self?.connectionStartView.updateButtonState(isEnabled: true)
            self?.chatSessionView.isHidden = true
            self?.chatSessionView.endCallButton.isEnabled = true
        }
    }
    
    private func showActiveButtons() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionStartView.isHidden = true
            self?.chatSessionView.isHidden = false
            self?.chatSessionView.micButton.isEnabled = true
            self?.chatSessionView.endCallButton.isEnabled = true
        }
    }
    
    private func logToView(_ message: String) {
        print("[VoiceAgent] \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.logView.addLog(message)
        }
    }
}

// MARK: - AgoraRtmClientDelegate

extension ViewController: AgoraRtmClientDelegate {
    func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveLinkStateEvent event: AgoraRtmLinkStateEvent) {
        if event.currentState == .failed {
            logToView("RTM connection failed; re-login required")
        }
    }
}

// MARK: - AgoraRtcEngineDelegate

extension ViewController: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        logToView("RTC joined channel")
        subscribeConvoAIMessage { [weak self] success in
            guard let self = self, success else {
                self?.showIdleButtons()
                return
            }
            self.startAgent()
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        if uid == agentUid && isActive {
            chatSessionView.updateStatusView(state: .speaking)
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        logToView("RTC error: \(errorCode.rawValue)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
    }
}

// MARK: - ConversationalAIAPIEventHandler

extension ViewController: ConversationalAIAPIEventHandler {
    
    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        if let index = transcripts.firstIndex(where: {
            $0.turnId == transcript.turnId &&
            $0.type.rawValue == transcript.type.rawValue &&
            $0.userId == transcript.userId
        }) {
            transcripts[index] = transcript
        } else {
            transcripts.append(transcript)
        }
        chatSessionView.updateTranscripts(transcripts)
    }
    
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        chatSessionView.updateStatusView(state: event.state)
    }
    
    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
    }

    func onMessageError(agentUserId: String, error: MessageError) {
    }

    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
    }

    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
    }

    func onAgentMetrics(agentUserId: String, metrics: Metric) {
    }

    func onAgentError(agentUserId: String, error: ModuleError) {
        logToView("Agent error: \(error)")
    }

    func onDebugLog(log: String) {
    }
}

// MARK: - UI Setup

extension ViewController {
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupLogView()
        setupContentViews()
        layoutPanels()
    }
    
    private func setupLogView() {
        logView = LogView()
        view.addSubview(logView)
    }
    
    private func setupContentViews() {
        connectionStartView.startButton.target = self
        connectionStartView.startButton.action = #selector(startButtonTapped)
        view.addSubview(connectionStartView)

        chatSessionView.isHidden = true
        chatSessionView.micButton.target = self
        chatSessionView.micButton.action = #selector(muteButtonTapped)
        chatSessionView.endCallButton.target = self
        chatSessionView.endCallButton.action = #selector(stopButtonTapped)
        view.addSubview(chatSessionView)
    }
    
    private func layoutPanels() {
        logView.snp.makeConstraints { make in
            make.top.right.bottom.equalToSuperview()
            make.width.equalTo(logViewWidth)
        }

        connectionStartView.snp.makeConstraints { make in
            make.top.left.bottom.equalToSuperview()
            make.right.equalTo(logView.snp.left).offset(-padding)
        }

        chatSessionView.snp.makeConstraints { make in
            make.top.left.bottom.equalToSuperview()
            make.right.equalTo(logView.snp.left).offset(-padding)
        }
    }
}

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
    private var topPanel: NSView!
    private var bottomPanel: NSView!
    private var logView: LogView!
    private var messageListView: MessageListView!
    private var agentStatusLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var muteButton: NSButton!
    
    // MARK: - Agora SDK
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    
    // MARK: - State
    private var channelName = ""
    private var userToken = ""
    private var agentToken = ""
    private var authToken = ""
    private var agentId = ""
    private var isActive = false
    private var isMuted = false
    private var transcripts: [Transcript] = []
    private var rtcJoined = false
    private var rtmLoggedIn = false
    
    // MARK: - Constants
    private var userUid: UInt = 0
    private var agentUid: UInt = 0
    private let bottomPanelHeight: CGFloat = 70
    private let padding: CGFloat = 20
    private let buttonHeight: CGFloat = 44
    private let logViewWidth: CGFloat = 200
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSDK()
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
        updateAgentStatus("Not Started")
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
        logToView("RTC init OK, v\(AgoraRtcEngineKit.getSdkVersion())")
    }
    
    private func initializeRTM() {
        let config = AgoraRtmClientConfig(appId: KeyCenter.AGORA_APP_ID, userId: "\(userUid)")
        config.areaCode = [.CN, .NA]
        config.presenceTimeout = 30
        config.heartbeatInterval = 10
        config.useStringUserId = true
        
        do {
            self.rtmEngine = try AgoraRtmClientKit(config, delegate: self)
            logToView("RTM init OK")
        } catch {
            logToView("RTM init FAIL: \(error)")
        }
    }
    
    // MARK: - Actions
    
    @objc private func startButtonTapped() {
        startButton.isEnabled = false
        startSession()
    }
    
    @objc private func stopButtonTapped() {
        stopButton.isEnabled = false
        stopSession()
    }
    
    @objc private func muteButtonTapped() {
        isMuted.toggle()
        rtcEngine?.adjustRecordingSignalVolume(isMuted ? 0 : 100)
        muteButton.title = isMuted ? "Unmute" : "Mute"
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        channelName = generateRandomChannelName()
        transcripts.removeAll()
        messageListView.updateTranscripts(transcripts)
        rtcJoined = false
        rtmLoggedIn = false
        updateAgentStatus("Generating token...")
        
        TokenGenerator.generateToken(channelName: "", uid: "\(userUid)", types: [.rtc, .rtm]) { [weak self] token in
            guard let self = self, let token = token else {
                self?.logToView("Token FAIL")
                self?.updateAgentStatus("Token failed")
                self?.showIdleButtons()
                return
            }
            
            self.logToView("Token OK")
            self.userToken = token
            self.updateAgentStatus("Joining...")
            
            self.joinRTCChannel(token: token)
            self.loginRTM(token: token) { [weak self] success in
                guard let self = self, success else {
                    self?.logToView("RTM login FAIL")
                    self?.updateAgentStatus("RTM login failed")
                    self?.showIdleButtons()
                    return
                }
                
                self.logToView("RTM login OK")
                self.rtmLoggedIn = true
                self.checkJoinAndLoginComplete()
            }
        }
    }
    
    private func stopSession() {
        updateAgentStatus("Stopping...")
        
        // Cleanup
        convoAIAPI?.destroy()
        convoAIAPI = nil
        
        if !agentId.isEmpty, !authToken.isEmpty {
            AgentManager.stopAgent(agentId: agentId, authToken: authToken) { _ in }
        }
        
        rtcEngine?.leaveChannel()
        rtmEngine?.logout { _, _ in }
        
        // Reset state
        channelName = ""
        userToken = ""
        agentToken = ""
        authToken = ""
        agentId = ""
        isActive = false
        isMuted = false
        rtcJoined = false
        rtmLoggedIn = false
        transcripts = []
        
        // Update UI
        messageListView.updateTranscripts(transcripts)
        muteButton.title = "Mute"
        showIdleButtons()
        updateAgentStatus("Not Started")
    }
    
    // MARK: - Channel Operations
    
    private func joinRTCChannel(token: String) {
        guard let rtcEngine = rtcEngine else {
            logToView("joinChannel FAIL: nil")
            return
        }
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        
        let ret = rtcEngine.joinChannel(byToken: token, channelId: channelName, uid: userUid, mediaOptions: options)
        logToView("joinChannel ret=\(ret)")
    }
    
    private func loginRTM(token: String, completion: @escaping (Bool) -> Void) {
        guard let rtmEngine = rtmEngine else {
            completion(false)
            return
        }
        
        rtmEngine.login(token) { _, error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    private func initializeConvoAI() {
        guard let rtcEngine = rtcEngine, let rtmEngine = rtmEngine else { return }
        
        let config = ConversationalAIAPIConfig(
            rtcEngine: rtcEngine,
            rtmEngine: rtmEngine,
            renderMode: .words,
            enableLog: true
        )
        
        let api = ConversationalAIAPIImpl(config: config)
        api.addHandler(handler: self)
        api.subscribeMessage(channelName: channelName) { _ in }
        self.convoAIAPI = api
    }
    
    private func startAgent() {
        TokenGenerator.generateToken(channelName: channelName, uid: "\(agentUid)", types: [.rtc, .rtm]) { [weak self] token in
            guard let self = self, let token = token else {
                self?.logToView("Agent token FAIL")
                self?.updateAgentStatus("Token failed")
                self?.showIdleButtons()
                return
            }
            
            self.logToView("Agent token OK")
            self.agentToken = token

            TokenGenerator.generateToken(channelName: self.channelName, uid: "\(self.agentUid)", types: [.rtc, .rtm]) { [weak self] authToken in
                guard let self = self, let authToken = authToken else {
                    self?.logToView("Auth token FAIL")
                    self?.updateAgentStatus("Auth failed")
                    self?.showIdleButtons()
                    return
                }

                self.logToView("Auth token OK")
                self.authToken = authToken

                AgentManager.startAgent(
                    channelName: self.channelName,
                    agentRtcUid: "\(self.agentUid)",
                    agentToken: token,
                    authToken: authToken
                ) { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .success(let agentId):
                        self.logToView("Agent start OK")
                        self.agentId = agentId
                        self.isActive = true
                        self.showActiveButtons()
                        self.updateAgentStatus("Launching...")

                    case .failure(let error):
                        self.logToView("Agent start FAIL: \(error.localizedDescription)")
                        self.updateAgentStatus("Start failed")
                        self.stopSession()
                    }
                }
            }
        }
    }

    private func checkJoinAndLoginComplete() {
        guard rtcJoined, rtmLoggedIn else { return }
        updateAgentStatus("Starting agent...")
        initializeConvoAI()
        startAgent()
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
    
    private func updateAgentStatus(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.agentStatusLabel.stringValue = "Agent: \(message)"
        }
    }
    
    private func showIdleButtons() {
        DispatchQueue.main.async { [weak self] in
            self?.startButton.isHidden = false
            self?.startButton.isEnabled = true
            self?.muteButton.isHidden = true
            self?.stopButton.isHidden = true
        }
    }
    
    private func showActiveButtons() {
        DispatchQueue.main.async { [weak self] in
            self?.startButton.isHidden = true
            self?.muteButton.isHidden = false
            self?.muteButton.isEnabled = true
            self?.stopButton.isHidden = false
            self?.stopButton.isEnabled = true
        }
    }
    
    private func logToView(_ message: String) {
        print("[Log] \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.logView.addLog(message)
        }
    }
}

// MARK: - AgoraRtmClientDelegate

extension ViewController: AgoraRtmClientDelegate {
    func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveLinkStateEvent event: AgoraRtmLinkStateEvent) {
        // RTM connection state handling if needed
    }
}

// MARK: - AgoraRtcEngineDelegate

extension ViewController: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        logToView("onJoinSuccess uid=\(uid)")
        rtcJoined = true
        checkJoinAndLoginComplete()
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        logToView("onUserJoined uid=\(uid)")
        if uid == agentUid && isActive {
            updateAgentStatus("Connected")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        logToView("onUserOffline uid=\(uid)")
        if uid == agentUid && isActive {
            updateAgentStatus("Disconnected")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        if state == .disconnected || state == .failed {
            updateAgentStatus("Connection lost")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        logToView("onError code=\(errorCode.rawValue)")
        updateAgentStatus("RTC error: \(errorCode.rawValue)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        logToView("Token expiring")
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
        messageListView.updateTranscripts(transcripts)
    }
    
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        switch event.state {
        case .idle: updateAgentStatus("Idle")
        case .silent: updateAgentStatus("Silent")
        case .listening: updateAgentStatus("Listening")
        case .thinking: updateAgentStatus("Thinking")
        case .speaking: updateAgentStatus("Speaking")
        default: break
        }
    }
    
    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {}
    func onMessageError(agentUserId: String, error: MessageError) {}
    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {}
    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {}
    func onAgentMetrics(agentUserId: String, metrics: Metric) {}
    func onAgentError(agentUserId: String, error: ModuleError) {}
    func onDebugLog(log: String) {}
}

// MARK: - UI Setup

extension ViewController {
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupLogView()
        setupTopPanel()
        setupBottomPanel()
        layoutPanels()
    }
    
    private func setupLogView() {
        logView = LogView()
        view.addSubview(logView)
    }
    
    private func setupTopPanel() {
        topPanel = NSView()
        topPanel.wantsLayer = true
        topPanel.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        view.addSubview(topPanel)
        
        messageListView = MessageListView()
        topPanel.addSubview(messageListView)
        
        agentStatusLabel = NSTextField(labelWithString: "Agent: Not Started")
        agentStatusLabel.font = .systemFont(ofSize: 11)
        agentStatusLabel.textColor = .secondaryLabelColor
        agentStatusLabel.alignment = .right
        topPanel.addSubview(agentStatusLabel)
        
        messageListView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview().inset(padding)
            make.bottom.equalTo(agentStatusLabel.snp.top).offset(-8)
        }
        
        agentStatusLabel.snp.makeConstraints { make in
            make.right.bottom.equalToSuperview().inset(padding)
            make.height.equalTo(16)
        }
    }
    
    private func setupBottomPanel() {
        bottomPanel = NSView()
        bottomPanel.wantsLayer = true
        bottomPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        bottomPanel.layer?.borderWidth = 0.5
        bottomPanel.layer?.borderColor = NSColor.separatorColor.cgColor
        view.addSubview(bottomPanel)
        
        startButton = createButton("Start Agent", action: #selector(startButtonTapped), color: .systemGreen)
        muteButton = createButton("Mute", action: #selector(muteButtonTapped))
        stopButton = createButton("Stop Agent", action: #selector(stopButtonTapped), color: .systemRed)
        
        muteButton.isHidden = true
        stopButton.isHidden = true
        
        bottomPanel.addSubview(startButton)
        bottomPanel.addSubview(muteButton)
        bottomPanel.addSubview(stopButton)
        
        startButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.right.equalToSuperview().inset(padding)
            make.height.equalTo(buttonHeight)
        }
        
        muteButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(padding)
            make.right.equalTo(bottomPanel.snp.centerX).offset(-4)
            make.height.equalTo(buttonHeight)
        }
        
        stopButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(bottomPanel.snp.centerX).offset(4)
            make.right.equalToSuperview().offset(-padding)
            make.height.equalTo(buttonHeight)
        }
    }
    
    private func layoutPanels() {
        logView.snp.makeConstraints { make in
            make.top.right.bottom.equalToSuperview()
            make.width.equalTo(logViewWidth)
        }
        
        topPanel.snp.makeConstraints { make in
            make.top.left.equalToSuperview()
            make.right.equalTo(logView.snp.left).offset(-padding)
            make.bottom.equalTo(bottomPanel.snp.top).offset(-1)
        }
        
        bottomPanel.snp.makeConstraints { make in
            make.left.bottom.equalToSuperview()
            make.right.equalTo(logView.snp.left).offset(-padding)
            make.height.equalTo(bottomPanelHeight)
        }
    }
    
    private func createButton(_ title: String, action: Selector, color: NSColor? = nil) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12, weight: .medium)
        if let color = color {
            button.contentTintColor = color
        }
        return button
    }
}

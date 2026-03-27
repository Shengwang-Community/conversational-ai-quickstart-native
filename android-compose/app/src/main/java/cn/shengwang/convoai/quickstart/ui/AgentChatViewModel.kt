package cn.shengwang.convoai.quickstart.ui

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.convoai.convoaiApi.AgentState
import io.agora.convoai.convoaiApi.ConversationalAIAPIConfig
import io.agora.convoai.convoaiApi.ConversationalAIAPIImpl
import io.agora.convoai.convoaiApi.IConversationalAIAPI
import io.agora.convoai.convoaiApi.IConversationalAIAPIEventHandler
import io.agora.convoai.convoaiApi.InterruptEvent
import io.agora.convoai.convoaiApi.MessageError
import io.agora.convoai.convoaiApi.MessageReceipt
import io.agora.convoai.convoaiApi.Metric
import io.agora.convoai.convoaiApi.ModuleError
import io.agora.convoai.convoaiApi.StateChangeEvent
import io.agora.convoai.convoaiApi.Transcript
import io.agora.convoai.convoaiApi.VoiceprintStateChangeEvent
import cn.shengwang.convoai.quickstart.AgentApp
import cn.shengwang.convoai.quickstart.KeyCenter
import cn.shengwang.convoai.quickstart.api.AgentStarter
import cn.shengwang.convoai.quickstart.api.TokenGenerator
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.Constants.CLIENT_ROLE_BROADCASTER
import io.agora.rtc2.Constants.ERR_OK
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.RtcEngineEx
import io.agora.rtm.ErrorInfo
import io.agora.rtm.LinkStateEvent
import io.agora.rtm.PresenceEvent
import io.agora.rtm.ResultCallback
import io.agora.rtm.RtmClient
import io.agora.rtm.RtmConfig
import io.agora.rtm.RtmConstants
import io.agora.rtm.RtmEventListener
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class AgentChatViewModel : ViewModel() {

    companion object {
        private const val TAG = "ConversationViewModel"
        val userId = (100000..999999).random()
        val agentUid: Int = generateUniqueUid(userId)

        private fun generateUniqueUid(excludeUid: Int): Int {
            var uid: Int
            do {
                uid = (100000..999999).random()
            } while (uid == excludeUid)
            return uid
        }

        fun generateRandomChannelName(): String {
            return "channel_compose_${(100000..999999).random()}"
        }
    }

    enum class ConnectionState {
        Idle,
        Connecting,
        Connected,
        Error
    }

    data class ConversationUiState(
        val isMuted: Boolean = false,
        val connectionState: ConnectionState = ConnectionState.Idle
    )

    private val _uiState = MutableStateFlow(ConversationUiState())
    val uiState: StateFlow<ConversationUiState> = _uiState.asStateFlow()

    private val _transcriptList = MutableStateFlow<List<Transcript>>(emptyList())
    val transcriptList: StateFlow<List<Transcript>> = _transcriptList.asStateFlow()

    private val _agentState = MutableStateFlow(AgentState.IDLE)
    val agentState: StateFlow<AgentState?> = _agentState.asStateFlow()

    private val _debugLogList = MutableStateFlow<List<String>>(emptyList())
    val debugLogList: StateFlow<List<String>> = _debugLogList.asStateFlow()

    private val _agentError = MutableSharedFlow<ModuleError>(extraBufferCapacity = 1)
    val agentError: SharedFlow<ModuleError> = _agentError.asSharedFlow()

    private var unifiedToken: String? = null
    private var authToken: String? = null
    private var conversationalAIAPI: IConversationalAIAPI? = null
    private var channelName = ""
    private var rtcJoined = false
    private var rtmLoggedIn = false
    private var agentId: String? = null
    private var rtcEngine: RtcEngineEx? = null
    private var rtmClient: RtmClient? = null
    private var isRtmLogin = false
    private var isLoggingIn = false

    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            viewModelScope.launch {
                rtcJoined = true
                addStatusLog("Rtc onJoinChannelSuccess, channel:$channel uid:$uid")
                checkJoinAndLoginComplete()
            }
        }

        override fun onLeaveChannel(stats: RtcStats?) {
            super.onLeaveChannel(stats)
            viewModelScope.launch {
                addStatusLog("Rtc onLeaveChannel")
            }
        }

        override fun onUserJoined(uid: Int, elapsed: Int) {
            viewModelScope.launch {
                addStatusLog("Rtc onUserJoined, uid:$uid")
            }
        }

        override fun onUserOffline(uid: Int, reason: Int) {
            viewModelScope.launch {
                addStatusLog("Rtc onUserOffline, uid:$uid")
            }
        }

        override fun onError(err: Int) {
            viewModelScope.launch {
                _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Error)
                addStatusLog("Rtc onError: $err")
                Log.e(TAG, "RTC error: $err")
            }
        }

        override fun onTokenPrivilegeWillExpire(token: String?) {
            Log.d(TAG, "RTC onTokenPrivilegeWillExpire $channelName")
        }
    }

    private val rtmEventListener = object : RtmEventListener {
        override fun onLinkStateEvent(event: LinkStateEvent?) {
            super.onLinkStateEvent(event)
            event ?: return

            when (event.currentState) {
                RtmConstants.RtmLinkState.CONNECTED -> {
                    isRtmLogin = true
                    addStatusLog("Rtm connected successfully")
                }

                RtmConstants.RtmLinkState.FAILED -> {
                    isRtmLogin = false
                    isLoggingIn = false
                    viewModelScope.launch {
                        _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Error)
                        addStatusLog("Rtm connected failed")
                        unifiedToken = null
                    }
                }

                else -> Unit
            }
        }

        override fun onTokenPrivilegeWillExpire(channelName: String) {
            Log.d(TAG, "RTM onTokenPrivilegeWillExpire $channelName")
        }

        override fun onPresenceEvent(event: PresenceEvent) {
            super.onPresenceEvent(event)
        }
    }

    private val conversationalAIAPIEventHandler = object : IConversationalAIAPIEventHandler {
        override fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
            _agentState.value = event.state
        }

        override fun onAgentInterrupted(agentUserId: String, event: InterruptEvent) = Unit

        override fun onAgentMetrics(agentUserId: String, metric: Metric) = Unit

        override fun onAgentError(agentUserId: String, error: ModuleError) {
            addStatusLog("Agent error: type=${error.type.value}, code=${error.code}, msg=${error.message}")
            _agentError.tryEmit(error)
        }

        override fun onMessageError(agentUserId: String, error: MessageError) = Unit

        override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
            addTranscript(transcript)
        }

        override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) = Unit

        override fun onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) = Unit

        override fun onDebugLog(log: String) {
            Log.d("conversationalAIAPI", log)
        }
    }

    init {
        initRtcEngine()
        initRtmClient()
        if (rtcEngine != null && rtmClient != null) {
            conversationalAIAPI = ConversationalAIAPIImpl(
                ConversationalAIAPIConfig(
                    rtcEngine = rtcEngine!!,
                    rtmClient = rtmClient!!,
                    enableLog = true
                )
            )
            conversationalAIAPI?.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT)
            conversationalAIAPI?.addHandler(conversationalAIAPIEventHandler)
            Log.d(TAG, "RTC engine and RTM client created successfully")
        } else {
            _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Error)
            Log.e(TAG, "Failed to create RTC engine or RTM client")
        }
    }

    private fun initRtcEngine() {
        if (rtcEngine != null) return

        val config = RtcEngineConfig()
        config.mContext = AgentApp.instance()
        config.mAppId = KeyCenter.APP_ID
        config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING
        config.mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT
        config.mEventHandler = rtcEventHandler
        try {
            rtcEngine = (RtcEngine.create(config) as RtcEngineEx).apply {
                enableVideo()
                loadExtensionProvider("ai_echo_cancellation_extension")
                loadExtensionProvider("ai_noise_suppression_extension")
            }
            addStatusLog("RtcEngine init successfully")
        } catch (e: Exception) {
            Log.e(TAG, "initRtcEngine error: $e")
            addStatusLog("RtcEngine init failed")
        }
    }

    private fun initRtmClient() {
        if (rtmClient != null) return

        val rtmConfig = RtmConfig.Builder(KeyCenter.APP_ID, userId.toString()).build()
        try {
            rtmClient = RtmClient.create(rtmConfig)
            rtmClient?.addEventListener(rtmEventListener)
            addStatusLog("RtmClient init successfully")
        } catch (e: Exception) {
            Log.e(TAG, "RTM initRtmClient error: ${e.message}")
            addStatusLog("RtmClient init failed")
        }
    }

    private fun loginRtm(rtmToken: String, completion: (Exception?) -> Unit) {
        if (isLoggingIn) {
            completion.invoke(Exception("Login already in progress"))
            return
        }

        if (isRtmLogin) {
            completion.invoke(null)
            return
        }

        val client = rtmClient ?: run {
            completion.invoke(Exception("RTM client not initialized"))
            return
        }

        isLoggingIn = true
        isRtmLogin = false
        client.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                performRtmLogin(client, rtmToken, completion)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                performRtmLogin(client, rtmToken, completion)
            }
        })
    }

    private fun performRtmLogin(client: RtmClient, rtmToken: String, completion: (Exception?) -> Unit) {
        client.login(rtmToken, object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                isRtmLogin = true
                isLoggingIn = false
                addStatusLog("Rtm login successful")
                completion.invoke(null)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                isRtmLogin = false
                isLoggingIn = false
                addStatusLog("Rtm login failed, code: ${errorInfo?.errorCode}")
                completion.invoke(Exception("${errorInfo?.errorCode}"))
            }
        })
    }

    private fun logoutRtm() {
        rtmClient?.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                isRtmLogin = false
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                isRtmLogin = false
            }
        })
    }

    private fun joinRtcChannel(rtcToken: String, channelName: String, uid: Int) {
        val channelOptions = ChannelMediaOptions().apply {
            clientRoleType = CLIENT_ROLE_BROADCASTER
            publishMicrophoneTrack = true
            publishCameraTrack = false
            autoSubscribeAudio = true
            autoSubscribeVideo = true
        }
        val ret = rtcEngine?.joinChannel(rtcToken, channelName, uid, channelOptions)
        if (ret != ERR_OK) {
            addStatusLog("Rtc joinChannel failed ret: $ret")
        }
    }

    private fun leaveRtcChannel() {
        rtcEngine?.leaveChannel()
    }

    private fun muteLocalAudio(mute: Boolean) {
        rtcEngine?.adjustRecordingSignalVolume(if (mute) 0 else 100)
    }

    private fun checkJoinAndLoginComplete() {
        if (rtcJoined && rtmLoggedIn) {
            startAgent()
        }
    }

    fun startAgent() {
        viewModelScope.launch {
            if (agentId != null) return@launch

            val agentToken = TokenGenerator.generateTokensAsync(
                channelName = channelName,
                uid = agentUid.toString()
            ).fold(
                onSuccess = { token ->
                    addStatusLog("Generate agent token successfully")
                    token
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Error)
                    addStatusLog("Generate agent token failed")
                    Log.e(TAG, "Failed to generate agent token: ${exception.message}", exception)
                    return@launch
                }
            )

            val restAuthToken = TokenGenerator.generateTokensAsync(
                channelName = channelName,
                uid = agentUid.toString()
            ).fold(
                onSuccess = { token ->
                    authToken = token
                    addStatusLog("Generate auth token successfully")
                    token
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Error)
                    addStatusLog("Generate auth token failed")
                    Log.e(TAG, "Failed to generate auth token: ${exception.message}", exception)
                    return@launch
                }
            )

            AgentStarter.startAgentAsync(
                channelName = channelName,
                agentRtcUid = agentUid.toString(),
                agentToken = agentToken,
                authToken = restAuthToken,
                remoteRtcUid = userId.toString()
            ).fold(
                onSuccess = { startedAgentId ->
                    agentId = startedAgentId
                    _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Connected)
                    addStatusLog("Agent start successfully")
                    Log.d(TAG, "Agent started successfully, agentId: $startedAgentId")
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Error)
                    addStatusLog("Agent start failed")
                    Log.e(TAG, "Failed to start agent: ${exception.message}", exception)
                }
            )
        }
    }

    private suspend fun generateUserToken(): String? {
        return TokenGenerator.generateTokensAsync(
            channelName = "",
            uid = userId.toString()
        ).fold(
            onSuccess = { token ->
                addStatusLog("Generate user token successfully")
                unifiedToken = token
                token
            },
            onFailure = { exception ->
                _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Error)
                addStatusLog("Generate user token failed")
                Log.e(TAG, "Failed to get token: ${exception.message}", exception)
                null
            }
        )
    }

    fun joinChannelAndLogin(channelName: String) {
        viewModelScope.launch {
            this@AgentChatViewModel.channelName = channelName
            rtcJoined = false
            rtmLoggedIn = false
            _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Connecting)

            val token = unifiedToken ?: generateUserToken() ?: return@launch
            joinRtcChannel(token, channelName, userId)

            loginRtm(token) { exception ->
                viewModelScope.launch {
                    if (exception == null) {
                        rtmLoggedIn = true
                        conversationalAIAPI?.subscribeMessage(channelName) { errorInfo ->
                            if (errorInfo != null) {
                                Log.e(TAG, "Subscribe message error: $errorInfo")
                            }
                        }
                        checkJoinAndLoginComplete()
                    } else {
                        _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Error)
                        Log.e(TAG, "RTM login failed: ${exception.message}", exception)
                    }
                }
            }
        }
    }

    fun toggleMute() {
        val newMuteState = !_uiState.value.isMuted
        _uiState.value = _uiState.value.copy(isMuted = newMuteState)
        muteLocalAudio(newMuteState)
    }

    fun addTranscript(transcript: Transcript) {
        viewModelScope.launch {
            val currentList = _transcriptList.value.toMutableList()
            val existingIndex = currentList.indexOfFirst {
                it.turnId == transcript.turnId && it.type == transcript.type
            }
            if (existingIndex >= 0) {
                currentList[existingIndex] = transcript
            } else {
                currentList.add(transcript)
            }
            _transcriptList.value = currentList
        }
    }

    private fun addStatusLog(message: String) {
        if (message.isEmpty()) return
        viewModelScope.launch {
            val currentLogs = _debugLogList.value.toMutableList()
            currentLogs.add(message)
            if (currentLogs.size > 20) {
                currentLogs.removeAt(0)
            }
            _debugLogList.value = currentLogs
        }
    }

    fun hangup() {
        viewModelScope.launch {
            try {
                conversationalAIAPI?.unsubscribeMessage(channelName) { errorInfo ->
                    if (errorInfo != null) {
                        Log.e(TAG, "Unsubscribe message error: $errorInfo")
                    }
                }

                if (agentId != null) {
                    AgentStarter.stopAgentAsync(
                        agentId = agentId!!,
                        authToken = authToken ?: ""
                    ).fold(
                        onSuccess = {
                            addStatusLog("Agent stopped successfully")
                        },
                        onFailure = { exception ->
                            Log.e(TAG, "Failed to stop agent: ${exception.message}", exception)
                        }
                    )
                    agentId = null
                }

                leaveRtcChannel()
                rtcJoined = false
                authToken = null
                _uiState.value = _uiState.value.copy(connectionState = ConnectionState.Idle)
                _transcriptList.value = emptyList()
                _agentState.value = AgentState.IDLE
                Log.d(TAG, "Hangup completed")
            } catch (e: Exception) {
                Log.e(TAG, "Error during hangup: ${e.message}", e)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        leaveRtcChannel()
        logoutRtm()
        rtmClient?.let { client ->
            try {
                client.removeEventListener(rtmEventListener)
            } catch (e: Exception) {
                Log.e(TAG, "Error removing RTM event listener: ${e.message}")
            }
        }
        rtcEngine = null
        rtmClient = null
    }
}

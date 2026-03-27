package cn.shengwang.convoai.quickstart.ui;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import androidx.lifecycle.ViewModel;

import io.agora.convoai.convoaiApi.AgentState;
import io.agora.convoai.convoaiApi.ConversationalAIAPIConfig;
import io.agora.convoai.convoaiApi.ConversationalAIAPIImpl;
import io.agora.convoai.convoaiApi.IConversationalAIAPI;
import io.agora.convoai.convoaiApi.IConversationalAIAPIEventHandler;
import io.agora.convoai.convoaiApi.InterruptEvent;
import io.agora.convoai.convoaiApi.MessageError;
import io.agora.convoai.convoaiApi.MessageReceipt;
import io.agora.convoai.convoaiApi.Metric;
import io.agora.convoai.convoaiApi.ModuleError;
import io.agora.convoai.convoaiApi.StateChangeEvent;
import io.agora.convoai.convoaiApi.Transcript;
import io.agora.convoai.convoaiApi.TranscriptRenderMode;
import io.agora.convoai.convoaiApi.VoiceprintStateChangeEvent;
import cn.shengwang.convoai.quickstart.AgentApp;
import cn.shengwang.convoai.quickstart.KeyCenter;
import cn.shengwang.convoai.quickstart.api.AgentStarter;
import cn.shengwang.convoai.quickstart.api.TokenGenerator;
import io.agora.rtc2.Constants;
import io.agora.rtc2.ChannelMediaOptions;
import io.agora.rtc2.IRtcEngineEventHandler;
import io.agora.rtc2.RtcEngine;
import io.agora.rtc2.RtcEngineConfig;
import io.agora.rtc2.RtcEngineEx;
import io.agora.rtm.ErrorInfo;
import io.agora.rtm.LinkStateEvent;
import io.agora.rtm.PresenceEvent;
import io.agora.rtm.ResultCallback;
import io.agora.rtm.RtmClient;
import io.agora.rtm.RtmConfig;
import io.agora.rtm.RtmConstants;
import io.agora.rtm.RtmEventListener;
import kotlin.Unit;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * ViewModel for managing conversation-related business logic
 * Integrates RTC and RTM logic directly (no separate managers)
 */
public class AgentChatViewModel extends ViewModel {
    private static final String TAG = "AgentChatViewModel";
    public static final int userId = generateRandomUid();
    public static final int agentUid = generateUniqueUid(userId);

    private static int generateRandomUid() {
        Random random = new Random();
        return random.nextInt(900000) + 100000;
    }

    private static int generateUniqueUid(int excludeUid) {
        int uid;
        do {
            uid = generateRandomUid();
        } while (uid == excludeUid);
        return uid;
    }

    /**
     * Generate a random channel name
     */
    public static String generateRandomChannelName() {
        Random random = new Random();
        int randomNum = random.nextInt(900000) + 100000; // 100000-999999
        return "channel_java_" + randomNum;
    }

    /**
     * Connection state enum
     */
    public enum ConnectionState {
        Idle,
        Connecting,
        Connected,
        Error
    }

    /**
     * UI State
     */
    public static class ConversationUiState {
        public boolean isMuted = false;
        public ConnectionState connectionState = ConnectionState.Idle;

        public ConversationUiState() {
        }

        public ConversationUiState(boolean isMuted, ConnectionState connectionState) {
            this.isMuted = isMuted;
            this.connectionState = connectionState;
        }

        public ConversationUiState copy() {
            return new ConversationUiState(this.isMuted, this.connectionState);
        }

        public ConversationUiState copy(boolean isMuted, ConnectionState connectionState) {
            return new ConversationUiState(isMuted, connectionState);
        }
    }

    public static class AgentErrorUiEvent {
        public final long eventId;
        public final String message;

        public AgentErrorUiEvent(long eventId, String message) {
            this.eventId = eventId;
            this.message = message;
        }
    }

    private final MutableLiveData<ConversationUiState> _uiState = new MutableLiveData<>(new ConversationUiState());
    public LiveData<ConversationUiState> uiState = _uiState;

    // Transcript list - separate from UI state
    private final MutableLiveData<List<Transcript>> _transcriptList = new MutableLiveData<>(new ArrayList<>());
    public LiveData<List<Transcript>> transcriptList = _transcriptList;

    private final MutableLiveData<AgentState> _agentState = new MutableLiveData<>(AgentState.IDLE);
    public LiveData<AgentState> agentState = _agentState;

    // Debug log list - for displaying logs in UI
    private final MutableLiveData<List<String>> _debugLogList = new MutableLiveData<>(new ArrayList<>());
    public LiveData<List<String>> debugLogList = _debugLogList;

    private final MutableLiveData<AgentErrorUiEvent> _agentErrorEvent = new MutableLiveData<>();
    public LiveData<AgentErrorUiEvent> agentErrorEvent = _agentErrorEvent;

    private String unifiedToken = null;
    private IConversationalAIAPI conversationalAIAPI = null;
    private String channelName = "";
    private boolean rtcJoined = false;
    private boolean rtmLoggedIn = false;

    // Agent management
    private String agentId = null;
    private String authToken = null;

    // RTC and RTM instances
    private RtcEngineEx rtcEngine = null;
    private RtmClient rtmClient = null;
    private boolean isRtmLogin = false;
    private boolean isLoggingIn = false;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private final IRtcEngineEventHandler rtcEventHandler = new IRtcEngineEventHandler() {
        @Override
        public void onJoinChannelSuccess(String channel, int uid, int elapsed) {
            mainHandler.post(() -> {
                rtcJoined = true;
                addStatusLog("Rtc onJoinChannelSuccess, channel:" + channel + " uid:" + uid);
                Log.d(TAG, "RTC joined channel: " + channel + ", uid: " + uid);
                checkJoinAndLoginComplete();
            });
        }

        @Override
        public void onLeaveChannel(RtcStats stats) {
            super.onLeaveChannel(stats);
            mainHandler.post(() -> {
                addStatusLog("Rtc onLeaveChannel");
            });
        }

        @Override
        public void onUserJoined(int uid, int elapsed) {
            mainHandler.post(() -> {
                addStatusLog("Rtc onUserJoined, uid:" + uid);
                if (uid == agentUid) {
                    Log.d(TAG, "Agent joined the channel, uid: " + uid);
                } else {
                    Log.d(TAG, "User joined the channel, uid: " + uid);
                }
            });
        }

        @Override
        public void onUserOffline(int uid, int reason) {
            mainHandler.post(() -> {
                addStatusLog("Rtc onUserOffline, uid:" + uid);
                if (uid == agentUid) {
                    Log.d(TAG, "Agent left the channel, uid: " + uid + ", reason: " + reason);
                } else {
                    Log.d(TAG, "User left the channel, uid: " + uid + ", reason: " + reason);
                }
            });
        }

        @Override
        public void onError(int err) {
            mainHandler.post(() -> {
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    _uiState.setValue(currentState.copy(false, ConnectionState.Error));
                }
                addStatusLog("Rtc onError: " + err);
                Log.e(TAG, "RTC error: " + err);
            });
        }

        @Override
        public void onTokenPrivilegeWillExpire(String token) {
            Log.d(TAG, "RTC onTokenPrivilegeWillExpire " + channelName);
        }
    };

    // RTM event listener
    private final RtmEventListener rtmEventListener = new RtmEventListener() {
        @Override
        public void onLinkStateEvent(LinkStateEvent event) {
            RtmEventListener.super.onLinkStateEvent(event);
            if (event == null) {
                return;
            }

            Log.d(TAG, "Rtm link state changed: " + event.getCurrentState());

            if (event.getCurrentState() == RtmConstants.RtmLinkState.CONNECTED) {
                Log.d(TAG, "Rtm connected successfully");
                isRtmLogin = true;
                addStatusLog("Rtm connected successfully");
            } else if (event.getCurrentState() == RtmConstants.RtmLinkState.FAILED) {
                Log.d(TAG, "RTM connection failed, need to re-login");
                isRtmLogin = false;
                isLoggingIn = false;
                mainHandler.post(() -> {
                    ConversationUiState currentState = _uiState.getValue();
                    if (currentState != null) {
                        _uiState.setValue(currentState.copy(false, ConnectionState.Error));
                    }
                    addStatusLog("Rtm connected failed");
                    unifiedToken = null;
                });
            }
        }

        @Override
        public void onTokenPrivilegeWillExpire(String channelName) {
            Log.d(TAG, "RTM onTokenPrivilegeWillExpire " + channelName);
        }

        @Override
        public void onPresenceEvent(PresenceEvent event) {
            RtmEventListener.super.onPresenceEvent(event);
            // Handle presence events if needed
        }
    };

    private final IConversationalAIAPIEventHandler conversationalAIAPIEventHandler = new IConversationalAIAPIEventHandler() {
        @Override
        public void onAgentStateChanged(String agentUserId, StateChangeEvent event) {
            mainHandler.post(() -> {
                _agentState.setValue(event.getState());
            });
        }

        @Override
        public void onAgentInterrupted(String agentUserId, InterruptEvent event) {
            // Handle interruption
        }

        @Override
        public void onAgentMetrics(String agentUserId, Metric metric) {
            // Handle metrics
        }

        @Override
        public void onAgentError(String agentUserId, ModuleError error) {
            mainHandler.post(() -> {
                String message = "Agent error: type=" + error.getType().getValue()
                        + ", code=" + error.getCode()
                        + ", msg=" + error.getMessage();
                addStatusLog(message);
                _agentErrorEvent.setValue(new AgentErrorUiEvent(System.currentTimeMillis(), message));
            });
        }

        @Override
        public void onMessageError(String agentUserId, MessageError error) {
            // Handle message error
        }

        @Override
        public void onTranscriptUpdated(String agentUserId, Transcript transcript) {
            // Handle transcript updates
            addTranscript(transcript);
        }

        @Override
        public void onMessageReceiptUpdated(String agentUserId, MessageReceipt receipt) {
            // Handle message receipt
        }

        @Override
        public void onAgentVoiceprintStateChanged(String agentUserId, VoiceprintStateChangeEvent event) {
            // Update voice print state to notify Activity
        }

        @Override
        public void onDebugLog(String log) {
            // Only log to system log, don't collect for UI display
            // UI will only show ViewModel status messages
            Log.d("conversationalAIAPI", log);
        }
    };

    public AgentChatViewModel() {
        // Create RTC engine and RTM client during initialization
        Log.d(TAG, "Initializing RTC engine and RTM client...");
        // Init RTC engine
        initRtcEngine();
        // Init RTM client
        initRtmClient();
        if (rtcEngine != null && rtmClient != null) {
            conversationalAIAPI = new ConversationalAIAPIImpl(
                    new ConversationalAIAPIConfig(
                            rtcEngine,
                            rtmClient,
                            TranscriptRenderMode.Word,
                            true // enableLog
                    )
            );
            conversationalAIAPI.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT);
            conversationalAIAPI.addHandler(conversationalAIAPIEventHandler);
            Log.d(TAG, "RTC engine and RTM client created successfully");
        } else {
            Log.e(TAG, "Failed to create RTC engine or RTM client");
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                _uiState.setValue(currentState.copy(false, ConnectionState.Error));
            }
        }
    }

    /**
     * Init RTC engine
     */
    private void initRtcEngine() {
        if (rtcEngine != null) {
            return;
        }
        RtcEngineConfig config = new RtcEngineConfig();
        config.mContext = AgentApp.instance();
        config.mAppId = KeyCenter.APP_ID;
        config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING;
        config.mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT;
        config.mEventHandler = rtcEventHandler;
        try {
            rtcEngine = (RtcEngineEx) RtcEngine.create(config);
            rtcEngine.enableVideo();
            // Load extension provider for AI-QoS
            rtcEngine.loadExtensionProvider("ai_echo_cancellation_extension");
            rtcEngine.loadExtensionProvider("ai_noise_suppression_extension");
            Log.d(TAG, "initRtcEngine success");
            Log.d(TAG, "current sdk version: " + RtcEngine.getSdkVersion());
            addStatusLog("RtcEngine init successfully");
        } catch (Exception e) {
            Log.e(TAG, "initRtcEngine error: " + e.getMessage(), e);
            addStatusLog("RtcEngine init failed");
        }
    }

    /**
     * Init RTM client
     */
    private void initRtmClient() {
        if (rtmClient != null) {
            return;
        }

        RtmConfig rtmConfig = new RtmConfig.Builder(KeyCenter.APP_ID, String.valueOf(userId)).build();
        try {
            rtmClient = RtmClient.create(rtmConfig);
            rtmClient.addEventListener(rtmEventListener);
            Log.d(TAG, "RTM initRtmClient successfully");
            addStatusLog("RtmClient init successfully");
        } catch (Exception e) {
            Log.e(TAG, "RTM initRtmClient error: " + e.getMessage(), e);
            e.printStackTrace();
            addStatusLog("RtmClient init failed");
        }
    }

    /**
     * Login RTM
     */
    private void loginRtm(String rtmToken, LoginCallback callback) {
        Log.d(TAG, "Starting RTM login");

        if (isLoggingIn) {
            callback.onResult(new Exception("Login already in progress"));
            Log.d(TAG, "Login already in progress");
            return;
        }

        if (isRtmLogin) {
            callback.onResult(null); // Already logged in
            Log.d(TAG, "Already logged in");
            return;
        }

        if (rtmClient == null) {
            callback.onResult(new Exception("RTM client not initialized"));
            Log.d(TAG, "RTM client not initialized");
            return;
        }

        isLoggingIn = true;
        Log.d(TAG, "Performing logout to ensure clean environment before login");

        // Force logout first (synchronous flag update)
        isRtmLogin = false;
        rtmClient.logout(new ResultCallback<Void>() {
            @Override
            public void onSuccess(Void responseInfo) {
                Log.d(TAG, "Logout completed, starting login");
                performRtmLogin(rtmClient, rtmToken, callback);
            }

            @Override
            public void onFailure(ErrorInfo errorInfo) {
                Log.d(TAG, "Logout failed but continuing with login: " + (errorInfo != null ? errorInfo.getErrorReason() : "Unknown"));
                performRtmLogin(rtmClient, rtmToken, callback);
            }
        });
    }

    private void performRtmLogin(RtmClient client, String rtmToken, LoginCallback callback) {
        client.login(rtmToken, new ResultCallback<Void>() {
            @Override
            public void onSuccess(Void p0) {
                isRtmLogin = true;
                isLoggingIn = false;
                Log.d(TAG, "RTM login successful");
                callback.onResult(null);
                addStatusLog("Rtm login successful");
            }

            @Override
            public void onFailure(ErrorInfo errorInfo) {
                isRtmLogin = false;
                isLoggingIn = false;
                Log.e(TAG, "RTM token login failed: " + (errorInfo != null ? errorInfo.getErrorReason() : "Unknown"));
                callback.onResult(new Exception(String.valueOf(errorInfo != null ? errorInfo.getErrorCode() : "Unknown")));
                addStatusLog("Rtm login failed, code: " + (errorInfo != null ? errorInfo.getErrorCode() : "Unknown"));
            }
        });
    }

    /**
     * Logout RTM
     */
    private void logoutRtm() {
        Log.d(TAG, "RTM start logout");
        if (rtmClient != null) {
            rtmClient.logout(new ResultCallback<Void>() {
                @Override
                public void onSuccess(Void responseInfo) {
                    isRtmLogin = false;
                    Log.d(TAG, "RTM logout successful");
                }

                @Override
                public void onFailure(ErrorInfo errorInfo) {
                    Log.e(TAG, "RTM logout failed: " + (errorInfo != null ? errorInfo.getErrorCode() : "Unknown"));
                    // Still mark as logged out since we attempted logout
                    isRtmLogin = false;
                }
            });
        }
    }

    /**
     * Join RTC channel
     */
    private void joinRtcChannel(String rtcToken, String channelName, int uid) {
        Log.d(TAG, "joinChannel channelName: " + channelName + ", localUid: " + uid);
        // Join RTC channel
        ChannelMediaOptions channelOptions = new ChannelMediaOptions();
        channelOptions.clientRoleType = Constants.CLIENT_ROLE_BROADCASTER;
        channelOptions.publishMicrophoneTrack = true;
        channelOptions.publishCameraTrack = false;
        channelOptions.autoSubscribeAudio = true;
        channelOptions.autoSubscribeVideo = true;

        if (rtcEngine != null) {
            int ret = rtcEngine.joinChannel(rtcToken, channelName, uid, channelOptions);
            Log.d(TAG, "Joining RTC channel: " + channelName + ", uid: " + uid);
            if (ret == Constants.ERR_OK) {
                Log.d(TAG, "Join RTC room success");
            } else {
                Log.e(TAG, "Join RTC room failed, ret: " + ret);
                addStatusLog("Rtc joinChannel failed ret: " + ret);
            }
        }
    }

    /**
     * Leave RTC channel
     */
    private void leaveRtcChannel() {
        Log.d(TAG, "leaveChannel");
        if (rtcEngine != null) {
            rtcEngine.leaveChannel();
        }
    }

    /**
     * Mute local audio
     */
    private void muteLocalAudio(boolean mute) {
        Log.d(TAG, "muteLocalAudio " + mute);
        if (rtcEngine != null) {
            rtcEngine.adjustRecordingSignalVolume(mute ? 0 : 100);
        }
    }

    /**
     * Check if both RTC and RTM are connected, then start agent
     */
    private void checkJoinAndLoginComplete() {
        if (rtcJoined && rtmLoggedIn) {
            startAgent();
        }
    }

    /**
     * Callback interface for token generation
     */
    private interface TokenCallback {
        void onSuccess(String token);
        void onFailure(Exception e);
    }

    /**
     * Callback interface for RTM login
     */
    private interface LoginCallback {
        void onResult(Exception exception);
    }

    /**
     * Generate unified token for RTC and RTM
     */
    private void generateUserToken(TokenCallback callback) {
        TokenGenerator.generateTokens(
                "", // Empty channel name for wildcard token
                String.valueOf(userId),
                new TokenGenerator.AgoraTokenType[]{TokenGenerator.AgoraTokenType.RTC, TokenGenerator.AgoraTokenType.RTM},
                token -> {
                    unifiedToken = token;
                    addStatusLog("Generate user token successfully");
                    callback.onSuccess(token);
                },
                exception -> {
                    ConversationUiState currentState = _uiState.getValue();
                    if (currentState != null) {
                        _uiState.setValue(currentState.copy(false, ConnectionState.Error));
                    }
                    addStatusLog("Generate user token failed");
                    Log.e(TAG, "Failed to get token: " + exception.getMessage(), exception);
                    callback.onFailure(exception);
                }
        );
    }

    /**
     * Start agent (called automatically after RTC and RTM are connected)
     */
    public void startAgent() {
        if (agentId != null) {
            Log.d(TAG, "Agent already started, agentId: " + agentId);
            return;
        }

        if (channelName == null || channelName.isEmpty()) {
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                _uiState.setValue(currentState.copy(false, ConnectionState.Error));
            }
            Log.e(TAG, "Channel name is empty, cannot start agent");
            return;
        }

        addStatusLog("Generating agent token...");

        TokenGenerator.generateTokens(
                channelName,
                String.valueOf(agentUid),
                new TokenGenerator.AgoraTokenType[]{TokenGenerator.AgoraTokenType.RTC, TokenGenerator.AgoraTokenType.RTM},
                agentToken -> {
                    mainHandler.post(() -> {
                        addStatusLog("Generate agent token successfully");
                        addStatusLog("Generating auth token...");

                        TokenGenerator.generateTokens(
                                channelName,
                                String.valueOf(agentUid),
                                new TokenGenerator.AgoraTokenType[]{TokenGenerator.AgoraTokenType.RTC, TokenGenerator.AgoraTokenType.RTM},
                                restAuthToken -> {
                                    mainHandler.post(() -> {
                                        authToken = restAuthToken;
                                        addStatusLog("Generate auth token successfully");
                                        addStatusLog("Starting agent...");

                                        AgentStarter.startAgentAsync(
                                                channelName,
                                                String.valueOf(agentUid),
                                                agentToken,
                                                restAuthToken,
                                                String.valueOf(userId),
                                                new AgentStarter.AgentStartCallback() {
                                                    @Override
                                                    public void onSuccess(String agentId) {
                                                        mainHandler.post(() -> {
                                                            AgentChatViewModel.this.agentId = agentId;
                                                            ConversationUiState state = _uiState.getValue();
                                                            if (state != null) {
                                                                _uiState.setValue(state.copy(false, ConnectionState.Connected));
                                                            }
                                                            addStatusLog("Agent start successfully");
                                                            Log.d(TAG, "Agent started successfully, agentId: " + agentId);
                                                        });
                                                    }

                                                    @Override
                                                    public void onFailure(Exception e) {
                                                        mainHandler.post(() -> {
                                                            ConversationUiState state = _uiState.getValue();
                                                            if (state != null) {
                                                                _uiState.setValue(state.copy(false, ConnectionState.Error));
                                                            }
                                                            addStatusLog("Agent start failed");
                                                            Log.e(TAG, "Failed to start agent: " + e.getMessage(), e);
                                                        });
                                                    }
                                                }
                                        );
                                    });
                                },
                                e -> {
                                    mainHandler.post(() -> {
                                        ConversationUiState state = _uiState.getValue();
                                        if (state != null) {
                                            _uiState.setValue(state.copy(false, ConnectionState.Error));
                                        }
                                        addStatusLog("Generate auth token failed");
                                        Log.e(TAG, "Failed to generate auth token: " + e.getMessage(), e);
                                    });
                                }
                        );
                    });
                },
                e -> {
                    mainHandler.post(() -> {
                        ConversationUiState state = _uiState.getValue();
                        if (state != null) {
                            _uiState.setValue(state.copy(false, ConnectionState.Error));
                        }
                        addStatusLog("Generate agent token failed");
                        Log.e(TAG, "Failed to generate agent token: " + e.getMessage(), e);
                    });
                }
        );
    }

    /**
     * Join RTC channel and login RTM
     * @param channelName Channel name to join
     */
    public void joinChannelAndLogin(String channelName) {
        try {
            if (channelName == null || channelName.isEmpty()) {
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    _uiState.setValue(currentState.copy(false, ConnectionState.Idle));
                }
                Log.e(TAG, "Channel name is empty, cannot join channel");
                return;
            }

            this.channelName = channelName;
            rtcJoined = false;
            rtmLoggedIn = false;
            authToken = null;

            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                _uiState.setValue(currentState.copy(false, ConnectionState.Connecting));
            }

            // Get token if not available, otherwise use existing token
            if (unifiedToken == null || unifiedToken.isEmpty()) {
                generateUserToken(new TokenCallback() {
                    @Override
                    public void onSuccess(String token) {
                        mainHandler.post(() -> {
                            // Join RTC channel with the unified token
                            joinRtcChannel(token, channelName, userId);

                            // Login RTM with the same unified token
                            loginRtm(token, exception -> {
                                mainHandler.post(() -> {
                                    if (exception == null) {
                                        rtmLoggedIn = true;
                                        if (conversationalAIAPI != null) {
                                            conversationalAIAPI.subscribeMessage(channelName, errorInfo -> {
                                                if (errorInfo != null) {
                                                    Log.e(TAG, "Subscribe message error: " + errorInfo);
                                                }
                                                return Unit.INSTANCE;
                                            });
                                        }
                                        checkJoinAndLoginComplete();
                                    } else {
                                        ConversationUiState state = _uiState.getValue();
                                        if (state != null) {
                                            _uiState.setValue(state.copy(false, ConnectionState.Error));
                                        }
                                        Log.e(TAG, "RTM login failed: " + exception.getMessage(), exception);
                                    }
                                });
                            });
                        });
                    }

                    @Override
                    public void onFailure(Exception e) {
                        mainHandler.post(() -> {
                            ConversationUiState currentState1 = _uiState.getValue();
                            if (currentState1 != null) {
                                _uiState.setValue(currentState1.copy(false, ConnectionState.Error));
                            }
                            Log.e(TAG, "Failed to get token: " + e.getMessage(), e);
                        });
                    }
                });
            } else {
                // Use existing token
                mainHandler.post(() -> {
                    // Join RTC channel with the unified token
                    joinRtcChannel(unifiedToken, channelName, userId);

                    // Login RTM with the same unified token
                    loginRtm(unifiedToken, exception -> {
                        mainHandler.post(() -> {
                            if (exception == null) {
                                rtmLoggedIn = true;
                                if (conversationalAIAPI != null) {
                                    conversationalAIAPI.subscribeMessage(channelName, errorInfo -> {
                                        if (errorInfo != null) {
                                            Log.e(TAG, "Subscribe message error: " + errorInfo);
                                        }
                                        return Unit.INSTANCE;
                                    });
                                }
                                checkJoinAndLoginComplete();
                            } else {
                                ConversationUiState state = _uiState.getValue();
                                if (state != null) {
                                    _uiState.setValue(state.copy(false, ConnectionState.Error));
                                }
                                Log.e(TAG, "RTM login failed: " + exception.getMessage(), exception);
                            }
                        });
                    });
                });
            }
        } catch (Exception e) {
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                _uiState.setValue(currentState.copy(false, ConnectionState.Error));
            }
            Log.e(TAG, "Error joining channel/login: " + e.getMessage(), e);
        }
    }

    /**
     * Toggle microphone mute state
     */
    public void toggleMute() {
        ConversationUiState currentState = _uiState.getValue();
        if (currentState != null) {
            boolean newMuteState = !currentState.isMuted;
            _uiState.setValue(currentState.copy(newMuteState, currentState.connectionState));
            muteLocalAudio(newMuteState);
            Log.d(TAG, "Microphone muted: " + newMuteState);
        }
    }

    /**
     * Add a new transcript to the list
     */
    public void addTranscript(Transcript transcript) {
        mainHandler.post(() -> {
            List<Transcript> currentList = new ArrayList<>(_transcriptList.getValue() != null ? _transcriptList.getValue() : new ArrayList<>());
            // Update existing transcript if same turnId, otherwise add new
            int existingIndex = -1;
            for (int i = 0; i < currentList.size(); i++) {
                Transcript t = currentList.get(i);
                if (t.getTurnId() == transcript.getTurnId() && t.getType() == transcript.getType()) {
                    existingIndex = i;
                    break;
                }
            }
            if (existingIndex >= 0) {
                currentList.set(existingIndex, transcript);
            } else {
                currentList.add(transcript);
            }
            _transcriptList.setValue(currentList);
        });
    }

    /**
     * Add a status message to debug log list
     * This is used to track ViewModel state changes
     */
    private void addStatusLog(String message) {
        if (message == null || message.isEmpty()) {
            return;
        }
        mainHandler.post(() -> {
            List<String> currentLogs = new ArrayList<>(_debugLogList.getValue() != null ? _debugLogList.getValue() : new ArrayList<>());
            currentLogs.add(message);
            // Keep only last 20 logs to avoid memory issues
            if (currentLogs.size() > 20) {
                currentLogs.remove(0);
            }
            _debugLogList.setValue(currentLogs);
        });
    }

    public void clearAgentErrorEvent() {
        _agentErrorEvent.setValue(null);
    }

    /**
     * Hang up and cleanup connections
     */
    public void hangup() {
        try {
            if (conversationalAIAPI != null && channelName != null && !channelName.isEmpty()) {
                conversationalAIAPI.unsubscribeMessage(channelName, errorInfo -> {
                    if (errorInfo != null) {
                        Log.e(TAG, "Unsubscribe message error: " + errorInfo);
                    }
                    return Unit.INSTANCE;
                });
            }

            // Stop agent if it was started
            if (agentId != null) {
                AgentStarter.stopAgentAsync(
                        agentId,
                        authToken != null ? authToken : "",
                        new AgentStarter.AgentStopCallback() {
                            @Override
                            public void onSuccess() {
                                mainHandler.post(() -> {
                                    Log.d(TAG, "Agent stopped successfully");
                                    addStatusLog("Agent stopped successfully");
                                });
                            }

                            @Override
                            public void onFailure(Exception e) {
                                mainHandler.post(() -> {
                                    Log.e(TAG, "Failed to stop agent: " + e.getMessage(), e);
                                });
                            }
                        }
                );
                agentId = null;
            }

            leaveRtcChannel();
            rtcJoined = false;
            authToken = null;
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                _uiState.setValue(currentState.copy(false, ConnectionState.Idle));
            }
            _transcriptList.setValue(new ArrayList<>());
            _agentState.setValue(AgentState.IDLE);
            Log.d(TAG, "Hangup completed");
        } catch (Exception e) {
            Log.e(TAG, "Error during hangup: " + e.getMessage(), e);
        }
    }

    @Override
    protected void onCleared() {
        super.onCleared();
        leaveRtcChannel();
        logoutRtm();

        // Cleanup RTM client
        if (rtmClient != null) {
            try {
                rtmClient.removeEventListener(rtmEventListener);
            } catch (Exception e) {
                Log.e(TAG, "Error removing RTM event listener: " + e.getMessage());
            }
        }

        // Note: RtcEngine.destroy() should be called carefully as it's a global operation
        // Consider managing RTC engine lifecycle at Application level
        rtcEngine = null;
        rtmClient = null;
    }
}

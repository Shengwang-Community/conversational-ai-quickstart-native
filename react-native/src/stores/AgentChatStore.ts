import { create } from 'zustand';
import { InteractionManager } from 'react-native';
// RTC SDK: https://github.com/AgoraIO-Extensions/react-native-agora
import {
  createAgoraRtcEngine,
  AudioRoute,
  AudioScenarioType,
  IRtcEngineEventHandler,
  ChannelMediaOptions,
  RtcConnection,
  RtcStats,
} from 'react-native-agora';
import {
  ConnectionState,
  AgentState,
  Transcript,
  TranscriptType,
  TranscriptStatus,
} from '../types';
import { generateRandomChannelName } from '../utils/ChannelNameGenerator';
import { TokenGenerator } from '../api/TokenGenerator';
import { AgentStarter } from '../api/AgentStarter';
import { MessageParser } from '../utils/MessageParser';

interface AgentChatStore {
  // State
  connectionState: ConnectionState;
  agentState: AgentState;
  isMuted: boolean;
  transcripts: Transcript[];
  logs: string[];
  agentId: string | null;

  // Actions
  setConnectionState: (state: ConnectionState) => void;
  setAgentState: (state: AgentState) => void;
  setIsMuted: (muted: boolean) => void;
  addTranscript: (transcript: Transcript) => void;
  addLog: (message: string) => void;
  resetState: () => void;

  // Business logic
  initRtcEngine: () => Promise<void>;
  startConnection: () => Promise<void>;
  stopAgent: () => Promise<void>;
  toggleMute: () => void;
}

const MIN_UID = 100000;
const UID_RANGE = 900000;

function generateRandomUid(): number {
  return Math.floor(Math.random() * UID_RANGE) + MIN_UID;
}

function generateUniqueUid(excludeUid: number): number {
  let uid = generateRandomUid();

  while (uid === excludeUid) {
    uid = generateRandomUid();
  }

  return uid;
}

export const useAgentChatStore = create<AgentChatStore>((set, get) => {
  // RTC 实例直接在 Store 中管理（参考 Android Kotlin 实现）
  let rtcEngine: any | null = null;
  let rtcJoined = false;
  let channelName = '';
  let authToken: string | null = null;
  let dataStreamId = 0;
  const userId = generateRandomUid();
  const agentRtcUid = generateUniqueUid(userId);
  const messageParser = new MessageParser();

  // 设置消息解析错误回调（只输出到控制台，不显示在 UI 上）
  messageParser.setOnError((error) => {
    console.log(`[MessageParser] ${error}`);
  });

  const asInt = (value: unknown): number | null => {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return Math.trunc(value);
    }
    if (typeof value === 'string') {
      const parsed = Number.parseInt(value, 10);
      return Number.isNaN(parsed) ? null : parsed;
    }
    return null;
  };

  const handleAgentError = (message: Record<string, unknown>) => {
    const module = (message['module'] as string | undefined) || 'unknown';
    const code = asInt(message['code']) ?? -1;
    const errorMessage =
      (message['message'] as string | undefined) || 'Unknown error';
    const turnId = asInt(message['turn_id']);
    const sendTs = asInt(message['send_ts']);

    get().addLog(
      `Agent error: type=${module}, code=${code}, msg=${errorMessage}`,
    );

    console.log(
      `[handleParsedMessage] message.error: module=${module}, code=${code}, message=${errorMessage}, turnId=${turnId ?? 'n/a'}, sendTs=${sendTs ?? 'n/a'}`,
    );
  };

  const ensureRtcCallSucceeded = (
    methodName: string,
    result: unknown,
  ): void => {
    if (typeof result === 'number' && result < 0) {
      throw new Error(`${methodName} failed: ${result}`);
    }
  };

  const isHeadsetStyleRoute = (routing: number): boolean => {
    return (
      routing === AudioRoute.RouteHeadset ||
      routing === AudioRoute.RouteEarpiece ||
      routing === AudioRoute.RouteHeadsetnomic ||
      routing === AudioRoute.RouteBluetoothDeviceHfp ||
      routing === AudioRoute.RouteBluetoothDeviceA2dp
    );
  };

  const getAudioRouteLabel = (routing: number): string => {
    switch (routing) {
      case AudioRoute.RouteHeadset:
        return 'headset';
      case AudioRoute.RouteEarpiece:
        return 'earpiece';
      case AudioRoute.RouteHeadsetnomic:
        return 'headset-no-mic';
      case AudioRoute.RouteSpeakerphone:
        return 'speakerphone';
      case AudioRoute.RouteLoudspeaker:
        return 'loudspeaker';
      case AudioRoute.RouteBluetoothDeviceHfp:
        return 'bluetooth-hfp';
      case AudioRoute.RouteBluetoothDeviceA2dp:
        return 'bluetooth-a2dp';
      case AudioRoute.RouteUsb:
        return 'usb';
      case AudioRoute.RouteHdmi:
        return 'hdmi';
      case AudioRoute.RouteDisplayport:
        return 'displayport';
      case AudioRoute.RouteAirplay:
        return 'airplay';
      case AudioRoute.RouteDefault:
      default:
        return `route-${routing}`;
    }
  };

  const applyRtcAudioRouteParameters = async (routing: number) => {
    if (!rtcEngine) {
      return;
    }

    ensureRtcCallSucceeded(
      'setParameters che.audio.aec.split_srate_for_48k',
      rtcEngine.setParameters('{"che.audio.aec.split_srate_for_48k":16000}'),
    );
    ensureRtcCallSucceeded(
      'setParameters che.audio.sf.enabled',
      rtcEngine.setParameters('{"che.audio.sf.enabled":true}'),
    );
    ensureRtcCallSucceeded(
      'setParameters che.audio.sf.stftType',
      rtcEngine.setParameters('{"che.audio.sf.stftType":6}'),
    );
    ensureRtcCallSucceeded(
      'setParameters che.audio.sf.ainlpLowLatencyFlag',
      rtcEngine.setParameters('{"che.audio.sf.ainlpLowLatencyFlag":1}'),
    );
    ensureRtcCallSucceeded(
      'setParameters che.audio.sf.ainsLowLatencyFlag',
      rtcEngine.setParameters('{"che.audio.sf.ainsLowLatencyFlag":1}'),
    );
    ensureRtcCallSucceeded(
      'setParameters che.audio.sf.procChainMode',
      rtcEngine.setParameters('{"che.audio.sf.procChainMode":1}'),
    );
    ensureRtcCallSucceeded(
      'setParameters che.audio.sf.nlpDynamicMode',
      rtcEngine.setParameters('{"che.audio.sf.nlpDynamicMode":1}'),
    );
    ensureRtcCallSucceeded(
      'setParameters che.audio.sf.nlpAlgRoute',
      rtcEngine.setParameters(
        `{"che.audio.sf.nlpAlgRoute":${isHeadsetStyleRoute(routing) ? 0 : 1}}`,
      ),
    );
  };

  const applyRtcAudioBestPractices = async () => {
    if (!rtcEngine) {
      return;
    }

    ensureRtcCallSucceeded('enableAudio', rtcEngine.enableAudio());
    ensureRtcCallSucceeded(
      'setAudioScenario',
      rtcEngine.setAudioScenario(AudioScenarioType.AudioScenarioAiClient),
    );
    await applyRtcAudioRouteParameters(AudioRoute.RouteSpeakerphone);
  };

  const handleAudioRoutingChanged = async (routing: number) => {
    try {
      await applyRtcAudioRouteParameters(routing);
      get().addLog(`RTC audio routing changed: ${getAudioRouteLabel(routing)}`);
    } catch (error: any) {
      const errorMessage = error?.message || String(error);
      get().addLog(`RTC audio routing config failed: ${errorMessage}`);
    }
  };

  // 处理解析后的消息
  // 根据文档，消息类型通过 message['object'] 字段获取
  // 消息类型：assistant.transcription, user.transcription, message.interrupt,
  // message.state, message.error
  // 注意：此函数的日志只输出到控制台，不显示在 UI 上
  const handleParsedMessage = (message: Record<string, any>) => {
    try {
      // 获取消息类型（从 'object' 字段）
      const messageType = message['object'] as string | undefined;
      
      // Log received message type (console only, not UI)
      console.log(`[handleParsedMessage] Received message type: ${messageType || 'unknown'}`);
      
      if (!messageType) {
        // 消息没有 'object' 字段，记录日志并忽略
        console.log(`[handleParsedMessage] Message without 'object' key: ${JSON.stringify(message)}`);
        return;
      }

      // 根据消息类型处理
      // Reference: harmonyos/entry/src/main/ets/convoaiApi/TranscriptController.ets
      if (messageType === 'assistant.transcription') {
        // Agent 转录消息
        const text = (message['text'] as string) || '';
        const turnId = (message['turn_id'] as number) ?? 0;
        const userId = (message['user_id'] as string) || '';
        const turnStatusInt = (message['turn_status'] as number) ?? 0;
        // 0: in-progress, 1: end gracefully, 2: interrupted
        let status: TranscriptStatus;
        switch (turnStatusInt) {
          case 0:
            status = TranscriptStatus.IN_PROGRESS;
            break;
          case 1:
            status = TranscriptStatus.END;
            break;
          case 2:
            status = TranscriptStatus.INTERRUPTED;
            break;
          default:
            status = TranscriptStatus.UNKNOWN;
        }
        
        if (text.length === 0) {
          console.log(`[handleParsedMessage] assistant.transcription: empty text, ignored`);
          return;
        }
        
        // Discard messages with Unknown status
        if (status === TranscriptStatus.UNKNOWN) {
          console.log(`[handleParsedMessage] assistant.transcription: unknown turn_status:${turnStatusInt}`);
          return;
        }
        
        console.log(`[handleParsedMessage] assistant.transcription: turnId=${turnId}, text="${text}", status=${status}, turnStatus=${turnStatusInt}`);
        
        const transcript: Transcript = {
          turnId: turnId,
          userId: userId,
          text: text,
          status: status,
          type: TranscriptType.AGENT,
        };
        get().addTranscript(transcript);
      } else if (messageType === 'user.transcription') {
        // 用户转录消息
        const text = (message['text'] as string) || '';
        const turnId = (message['turn_id'] as number) ?? 0;
        const userId = (message['user_id'] as string) || '';
        const isFinal = (message['final'] as boolean) || false;
        const status = isFinal ? TranscriptStatus.END : TranscriptStatus.IN_PROGRESS;
        
        if (text.length === 0) {
          console.log(`[handleParsedMessage] user.transcription: empty text, ignored`);
          return;
        }
        
        console.log(`[handleParsedMessage] user.transcription: turnId=${turnId}, text="${text}", status=${status}, isFinal=${isFinal}`);
        
        const transcript: Transcript = {
          turnId: turnId,
          userId: userId,
          text: text,
          status: status,
          type: TranscriptType.USER,
        };
        get().addTranscript(transcript);
      } else if (messageType === 'message.interrupt') {
        // 中断消息
        const turnId = (message['turn_id'] as number) ?? 0;
        console.log(`[handleParsedMessage] message.interrupt: turnId=${turnId}`);
        // TODO: 处理中断事件，更新被中断的转录状态
      } else if (messageType === 'message.state') {
        // Agent 状态更新消息
        const state = (message['state'] as string) || '';
        console.log(`[handleParsedMessage] message.state: state=${state}`);
        
        if (state === 'idle') {
          set({ agentState: AgentState.IDLE });
        } else if (state === 'silent') {
          set({ agentState: AgentState.SILENT });
        } else if (state === 'listening') {
          set({ agentState: AgentState.LISTENING });
        } else if (state === 'thinking') {
          set({ agentState: AgentState.THINKING });
        } else if (state === 'speaking') {
          set({ agentState: AgentState.SPEAKING });
        } else {
          console.log(`[handleParsedMessage] message.state: unknown state value: ${state}`);
        }
      } else if (messageType === 'message.error') {
        handleAgentError(message);
      } else {
        // 未知消息类型
        console.log(`[handleParsedMessage] Unknown message type: ${messageType}, full message: ${JSON.stringify(message)}`);
      }
    } catch (error: any) {
      console.log(`[handleParsedMessage] error: ${error?.message || error}`);
    }
  };

  // 内部方法：启动 Agent（在 DataStream 创建成功后调用）
  const startAgentInternal = async () => {
    try {
      if (get().agentId) {
        return;
      }

      let agentToken: string;
      let nextAuthToken: string;
      try {
        agentToken = await TokenGenerator.generateUnifiedToken({
          channelName,
          uid: agentRtcUid.toString(),
        });
        get().addLog(`Generate agent token successfully`);
      } catch (error: any) {
        const errorMessage = error?.message || String(error);
        get().addLog(`Generate agent token failed: ${errorMessage}`);
        throw error;
      }

      try {
        nextAuthToken = await TokenGenerator.generateUnifiedToken({
          channelName,
          uid: userId.toString(),
        });
        get().addLog(`Generate REST auth token successfully`);
      } catch (error: any) {
        const errorMessage = error?.message || String(error);
        get().addLog(`Generate REST auth token failed: ${errorMessage}`);
        throw error;
      }

      try {
        const agentId = await AgentStarter.startAgentAsync({
          channelName,
          agentRtcUid: agentRtcUid.toString(),
          agentToken,
          authToken: nextAuthToken,
          remoteRtcUid: userId.toString(),
          messageTransport: 'datastream',
        });

        authToken = nextAuthToken;
        set({
          agentId,
          connectionState: ConnectionState.Connected,
        });
        get().addLog(`Agent start successfully`);
      } catch (error: any) {
        get().addLog(`Agent start failed`);
        throw error;
      }
    } catch (error: any) {
      set({ connectionState: ConnectionState.Error });
      throw error;
    }
  };

  // RTC 事件处理器
  // 注意：react-native-agora 4.x 版本的 API 可能有所不同，需要根据实际 SDK 文档调整
  const rtcEventHandler: Partial<IRtcEngineEventHandler> = {
    onJoinChannelSuccess: (connection: RtcConnection, elapsed: number) => {
      rtcJoined = true;
      const channel = connection?.channelId || 'unknown';
      const uid = connection?.localUid || 0;
      get().addLog(`Rtc onJoinChannelSuccess, channel:${channel} uid:${uid}`);
      
      // 创建 DataStream
      if (rtcEngine && dataStreamId === 0) {
        try {
          const streamId = rtcEngine.createDataStream(false, true);
          dataStreamId = streamId;
          console.log(`RTC DataStream created, streamId: ${streamId}`);
          
          // DataStream 创建成功后，启动 Agent
          startAgentInternal();
        } catch (error: any) {
          console.log(`RTC createDataStream failed: ${error?.message || error}`);
          set({ connectionState: ConnectionState.Error });
        }
      }
    },
    onUserJoined: (connection: RtcConnection, remoteUid: number, elapsed: number) => {
      get().addLog(`Rtc onUserJoined, uid:${remoteUid}`);
    },
    onUserOffline: (connection: RtcConnection, remoteUid: number, reason: any) => {
      get().addLog(`Rtc onUserOffline, uid:${remoteUid}`);
    },
    onAudioRoutingChanged: (routing: number) => {
      void handleAudioRoutingChanged(routing);
    },
    onError: (err: number, msg: string) => {
      set({ connectionState: ConnectionState.Error });
      get().addLog(`Rtc onError: ${err}`);
    },
    onLeaveChannel: (connection: RtcConnection, stats: RtcStats) => {
      rtcJoined = false;
      dataStreamId = 0;
      get().addLog(`Rtc onLeaveChannel`);
    },
    onStreamMessage: (connection: RtcConnection, remoteUid: number, streamId: number, data: Uint8Array, length: number, sentTs: number) => {
      
      // Copy data immediately to avoid data being released before async processing
      // Process message parsing in async task to avoid blocking RTC callback thread
      // Reference: HarmonyOS and Android implementations use background threads for message parsing
      const dataCopy = new Uint8Array(data);
      
      // Step 1: Parse message in async task (non-blocking)
      setTimeout(() => {
        try {
          // Convert Uint8Array to string
          // React Native: convert Uint8Array to UTF-8 string
          let messageString = '';
          for (let i = 0; i < dataCopy.length; i++) {
            messageString += String.fromCharCode(dataCopy[i]);
          }
          
          // Parse message (may be split into multiple parts)
          const parsedMessage = messageParser.parseStreamMessage(messageString);
          
          if (parsedMessage) {
            console.log(`[onStreamMessage] Message parsed successfully: ${JSON.stringify(parsedMessage)}`);
            
            // Step 2: Update UI on main thread using InteractionManager
            // This ensures state updates (Zustand) happen on the main JavaScript thread
            // Reference: Android uses Handler.post() to main thread, HarmonyOS uses runOnMainThread()
            // React Native: Use InteractionManager to ensure UI updates happen on main thread
            InteractionManager.runAfterInteractions(() => {
              handleParsedMessage(parsedMessage);
            });
          } else {
            console.log(`[onStreamMessage] Message parsing returned null (message may be incomplete or split into multiple parts)`);
          }
        } catch (error: any) {
          console.log(`[onStreamMessage] error: ${error?.message || error}`);
        }
      }, 0);
    },
  };

  // 初始化 RTC 引擎
  const initRtcEngine = async () => {
    if (rtcEngine) {
      console.log(`RtcEngine already initialized`);
      return;
    }

    try {
      console.log(`RtcEngine initializing...`);
      rtcEngine = createAgoraRtcEngine();
      rtcEngine.initialize({ appId: KeyCenter.APP_ID });
      rtcEngine.registerEventHandler(rtcEventHandler);
      get().addLog(`RtcEngine init successfully`);
    } catch (error: any) {
      const errorMessage = error?.message || String(error);
      get().addLog(`RtcEngine init failed: ${errorMessage}`);
      set({ connectionState: ConnectionState.Error });
    }
  };

  return {
    // Initial state
    connectionState: ConnectionState.Idle,
    agentState: AgentState.IDLE,
    isMuted: false,
    transcripts: [],
    logs: [],
    agentId: null,

    // Actions
    setConnectionState: (state) => set({ connectionState: state }),
    setAgentState: (state) => set({ agentState: state }),
    setIsMuted: (muted) => set({ isMuted: muted }),
    addTranscript: (transcript) => {
      // Reference: harmonyos/entry/src/main/ets/pages/AgentChatController.ets:456-480
      // If type and turnId are the same, it's the same sentence (should be updated, not added)
      set((state) => {
        const existingIndex = state.transcripts.findIndex(
          (t) => t.turnId === transcript.turnId && t.type === transcript.type
        );
        
        if (existingIndex >= 0) {
          // Update existing transcript (same type and turnId)
          const newTranscripts = [...state.transcripts];
          newTranscripts[existingIndex] = transcript;
          return { transcripts: newTranscripts };
        } else {
          // Add new transcript (different type or turnId)
          return { transcripts: [...state.transcripts, transcript] };
        }
      });
    },
    addLog: (message) => {
      // Also log to console for debugging
      console.log(message);
      set((state) => {
        const nextLogs =
          state.logs.length >= 20
            ? [...state.logs.slice(-19), message]
            : [...state.logs, message];

        return { logs: nextLogs };
      });
    },
    resetState: () => {
      authToken = null;
      channelName = '';
      set({
        connectionState: ConnectionState.Idle,
        agentState: AgentState.IDLE,
        isMuted: false,
        transcripts: [],
        logs: [],
        agentId: null,
      });
    },

    // Initialize RTC engine when store is first accessed
    initRtcEngine: async () => {
      await initRtcEngine();
    },

    // Business logic
    startConnection: async () => {
      try {
        // 检查是否已经在连接中
        if (get().connectionState === ConnectionState.Connecting) {
          return;
        }

        set({ connectionState: ConnectionState.Connecting });
        authToken = null;

        // 步骤 1: 生成随机 Channel Name
        channelName = generateRandomChannelName('reactnative');

        // 确保 RTC 引擎已初始化
        if (!rtcEngine) {
          await initRtcEngine();
        }
        if (!rtcEngine) {
          console.log('RTC 引擎初始化失败');
        }

        await applyRtcAudioBestPractices();

        let userToken: string;
        try {
          userToken = await TokenGenerator.generateUnifiedToken({
            channelName,
            uid: userId,
          });
          get().addLog(`Generate user token successfully`);
        } catch (error: any) {
          const errorMessage = error?.message || String(error);
          get().addLog(`Generate user token failed: ${errorMessage}`);
          throw error;
        }

        get().addLog(
          `Using RTC UIDs user=${userId}, agent=${agentRtcUid}`,
        );

        // 步骤 3: 加入 RTC 频道
        rtcJoined = false;
        dataStreamId = 0;
        const channelOptions: ChannelMediaOptions = {
          clientRoleType: 1, // CLIENT_ROLE_BROADCASTER = 1
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: false,
        };

        try {
          await rtcEngine.joinChannel(
            userToken,
            channelName,
            userId,
            channelOptions
          );
        } catch (error: any) {
          const errCode = error?.code || error?.err || 'unknown';
          const errorMessage = error?.message || String(error);
          get().addLog(`Rtc joinChannel failed ret: ${errCode}, error: ${errorMessage}`);
        }
      } catch (error: any) {
        set({ connectionState: ConnectionState.Error });
        throw error;
      }
    },

    stopAgent: async () => {
      try {
        // 1. 停止 Agent（调用 RESTful API）
        const currentAgentId = get().agentId;
        if (currentAgentId) {
          try {
            if (!authToken) {
              throw new Error('REST auth token is empty');
            }
            await AgentStarter.stopAgentAsync(currentAgentId, authToken);
            set({ agentId: null });
            get().addLog(`Agent stop successfully`);
          } catch (error: any) {
            get().addLog(`Agent stop failed`);
          }
        }

        // 2. 离开 RTC 频道
        if (rtcEngine && rtcJoined) {
          try {
            await rtcEngine.leaveChannel();
            rtcJoined = false;
            dataStreamId = 0;
          } catch (error: any) {
            // 忽略错误，继续清理
          }
        }

        // 3. 重置状态
        set({
          connectionState: ConnectionState.Idle,
          agentState: AgentState.IDLE,
          isMuted: false,
          transcripts: [],
          agentId: null,
        });

        channelName = '';
        authToken = null;
      } catch (error: any) {
        // 即使出错也重置状态
        set({
          connectionState: ConnectionState.Idle,
          agentState: AgentState.IDLE,
        });
        authToken = null;
      }
    },

    toggleMute: () => {
      const { isMuted } = get();
      const newMuteState = !isMuted;
      set({ isMuted: newMuteState });

      // 调用 RTC 调整录音音量
      if (rtcEngine) {
        rtcEngine.adjustRecordingSignalVolume(newMuteState ? 0 : 100);
      }
    },
  };
});

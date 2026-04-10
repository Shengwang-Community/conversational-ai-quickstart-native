import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import util from '@ohos.util';
import {
  RtcEngine,
  RtcEngineConfig,
  ChannelMediaOptions,
  Constants
} from '@shengwang/rtc-full';
import {
  RtmChannelType,
  RtmClient,
  RtmConfig,
  RtmPresenceEventType,
  MessageEvent,
  PresenceEvent
} from '@shengwang/rtm-full';
import {
  AgentState,
  ConnectionState,
  TranscriptRecord,
  TranscriptStatus,
  TranscriptType,
  UiMutation
} from '../common/Types';
import { KeyCenter } from '../common/KeyCenter';
import { generateRandomChannelName } from '../common/ChannelNameGenerator';
import { TokenGenerator } from '../api/TokenGenerator';
import { AgentStarter } from '../api/AgentStarter';

type StateListener = (mutation: UiMutation) => void;

const MIN_UID = 100000;
const UID_RANGE = 900000;
const MAX_LOG_LINES = 60;
const UTF8_TEXT_DECODER = util.TextDecoder.create('utf-8');

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

export class AgentChatController {
  private readonly onStateChange: StateListener;
  private rtcEngine?: RtcEngine;
  private rtmClient?: RtmClient;
  private rtcJoined: boolean = false;
  private rtmReady: boolean = false;
  private channelName: string = '';
  private authToken: string = '';
  private connectionState: ConnectionState = ConnectionState.Idle;
  private agentState: AgentState = AgentState.IDLE;
  private isMuted: boolean = false;
  private transcripts: TranscriptRecord[] = [];
  private logs: string[] = [];
  private agentId: string = '';
  private isStopping: boolean = false;
  private isInitialized: boolean = false;
  private userId: number = 0;
  private agentRtcUid: number = 0;
  private lastAgentStateTurnId: number = -1;
  private lastAgentStateTimestamp: number = -1;

  constructor(onStateChange: StateListener) {
    this.onStateChange = onStateChange;
  }

  async initialize(context: common.Context): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    await KeyCenter.ensureLoaded(context);

    const missingConfig = KeyCenter.validateAppConfig();
    if (missingConfig.length > 0) {
      throw new Error(
        `Missing app config: ${missingConfig.join(', ')}. Update harmony/entry/src/main/resources/rawfile/env.local and rebuild the app.`
      );
    }

    this.userId = generateRandomUid();
    this.agentRtcUid = generateUniqueUid(this.userId);
    this.appendLog(
      `Initialized session UIDs user=${this.userId}, agent=${this.agentRtcUid}`
    );

    this.initRtcEngine(context);
    this.initRtmClient();
    this.isInitialized = true;
  }

  private initRtcEngine(context: common.Context): void {
    if (this.rtcEngine) {
      return;
    }

    let config: RtcEngineConfig = new RtcEngineConfig();
    config.mContext = context;
    config.mAppId = KeyCenter.APP_ID;
    config.mEventHandler = {};
    config.mEventHandler.onJoinChannelSuccess = (channel: string, uid: number) => {
      this.rtcJoined = true;
      this.appendLog(`Rtc onJoinChannelSuccess, channel:${channel} uid:${uid}`);
      this.checkJoinAndLoginComplete();
    };
    config.mEventHandler.onUserJoined = (uid: number) => {
      this.appendLog(`Rtc onUserJoined, uid:${uid}`);
    };
    config.mEventHandler.onUserOffline = (uid: number) => {
      this.appendLog(`Rtc onUserOffline, uid:${uid}`);
    };
    config.mEventHandler.onConnectionStateChanged = (state: Constants.ConnectionState) => {
      if (state === Constants.ConnectionState.RECONNECTING) {
        this.appendLog('RTC reconnecting');
      }

      if (state === Constants.ConnectionState.FAILED) {
        this.setConnectionState(ConnectionState.Error);
        this.appendLog('RTC connection failed');
      }
    };
    config.mEventHandler.onError = (err: Constants.ErrorCode, message: string) => {
      this.setConnectionState(ConnectionState.Error);
      this.appendLog(`Rtc onError: ${err}, ${message}`);
    };
    config.mEventHandler.onPermissionError = () => {
      this.setConnectionState(ConnectionState.Error);
      this.appendLog('RTC permission error: microphone permission is required');
    };
    config.mEventHandler.onLeaveChannel = () => {
      this.rtcJoined = false;
      if (!this.isStopping) {
        this.appendLog('Rtc onLeaveChannel');
      }
    };
    config.mEventHandler.onTokenPrivilegeWillExpire = () => {
      this.appendLog('RTC token will expire soon');
    };
    this.rtcEngine = RtcEngine.create(config);

    const setChannelProfileResult = this.rtcEngine.setChannelProfile(
      Constants.ChannelProfile.COMMUNICATION
    );
    if (setChannelProfileResult < 0) {
      throw new Error(`setChannelProfile failed: ${setChannelProfileResult}`);
    }

    const enableAudioResult = this.rtcEngine.enableAudio();
    if (enableAudioResult < 0) {
      throw new Error(`enableAudio failed: ${enableAudioResult}`);
    }

    this.appendLog('RtcEngine init successfully');
  }

  async ensureMicrophonePermission(context: common.Context): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const tokenId = context.applicationInfo.accessTokenId;
    const permissionName = 'ohos.permission.MICROPHONE';

    const grantStatus = atManager.checkAccessTokenSync(tokenId, permissionName);
    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      return true;
    }

    const permissionResult = await atManager.requestPermissionsFromUser(
      context,
      [permissionName]
    );

    return permissionResult.authResults.length > 0 &&
      permissionResult.authResults[0] ===
      abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  async startConnection(): Promise<void> {
    if (this.connectionState === ConnectionState.Connecting) {
      return;
    }
    if (!this.isInitialized) {
      throw new Error('AgentChatController is not initialized');
    }

    this.setConnectionState(ConnectionState.Connecting);
    this.setAgentState(AgentState.IDLE);
    this.setMuted(false);
    this.setAgentId('');
    this.setTranscripts([]);
    this.authToken = '';
    this.rtcJoined = false;
    this.rtmReady = false;
    this.lastAgentStateTurnId = -1;
    this.lastAgentStateTimestamp = -1;
    this.channelName = generateRandomChannelName('harmony');

    const userToken = await TokenGenerator.generateUnifiedToken(
      this.channelName,
      this.userId
    );
    this.appendLog('Generate user token successfully');

    const channelOptions = new ChannelMediaOptions();
    channelOptions.clientRoleType = Constants.ClientRole.BROADCASTER;
    channelOptions.publishMicrophoneTrack = true;
    channelOptions.publishCameraTrack = false;
    channelOptions.autoSubscribeAudio = true;
    channelOptions.autoSubscribeVideo = false;
    channelOptions.channelProfile = Constants.ChannelProfile.LIVE_BROADCASTING;
    channelOptions.enableAudioRecordingOrPlayout = true;

    const joinChannelResult = this.requireRtcEngine().joinChannelWithOptions(
      userToken,
      this.channelName,
      this.userId,
      channelOptions
    );
    if (joinChannelResult < 0) {
      throw new Error(`joinChannelWithOptions failed: ${joinChannelResult}`);
    }
    this.appendLog(`RTC joining channel: ${this.channelName}`);

    await this.loginRtmAndSubscribe(userToken);
    this.checkJoinAndLoginComplete();
  }

  async stopAgent(): Promise<void> {
    this.isStopping = true;

    try {
      if (this.agentId.length > 0 && this.authToken.length > 0) {
        await AgentStarter.stopAgent(this.agentId, this.authToken);
        this.appendLog('Agent stop successfully');
      }
    } catch (error) {
      this.appendLog(
        `Agent stop failed: ${(error as Error).message ?? 'Unknown error'}`
      );
    }

    try {
      if (this.rtcEngine && this.rtcJoined) {
        this.rtcEngine.leaveChannel();
      }
    } catch (_) {
    }

    await this.logoutRtmIfNeeded();

    this.rtcJoined = false;
    this.rtmReady = false;
    this.channelName = '';
    this.authToken = '';
    this.setConnectionState(ConnectionState.Idle);
    this.setAgentState(AgentState.IDLE);
    this.setMuted(false);
    this.setTranscripts([]);
    this.setAgentId('');
    this.isStopping = false;
  }

  toggleMute(): void {
    const nextMuted = !this.isMuted;
    this.setMuted(nextMuted);

    if (this.rtcEngine) {
      const muteLocalAudioStreamResult = this.rtcEngine.muteLocalAudioStream(nextMuted);
      if (muteLocalAudioStreamResult < 0) {
        throw new Error(`muteLocalAudioStream failed: ${muteLocalAudioStreamResult}`);
      }
    }
  }

  async destroy(): Promise<void> {
    try {
      await this.stopAgent();
    } catch (_) {
    }

    this.rtcEngine = undefined;
    if (this.rtmClient) {
      this.rtmClient.release();
      this.rtmClient = undefined;
    }
    RtcEngine.destroySync();
  }

  private async startAgentInternal(): Promise<void> {
    try {
      if (this.agentId.length > 0) {
        return;
      }

      const agentToken = await TokenGenerator.generateUnifiedToken(
        this.channelName,
        this.agentRtcUid
      );
      this.appendLog('Generate agent token successfully');

      this.authToken = await TokenGenerator.generateUnifiedToken(
        this.channelName,
        this.agentRtcUid
      );
      this.appendLog('Generate REST auth token successfully');

      const nextAgentId = await AgentStarter.startAgent(
        this.channelName,
        this.agentRtcUid.toString(),
        agentToken,
        this.authToken,
        this.userId.toString(),
        'rtm'
      );

      this.setAgentId(nextAgentId);
      this.setConnectionState(ConnectionState.Connected);
      this.appendLog('Agent start successfully');
    } catch (error) {
      this.setConnectionState(ConnectionState.Error);
      this.appendLog(
        `Agent start failed: ${(error as Error).message ?? 'Unknown error'}`
      );

      try {
        if (this.rtcEngine && this.rtcJoined) {
          this.rtcEngine.leaveChannel();
        }
      } catch (_) {
      }
    }
  }

  private initRtmClient(): void {
    if (this.rtmClient) {
      return;
    }

    if (!this.rtcEngine) {
      throw new Error('RtcEngine must be initialized before RtmClient');
    }

    const config = new RtmConfig(KeyCenter.APP_ID, this.userId.toString());
    this.rtmClient = new RtmClient(config);
    this.rtmClient.addEventListener('message', (event: object) => {
      this.handleRtmMessage(event as MessageEvent);
    });
    this.rtmClient.addEventListener('presence', (event: object) => {
      this.handleRtmPresence(event as PresenceEvent);
    });
    this.rtmClient.addEventListener('linkState', (event: object) => {
      this.handleRtmLinkState(event);
    });
    this.appendLog('RtmClient init successfully');
  }

  private async loginRtmAndSubscribe(userToken: string): Promise<void> {
    const client = this.requireRtmClient();
    this.appendLog('RTM login start');
    await client.login(userToken);
    this.appendLog('RTM login successful');
    await client.subscribe(this.channelName);
    this.appendLog(`RTM subscribe successful channel:${this.channelName}`);
    this.rtmReady = true;
  }

  private async logoutRtmIfNeeded(): Promise<void> {
    if (!this.rtmClient) {
      return;
    }

    if (this.channelName.length > 0 && this.rtmReady) {
      try {
        await this.rtmClient.unsubscribe(this.channelName);
        this.appendLog('RTM unsubscribe successful');
      } catch (error) {
        this.appendLog(
          `RTM unsubscribe failed: ${(error as Error).message ?? 'Unknown error'}`
        );
      }
    }

    try {
      await this.rtmClient.logout();
      this.appendLog('RTM logout successful');
    } catch (error) {
      this.appendLog(
        `RTM logout failed: ${(error as Error).message ?? 'Unknown error'}`
      );
    }
  }

  private checkJoinAndLoginComplete(): void {
    if (this.rtcJoined && this.rtmReady) {
      void this.startAgentInternal();
    }
  }

  private handleRtmMessage(event: MessageEvent): void {
    if (event.channelName !== this.channelName) {
      return;
    }
    if (event.channelType !== RtmChannelType.MESSAGE) {
      return;
    }

    let messageText = '';
    if (typeof event.message === 'string') {
      messageText = event.message;
    } else {
      messageText = this.uint8ArrayToString(event.message);
    }

    if (messageText.length === 0) {
      return;
    }

    this.handleParsedMessage(messageText);
  }

  private handleRtmPresence(event: PresenceEvent): void {
    if (event.channelName !== this.channelName) {
      return;
    }
    if (event.channelType !== RtmChannelType.MESSAGE) {
      return;
    }
    if (event.eventType !== RtmPresenceEventType.REMOTE_STATE_CHANGED) {
      return;
    }

    let nextState = '';
    let turnId = 0;
    for (const item of event.stateChanged) {
      if (item.key === 'state') {
        nextState = item.value.toLowerCase();
      } else if (item.key === 'turn_id') {
        const parsedTurnId = Number.parseInt(item.value, 10);
        turnId = Number.isNaN(parsedTurnId) ? 0 : parsedTurnId;
      }
    }

    if (nextState.length === 0) {
      return;
    }
    if (turnId < this.lastAgentStateTurnId) {
      return;
    }
    if (event.timestamp <= this.lastAgentStateTimestamp) {
      return;
    }

    this.lastAgentStateTurnId = turnId;
    this.lastAgentStateTimestamp = event.timestamp;

    if (nextState === AgentState.IDLE) {
      this.setAgentState(AgentState.IDLE);
    } else if (nextState === AgentState.SILENT) {
      this.setAgentState(AgentState.SILENT);
    } else if (nextState === AgentState.LISTENING) {
      this.setAgentState(AgentState.LISTENING);
    } else if (nextState === AgentState.THINKING) {
      this.setAgentState(AgentState.THINKING);
    } else if (nextState === AgentState.SPEAKING) {
      this.setAgentState(AgentState.SPEAKING);
    }
  }

  private handleRtmLinkState(event: object): void {
    const eventText = JSON.stringify(event);
    this.appendLog(`RTM linkState ${eventText}`);
  }

  private handleParsedMessage(message: string): void {
    const messageType = this.extractStringField(message, 'object');
    if (messageType.length === 0) {
      return;
    }

    if (messageType === 'assistant.transcription') {
      const text = this.extractStringField(message, 'text');
      const turnId = this.extractIntField(message, 'turn_id');
      const userId = this.extractStringField(message, 'user_id');
      const turnStatus = this.extractIntField(message, 'turn_status');

      if (turnId < 0) {
        return;
      }

      let status = TranscriptStatus.UNKNOWN;
      if (turnStatus < 0 || turnStatus === 0) {
        status = TranscriptStatus.IN_PROGRESS;
      } else if (turnStatus === 1) {
        status = TranscriptStatus.END;
      } else if (turnStatus === 2) {
        status = TranscriptStatus.INTERRUPTED;
      }

      if (status === TranscriptStatus.UNKNOWN) {
        return;
      }

      const transcript: TranscriptRecord = {
        turnId: turnId,
        userId: userId,
        text: text.length > 0 ? text : '(empty)',
        status: status,
        type: TranscriptType.AGENT
      };
      this.upsertTranscript(transcript);
      return;
    }

    if (messageType === 'user.transcription') {
      const text = this.extractStringField(message, 'text');
      const turnId = this.extractIntField(message, 'turn_id');
      const userId = this.extractStringField(message, 'user_id');
      const turnStatus = this.extractIntField(message, 'turn_status');

      if (turnId < 0) {
        return;
      }

      let status = TranscriptStatus.UNKNOWN;
      if (turnStatus < 0 || turnStatus === 0) {
        status = TranscriptStatus.IN_PROGRESS;
      } else if (turnStatus === 1) {
        status = TranscriptStatus.END;
      } else if (turnStatus === 2) {
        status = TranscriptStatus.INTERRUPTED;
      }

      if (status === TranscriptStatus.UNKNOWN) {
        return;
      }

      const transcript: TranscriptRecord = {
        turnId: turnId,
        userId: userId,
        text: text.length > 0 ? text : '(empty)',
        status: status,
        type: TranscriptType.USER
      };
      this.upsertTranscript(transcript);
      return;
    }

    if (messageType === 'message.state') {
      const state = this.extractStringField(message, 'state');
      if (state === AgentState.IDLE) {
        this.setAgentState(AgentState.IDLE);
      } else if (state === AgentState.SILENT) {
        this.setAgentState(AgentState.SILENT);
      } else if (state === AgentState.LISTENING) {
        this.setAgentState(AgentState.LISTENING);
      } else if (state === AgentState.THINKING) {
        this.setAgentState(AgentState.THINKING);
      } else if (state === AgentState.SPEAKING) {
        this.setAgentState(AgentState.SPEAKING);
      }
      return;
    }

    if (messageType === 'message.interrupt') {
      const turnId = this.extractIntField(message, 'turn_id');
      if (turnId >= 0) {
        const nextTranscripts: TranscriptRecord[] = [];
        for (const item of this.transcripts) {
          if (item.type === TranscriptType.AGENT && item.turnId === turnId) {
            const updated: TranscriptRecord = {
              turnId: item.turnId,
              userId: item.userId,
              text: item.text,
              status: TranscriptStatus.INTERRUPTED,
              type: item.type
            };
            nextTranscripts.push(updated);
          } else {
            nextTranscripts.push(item);
          }
        }
        this.setTranscripts(nextTranscripts);
      }
      return;
    }

    if (messageType === 'message.error') {
      const moduleName = this.extractStringField(message, 'module');
      const code = this.extractIntField(message, 'code');
      const errorMessage = this.extractStringField(message, 'message');
      this.appendLog(
        `Agent error: type=${moduleName.length > 0 ? moduleName : 'unknown'}, code=${code}, msg=${errorMessage.length >
          0 ? errorMessage : 'Unknown error'}`
      );
    }
  }

  private upsertTranscript(transcript: TranscriptRecord): void {
    const nextTranscripts: TranscriptRecord[] = [];
    let replaced = false;
    let hasChanged = true;

    for (const item of this.transcripts) {
      if (item.turnId === transcript.turnId && item.type === transcript.type) {
        if (this.isSameTranscript(item, transcript)) {
          nextTranscripts.push(item);
          hasChanged = false;
        } else {
          nextTranscripts.push(transcript);
        }
        replaced = true;
      } else {
        nextTranscripts.push(item);
      }
    }

    if (!replaced) {
      nextTranscripts.push(transcript);
    }

    if (!hasChanged) {
      return;
    }

    this.appendTranscriptLog(transcript);
    this.setTranscripts(nextTranscripts);
  }

  private appendLog(message: string): void {
    const nextLogs: string[] = [];
    const startIndex = this.logs.length >= MAX_LOG_LINES
      ? this.logs.length - (MAX_LOG_LINES - 1)
      : 0;

    for (let index = startIndex; index < this.logs.length; index += 1) {
      nextLogs.push(this.logs[index]);
    }
    nextLogs.push(message);
    this.logs = nextLogs;
    this.onStateChange({ logs: nextLogs });
  }

  private appendTranscriptLog(transcript: TranscriptRecord): void {
    const speaker = transcript.type === TranscriptType.USER ? 'USER' : 'AI';
    console.info(
      `Subtitle ${speaker} turn=${transcript.turnId} status=${transcript.status}: ${transcript.text}`
    );
  }

  private isSameTranscript(
    current: TranscriptRecord,
    next: TranscriptRecord
  ): boolean {
    return current.turnId === next.turnId &&
      current.userId === next.userId &&
      current.text === next.text &&
      current.status === next.status &&
      current.type === next.type;
  }

  private setConnectionState(nextState: ConnectionState): void {
    this.connectionState = nextState;
    this.onStateChange({ connectionState: nextState });
  }

  private setAgentState(nextState: AgentState): void {
    this.agentState = nextState;
    this.onStateChange({ agentState: nextState });
  }

  private setMuted(muted: boolean): void {
    this.isMuted = muted;
    this.onStateChange({ isMuted: muted });
  }

  private setTranscripts(nextTranscripts: TranscriptRecord[]): void {
    this.transcripts = nextTranscripts;
    this.onStateChange({ transcripts: nextTranscripts });
  }

  private setAgentId(agentId: string): void {
    this.agentId = agentId;
    this.onStateChange({ agentId });
  }

  private extractStringField(jsonText: string, fieldName: string): string {
    const pattern = new RegExp(
      `"${fieldName}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`,
      'g'
    );
    let match = pattern.exec(jsonText);
    let lastMatch = match;

    while (match) {
      lastMatch = match;
      match = pattern.exec(jsonText);
    }

    if (!lastMatch || lastMatch.length < 2) {
      return '';
    }

    return this.decodeJsonString(lastMatch[1]);
  }

  private extractIntField(jsonText: string, fieldName: string): number {
    const pattern = new RegExp(`"${fieldName}"\\s*:\\s*(-?\\d+)`);
    const match = pattern.exec(jsonText);
    if (!match || match.length < 2) {
      return -1;
    }

    return Number.parseInt(match[1], 10);
  }

  private decodeJsonString(value: string): string {
    try {
      return JSON.parse(`"${value.replace(/"/g, '\\"')}"`) as string;
    } catch (_) {
      return value;
    }
  }

  private uint8ArrayToString(value: Uint8Array): string {
    try {
      const start = value.byteOffset;
      const end = value.byteOffset + value.byteLength;
      const content = new Uint8Array(value.buffer.slice(start, end));
      return UTF8_TEXT_DECODER.decodeToString(content);
    } catch (_) {
      let result = '';
      for (let index = 0; index < value.length; index += 1) {
        result += String.fromCharCode(value[index]);
      }
      return result;
    }
  }

  private requireRtcEngine(): RtcEngine {
    if (!this.rtcEngine) {
      throw new Error('RtcEngine is not initialized');
    }

    return this.rtcEngine;
  }

  private requireRtmClient(): RtmClient {
    if (!this.rtmClient) {
      throw new Error('RtmClient is not initialized');
    }

    return this.rtmClient;
  }
}

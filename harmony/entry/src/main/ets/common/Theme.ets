import {
  AgentState,
  ConnectionState,
  TranscriptStatus
} from './Types';

export class ChatTheme {
  static readonly bgPrimary = '#0F172A';
  static readonly bgSecondary = '#111827';
  static readonly bgCard = '#1E293BCC';
  static readonly bgLogOuter = '#0B1120D9';
  static readonly bgLogInner = '#020617B3';
  static readonly border = '#334155';

  static readonly textTitle = '#FFFFFF';
  static readonly textSubtitle = '#CBD5E1';
  static readonly textSecondary = '#94A3B8';
  static readonly textMuted = '#64748B';

  static readonly accentBlue = '#3B82F6';
  static readonly successGreen = '#10B981';
  static readonly successGreenLight = '#34D399';
  static readonly errorRed = '#EF4444';
  static readonly errorRedDark = '#DC2626';
  static readonly errorRedLight = '#F87171';
  static readonly warningAmber = '#F59E0B';
  static readonly warningAmberLight = '#FBBF24';

  static readonly stateIdle = '#64748B';
  static readonly stateSilent = '#475569';
  static readonly stateListening = '#10B981';
  static readonly stateThinking = '#F59E0B';
  static readonly stateSpeaking = '#3B82F6';

  static readonly bubbleAgentBg = '#334155';
  static readonly bubbleAgentText = '#F1F5F9';
  static readonly bubbleUserBg = '#2563EB';
  static readonly bubbleUserText = '#FFFFFF';

  static readonly buttonStart = '#2563EB';
  static readonly buttonStartPressed = '#3B82F6';
  static readonly buttonStop = '#DC2626';
  static readonly buttonStopPressed = '#EF4444';
  static readonly buttonDisabled = '#334155';
  static readonly buttonDisabledText = '#94A3B8';

  static readonly micNormalBg = '#334155';
  static readonly micNormalPressed = '#475569';
  static readonly micNormalText = '#CBD5E1';
  static readonly micMutedBg = '#7F1D1D';
  static readonly micMutedText = '#FCA5A5';
}

export function getStartButtonLabel(connectionState: ConnectionState): string {
  switch (connectionState) {
    case ConnectionState.Connecting:
      return 'Connecting...';
    case ConnectionState.Error:
      return 'Retry';
    case ConnectionState.Idle:
    case ConnectionState.Connected:
    default:
      return 'Start Agent';
  }
}

export function getStatusLabel(
  connectionState: ConnectionState,
  agentState: AgentState
): string {
  if (connectionState === ConnectionState.Connecting) {
    return 'Connecting';
  }

  if (connectionState === ConnectionState.Error) {
    return 'Error';
  }

  switch (agentState) {
    case AgentState.SILENT:
      return 'Silent';
    case AgentState.LISTENING:
      return 'Listening';
    case AgentState.THINKING:
      return 'Thinking';
    case AgentState.SPEAKING:
      return 'Speaking';
    case AgentState.IDLE:
    default:
      return 'Idle';
  }
}

export function getStatusColor(
  connectionState: ConnectionState,
  agentState: AgentState
): string {
  if (connectionState === ConnectionState.Connecting) {
    return ChatTheme.warningAmber;
  }

  if (connectionState === ConnectionState.Error) {
    return ChatTheme.errorRedLight;
  }

  switch (agentState) {
    case AgentState.LISTENING:
      return ChatTheme.stateListening;
    case AgentState.THINKING:
      return ChatTheme.stateThinking;
    case AgentState.SPEAKING:
      return ChatTheme.stateSpeaking;
    case AgentState.SILENT:
      return ChatTheme.stateSilent;
    case AgentState.IDLE:
    default:
      return ChatTheme.stateIdle;
  }
}

export function getLogColor(message: string): string {
  const lowerCaseMessage = message.toLowerCase();

  if (lowerCaseMessage.indexOf('failed') >= 0 || lowerCaseMessage.indexOf('error') >= 0) {
    return ChatTheme.errorRedLight;
  }

  if (lowerCaseMessage.indexOf('success') >= 0 || message.indexOf('成功') >= 0) {
    return ChatTheme.successGreenLight;
  }

  if (
    lowerCaseMessage.indexOf('connecting') >= 0 ||
    lowerCaseMessage.indexOf('starting') >= 0 ||
    message.indexOf('调用') >= 0
  ) {
    return ChatTheme.warningAmberLight;
  }

  return ChatTheme.textSecondary;
}

export function getTranscriptMetaLabel(status: TranscriptStatus): string {
  if (status === TranscriptStatus.INTERRUPTED) {
    return 'Interrupted';
  }

  if (status === TranscriptStatus.IN_PROGRESS) {
    return 'Live';
  }

  return '';
}

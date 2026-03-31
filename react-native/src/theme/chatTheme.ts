import {
  AgentState,
  ConnectionState,
  TranscriptStatus,
} from '../types';

export const chatPalette = {
  bgPrimary: '#0F172A',
  bgSecondary: '#1E293B',
  bgCard: 'rgba(30, 41, 59, 0.5)',
  bgControlBar: 'rgba(30, 41, 59, 0.8)',
  bgLogOuter: 'rgba(15, 23, 42, 0.8)',
  bgLogInner: 'rgba(2, 6, 23, 0.5)',
  border: 'rgba(51, 65, 85, 0.5)',

  textTitle: '#FFFFFF',
  textSubtitle: '#CBD5E1',
  textSecondary: '#94A3B8',

  accentBlue: '#3B82F6',
  successGreen: '#10B981',
  successGreenLight: '#34D399',
  errorRed: '#EF4444',
  errorRedDark: '#DC2626',
  errorRedLight: '#F87171',
  warningAmber: '#F59E0B',
  warningAmberLight: '#FBBF24',

  stateIdle: '#64748B',
  stateListening: '#10B981',
  stateThinking: '#F59E0B',
  stateSpeaking: '#3B82F6',
  stateSilent: '#475569',

  bubbleAgentBg: '#334155',
  bubbleAgentText: '#F1F5F9',
  bubbleUserBg: '#2563EB',
  bubbleUserText: '#FFFFFF',

  buttonStart: '#2563EB',
  buttonStartPressed: '#3B82F6',
  buttonStop: '#DC2626',
  buttonStopPressed: '#EF4444',
  buttonDisabled: '#334155',
  buttonDisabledText: '#94A3B8',

  micNormalBg: '#334155',
  micNormalPressed: '#475569',
  micNormalText: '#CBD5E1',
  micMutedBg: 'rgba(239, 68, 68, 0.2)',
  micMutedText: '#F87171',
} as const;

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
  agentState: AgentState,
): string {
  if (connectionState === ConnectionState.Connecting) {
    return 'Connecting';
  }

  if (connectionState === ConnectionState.Error) {
    return 'Error';
  }

  return agentState.charAt(0).toUpperCase() + agentState.slice(1);
}

export function getStatusColor(
  connectionState: ConnectionState,
  agentState: AgentState,
): string {
  if (connectionState === ConnectionState.Connecting) {
    return chatPalette.warningAmber;
  }

  if (connectionState === ConnectionState.Error) {
    return chatPalette.errorRedLight;
  }

  switch (agentState) {
    case AgentState.LISTENING:
      return chatPalette.stateListening;
    case AgentState.THINKING:
      return chatPalette.stateThinking;
    case AgentState.SPEAKING:
      return chatPalette.stateSpeaking;
    case AgentState.SILENT:
      return chatPalette.stateSilent;
    case AgentState.IDLE:
    default:
      return chatPalette.stateIdle;
  }
}

export function getLogColor(message: string): string {
  const lowerCaseMessage = message.toLowerCase();

  if (
    lowerCaseMessage.includes('failed') ||
    lowerCaseMessage.includes('error')
  ) {
    return chatPalette.errorRedLight;
  }

  if (
    lowerCaseMessage.includes('success') ||
    message.includes('成功')
  ) {
    return chatPalette.successGreenLight;
  }

  if (
    lowerCaseMessage.includes('connecting') ||
    lowerCaseMessage.includes('starting') ||
    message.includes('调用')
  ) {
    return chatPalette.warningAmberLight;
  }

  return chatPalette.textSecondary;
}

export function getTranscriptMetaLabel(
  status: TranscriptStatus,
): string | undefined {
  if (status === TranscriptStatus.INTERRUPTED) {
    return 'Interrupted';
  }

  return undefined;
}

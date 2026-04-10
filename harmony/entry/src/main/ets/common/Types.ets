export enum ConnectionState {
  Idle = 'Idle',
  Connecting = 'Connecting',
  Connected = 'Connected',
  Error = 'Error'
}

export enum AgentState {
  IDLE = 'idle',
  SILENT = 'silent',
  LISTENING = 'listening',
  THINKING = 'thinking',
  SPEAKING = 'speaking'
}

export enum TranscriptType {
  AGENT = 'agent',
  USER = 'user'
}

export enum TranscriptStatus {
  IN_PROGRESS = 'in_progress',
  END = 'end',
  INTERRUPTED = 'interrupted',
  UNKNOWN = 'unknown'
}

export interface TranscriptRecord {
  turnId: number;
  userId: string;
  text: string;
  status: TranscriptStatus;
  type: TranscriptType;
}

export interface UiMutation {
  connectionState?: ConnectionState;
  agentState?: AgentState;
  isMuted?: boolean;
  transcripts?: TranscriptRecord[];
  logs?: string[];
  agentId?: string;
}

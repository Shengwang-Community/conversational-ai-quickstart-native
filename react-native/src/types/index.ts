export enum ConnectionState {
  Idle = 'Idle',
  Connecting = 'Connecting',
  Connected = 'Connected',
  Error = 'Error',
}

export enum AgentState {
  IDLE = 'idle',
  SILENT = 'silent',
  LISTENING = 'listening',
  THINKING = 'thinking',
  SPEAKING = 'speaking',
}

/**
 * Transcript type enum
 * Reference: harmonyos/entry/src/main/ets/convoaiApi/IConversationalAIAPI.ets:168-174
 */
export enum TranscriptType {
  /** AI assistant transcript */
  AGENT = 'agent',
  /** User transcript */
  USER = 'user',
}

/**
 * Transcript status enum
 * Reference: harmonyos/entry/src/main/ets/convoaiApi/IConversationalAIAPI.ets:179-191
 */
export enum TranscriptStatus {
  /** Transcript is still being generated or spoken */
  IN_PROGRESS = 'in_progress',
  /** Transcript has completed normally */
  END = 'end',
  /** Transcript was interrupted before completion */
  INTERRUPTED = 'interrupted',
  /** Unknown status */
  UNKNOWN = 'unknown',
}

/**
 * Transcript interface
 * Reference: harmonyos/entry/src/main/ets/convoaiApi/IConversationalAIAPI.ets:196-211
 * 
 * Note: type and turnId together uniquely identify a transcript.
 * If type and turnId are the same, it's the same sentence (should be updated, not added).
 */
export interface Transcript {
  /** Unique identifier for the conversation turn */
  turnId: number;
  /** User identifier associated with this Transcript */
  userId: string;
  /** The actual Transcript text content */
  text: string;
  /** Current status of the Transcript */
  status: TranscriptStatus;
  /** Transcript type (AGENT/USER) */
  type: TranscriptType;
}

export interface ConversationUiState {
  connectionState: ConnectionState;
  agentState: AgentState;
  isMuted: boolean;
  transcripts: Transcript[];
  logs: string[];
  agentId: string | null;
}


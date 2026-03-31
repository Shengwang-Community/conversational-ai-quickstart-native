import React, { useEffect } from 'react';
import { Alert, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAgentChatStore } from '../stores/AgentChatStore';
import { LogCard } from './LogCard';
import { TranscriptPanel } from './TranscriptPanel';
import { ActionBar } from './ActionBar';
import { requestAudioPermission } from '../utils/PermissionHelper';
import { chatPalette } from '../theme/chatTheme';

export const AgentChatPage: React.FC = () => {
  const {
    connectionState,
    agentState,
    transcripts,
    logs,
    isMuted,
    startConnection,
    stopAgent,
    toggleMute,
    initRtcEngine,
  } = useAgentChatStore();

  useEffect(() => {
    void initRtcEngine();
  }, [initRtcEngine]);

  const handleStart = async () => {
    try {
      const hasPermission = await requestAudioPermission();
      if (!hasPermission) {
        Alert.alert(
          'Microphone Required',
          'Allow microphone access to start a real-time voice conversation.',
        );
        return;
      }

      await startConnection();
    } catch (error: unknown) {
      Alert.alert(
        'Start Failed',
        error instanceof Error ? error.message : 'Unknown error',
      );
    }
  };

  return (
    <SafeAreaView
      style={styles.safeArea}
      edges={['top', 'right', 'bottom', 'left']}
    >
      <View style={styles.container}>
        <View style={styles.titleSection}>
          <Text style={styles.title}>Shengwang Conversational AI</Text>
          <Text style={styles.subtitle}>Real-time Voice Conversation Demo</Text>
        </View>

        <View style={styles.content}>
          <LogCard logs={logs} style={styles.logSection} />
          <View style={styles.contentSpacer} />
          <TranscriptPanel
            transcripts={transcripts}
            agentState={agentState}
            connectionState={connectionState}
            style={styles.transcriptSection}
          />
        </View>

        <View style={styles.actionSection}>
          <ActionBar
            connectionState={connectionState}
            isMuted={isMuted}
            onStart={handleStart}
            onStopAgent={stopAgent}
            onToggleMute={toggleMute}
          />
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: chatPalette.bgPrimary,
  },
  container: {
    flex: 1,
    backgroundColor: chatPalette.bgPrimary,
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
  titleSection: {
    paddingTop: 8,
    marginBottom: 12,
  },
  title: {
    color: chatPalette.textTitle,
    fontSize: 20,
    fontWeight: '700',
  },
  subtitle: {
    marginTop: 2,
    color: chatPalette.textSubtitle,
    fontSize: 13,
  },
  content: {
    flex: 1,
  },
  logSection: {
    flex: 3,
  },
  contentSpacer: {
    height: 8,
  },
  transcriptSection: {
    flex: 7,
  },
  actionSection: {
    marginTop: 16,
  },
});

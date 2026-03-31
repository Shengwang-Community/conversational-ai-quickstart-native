import React from 'react';
import {
  FlatList,
  ListRenderItem,
  StyleProp,
  StyleSheet,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import {
  AgentState,
  ConnectionState,
  Transcript,
  TranscriptStatus,
  TranscriptType,
} from '../types';
import {
  chatPalette,
  getStatusColor,
  getStatusLabel,
  getTranscriptMetaLabel,
} from '../theme/chatTheme';

interface TranscriptPanelProps {
  transcripts: Transcript[];
  agentState: AgentState;
  connectionState: ConnectionState;
  style?: StyleProp<ViewStyle>;
}

export const TranscriptPanel: React.FC<TranscriptPanelProps> = ({
  transcripts,
  agentState,
  connectionState,
  style,
}) => {
  const listRef = React.useRef<FlatList<Transcript>>(null);

  const lastTranscript = transcripts[transcripts.length - 1];

  React.useEffect(() => {
    if (transcripts.length === 0) {
      return;
    }

    const timerId = setTimeout(() => {
      listRef.current?.scrollToEnd({ animated: true });
    }, 80);

    return () => {
      clearTimeout(timerId);
    };
  }, [transcripts.length, lastTranscript?.text]);

  const renderItem: ListRenderItem<Transcript> = ({ item }) => {
    const isUser = item.type === TranscriptType.USER;
    const metaLabel = getTranscriptMetaLabel(item.status);

    return (
      <View
        style={[
          styles.messageRow,
          isUser ? styles.userRow : styles.agentRow,
        ]}
      >
        {!isUser ? (
          <>
            <View style={[styles.avatar, styles.agentAvatar]}>
              <Text style={styles.avatarText}>AI</Text>
            </View>
            <View style={styles.avatarSpacer} />
          </>
        ) : null}

        <View style={styles.messageColumn}>
          <View
            style={[
              styles.bubble,
              isUser ? styles.userBubble : styles.agentBubble,
              item.status === TranscriptStatus.IN_PROGRESS &&
                styles.inProgressBubble,
            ]}
          >
            <Text
              style={[
                styles.bubbleText,
                isUser ? styles.userBubbleText : styles.agentBubbleText,
              ]}
            >
              {item.text}
            </Text>
          </View>

          {metaLabel ? (
            <Text
              style={[
                styles.metaLabel,
                isUser ? styles.userMetaLabel : styles.agentMetaLabel,
              ]}
            >
              {metaLabel}
            </Text>
          ) : null}
        </View>

        {isUser ? (
          <>
            <View style={styles.avatarSpacer} />
            <View style={[styles.avatar, styles.userAvatar]}>
              <Text style={styles.avatarText}>Me</Text>
            </View>
          </>
        ) : null}
      </View>
    );
  };

  const statusColor = getStatusColor(connectionState, agentState);
  const statusLabel = getStatusLabel(connectionState, agentState);

  return (
    <View style={[styles.container, style]}>
      <View style={styles.transcriptCard}>
        <FlatList
          ref={listRef}
          data={transcripts}
          renderItem={renderItem}
          keyExtractor={(item) => `${item.type}-${item.turnId}`}
          contentContainerStyle={[
            styles.listContent,
            transcripts.length === 0 && styles.emptyListContent,
          ]}
          showsVerticalScrollIndicator
          ListEmptyComponent={
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyTitle}>No transcript yet</Text>
              <Text style={styles.emptyHint}>
                Start Agent to see the live conversation transcript.
              </Text>
            </View>
          }
        />

        <View style={styles.statusBar}>
          <View style={[styles.statusDot, { backgroundColor: statusColor }]} />
          <Text style={[styles.statusText, { color: statusColor }]}>
            {statusLabel}
          </Text>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  transcriptCard: {
    flex: 1,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: chatPalette.border,
    backgroundColor: chatPalette.bgCard,
    overflow: 'hidden',
  },
  listContent: {
    paddingVertical: 12,
  },
  emptyListContent: {
    flexGrow: 1,
  },
  messageRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginVertical: 4,
    paddingHorizontal: 12,
  },
  agentRow: {
    paddingRight: 56,
  },
  userRow: {
    justifyContent: 'flex-end',
    paddingLeft: 56,
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  agentAvatar: {
    backgroundColor: chatPalette.accentBlue,
  },
  userAvatar: {
    backgroundColor: chatPalette.successGreen,
  },
  avatarText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '700',
  },
  avatarSpacer: {
    width: 8,
  },
  messageColumn: {
    maxWidth: '78%',
  },
  bubble: {
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  agentBubble: {
    borderTopLeftRadius: 2,
    borderTopRightRadius: 16,
    borderBottomLeftRadius: 16,
    borderBottomRightRadius: 16,
    backgroundColor: chatPalette.bubbleAgentBg,
  },
  userBubble: {
    borderTopLeftRadius: 16,
    borderTopRightRadius: 2,
    borderBottomLeftRadius: 16,
    borderBottomRightRadius: 16,
    backgroundColor: chatPalette.bubbleUserBg,
  },
  inProgressBubble: {
    opacity: 0.92,
  },
  bubbleText: {
    fontSize: 14,
    lineHeight: 19,
  },
  agentBubbleText: {
    color: chatPalette.bubbleAgentText,
  },
  userBubbleText: {
    color: chatPalette.bubbleUserText,
  },
  metaLabel: {
    fontSize: 12,
    color: chatPalette.warningAmberLight,
    marginTop: 4,
  },
  agentMetaLabel: {
    alignSelf: 'flex-start',
  },
  userMetaLabel: {
    alignSelf: 'flex-end',
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    padding: 32,
    justifyContent: 'center',
  },
  emptyTitle: {
    fontSize: 16,
    color: chatPalette.textSubtitle,
    fontWeight: '600',
  },
  emptyHint: {
    marginTop: 8,
    color: chatPalette.textSecondary,
    fontSize: 13,
    textAlign: 'center',
  },
  statusBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    paddingVertical: 12,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: chatPalette.border,
    backgroundColor: chatPalette.bgControlBar,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  statusText: {
    marginLeft: 8,
    fontSize: 13,
    fontWeight: '700',
  },
});

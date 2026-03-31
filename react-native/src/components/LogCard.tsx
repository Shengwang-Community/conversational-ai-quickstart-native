import React, { useRef, useEffect } from 'react';
import {
  Platform,
  ScrollView,
  StyleProp,
  StyleSheet,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import { chatPalette, getLogColor } from '../theme/chatTheme';

interface LogCardProps {
  logs: string[];
  style?: StyleProp<ViewStyle>;
}

export const LogCard: React.FC<LogCardProps> = ({ logs, style }) => {
  const scrollViewRef = useRef<ScrollView>(null);

  useEffect(() => {
    if (scrollViewRef.current && logs.length > 0) {
      const timerId = setTimeout(() => {
        scrollViewRef.current?.scrollToEnd({ animated: true });
      }, 100);

      return () => {
        clearTimeout(timerId);
      };
    }
  }, [logs.length]);

  return (
    <View style={[styles.card, style]}>
      <View style={styles.innerCard}>
        <ScrollView
          ref={scrollViewRef}
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator
        >
          {logs.length === 0 ? (
            <Text style={styles.emptyText}>log</Text>
          ) : (
            logs.map((log, index) => (
              <Text
                key={`${index}-${log}`}
                style={[styles.logLine, { color: getLogColor(log) }]}
              >
                {log}
              </Text>
            ))
          )}
        </ScrollView>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    width: '100%',
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: chatPalette.border,
    backgroundColor: chatPalette.bgLogOuter,
    padding: 1,
  },
  innerCard: {
    flex: 1,
    borderRadius: 11,
    backgroundColor: chatPalette.bgLogInner,
    overflow: 'hidden',
    padding: 12,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
  },
  logLine: {
    fontSize: 12,
    lineHeight: 17,
    marginBottom: 2,
    fontFamily: Platform.select({
      ios: 'Menlo',
      android: 'monospace',
      default: 'monospace',
    }),
  },
  emptyText: {
    fontSize: 12,
    lineHeight: 17,
    color: chatPalette.textSecondary,
    fontFamily: Platform.select({
      ios: 'Menlo',
      android: 'monospace',
      default: 'monospace',
    }),
  },
});

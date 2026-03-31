import React from 'react';
import {
  Alert,
  Pressable,
  StyleProp,
  StyleSheet,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import { ConnectionState } from '../types';
import { chatPalette, getStartButtonLabel } from '../theme/chatTheme';

interface ActionBarProps {
  connectionState: ConnectionState;
  isMuted: boolean;
  onStart: () => Promise<void>;
  onStopAgent: () => Promise<void>;
  onToggleMute: () => void;
}

interface ActionButtonProps {
  label: string;
  onPress?: () => void;
  backgroundColor: string;
  pressedColor: string;
  textColor: string;
  disabled?: boolean;
  disabledBackgroundColor?: string;
  disabledTextColor?: string;
  style?: StyleProp<ViewStyle>;
  children?: React.ReactNode;
  accessibilityLabel?: string;
}

function ActionButton({
  label,
  onPress,
  backgroundColor,
  pressedColor,
  textColor,
  disabled = false,
  disabledBackgroundColor = chatPalette.buttonDisabled,
  disabledTextColor = chatPalette.buttonDisabledText,
  style,
  children,
  accessibilityLabel,
}: ActionButtonProps) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        style,
        {
          backgroundColor: disabled
            ? disabledBackgroundColor
            : pressed
              ? pressedColor
              : backgroundColor,
        },
      ]}
    >
      {children ?? (
        <Text
          style={[
            styles.buttonText,
            { color: disabled ? disabledTextColor : textColor },
          ]}
        >
          {label}
        </Text>
      )}
    </Pressable>
  );
}

export const ActionBar: React.FC<ActionBarProps> = ({
  connectionState,
  isMuted,
  onStart,
  onStopAgent,
  onToggleMute,
}) => {
  const handleStart = async () => {
    try {
      await onStart();
    } catch (error: unknown) {
      Alert.alert(
        'Start Failed',
        error instanceof Error ? error.message : 'Unknown error',
      );
    }
  };

  const handleStopAgent = async () => {
    try {
      await onStopAgent();
    } catch (error: unknown) {
      Alert.alert(
        'Stop Failed',
        error instanceof Error ? error.message : 'Unknown error',
      );
    }
  };

  const isConnecting = connectionState === ConnectionState.Connecting;
  const isError = connectionState === ConnectionState.Error;
  const isConnected = connectionState === ConnectionState.Connected;

  return (
    <View style={styles.container}>
      {!isConnected ? (
        <ActionButton
          label={getStartButtonLabel(connectionState)}
          onPress={handleStart}
          disabled={isConnecting}
          backgroundColor={
            isError ? chatPalette.errorRedDark : chatPalette.buttonStart
          }
          pressedColor={
            isError ? chatPalette.errorRed : chatPalette.buttonStartPressed
          }
          textColor="#FFFFFF"
          style={styles.primaryButton}
        />
      ) : (
        <View style={styles.connectedActions}>
          <ActionButton
            label={isMuted ? 'Off' : 'Mic'}
            onPress={onToggleMute}
            backgroundColor={
              isMuted ? chatPalette.micMutedBg : chatPalette.micNormalBg
            }
            pressedColor={
              isMuted ? chatPalette.micMutedBg : chatPalette.micNormalPressed
            }
            textColor={
              isMuted ? chatPalette.micMutedText : chatPalette.micNormalText
            }
            style={styles.micButton}
            accessibilityLabel={
              isMuted ? 'Unmute microphone' : 'Mute microphone'
            }
          >
            <Text
              style={[
                styles.micButtonText,
                {
                  color: isMuted
                    ? chatPalette.micMutedText
                    : chatPalette.micNormalText,
                },
              ]}
            >
              {isMuted ? 'Off' : 'Mic'}
            </Text>
          </ActionButton>

          <ActionButton
            label="Stop Agent"
            onPress={handleStopAgent}
            backgroundColor={chatPalette.buttonStop}
            pressedColor={chatPalette.buttonStopPressed}
            textColor="#FFFFFF"
            style={styles.stopButton}
          />
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
  },
  button: {
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 56,
    borderRadius: 8,
  },
  primaryButton: {
    width: '100%',
  },
  connectedActions: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  micButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
  },
  stopButton: {
    flex: 1,
    marginLeft: 24,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: '700',
    letterSpacing: 0.2,
  },
  micButtonText: {
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0.3,
  },
});

/**
 * @format
 */

import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import App from '../App';

const mockInitRtcEngine = jest.fn().mockResolvedValue(undefined);

jest.mock('react-native-safe-area-context', () => {
  const React = require('react');
  const { View } = require('react-native');

  return {
    SafeAreaProvider: ({ children }: { children: React.ReactNode }) => children,
    SafeAreaView: ({ children }: { children: React.ReactNode }) => (
      <View>{children}</View>
    ),
  };
});

jest.mock('../src/stores/AgentChatStore', () => ({
  useAgentChatStore: () => ({
    connectionState: 'Idle',
    agentState: 'idle',
    transcripts: [],
    logs: [],
    isMuted: false,
    startConnection: jest.fn().mockResolvedValue(undefined),
    stopAgent: jest.fn().mockResolvedValue(undefined),
    toggleMute: jest.fn(),
    initRtcEngine: mockInitRtcEngine,
  }),
}));

test('renders correctly', async () => {
  await ReactTestRenderer.act(() => {
    ReactTestRenderer.create(<App />);
  });

  expect(mockInitRtcEngine).toHaveBeenCalled();
});

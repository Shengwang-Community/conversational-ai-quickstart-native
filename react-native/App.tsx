import React from 'react';
import { StatusBar } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AgentChatPage } from './src/components/AgentChatPage';
import { chatPalette } from './src/theme/chatTheme';

function App() {
  return (
    <SafeAreaProvider>
      <StatusBar
        barStyle="light-content"
        backgroundColor={chatPalette.bgPrimary}
      />
      <AgentChatPage />
    </SafeAreaProvider>
  );
}

export default App;

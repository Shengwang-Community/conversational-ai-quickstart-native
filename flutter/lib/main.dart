import 'package:flutter/material.dart';

import 'agent_chat_page.dart';
import 'services/keycenter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KeyCenter.load();
  runApp(const StartupApp());
}

class StartupApp extends StatelessWidget {
  const StartupApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shengwang Conversational AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
      ),
      home: const AgentChatPage(),
    );
  }
}

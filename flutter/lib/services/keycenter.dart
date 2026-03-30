import 'package:flutter/services.dart' show rootBundle;

class KeyCenter {
  static const String _defaultLlmUrl =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const String _defaultLlmModel = 'qwen-plus';

  static String appId = const String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '',
  );
  static String appCertificate = const String.fromEnvironment(
    'AGORA_APP_CERTIFICATE',
    defaultValue: '',
  );
  static String llmApiKey = const String.fromEnvironment(
    'LLM_API_KEY',
    defaultValue: '',
  );
  static String llmUrl = const String.fromEnvironment(
    'LLM_URL',
    defaultValue: _defaultLlmUrl,
  );
  static String llmModel = const String.fromEnvironment(
    'LLM_MODEL',
    defaultValue: _defaultLlmModel,
  );
  static String ttsBytedanceAppId = const String.fromEnvironment(
    'TTS_BYTEDANCE_APP_ID',
    defaultValue: '',
  );
  static String ttsBytedanceToken = const String.fromEnvironment(
    'TTS_BYTEDANCE_TOKEN',
    defaultValue: '',
  );

  static Future<void> load() async {
    try {
      final content = await rootBundle.loadString('assets/env.properties');
      final lines = content.split(RegExp(r'\r?\n'));
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final idx = line.indexOf('=');
        if (idx <= 0) continue;
        final key = line.substring(0, idx).trim();
        final value = line.substring(idx + 1).trim();
        switch (key) {
          case 'APP_ID':
          case 'agora.appId':
            appId = value;
            break;
          case 'APP_CERTIFICATE':
          case 'agora.appCertificate':
            appCertificate = value;
            break;
          case 'LLM_API_KEY':
          case 'agora.llmApiKey':
            llmApiKey = value;
            break;
          case 'LLM_URL':
          case 'agora.llmUrl':
            llmUrl = value;
            break;
          case 'LLM_MODEL':
          case 'agora.llmModel':
            llmModel = value;
            break;
          case 'TTS_BYTEDANCE_APP_ID':
          case 'agora.ttsBytedanceAppId':
            ttsBytedanceAppId = value;
            break;
          case 'TTS_BYTEDANCE_TOKEN':
          case 'agora.ttsBytedanceToken':
            ttsBytedanceToken = value;
            break;
        }
      }
    } catch (_) {
      // keep dart-define values as fallback
    }
  }
}

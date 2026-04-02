import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'keycenter.dart';

class AgentStarter {
  static const _jsonType = 'application/json; charset=utf-8';
  static const String _base =
      'https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects';

  static final Set<String> _sensitive = {
    'auth',
    'token',
    'password',
    'cert',
    'secret',
    'api_key',
    'appId',
    'app_id',
    'appCertificate',
  };

  static dynamic _mask(dynamic v) {
    if (v is Map) {
      return v.map((k, value) {
        final key = k.toString();
        if (_sensitive.contains(key)) {
          return MapEntry(key, '***');
        }
        return MapEntry(key, _mask(value));
      });
    } else if (v is List) {
      return v.map(_mask).toList();
    }
    return v;
  }

  static String _maskJson(String input) {
    try {
      final obj = jsonDecode(input);
      return jsonEncode(_mask(obj));
    } catch (_) {
      return input;
    }
  }

  static Map<String, dynamic> _buildJsonPayload({
    required String channelName,
    required String agentRtcUid,
    required String agentToken,
    required String remoteRtcUid,
  }) {
    return <String, dynamic>{
      'name': channelName,
      'properties': <String, dynamic>{
        'channel': channelName,
        'token': agentToken,
        'agent_rtc_uid': agentRtcUid,
        'remote_rtc_uids': <String>[remoteRtcUid],
        'enable_string_uid': false,
        'idle_timeout': 120,
        'advanced_features': <String, dynamic>{'enable_rtm': true},
        'asr': <String, dynamic>{
          'vendor': 'fengming',
          'language': 'zh-CN',
        },
        'llm': <String, dynamic>{
          'vendor': 'aliyun',
          'url': KeyCenter.llmUrl,
          'api_key': KeyCenter.llmApiKey,
          'system_messages': <Map<String, String>>[
            <String, String>{
              'role': 'system',
              'content': '你是一名有帮助的 AI 助手。',
            },
          ],
          'greeting_message': '你好！我是你的 AI 助手，有什么可以帮你？',
          'failure_message': '抱歉，我暂时处理不了你的请求，请稍后再试。',
          'params': <String, dynamic>{'model': KeyCenter.llmModel},
        },
        'tts': <String, dynamic>{
          'vendor': 'bytedance',
          'params': <String, dynamic>{
            'token': KeyCenter.ttsBytedanceToken,
            'app_id': KeyCenter.ttsBytedanceAppId,
            'cluster': 'volcano_tts',
            'voice_type': 'BV700_streaming',
            'speed_ratio': 1.0,
            'volume_ratio': 1.0,
            'pitch_ratio': 1.0,
          },
        },
        'parameters': <String, dynamic>{
          'data_channel': 'rtm',
          'enable_error_message': true,
        },
      },
    };
  }

  static Future<String> startAgent({
    required String channelName,
    required String agentRtcUid,
    required String agentToken,
    required String authToken,
    required String remoteRtcUid,
  }) async {
    final projectId = KeyCenter.appId;
    final url = Uri.parse('$_base/$projectId/join');
    final body = jsonEncode(
      _buildJsonPayload(
        channelName: channelName,
        agentRtcUid: agentRtcUid,
        agentToken: agentToken,
        remoteRtcUid: remoteRtcUid,
      ),
    );
    debugPrint('POST $url');
    debugPrint(
      'Headers: ${jsonEncode({'Authorization': '***', 'Content-Type': _jsonType})}',
    );
    debugPrint('Body: ${_maskJson(body)}');
    final resp = await _postWithRedirects(
      url,
      headers: <String, String>{
        'Authorization': 'agora token=$authToken',
        'Content-Type': _jsonType,
      },
      body: body,
    );
    debugPrint('Resp ${resp.statusCode} ${resp.reasonPhrase}');
    debugPrint(_maskJson(resp.body));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body);
      final agentId = (json['agent_id'] ?? '').toString();
      if (agentId.isEmpty) {
        throw Exception('agent_id empty');
      }
      return agentId;
    }
    throw Exception('Start agent error: ${resp.statusCode} ${resp.body}');
  }

  static Future<void> stopAgent(String agentId, String authToken) async {
    final projectId = KeyCenter.appId;
    final url = Uri.parse('$_base/$projectId/agents/$agentId/leave');
    debugPrint('POST $url');
    debugPrint(
      'Headers: ${jsonEncode({'Authorization': '***', 'Content-Type': _jsonType})}',
    );
    final resp = await _postWithRedirects(
      url,
      headers: <String, String>{
        'Authorization': 'agora token=$authToken',
        'Content-Type': _jsonType,
      },
      body: '',
    );
    debugPrint('Resp ${resp.statusCode} ${resp.reasonPhrase}');
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Stop agent error: ${resp.statusCode} ${resp.body}');
    }
  }

  static Future<http.Response> _postWithRedirects(
    Uri url, {
    required Map<String, String> headers,
    required String body,
    int maxRedirects = 3,
  }) async {
    var current = url;
    for (var i = 0; i <= maxRedirects; i++) {
      final resp = await http.post(current, headers: headers, body: body);
      final code = resp.statusCode;
      if (code == 308 || code == 307 || code == 302 || code == 301) {
        final loc = resp.headers['location'] ?? resp.headers['Location'];
        debugPrint('Redirect ($code) to: ${loc ?? "<none>"}');
        if (loc == null || loc.isEmpty) {
          return resp;
        }
        current = Uri.parse(loc);
        continue;
      }
      return resp;
    }
    return await http.post(current, headers: headers, body: body);
  }
}

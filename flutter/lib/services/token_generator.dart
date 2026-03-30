import 'dart:convert';
import 'package:http/http.dart' as http;
import 'keycenter.dart';

class TokenGenerator {
  static const _host = 'https://service.apprtc.cn/toolbox';

  static Future<String> generateUnifiedToken({required String channelName, required String uid}) async {
    final url = Uri.parse('$_host/v2/token/generate');
    final body = jsonEncode({
      'appId': KeyCenter.appId,
      'appCertificate': KeyCenter.appCertificate,
      'channelName': channelName,
      'expire': 60 * 60 * 24,
      'src': 'Flutter',
      'ts': DateTime.now().millisecondsSinceEpoch.toString(),
      'types': [1, 2],
      'uid': uid,
    });
    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
    }, body: body);
    if (resp.statusCode != 200) {
      throw Exception('Fetch token http ${resp.statusCode} ${resp.reasonPhrase}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if ((json['code'] ?? -1) != 0) {
      throw Exception('Token service error: ${json['code']} ${json['message']}');
    }
    final data = json['data'] as Map<String, dynamic>;
    return (data['token'] ?? '') as String;
  }
}

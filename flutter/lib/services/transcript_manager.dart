import 'dart:convert';

enum TranscriptType { user, agent }

enum TranscriptStatus { inProgress, end, interrupted, unknown }

class TranscriptItem {
  final String id;
  final TranscriptType type;
  final String text;
  final TranscriptStatus status;

  const TranscriptItem({
    required this.id,
    required this.type,
    required this.text,
    required this.status,
  });
}

class TranscriptManager {
  final List<TranscriptItem> items = [];

  bool upsert(TranscriptItem item) {
    final idx = items.indexWhere((e) => e.id == item.id && e.type == item.type);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    return true;
  }

  bool upsertFromJson(String json) {
    final parsed = _parseJson(json);
    if (parsed == null) return false;
    return upsert(parsed);
  }

  TranscriptItem? _parseJson(String json) {
    try {
      final obj = jsonDecode(json);
      if (obj is! Map<String, dynamic>) return null;
      final objType = (obj['object'] ?? '').toString();
      TranscriptType type;
      if (objType == 'assistant.transcription') {
        type = TranscriptType.agent;
      } else if (objType == 'user.transcription') {
        type = TranscriptType.user;
      } else {
        return null;
      }
      final idAny =
          obj['turn_id'] ??
          obj['message_id'] ??
          DateTime.now().microsecondsSinceEpoch;
      final id = idAny.toString();
      final text = (obj['text'] ?? '').toString();
      final statusCode = _asInt(obj['turn_status']);
      TranscriptStatus status;
      switch (statusCode) {
        case null:
          status = TranscriptStatus.inProgress;
          break;
        case 0:
          status = TranscriptStatus.inProgress;
          break;
        case 1:
          status = TranscriptStatus.end;
          break;
        case 2:
          status = TranscriptStatus.interrupted;
          break;
        default:
          status = TranscriptStatus.unknown;
      }
      return TranscriptItem(
        id: id,
        type: type,
        text: text.isEmpty ? '(empty)' : text,
        status: status,
      );
    } catch (_) {
      return null;
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

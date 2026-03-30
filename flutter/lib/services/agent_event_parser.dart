import 'dart:convert';

import 'package:agora_rtm/agora_rtm.dart';

class AgentStateChange {
  const AgentStateChange({
    required this.agentUserId,
    required this.state,
    required this.turnId,
    required this.timestamp,
  });

  final String agentUserId;
  final String state;
  final int turnId;
  final int timestamp;
}

class AgentError {
  const AgentError({
    required this.agentUserId,
    required this.module,
    required this.code,
    required this.message,
    required this.timestamp,
    this.turnId,
  });

  final String agentUserId;
  final String module;
  final int code;
  final String message;
  final int timestamp;
  final int? turnId;
}

class AgentEventParser {
  static String formatConsoleMessage(String rawMessage) {
    return rawMessage.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) {
        final int? codeUnit = int.tryParse(match.group(1)!, radix: 16);
        if (codeUnit == null) {
          return match.group(0)!;
        }
        return String.fromCharCode(codeUnit);
      },
    );
  }

  static AgentStateChange? parsePresenceEvent(
    PresenceEvent event, {
    required String currentChannelName,
    required int lastTurnId,
    required int lastTimestamp,
  }) {
    if (event.channelName != currentChannelName) {
      return null;
    }
    if (event.channelType != RtmChannelType.message) {
      return null;
    }
    if (event.type != RtmPresenceEventType.remoteStateChanged) {
      return null;
    }

    final Map<String, String> stateMap = <String, String>{
      for (final StateItem item in event.stateItems ?? <StateItem>[])
        if (item.key != null && item.value != null) item.key!: item.value!,
    };

    final String state = (stateMap['state'] ?? '').trim().toLowerCase();
    if (state.isEmpty) {
      return null;
    }

    final int turnId = int.tryParse(stateMap['turn_id'] ?? '') ?? 0;
    final int timestamp = event.timestamp ?? 0;
    if (turnId < lastTurnId) {
      return null;
    }
    if (timestamp <= lastTimestamp) {
      return null;
    }

    return AgentStateChange(
      agentUserId: event.publisher ?? '',
      state: state,
      turnId: turnId,
      timestamp: timestamp,
    );
  }

  static AgentError? parseMessageError(
    String rawMessage, {
    required String agentUserId,
  }) {
    try {
      final dynamic decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      if ((decoded['object'] ?? '').toString() != 'message.error') {
        return null;
      }

      return AgentError(
        agentUserId: agentUserId,
        module: (decoded['module'] ?? '').toString(),
        code: _asInt(decoded['code']) ?? -1,
        message: (decoded['message'] ?? 'Unknown error').toString(),
        timestamp: _asInt(decoded['send_ts']) ?? 0,
        turnId: _asInt(decoded['turn_id']),
      );
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

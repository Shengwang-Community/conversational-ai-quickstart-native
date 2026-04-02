import 'dart:convert';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'services/agent_starter.dart';
import 'services/agent_event_parser.dart';
import 'services/keycenter.dart';
import 'services/permission_service.dart';
import 'services/token_generator.dart';
import 'services/transcript_manager.dart';

enum AgentConnectionState { idle, connecting, connected, error }

class _ChatPalette {
  static const Color bgPrimary = Color(0xFF0F172A);
  static const Color bgSecondary = Color(0xFF1E293B);
  static const Color bgCard = Color(0x801E293B);
  static const Color bgControlBar = Color(0xCC1E293B);
  static const Color bgLogOuter = Color(0xCC0F172A);
  static const Color bgLogInner = Color(0x80020617);
  static const Color border = Color(0x80334155);

  static const Color textTitle = Colors.white;
  static const Color textSubtitle = Color(0xFFCBD5E1);
  static const Color textSecondary = Color(0xFF94A3B8);

  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color successGreenLight = Color(0xFF34D399);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedDark = Color(0xFFDC2626);
  static const Color errorRedLight = Color(0xFFF87171);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberLight = Color(0xFFFBBF24);

  static const Color stateIdle = Color(0xFF64748B);
  static const Color stateListening = Color(0xFF10B981);
  static const Color stateThinking = Color(0xFFF59E0B);
  static const Color stateSpeaking = Color(0xFF3B82F6);
  static const Color stateSilent = Color(0xFF475569);

  static const Color bubbleAgentBg = Color(0xFF334155);
  static const Color bubbleAgentText = Color(0xFFF1F5F9);
  static const Color bubbleUserBg = Color(0xFF2563EB);
  static const Color bubbleUserText = Colors.white;

  static const Color buttonStart = Color(0xFF2563EB);
  static const Color buttonStartPressed = Color(0xFF3B82F6);
  static const Color buttonStop = Color(0xFFDC2626);
  static const Color buttonStopPressed = Color(0xFFEF4444);
  static const Color buttonDisabled = Color(0xFF334155);
  static const Color buttonDisabledText = Color(0xFF94A3B8);

  static const Color micNormalBg = Color(0xFF334155);
  static const Color micNormalPressed = Color(0xFF475569);
  static const Color micNormalIcon = Color(0xFFCBD5E1);
  static const Color micMutedBg = Color(0x33EF4444);
  static const Color micMutedIcon = Color(0xFFF87171);
}

class AgentChatPage extends StatefulWidget {
  const AgentChatPage({super.key});

  @override
  State<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends State<AgentChatPage> {
  late final int userUid = _generateRandomUid();
  late final int agentUid = _generateUniqueUid(userUid);

  final TranscriptManager transcriptMgr = TranscriptManager();
  final List<String> debugLogs = <String>[];
  final ScrollController _logCtrl = ScrollController();
  final ScrollController _transcriptCtrl = ScrollController();

  AgentConnectionState connectionState = AgentConnectionState.idle;
  bool isMuted = false;
  String agentStateText = 'Idle';
  String channelName = '';
  String? agentId;
  String? authToken;
  RtcEngine? _rtc;
  RtmClient? _rtm;
  int _lastAgentStateTurnId = -1;
  int _lastAgentStateTimestamp = -1;

  bool get _hasRemoteAgentReference {
    return agentId != null &&
        agentId!.isNotEmpty &&
        authToken != null &&
        authToken!.isNotEmpty;
  }

  int _generateRandomUid() {
    return 100000 + Random().nextInt(900000);
  }

  int _generateUniqueUid(int excludeUid) {
    int uid;
    do {
      uid = _generateRandomUid();
    } while (uid == excludeUid);
    return uid;
  }

  String _randomChannel() {
    final int suffix = 100000 + Random().nextInt(900000);
    return 'channel_flutter_$suffix';
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    setState(fn);
  }

  void _addLog(String message) {
    if (debugLogs.length >= 20) {
      debugLogs.removeAt(0);
    }
    debugLogs.add(message);
  }

  void _scheduleAutoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logCtrl.hasClients) {
        _logCtrl.jumpTo(_logCtrl.position.maxScrollExtent);
      }
      if (_transcriptCtrl.hasClients) {
        _transcriptCtrl.jumpTo(_transcriptCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _applyRtcAudioBestPractices() async {
    final RtcEngine? engine = _rtc;
    if (engine == null) {
      return;
    }

    await engine.enableAudio();
    await engine.setAudioScenario(AudioScenarioType.audioScenarioAiClient);
    await _applyRtcAudioRouteParameters(AudioRoute.routeSpeakerphone.value());
  }

  Future<void> _applyRtcAudioRouteParameters(int routing) async {
    final RtcEngine? engine = _rtc;
    if (engine == null) {
      return;
    }

    await engine.setParameters('{"che.audio.aec.split_srate_for_48k":16000}');
    await engine.setParameters('{"che.audio.sf.enabled":true}');
    await engine.setParameters('{"che.audio.sf.stftType":6}');
    await engine.setParameters('{"che.audio.sf.ainlpLowLatencyFlag":1}');
    await engine.setParameters('{"che.audio.sf.ainsLowLatencyFlag":1}');
    await engine.setParameters('{"che.audio.sf.procChainMode":1}');
    await engine.setParameters('{"che.audio.sf.nlpDynamicMode":1}');
    await engine.setParameters(
      '{"che.audio.sf.nlpAlgRoute":${_isHeadsetStyleRoute(routing) ? 0 : 1}}',
    );
  }

  bool _isHeadsetStyleRoute(int routing) {
    return routing == AudioRoute.routeHeadset.value() ||
        routing == AudioRoute.routeEarpiece.value() ||
        routing == AudioRoute.routeHeadsetnomic.value() ||
        routing == AudioRoute.routeBluetoothDeviceHfp.value() ||
        routing == AudioRoute.routeBluetoothDeviceA2dp.value();
  }

  String _audioRouteLabel(int routing) {
    switch (routing) {
      case 0:
        return 'headset';
      case 1:
        return 'earpiece';
      case 2:
        return 'headset-no-mic';
      case 3:
        return 'speakerphone';
      case 4:
        return 'loudspeaker';
      case 5:
        return 'bluetooth-hfp';
      case 10:
        return 'bluetooth-a2dp';
      default:
        return 'route-$routing';
    }
  }

  Future<void> _handleAudioRoutingChanged(int routing) async {
    try {
      await _applyRtcAudioRouteParameters(routing);
      _safeSetState(() {
        _addLog('RTC 音频路由切换: ${_audioRouteLabel(routing)}');
      });
    } catch (e) {
      _safeSetState(() {
        _addLog('RTC 音频路由配置失败: $e');
      });
    }
  }

  Future<bool> _stopRemoteAgentIfNeeded({
    required String successLog,
    required String failureLogPrefix,
  }) async {
    final String? currentAgentId = agentId;
    final String? currentAuthToken = authToken;
    if (currentAgentId == null ||
        currentAgentId.isEmpty ||
        currentAuthToken == null ||
        currentAuthToken.isEmpty) {
      return true;
    }

    try {
      await AgentStarter.stopAgent(currentAgentId, currentAuthToken);
      _safeSetState(() {
        _addLog(successLog);
      });
      agentId = null;
      authToken = null;
      return true;
    } catch (e) {
      _safeSetState(() {
        _addLog('$failureLogPrefix: $e');
      });
      return false;
    }
  }

  Future<void> _cleanupLocalSession() async {
    final RtmClient? rtm = _rtm;
    final RtcEngine? rtc = _rtc;
    final String activeChannel = channelName;

    _rtm = null;
    _rtc = null;

    if (rtm != null) {
      if (activeChannel.isNotEmpty) {
        try {
          await rtm.unsubscribe(activeChannel);
        } catch (e) {
          _safeSetState(() {
            _addLog('RTM unsubscribe 失败: $e');
          });
        }
      }

      try {
        await rtm.logout();
      } catch (e) {
        _safeSetState(() {
          _addLog('RTM logout 失败: $e');
        });
      }
    }

    if (rtc != null) {
      try {
        await rtc.leaveChannel();
      } catch (e) {
        _safeSetState(() {
          _addLog('RTC leaveChannel 失败: $e');
        });
      }

      try {
        await rtc.release();
      } catch (e) {
        _safeSetState(() {
          _addLog('RTC release 失败: $e');
        });
      }
    }
  }

  void _resetSessionUi(
    AgentConnectionState nextState, {
    required bool clearRemoteAgentReference,
  }) {
    _safeSetState(() {
      connectionState = nextState;
      isMuted = false;
      agentStateText = 'Idle';
      channelName = '';
      if (clearRemoteAgentReference) {
        agentId = null;
        authToken = null;
      }
      _lastAgentStateTurnId = -1;
      _lastAgentStateTimestamp = -1;
      transcriptMgr.items.clear();
    });
  }

  Future<void> _startFlow() async {
    if (connectionState == AgentConnectionState.connecting) {
      return;
    }

    final String appId = KeyCenter.appId;
    final bool isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    _safeSetState(() {
      connectionState = AgentConnectionState.connecting;
      agentStateText = 'Idle';
      _lastAgentStateTurnId = -1;
      _lastAgentStateTimestamp = -1;
      _addLog('Starting...');
    });

    try {
      if (_rtc != null || _rtm != null) {
        _safeSetState(() {
          _addLog('检测到残留本地会话，正在清理');
        });
        await _cleanupLocalSession();
      }

      if (_hasRemoteAgentReference) {
        _safeSetState(() {
          _addLog('检测到未停止的远端 Agent，正在重试 stop');
        });
        final bool cleanedUpRemoteAgent = await _stopRemoteAgentIfNeeded(
          successLog: '已清理上次残留的远端 Agent',
          failureLogPrefix: '清理上次残留的远端 Agent 失败',
        );
        if (!cleanedUpRemoteAgent) {
          _resetSessionUi(
            AgentConnectionState.error,
            clearRemoteAgentReference: false,
          );
          return;
        }
      }

      final String nextChannelName = _randomChannel();
      _safeSetState(() {
        channelName = nextChannelName;
        agentId = null;
        authToken = null;
        transcriptMgr.items.clear();
      });

      if (!isMobile) {
        _safeSetState(() {
          connectionState = AgentConnectionState.error;
          _addLog('当前平台不支持 RTC/RTM 插件');
        });
        return;
      }

      if (!mounted) {
        return;
      }

      final bool granted = await PermissionService.ensureMicrophoneGranted(
        context,
      );
      if (!granted) {
        _safeSetState(() {
          connectionState = AgentConnectionState.error;
          _addLog('麦克风权限未授予');
        });
        return;
      }

      _rtc = createAgoraRtcEngine();
      await _rtc!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _safeSetState(() {
        _addLog('RtcEngine 初始化成功');
      });

      _rtc!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            _safeSetState(() {
              _addLog('RTC 加入成功 channelId：${connection.channelId} localUid：${connection.localUid}');
            });
          },
          onError: (ErrorCodeType code, String message) {
            _safeSetState(() {
              connectionState = AgentConnectionState.error;
              _addLog('RTC 错误 ${code.index}');
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            _safeSetState(() {
              _addLog('RTC onUserJoined uid:$remoteUid');
            });
          },
          onAudioRoutingChanged: (int routing) {
            _handleAudioRoutingChanged(routing);
          },
        ),
      );

      try {
        await _applyRtcAudioBestPractices();
      } catch (_) {}

      late final String userToken;
      try {
        userToken = await TokenGenerator.generateUnifiedToken(
          channelName: channelName,
          uid: userUid.toString(),
        );
        _safeSetState(() {
          _addLog('获取 Token 成功');
        });
      } catch (e) {
        _safeSetState(() {
          _addLog('获取 Token 失败: $e');
        });
        rethrow;
      }

      await _rtc!.joinChannel(
        token: userToken,
        channelId: channelName,
        uid: userUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      await _rtc?.adjustRecordingSignalVolume(100);
      _safeSetState(() {
        isMuted = false;
        _addLog('joinChannel 调用完成');
        _addLog('已自动开麦');
      });

      try {
        final result = await RTM(appId, userUid.toString());
        _rtm = result.$2;
        _safeSetState(() {
          _addLog('RtmClient 初始化成功');
        });
      } catch (e) {
        _safeSetState(() {
          _addLog('RtmClient 初始化失败: $e');
        });
        rethrow;
      }

      _rtm!.addListener(
        message: (event) {
          final String text = utf8.decode(event.message ?? <int>[]);
          final String readableText = AgentEventParser.formatConsoleMessage(
            text,
          );
          debugPrint('RTM 收到消息: $readableText');
          final AgentError? agentError = AgentEventParser.parseMessageError(
            text,
            agentUserId: event.publisher ?? '',
          );
          final bool updated = transcriptMgr.upsertFromJson(text);
          if (updated || agentError != null) {
            _safeSetState(() {
              if (agentError != null) {
                _addLog(
                  'Agent error: type=${agentError.module}, code=${agentError.code}, msg=${agentError.message}',
                );
              }
            });
          }
        },
        linkState: (event) {
          _safeSetState(() {
            _addLog('RTM ${event.previousState} -> ${event.currentState}');
          });
        },
        presence: (event) {
          final AgentStateChange? stateChange =
              AgentEventParser.parsePresenceEvent(
            event,
            currentChannelName: channelName,
            lastTurnId: _lastAgentStateTurnId,
            lastTimestamp: _lastAgentStateTimestamp,
          );
          if (stateChange == null) {
            return;
          }
          _safeSetState(() {
            _lastAgentStateTurnId = stateChange.turnId;
            _lastAgentStateTimestamp = stateChange.timestamp;
            agentStateText = stateChange.state;
          });
        },
      );

      try {
        _safeSetState(() {
          _addLog('rtmLogin 调用');
        });
        await _rtm!.login(userToken);
        _safeSetState(() {
          _addLog('rtmLogin 成功');
        });
      } catch (e) {
        _safeSetState(() {
          _addLog('rtmLogin 失败: $e');
        });
        rethrow;
      }

      await _rtm!.subscribe(channelName);

      late final String agentToken;
      try {
        agentToken = await TokenGenerator.generateUnifiedToken(
          channelName: channelName,
          uid: agentUid.toString(),
        );
        _safeSetState(() {
          _addLog('获取 Agent Token 成功');
        });
      } catch (e) {
        _safeSetState(() {
          _addLog('获取 Agent Token 失败: $e');
        });
        rethrow;
      }

      late final String restAuthToken;
      try {
        restAuthToken = await TokenGenerator.generateUnifiedToken(
          channelName: channelName,
          uid: agentUid.toString(),
        );
        _safeSetState(() {
          _addLog('获取 REST Auth Token 成功');
        });
      } catch (e) {
        _safeSetState(() {
          _addLog('获取 REST Auth Token 失败: $e');
        });
        rethrow;
      }

      try {
        _safeSetState(() {
          _addLog('Agent Start 调用');
        });
        agentId = await AgentStarter.startAgent(
          channelName: channelName,
          agentRtcUid: agentUid.toString(),
          agentToken: agentToken,
          authToken: restAuthToken,
          remoteRtcUid: userUid.toString(),
        );
        _safeSetState(() {
          authToken = restAuthToken;
          _addLog('Agent Start 成功');
        });
      } catch (e) {
        _safeSetState(() {
          _addLog('Agent Start 失败: $e');
        });
        rethrow;
      }

      _safeSetState(() {
        connectionState = AgentConnectionState.connected;
        agentStateText = 'Idle';
        _addLog('Agent start successfully');
      });
    } catch (e) {
      _safeSetState(() {
        _addLog('连接失败 $e');
      });
      await _cleanupLocalSession();
      final bool cleanedUpRemoteAgent = await _stopRemoteAgentIfNeeded(
        successLog: '启动失败后的远端 Agent 已停止',
        failureLogPrefix: '启动失败后停止远端 Agent 失败',
      );
      _resetSessionUi(
        AgentConnectionState.error,
        clearRemoteAgentReference: cleanedUpRemoteAgent,
      );
    }
  }

  Future<void> _toggleMute() async {
    final bool nextMuted = !isMuted;
    await _rtc?.adjustRecordingSignalVolume(nextMuted ? 0 : 100);
    _safeSetState(() {
      isMuted = nextMuted;
    });
  }

  Future<void> _hangup() async {
    await _cleanupLocalSession();
    final bool remoteAgentStopped = await _stopRemoteAgentIfNeeded(
      successLog: 'Agent stopped successfully',
      failureLogPrefix: 'Stop Agent 失败',
    );

    _resetSessionUi(
      remoteAgentStopped
          ? AgentConnectionState.idle
          : AgentConnectionState.error,
      clearRemoteAgentReference: remoteAgentStopped,
    );

    if (!remoteAgentStopped) {
      _safeSetState(() {
        _addLog('本地连接已清理，请重试停止远端 Agent');
      });
    }
  }

  Color _logColor(String message) {
    final String lower = message.toLowerCase();
    if (lower.contains('failed') || lower.contains('error')) {
      return _ChatPalette.errorRedLight;
    }
    if (lower.contains('success') || lower.contains('成功')) {
      return _ChatPalette.successGreenLight;
    }
    if (lower.contains('connecting') ||
        lower.contains('starting') ||
        lower.contains('调用')) {
      return _ChatPalette.warningAmberLight;
    }
    return _ChatPalette.textSecondary;
  }

  TextSpan _buildLogSpan() {
    final TextStyle baseStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.45,
    );

    if (debugLogs.isEmpty) {
      return TextSpan(
        text: 'log',
        style: baseStyle.copyWith(color: _ChatPalette.textSecondary),
      );
    }

    final List<InlineSpan> children = <InlineSpan>[];
    for (int index = 0; index < debugLogs.length; index++) {
      final String line = debugLogs[index];
      children.add(
        TextSpan(
          text: line,
          style: baseStyle.copyWith(color: _logColor(line)),
        ),
      );
      if (index < debugLogs.length - 1) {
        children.add(const TextSpan(text: '\n'));
      }
    }
    return TextSpan(children: children);
  }

  String get _startButtonLabel {
    switch (connectionState) {
      case AgentConnectionState.connecting:
        return 'Connecting...';
      case AgentConnectionState.error:
        return 'Retry';
      case AgentConnectionState.connected:
      case AgentConnectionState.idle:
        return 'Start Agent';
    }
  }

  Color get _startButtonColor {
    switch (connectionState) {
      case AgentConnectionState.connecting:
        return _ChatPalette.buttonDisabled;
      case AgentConnectionState.error:
        return _ChatPalette.errorRedDark;
      case AgentConnectionState.connected:
      case AgentConnectionState.idle:
        return _ChatPalette.buttonStart;
    }
  }

  Color get _startButtonPressedColor {
    switch (connectionState) {
      case AgentConnectionState.connecting:
        return _ChatPalette.buttonDisabled;
      case AgentConnectionState.error:
        return _ChatPalette.errorRed;
      case AgentConnectionState.connected:
      case AgentConnectionState.idle:
        return _ChatPalette.buttonStartPressed;
    }
  }

  Color get _startButtonTextColor {
    return connectionState == AgentConnectionState.connecting
        ? _ChatPalette.buttonDisabledText
        : Colors.white;
  }

  String get _statusLabel {
    if (connectionState == AgentConnectionState.connecting) {
      return 'Connecting';
    }
    if (connectionState == AgentConnectionState.error) {
      return 'Error';
    }
    if (agentStateText.isEmpty) {
      return 'Idle';
    }
    return agentStateText[0].toUpperCase() + agentStateText.substring(1);
  }

  Color get _statusColor {
    if (connectionState == AgentConnectionState.connecting) {
      return _ChatPalette.warningAmber;
    }
    if (connectionState == AgentConnectionState.error) {
      return _ChatPalette.errorRedLight;
    }

    switch (agentStateText.toLowerCase()) {
      case 'listening':
        return _ChatPalette.stateListening;
      case 'thinking':
        return _ChatPalette.stateThinking;
      case 'speaking':
        return _ChatPalette.stateSpeaking;
      case 'silent':
        return _ChatPalette.stateSilent;
      case 'idle':
      default:
        return _ChatPalette.stateIdle;
    }
  }

  ButtonStyle _buttonStyle({
    required Color color,
    required Color pressedColor,
    required Color foregroundColor,
    Color? disabledColor,
    Color? disabledForegroundColor,
    bool circular = false,
  }) {
    return ButtonStyle(
      elevation: WidgetStateProperty.all<double>(0),
      padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
        circular ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
      ),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabledColor ?? color;
        }
        if (states.contains(WidgetState.pressed)) {
          return pressedColor;
        }
        return color;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabledForegroundColor ?? foregroundColor;
        }
        return foregroundColor;
      }),
      shape: WidgetStateProperty.all<OutlinedBorder>(
        circular
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: WidgetStateProperty.all<TextStyle>(
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Text(
          'Shengwang Conversational AI',
          style: TextStyle(
            color: _ChatPalette.textTitle,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Real-time Voice Conversation Demo',
          style: TextStyle(color: _ChatPalette.textSubtitle, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildLogCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _ChatPalette.bgLogOuter,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ChatPalette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Container(
          color: _ChatPalette.bgLogInner,
          padding: const EdgeInsets.all(12),
          child: SizedBox.expand(
            child: Scrollbar(
              controller: _logCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _logCtrl,
                child: SizedBox(
                  width: double.infinity,
                  child: Text.rich(_buildLogSpan()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptItem(BuildContext context, TranscriptItem item) {
    final bool isUser = item.type == TranscriptType.user;
    final double maxBubbleWidth = MediaQuery.of(context).size.width * 0.62;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 56 : 12,
        right: isUser ? 12 : 56,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isUser) _buildAvatar('AI', _ChatPalette.accentBlue, 12),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? _ChatPalette.bubbleUserBg
                      : _ChatPalette.bubbleAgentBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isUser ? 16 : 2),
                    topRight: Radius.circular(isUser ? 2 : 16),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: const Radius.circular(16),
                  ),
                ),
                child: Text(
                  item.text,
                  style: TextStyle(
                    color: isUser
                        ? _ChatPalette.bubbleUserText
                        : _ChatPalette.bubbleAgentText,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildAvatar('Me', _ChatPalette.successGreen, 11),
        ],
      ),
    );
  }

  Widget _buildAvatar(String label, Color color, double fontSize) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTranscriptCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _ChatPalette.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ChatPalette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Scrollbar(
                controller: _transcriptCtrl,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _transcriptCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: transcriptMgr.items.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _buildTranscriptItem(
                      context,
                      transcriptMgr.items[index],
                    );
                  },
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: _ChatPalette.bgControlBar,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final bool isConnected = connectionState == AgentConnectionState.connected;
    final bool isConnecting =
        connectionState == AgentConnectionState.connecting;

    if (!isConnected) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isConnecting ? null : _startFlow,
          style: _buttonStyle(
            color: _startButtonColor,
            pressedColor: _startButtonPressedColor,
            foregroundColor: _startButtonTextColor,
            disabledColor: _ChatPalette.buttonDisabled,
            disabledForegroundColor: _ChatPalette.buttonDisabledText,
          ),
          child: Text(_startButtonLabel),
        ),
      );
    }

    return Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          height: 56,
          child: ElevatedButton(
            onPressed: _toggleMute,
            style: _buttonStyle(
              color:
                  isMuted ? _ChatPalette.micMutedBg : _ChatPalette.micNormalBg,
              pressedColor: isMuted
                  ? _ChatPalette.micMutedBg
                  : _ChatPalette.micNormalPressed,
              foregroundColor: isMuted
                  ? _ChatPalette.micMutedIcon
                  : _ChatPalette.micNormalIcon,
              circular: true,
            ),
            child: Icon(isMuted ? Icons.mic_off : Icons.mic, size: 24),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _hangup,
              style: _buttonStyle(
                color: _ChatPalette.buttonStop,
                pressedColor: _ChatPalette.buttonStopPressed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Stop Agent'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _logCtrl.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleAutoScroll();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              _ChatPalette.bgPrimary,
              _ChatPalette.bgSecondary,
              _ChatPalette.bgPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildTitleSection(),
                const SizedBox(height: 12),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Expanded(flex: 3, child: _buildLogCard()),
                      const SizedBox(height: 8),
                      Expanded(flex: 7, child: _buildTranscriptCard(context)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

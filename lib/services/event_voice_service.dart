import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventVoiceParticipant {
  final String identity;
  final String? name;
  final bool isSpeaking;
  final bool micEnabled;
  final double audioLevel;

  EventVoiceParticipant({
    required this.identity,
    this.name,
    this.isSpeaking = false,
    this.micEnabled = false,
    this.audioLevel = 0.0,
  });
}

enum ConnectionQuality { excellent, good, fair, poor, unknown }

class EventVoiceService extends ChangeNotifier {
  static EventVoiceService? _instance;
  static EventVoiceService get instance => _instance ??= EventVoiceService._();

  EventVoiceService._();

  Room? _room;
  String? _channelId;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isMuted = true;
  bool _pushToTalkActive = false;
  bool _alwaysOnMode = false;
  bool _backgroundAudioEnabled = true;
  String? _lastError;
  List<EventVoiceParticipant> _participants = [];
  ConnectionQuality _connectionQuality = ConnectionQuality.unknown;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  Timer? _audioLevelTimer;
  double _localAudioLevel = 0.0;

  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get pushToTalkActive => _pushToTalkActive;
  bool get alwaysOnMode => _alwaysOnMode;
  bool get backgroundAudioEnabled => _backgroundAudioEnabled;
  String? get lastError => _lastError;
  String? get channelId => _channelId;
  List<EventVoiceParticipant> get participants => _participants;
  int get participantCount => _participants.length;
  ConnectionQuality get connectionQuality => _connectionQuality;
  double get localAudioLevel => _localAudioLevel;

  void setAlwaysOnMode(bool value) {
    _alwaysOnMode = value;
    if (_isConnected) {
      _setMicEnabled(_alwaysOnMode);
    }
    notifyListeners();
  }

  void setBackgroundAudioEnabled(bool value) {
    _backgroundAudioEnabled = value;
    notifyListeners();
  }

  String get connectionQualityLabel {
    switch (_connectionQuality) {
      case ConnectionQuality.excellent: return 'Excellent';
      case ConnectionQuality.good: return 'Good';
      case ConnectionQuality.fair: return 'Fair';
      case ConnectionQuality.poor: return 'Poor';
      case ConnectionQuality.unknown: return 'Connecting...';
    }
  }

  Future<bool> connect(String channelId) async {
    if (_isConnected && _channelId == channelId) return true;

    await disconnect();

    _isConnecting = true;
    _channelId = channelId;
    _lastError = null;
    _reconnectAttempts = 0;
    notifyListeners();

    return await _doConnect(channelId);
  }

  Future<bool> _doConnect(String channelId) async {
    try {
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        _lastError = 'Microphone permission is required for voice chat';
        _isConnecting = false;
        _channelId = null;
        notifyListeners();
        return false;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'event-voice-token',
        body: {'channelId': channelId},
      );

      final data = response.data;
      if (data is! Map) {
        _lastError = 'Could not start voice chat';
        _isConnecting = false;
        _notifyFailure();
        return false;
      }

      final livekitUrl = data['url'] as String?;
      final token = data['token'] as String?;

      if (livekitUrl == null || token == null) {
        _lastError = data['error'] as String? ?? 'Could not start voice chat';
        _isConnecting = false;
        _notifyFailure();
        return false;
      }

      final room = Room();
      await room.connect(livekitUrl, token);

      await room.localParticipant?.setMicrophoneEnabled(false);

      room.addListener(() => _syncRoomState(room));

      _room = room;
      _isConnected = true;
      _isMuted = true;
      _isConnecting = false;
      _pushToTalkActive = false;
      _connectionQuality = ConnectionQuality.excellent;
      _reconnectAttempts = 0;

      _startAudioLevelMonitoring();
      _updateParticipants(room);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('EventVoiceService connect error');
      _lastError = 'Could not connect to voice channel';
      _isConnecting = false;
      _notifyFailure();
      return false;
    }
  }

  void _notifyFailure() {
    _scheduleReconnect();
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_channelId == null) return;
    if (_reconnectAttempts >= 5) {
      _lastError = 'Connection lost. Please rejoin the channel.';
      _isConnected = false;
      notifyListeners();
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_isConnected || _channelId == null) return;
      debugPrint(['Reconnect attempt ', _reconnectAttempts.toString()].join());
      await _doConnect(_channelId!);
    });
  }

  void _syncRoomState(Room room) {
    if (_room != room) return;

    final connected = room.connectionState == ConnectionState.connected;
    final reconnecting = room.connectionState == ConnectionState.reconnecting;

    if (connected) {
      _connectionQuality = _getConnectionQuality(room);
      _reconnectAttempts = 0;
    } else if (reconnecting) {
      _connectionQuality = ConnectionQuality.fair;
    } else {
      _connectionQuality = ConnectionQuality.poor;
      if (!_isConnecting) {
        _isConnected = false;
        _isMuted = true;
        _pushToTalkActive = false;
        _scheduleReconnect();
      }
    }

    _updateParticipants(room);
    notifyListeners();
  }

  ConnectionQuality _getConnectionQuality(Room room) {
    try {
      final quality = room.engine.connectionState;
      if (quality == ConnectionState.connected) {
        return ConnectionQuality.excellent;
      }
    } catch (_) {}
    return ConnectionQuality.good;
  }

  void _startAudioLevelMonitoring() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_room == null || !_isConnected) return;

      // Get local audio level
      try {
        final localTrack = _room?.localParticipant?.audioTrackPublications
            .where((p) => p.track != null)
            .firstOrNull;
        if (localTrack?.track != null) {
          _localAudioLevel = 0.5 + (DateTime.now().millisecond % 100) / 200.0;
        } else {
          _localAudioLevel = 0.0;
        }
      } catch (_) {
        _localAudioLevel = 0.0;
      }

      _updateParticipants(_room!);
      notifyListeners();
    });
  }

  void _updateParticipants(Room room) {
    final list = <EventVoiceParticipant>[];

    final local = room.localParticipant;
    if (local != null) {
      list.add(EventVoiceParticipant(
        identity: local.identity,
        name: local.name,
        isSpeaking: local.isSpeaking,
        micEnabled: !_isMuted,
        audioLevel: _localAudioLevel,
      ));
    }

    for (final participant in room.remoteParticipants.values) {
      list.add(EventVoiceParticipant(
        identity: participant.identity,
        name: participant.name,
        isSpeaking: participant.isSpeaking,
        micEnabled: participant.audioTrackPublications.isNotEmpty,
        audioLevel: participant.isSpeaking ? 0.6 : 0.0,
      ));
    }

    _participants = list;
  }

  Future<void> startPushToTalk() async {
    if (!_isConnected || _room == null) return;
    if (_alwaysOnMode) return;

    _pushToTalkActive = true;
    await _setMicEnabled(true);
    notifyListeners();
  }

  Future<void> stopPushToTalk() async {
    if (!_isConnected || _room == null) return;
    if (_alwaysOnMode) return;

    _pushToTalkActive = false;
    await _setMicEnabled(false);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (!_isConnected || _room == null) return;
    final nextMuted = !_isMuted;
    await _setMicEnabled(!nextMuted);
    notifyListeners();
  }

  Future<void> _setMicEnabled(bool enabled) async {
    if (_room == null) return;
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(enabled);
      _isMuted = !enabled;
    } catch (e) {
      debugPrint('EventVoiceService mic error');
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _audioLevelTimer?.cancel();

    final room = _room;
    _room = null;

    try {
      await room?.localParticipant?.setMicrophoneEnabled(false);
      await room?.disconnect();
      await room?.dispose();
    } catch (e) {
      debugPrint('EventVoiceService disconnect error');
    }

    _channelId = null;
    _isConnecting = false;
    _isConnected = false;
    _isMuted = true;
    _pushToTalkActive = false;
    _participants = [];
    _connectionQuality = ConnectionQuality.unknown;
    _localAudioLevel = 0.0;
    _reconnectAttempts = 0;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveRideVoiceService extends ChangeNotifier {
  static LiveRideVoiceService? _instance;
  static LiveRideVoiceService get instance =>
      _instance ??= LiveRideVoiceService._();

  LiveRideVoiceService._();

  Room? _room;
  String? _sessionId;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isMuted = false;
  String? _lastError;

  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  String? get lastError => _lastError;
  String? get sessionId => _sessionId;

  Future<bool> connect(String sessionId) async {
    if (_isConnected && _sessionId == sessionId) return true;

    await disconnect();

    _isConnecting = true;
    _lastError = null;
    _sessionId = sessionId;
    notifyListeners();

    try {
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        _lastError = 'Microphone permission is required for voice chat';
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'livekit-token',
        body: {'sessionId': sessionId},
      );

      final data = response.data;
      if (data is! Map) {
        _lastError = 'Could not start voice chat';
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      final livekitUrl = data['url'] as String?;
      final token = data['token'] as String?;

      if (livekitUrl == null || token == null) {
        _lastError = data['error'] as String? ?? 'Could not start voice chat';
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      final room = Room();
      await room.connect(livekitUrl, token);
      await room.localParticipant?.setMicrophoneEnabled(true);

      _room = room;
      _isConnected = true;
      _isMuted = false;
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('LiveRideVoiceService.connect error: $e');
      debugPrintStack(stackTrace: stack);
      _lastError = e.toString();
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleMute() async {
    if (!_isConnected || _room == null) return;

    final nextMuted = !_isMuted;
    await _room!.localParticipant?.setMicrophoneEnabled(!nextMuted);
    _isMuted = nextMuted;
    notifyListeners();
  }

  Future<void> disconnect() async {
    final room = _room;
    _room = null;

    try {
      await room?.localParticipant?.setMicrophoneEnabled(false);
      await room?.disconnect();
      room?.dispose();
    } catch (e) {
      debugPrint('LiveRideVoiceService.disconnect error: $e');
    }

    _sessionId = null;
    _isConnecting = false;
    _isConnected = false;
    _isMuted = false;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'diagnostics_service.dart';
import 'premium_service.dart';

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

    Room? pendingRoom;
    try {
      await PremiumService().refresh();
      if (!PremiumService().isPremium) {
        _lastError = 'Premium subscription required for voice chat';
        await DiagnosticsService.instance.logError(
          feature: 'live_ride_voice',
          action: 'connect_premium_required',
          error: _lastError!,
          context: {'session_id': sessionId},
          severity: 'warning',
        );
        _isConnecting = false;
        _sessionId = null;
        notifyListeners();
        return false;
      }

      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        _lastError = 'Microphone permission is required for voice chat';
        await DiagnosticsService.instance.logError(
          feature: 'live_ride_voice',
          action: 'microphone_permission_denied',
          error: _lastError!,
          context: {
            'session_id': sessionId,
            'permission_status': micPermission.name,
          },
          severity: 'warning',
        );
        _isConnecting = false;
        _sessionId = null;
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
        await DiagnosticsService.instance.logError(
          feature: 'live_ride_voice',
          action: 'token_response_invalid',
          error: 'LiveKit token response was not a map',
          context: {
            'session_id': sessionId,
            'response_type': data.runtimeType.toString(),
          },
        );
        _isConnecting = false;
        _sessionId = null;
        notifyListeners();
        return false;
      }

      final livekitUrl = data['url'] as String?;
      final token = data['token'] as String?;

      if (livekitUrl == null || token == null) {
        _lastError = data['error'] as String? ?? 'Could not start voice chat';
        await DiagnosticsService.instance.logError(
          feature: 'live_ride_voice',
          action: 'token_missing',
          error: _lastError!,
          context: {
            'session_id': sessionId,
            'has_url': livekitUrl != null,
            'has_token': token != null,
          },
        );
        _isConnecting = false;
        _sessionId = null;
        notifyListeners();
        return false;
      }

      final room = Room();
      pendingRoom = room;
      await room.connect(livekitUrl, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      room.addListener(() => _syncRoomState(room));

      _room = room;
      _isConnected = true;
      _isMuted = false;
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('LiveRideVoiceService.connect error: $e');
      debugPrintStack(stackTrace: stack);
      await DiagnosticsService.instance.logError(
        feature: 'live_ride_voice',
        action: 'connect',
        error: e,
        stackTrace: stack,
        context: {'session_id': sessionId},
      );
      try {
        await pendingRoom?.localParticipant?.setMicrophoneEnabled(false);
        await pendingRoom?.disconnect();
        await pendingRoom?.dispose();
      } catch (_) {}
      _lastError = e.toString();
      _isConnecting = false;
      _isConnected = false;
      _sessionId = null;
      notifyListeners();
      return false;
    }
  }

  void _syncRoomState(Room room) {
    if (_room != room) return;

    final isConnected =
        room.connectionState == ConnectionState.connected ||
        room.connectionState == ConnectionState.reconnecting;
    if (_isConnected == isConnected) return;

    _isConnected = isConnected;
    if (!isConnected) {
      _isMuted = false;
      _sessionId = null;
    }
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (!_isConnected || _room == null) return;

    final nextMuted = !_isMuted;
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(!nextMuted);
      _isMuted = nextMuted;
      notifyListeners();
    } catch (e) {
      debugPrint('LiveRideVoiceService.toggleMute error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride_voice',
        action: 'toggle_mute',
        error: e,
        context: {'session_id': _sessionId},
        severity: 'warning',
      );
      _lastError = 'Could not update microphone state';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    final room = _room;
    _room = null;

    try {
      await room?.localParticipant?.setMicrophoneEnabled(false);
      await room?.disconnect();
      await room?.dispose();
    } catch (e) {
      debugPrint('LiveRideVoiceService.disconnect error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride_voice',
        action: 'disconnect',
        error: e,
        context: {'session_id': _sessionId},
        severity: 'warning',
      );
    }

    _sessionId = null;
    _isConnecting = false;
    _isConnected = false;
    _isMuted = false;
    notifyListeners();
  }
}

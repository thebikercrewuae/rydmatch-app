import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'diagnostics_service.dart';

class RiderLocation {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final DateTime updatedAt;

  RiderLocation({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    required this.updatedAt,
  });

  RiderLocation copyWith({
    String? displayName,
    String? avatarUrl,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    DateTime? updatedAt,
  }) {
    return RiderLocation(
      userId: userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LiveRideSession {
  final String id;
  final String? rideGroupId;
  final String? routeId;
  final String startedBy;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime autoStopAt;

  LiveRideSession({
    required this.id,
    this.rideGroupId,
    this.routeId,
    required this.startedBy,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.autoStopAt,
  });

  factory LiveRideSession.fromMap(Map<String, dynamic> map) {
    return LiveRideSession(
      id: map['id'] as String,
      rideGroupId: map['ride_group_id'] as String?,
      routeId: map['route_id'] as String?,
      startedBy: map['started_by'] as String,
      status: map['status'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      autoStopAt: DateTime.parse(map['auto_stop_at'] as String),
    );
  }
}

class LiveRideService {
  static LiveRideService? _instance;
  static LiveRideService get instance => _instance ??= LiveRideService._();
  LiveRideService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? lastError;

  static final ValueNotifier<Map<String, RiderLocation>> riderLocations =
      ValueNotifier({});
  static final ValueNotifier<List<Map<String, dynamic>>> participants =
      ValueNotifier([]);
  static final ValueNotifier<bool> isRideActive = ValueNotifier(false);

  String? _currentSessionId;
  String? _currentParticipantId;
  Timer? _locationTimer;
  RealtimeChannel? _locationsChannel;
  RealtimeChannel? _participantsChannel;

  String? get currentSessionId => _currentSessionId;

  Future<LiveRideSession?> startRide(
    String rideGroupId,
    String? routeId,
  ) async {
    lastError = null;

    try {
      final userId = _supabase.auth.currentUser?.id;

      debugPrint('LiveRideService.startRide: userId=$userId');
      debugPrint('LiveRideService.startRide: rideGroupId=$rideGroupId');
      debugPrint('LiveRideService.startRide: routeId=$routeId');

      if (userId == null) {
        lastError = 'No signed-in user';
        return null;
      }

      if (rideGroupId.trim().isEmpty) {
        lastError = 'Missing ride group id';
        return null;
      }

      final now = DateTime.now().toUtc();
      final autoStopAt = now.add(const Duration(hours: 8));

      final payload = {
        'ride_group_id': rideGroupId,
        'route_id': routeId,
        'started_by': userId,
        'status': 'active',
        'started_at': now.toIso8601String(),
        'auto_stop_at': autoStopAt.toIso8601String(),
      };

      debugPrint('LiveRideService.startRide: payload=$payload');

      final sessionData = await _supabase
          .from('live_ride_sessions')
          .insert(payload)
          .select()
          .maybeSingle();

      debugPrint('LiveRideService.startRide: sessionData=$sessionData');

      if (sessionData == null) {
        throw Exception('Live ride session insert returned no row');
      }

      final session = LiveRideSession.fromMap(sessionData);
      _currentSessionId = session.id;

      await _joinAsParticipant(session.id, userId);
      await _notifyGroupMembers(rideGroupId, session.id);

      _startTracking();
      _subscribeToLocations(session.id);
      _subscribeToParticipants(session.id);

      isRideActive.value = true;
      return session;
    } catch (e, stack) {
      lastError = e.toString();
      debugPrint('LiveRideService.startRide error: $e');
      debugPrint('LiveRideService.startRide stack: $stack');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'start_ride',
        error: e,
        stackTrace: stack,
        context: {'ride_group_id': rideGroupId, 'route_id': routeId},
      );
      return null;
    }
  }

  Future<bool> joinRide(String sessionId) async {
    lastError = null;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        lastError = 'No signed-in user';
        return false;
      }

      _currentSessionId = sessionId;

      await _joinAsParticipant(sessionId, userId);

      _startTracking();
      _subscribeToLocations(sessionId);
      _subscribeToParticipants(sessionId);

      isRideActive.value = true;
      return true;
    } catch (e, stack) {
      lastError = e.toString();
      debugPrint('LiveRideService.joinRide error: $e');
      debugPrint('LiveRideService.joinRide stack: $stack');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'join_ride',
        error: e,
        stackTrace: stack,
        context: {'session_id': sessionId},
      );
      return false;
    }
  }

  Future<void> leaveRide() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || _currentSessionId == null) return;

      await _supabase
          .from('live_ride_participants')
          .update({
            'status': 'left',
            'left_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('session_id', _currentSessionId!)
          .eq('user_id', userId);

      _stopTracking();
    } catch (e) {
      debugPrint('LiveRideService.leaveRide error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'leave_ride',
        error: e,
        severity: 'warning',
        context: {'session_id': _currentSessionId},
      );
      _stopTracking();
    }
  }

  Future<void> endRide() async {
    try {
      if (_currentSessionId == null) return;

      await _supabase
          .from('live_ride_sessions')
          .update({
            'status': 'completed',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _currentSessionId!);

      _stopTracking();
    } catch (e) {
      debugPrint('LiveRideService.endRide error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'end_ride',
        error: e,
        context: {'session_id': _currentSessionId},
      );
      _stopTracking();
    }
  }

  Future<void> toggleLocationSharing(bool isSharing) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || _currentSessionId == null) return;

      await _supabase
          .from('live_ride_participants')
          .update({'is_sharing_location': isSharing})
          .eq('session_id', _currentSessionId!)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('LiveRideService.toggleLocationSharing error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'toggle_location_sharing',
        error: e,
        severity: 'warning',
        context: {'session_id': _currentSessionId, 'is_sharing': isSharing},
      );
    }
  }

  Future<LiveRideSession?> getActiveRide() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final participantData = await _supabase
          .from('live_ride_participants')
          .select('session_id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (participantData == null) return null;

      final sessionId = participantData['session_id'] as String;

      final sessionData = await _supabase
          .from('live_ride_sessions')
          .select()
          .eq('id', sessionId)
          .eq('status', 'active')
          .maybeSingle();

      if (sessionData == null) return null;

      _currentSessionId = sessionId;
      return LiveRideSession.fromMap(sessionData);
    } catch (e) {
      debugPrint('LiveRideService.getActiveRide error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'get_active_ride',
        error: e,
        severity: 'warning',
      );
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getParticipants(String sessionId) async {
    try {
      final data = await _supabase
          .from('live_ride_participants')
          .select('*, user_profiles:user_id(id, full_name, email, avatar_url)')
          .eq('session_id', sessionId)
          .neq('status', 'left');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('LiveRideService.getParticipants error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'get_participants',
        error: e,
        severity: 'warning',
        context: {'session_id': sessionId},
      );
      return [];
    }
  }

  Future<void> _joinAsParticipant(String sessionId, String userId) async {
    final existing = await _supabase
        .from('live_ride_participants')
        .select('id')
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      final result = await _supabase
          .from('live_ride_participants')
          .update({
            'status': 'active',
            'is_sharing_location': true,
            'left_at': null,
          })
          .eq('id', existing['id'] as String)
          .select()
          .single();

      _currentParticipantId = result['id'] as String?;
      return;
    }

    final result = await _supabase
        .from('live_ride_participants')
        .insert({
          'session_id': sessionId,
          'user_id': userId,
          'status': 'active',
          'is_sharing_location': true,
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    _currentParticipantId = result['id'] as String?;
  }

  void _startTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _sendLocation(),
    );
  }

  void _stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _locationsChannel?.unsubscribe();
    _participantsChannel?.unsubscribe();
    _locationsChannel = null;
    _participantsChannel = null;
    _currentSessionId = null;
    _currentParticipantId = null;
    isRideActive.value = false;
    riderLocations.value = {};
    participants.value = [];
  }

  Future<void> _sendLocation() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || _currentSessionId == null) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _supabase.from('live_ride_locations').insert({
        'session_id': _currentSessionId,
        'user_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
      });
    } catch (e) {
      debugPrint('LiveRideService._sendLocation error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'send_location',
        error: e,
        severity: 'warning',
        context: {'session_id': _currentSessionId},
      );
    }
  }

  void _subscribeToLocations(String sessionId) {
    _locationsChannel?.unsubscribe();

    _locationsChannel = _supabase
        .channel('live_ride_locations:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_ride_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) async {
            final record = payload.newRecord;
            final userId = record['user_id'] as String?;
            final currentUserId = _supabase.auth.currentUser?.id;

            if (userId == null || userId == currentUserId) return;

            String displayName = 'Rider';
            String? avatarUrl;

            try {
              final profile = await _supabase
                  .from('user_profiles')
                  .select('full_name, avatar_url')
                  .eq('id', userId)
                  .maybeSingle();

              if (profile != null) {
                displayName = profile['full_name'] as String? ?? 'Rider';
                avatarUrl = profile['avatar_url'] as String?;
              }
            } catch (_) {}

            final updated = Map<String, RiderLocation>.from(
              riderLocations.value,
            );

            updated[userId] = RiderLocation(
              userId: userId,
              displayName: displayName,
              avatarUrl: avatarUrl,
              latitude: (record['latitude'] as num).toDouble(),
              longitude: (record['longitude'] as num).toDouble(),
              heading: record['heading'] != null
                  ? (record['heading'] as num).toDouble()
                  : null,
              speed: record['speed'] != null
                  ? (record['speed'] as num).toDouble()
                  : null,
              updatedAt: DateTime.now(),
            );

            riderLocations.value = updated;
          },
        )
        .subscribe();
  }

  void _subscribeToParticipants(String sessionId) {
    _participantsChannel?.unsubscribe();

    _participantsChannel = _supabase
        .channel('live_ride_participants:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_ride_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (_) async {
            final updated = await getParticipants(sessionId);
            participants.value = updated;
          },
        )
        .subscribe();
  }

  Future<void> _notifyGroupMembers(String rideGroupId, String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      String starterName = 'A rider';

      try {
        final profile = await _supabase
            .from('user_profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();

        if (profile != null) {
          starterName = profile['full_name'] as String? ?? 'A rider';
        }
      } catch (_) {}

      final members = await _supabase
          .from('ride_group_invites')
          .select('invitee_id')
          .eq('group_id', rideGroupId)
          .eq('status', 'accepted');

      final notifications = (members as List)
          .where((member) => member['invitee_id'] != userId)
          .map(
            (member) => {
              'user_id': member['invitee_id'],
              'notification_type': 'ride_started',
              'title': 'Live Ride Started!',
              'message': '$starterName started a live ride. Tap to join!',
              'is_read': false,
              'action_route': '/ride-groups-screen',
              'action_arguments': {
                'session_id': sessionId,
                'ride_group_id': rideGroupId,
              },
              'reference_id': sessionId,
            },
          )
          .toList();

      if (notifications.isNotEmpty) {
        await _supabase.from('notifications').insert(notifications);
      }
    } catch (e) {
      debugPrint('LiveRideService._notifyGroupMembers error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'notify_group_members',
        error: e,
        severity: 'warning',
        context: {'ride_group_id': rideGroupId, 'session_id': sessionId},
      );
    }
  }

  void dispose() {
    _stopTracking();
  }
}

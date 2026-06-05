import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_service.dart';
import 'diagnostics_service.dart';
import 'profile_service.dart';

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
  Timer? _locationTimer;
  RealtimeChannel? _locationsChannel;
  RealtimeChannel? _participantsChannel;
  DateTime? _lastSessionHealthCheck;
  DateTime? _lastLocationErrorLogAt;
  final Map<String, ({String displayName, String? avatarUrl})> _profileCache =
      {};

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

      final existingSession = await _getActiveSessionForGroup(rideGroupId);
      if (existingSession != null) {
        _currentSessionId = existingSession.id;
        await _joinAsParticipant(existingSession.id, userId);
        await AnalyticsService.instance.logLiveRideJoined(
          sessionId: existingSession.id,
          rideGroupId: rideGroupId,
          reusedExistingSession: true,
        );
        await _activateRealtime(existingSession.id);
        return existingSession;
      }

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
      await AnalyticsService.instance.logLiveRideStarted(
        sessionId: session.id,
        rideGroupId: rideGroupId,
      );

      await _activateRealtime(session.id);
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

      final session = await _getJoinableSession(sessionId);
      if (session == null) {
        lastError = 'This live ride is no longer active';
        return false;
      }

      _currentSessionId = session.id;

      await _joinAsParticipant(session.id, userId);
      await AnalyticsService.instance.logLiveRideJoined(
        sessionId: session.id,
        rideGroupId: session.rideGroupId,
        reusedExistingSession: false,
      );

      await _activateRealtime(session.id);
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

  Future<void> _activateRealtime(String sessionId) async {
    _subscribeToLocations(sessionId);
    _subscribeToParticipants(sessionId);

    participants.value = await getParticipants(sessionId);
    await _loadLatestLocations(sessionId);

    _startTracking();
    isRideActive.value = true;
  }

  Future<LiveRideSession?> _getActiveSessionForGroup(String rideGroupId) async {
    try {
      final sessionData = await _supabase
          .from('live_ride_sessions')
          .select()
          .eq('ride_group_id', rideGroupId)
          .eq('status', 'active')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (sessionData == null) return null;

      final session = LiveRideSession.fromMap(sessionData);
      if (session.autoStopAt.isBefore(DateTime.now().toUtc())) {
        await _markSessionExpired(session.id);
        return null;
      }

      return session;
    } catch (e) {
      debugPrint('LiveRideService._getActiveSessionForGroup error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'get_active_session_for_group',
        error: e,
        severity: 'warning',
        context: {'ride_group_id': rideGroupId},
      );
      return null;
    }
  }

  Future<LiveRideSession?> _getJoinableSession(String sessionId) async {
    final sessionData = await _supabase
        .from('live_ride_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();

    if (sessionData == null) return null;

    final session = LiveRideSession.fromMap(sessionData);
    if (session.status != 'active') return null;

    if (session.autoStopAt.isBefore(DateTime.now().toUtc())) {
      await _markSessionExpired(session.id);
      return null;
    }

    return session;
  }

  Future<void> _markSessionExpired(String sessionId) async {
    await _supabase
        .from('live_ride_sessions')
        .update({
          'status': 'completed',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('status', 'active');
  }

  Future<void> _joinAsParticipant(String sessionId, String userId) async {
    final existing = await _supabase
        .from('live_ride_participants')
        .select('id')
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('live_ride_participants')
          .update({
            'status': 'active',
            'is_sharing_location': true,
            'left_at': null,
          })
          .eq('id', existing['id'] as String);

      return;
    }

    await _supabase.from('live_ride_participants').insert({
      'session_id': sessionId,
      'user_id': userId,
      'status': 'active',
      'is_sharing_location': true,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void _startTracking() {
    _locationTimer?.cancel();
    unawaited(_sendLocation());
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
    isRideActive.value = false;
    riderLocations.value = {};
    participants.value = [];
  }

  Future<void> _sendLocation() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || _currentSessionId == null) return;

      final sessionActive = await _isCurrentSessionActive();
      if (!sessionActive) {
        _stopTracking();
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _logLocationWarningOnce('location_service_disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _logLocationWarningOnce(
          permission == LocationPermission.deniedForever
              ? 'location_permission_denied_forever'
              : 'location_permission_denied',
        );
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
      final shouldLog =
          _lastLocationErrorLogAt == null ||
          DateTime.now().difference(_lastLocationErrorLogAt!) >
              const Duration(minutes: 2);
      if (shouldLog) {
        _lastLocationErrorLogAt = DateTime.now();
        await DiagnosticsService.instance.logError(
          feature: 'live_ride',
          action: 'send_location',
          error: e,
          severity: 'warning',
          context: {'session_id': _currentSessionId},
        );
      }
    }
  }

  Future<bool> _isCurrentSessionActive() async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return false;

    final now = DateTime.now();
    if (_lastSessionHealthCheck != null &&
        now.difference(_lastSessionHealthCheck!) <
            const Duration(seconds: 30)) {
      return true;
    }
    _lastSessionHealthCheck = now;

    try {
      final session = await _getJoinableSession(sessionId);
      return session != null;
    } catch (e) {
      debugPrint('LiveRideService._isCurrentSessionActive error: $e');
      return true;
    }
  }

  Future<void> _logLocationWarningOnce(String action) async {
    final now = DateTime.now();
    if (_lastLocationErrorLogAt != null &&
        now.difference(_lastLocationErrorLogAt!) < const Duration(minutes: 5)) {
      return;
    }
    _lastLocationErrorLogAt = now;

    await DiagnosticsService.instance.logError(
      feature: 'live_ride',
      action: action,
      error: 'Live ride location sharing is unavailable',
      severity: 'warning',
      context: {'session_id': _currentSessionId},
    );
  }

  Future<void> _loadLatestLocations(String sessionId) async {
    try {
      final data = await _supabase
          .from('live_ride_locations')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: false)
          .limit(100);

      final currentUserId = _supabase.auth.currentUser?.id;
      final latestByUser = <String, Map<String, dynamic>>{};

      for (final row in List<Map<String, dynamic>>.from(data)) {
        final userId = row['user_id'] as String?;
        if (userId == null || userId == currentUserId) continue;
        latestByUser.putIfAbsent(userId, () => row);
      }

      final updated = <String, RiderLocation>{};
      for (final entry in latestByUser.entries) {
        final rider = await _riderLocationFromRecord(entry.value);
        if (rider != null) {
          updated[entry.key] = rider;
        }
      }

      riderLocations.value = updated;
    } catch (e) {
      debugPrint('LiveRideService._loadLatestLocations error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'load_latest_locations',
        error: e,
        severity: 'warning',
        context: {'session_id': sessionId},
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

            final rider = await _riderLocationFromRecord(record);
            if (rider == null) return;

            final updated = Map<String, RiderLocation>.from(
              riderLocations.value,
            );

            updated[userId] = rider;

            riderLocations.value = updated;
          },
        )
        .subscribe();
  }

  Future<RiderLocation?> _riderLocationFromRecord(
    Map<String, dynamic> record,
  ) async {
    final userId = record['user_id'] as String?;
    final latitude = record['latitude'];
    final longitude = record['longitude'];

    if (userId == null || latitude is! num || longitude is! num) return null;

    final profile = await _profileForUser(userId);

    return RiderLocation(
      userId: userId,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      heading: record['heading'] != null
          ? (record['heading'] as num).toDouble()
          : null,
      speed: record['speed'] != null
          ? (record['speed'] as num).toDouble()
          : null,
      updatedAt: record['created_at'] is String
          ? DateTime.tryParse(record['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Future<({String displayName, String? avatarUrl})> _profileForUser(
    String userId,
  ) async {
    final cached = _profileCache[userId];
    if (cached != null) return cached;

    String displayName = 'Rider';
    String? avatarUrl;

    try {
      final profile = await _supabase
          .from('user_profiles')
          .select('full_name, email, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        final fullName = profile['full_name'] as String?;
        final email = profile['email'] as String?;

        if (fullName != null && fullName.trim().isNotEmpty) {
          displayName = fullName.trim();
        } else if (email != null && email.trim().isNotEmpty) {
          displayName = email.split('@').first;
        }

        avatarUrl = await ProfileService.resolveUserProfilePhotoUrl(
          userId: userId,
          avatarUrl: profile['avatar_url'] as String?,
        );
      }
    } catch (_) {}

    final result = (displayName: displayName, avatarUrl: avatarUrl);
    _profileCache[userId] = result;
    return result;
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

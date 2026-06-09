import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/live_ride_service.dart';
import '../../services/live_ride_voice_service.dart';
import '../../services/premium_service.dart';
import '../../services/diagnostics_service.dart';
import '../../utils/marker_utils.dart';
import './ride_chat_widget.dart';
import './ride_summary_screen.dart';
import '../../widgets/toast_widget.dart';

class LiveRideMapScreen extends StatefulWidget {
  final String sessionId;
  final String? routeId;
  final bool isCreator;
  final String initialRouteName;
  final List<LatLng> initialRoutePoints;

  const LiveRideMapScreen({
    super.key,
    required this.sessionId,
    this.routeId,
    required this.isCreator,
    this.initialRouteName = '',
    this.initialRoutePoints = const [],
  });

  @override
  State<LiveRideMapScreen> createState() => _LiveRideMapScreenState();
}

class _LiveRideMapScreenState extends State<LiveRideMapScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Map<String, List<LatLng>> _riderTrails = {};
  List<LatLng> _plannedRoutePoints = [];
  String _plannedRouteName = '';
  bool _hasFittedInitialView = false;
  LatLng? _myPosition;
  Timer? _positionTimer;
  bool _isSharingLocation = true;
  bool _isChatOpen = false;
  bool _isPremium = false;
  MapType _mapType = MapType.normal;
  bool _trafficEnabled = false;
  final LiveRideVoiceService _voiceService = LiveRideVoiceService.instance;
  RealtimeChannel? _chatNotificationChannel;
  int _unreadChatCount = 0;
  final Set<String> _seenChatMessageIds = {};
  void _subscribeToChatNotifications() {
    _chatNotificationChannel?.unsubscribe();

    _chatNotificationChannel = Supabase.instance.client
        .channel('live_ride_chat_notifications:${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_ride_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: widget.sessionId,
          ),
          callback: (payload) async {
            await _handleIncomingChatMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  Future<void> _handleIncomingChatMessage(Map<String, dynamic> record) async {
    if (!mounted) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final senderId = record['user_id'] as String?;
    final messageId = record['id']?.toString();

    if (senderId == null || senderId == currentUserId) return;
    if (messageId != null && _seenChatMessageIds.contains(messageId)) return;
    if (messageId != null) _seenChatMessageIds.add(messageId);

    if (_isChatOpen) return;

    final senderName = await _fetchRiderName(senderId);
    final body = record['message'] as String? ?? 'New message';

    final preview = body.length > 60 ? '${body.substring(0, 60)}...' : body;

    if (!mounted) return;

    setState(() => _unreadChatCount++);

    AppToast.show(
      context,
      message: '$senderName: $preview',
      type: ToastType.info,
    );
  }

  Future<String> _fetchRiderName(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name, email')
          .eq('id', userId)
          .maybeSingle();

      final fullName = profile?['full_name'] as String?;
      final email = profile?['email'] as String?;

      if (fullName != null && fullName.trim().isNotEmpty) {
        return fullName.trim();
      }

      if (email != null && email.trim().isNotEmpty) {
        return email.split('@').first;
      }
    } catch (_) {}

    return 'Rider';
  }

  String _participantName(Map<String, dynamic> participant) {
    final profile = participant['user_profiles'] as Map?;

    final fullName = profile?['full_name'] as String?;
    final email = profile?['email'] as String?;

    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    if (email != null && email.trim().isNotEmpty) {
      return email.split('@').first;
    }

    return 'Rider';
  }

  Future<void> _loadPlannedRoute() async {
    try {
      final session = await Supabase.instance.client
          .from('live_ride_sessions')
          .select('ride_group_id')
          .eq('id', widget.sessionId)
          .maybeSingle();

      final rideGroupId = session?['ride_group_id'] as String?;
      if (rideGroupId == null || rideGroupId.isEmpty) {
        await _logMissingPlannedRoute('session_missing_ride_group');
        return;
      }

      final group = await Supabase.instance.client
          .from('ride_groups')
          .select('route, route_polyline')
          .eq('id', rideGroupId)
          .maybeSingle();

      if (group == null) {
        await _logMissingPlannedRoute('ride_group_not_readable');
        return;
      }

      final routePoints = _parseRoutePolyline(group['route_polyline']);
      if (routePoints.length < 2) {
        await _logMissingPlannedRoute('ride_group_route_empty');
        return;
      }

      if (!mounted) return;
      setState(() {
        _plannedRouteName = group['route'] as String? ?? '';
        _plannedRoutePoints = routePoints;
      });
      _rebuildMarkers();
      _fitInitialView();
    } catch (e) {
      debugPrint('LiveRideMapScreen._loadPlannedRoute error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'live_ride',
        action: 'load_planned_route',
        error: e,
        severity: 'warning',
        context: {
          'session_id': widget.sessionId,
          'has_initial_route': widget.initialRoutePoints.length >= 2,
        },
      );
    }
  }

  Future<void> _logMissingPlannedRoute(String reason) async {
    if (widget.initialRoutePoints.length >= 2) return;

    await DiagnosticsService.instance.logError(
      feature: 'live_ride',
      action: 'planned_route_unavailable',
      error: 'Planned route is unavailable for live ride',
      severity: 'warning',
      context: {'session_id': widget.sessionId, 'reason': reason},
    );
  }

  List<LatLng> _parseRoutePolyline(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((point) {
          final lat = point['lat'];
          final lng = point['lng'];
          if (lat is! num || lng is! num) return null;
          return LatLng(lat.toDouble(), lng.toDouble());
        })
        .whereType<LatLng>()
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _plannedRouteName = widget.initialRouteName;
    _plannedRoutePoints = List<LatLng>.from(widget.initialRoutePoints);
    if (_plannedRoutePoints.length >= 2) {
      unawaited(_rebuildMarkers());
    }
    unawaited(_ensureLiveRideSessionActive());
    _loadPremiumAccess();
    _loadPlannedRoute();
    _initMyPosition();
    _startPositionUpdates();
    _subscribeToChatNotifications();
    _voiceService.addListener(_onVoiceStateChanged);
    LiveRideService.riderLocations.addListener(_onRiderLocationsChanged);
    LiveRideService.participants.addListener(_onParticipantsChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionTimer?.cancel();
    _chatNotificationChannel?.unsubscribe();
    _voiceService.removeListener(_onVoiceStateChanged);
    _voiceService.disconnect();
    LiveRideService.riderLocations.removeListener(_onRiderLocationsChanged);
    LiveRideService.participants.removeListener(_onParticipantsChanged);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_voiceService.ensureConnected());
    }
  }

  void _onVoiceStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPremiumAccess() async {
    await PremiumService().refresh();
    if (!mounted) return;
    setState(() => _isPremium = PremiumService().isPremium);
  }

  Future<void> _ensureLiveRideSessionActive() async {
    if (LiveRideService.instance.currentSessionId == widget.sessionId) return;

    final joined = await LiveRideService.instance.joinRide(widget.sessionId);
    if (!mounted || joined) return;

    await DiagnosticsService.instance.logError(
      feature: 'live_ride',
      action: 'map_session_resume_failed',
      error: LiveRideService.instance.lastError ?? 'Failed to resume live ride',
      severity: 'warning',
      context: {'session_id': widget.sessionId},
    );

    if (!mounted) return;
    AppToast.show(
      context,
      message: LiveRideService.instance.lastError ?? 'Failed to join live ride',
      type: ToastType.error,
    );
  }

  Future<void> _initMyPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _myPosition = LatLng(position.latitude, position.longitude);
        });
        _fitInitialView();
      }
    } catch (e) {
      debugPrint('LiveRideMapScreen._initMyPosition error: $e');
    }
  }

  void _startPositionUpdates() {
    _positionTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (mounted) {
          setState(() {
            _myPosition = LatLng(position.latitude, position.longitude);
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(_myPosition!));
        }
      } catch (_) {}
    });
  }

  void _onRiderLocationsChanged() {
    if (!mounted) return;
    _rebuildMarkers();
  }

  Future<void> _rebuildMarkers() async {
    final locations = LiveRideService.riderLocations.value;
    final newMarkers = <Marker>{..._plannedRouteMarkers()};
    final newPolylines = <Polyline>{};

    if (_plannedRoutePoints.length >= 2) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('planned_route'),
          points: _plannedRoutePoints,
          color: const Color(0xFF1D4ED8),
          width: 6,
          zIndex: 1,
        ),
      );
    }

    final trailColors = [
      const Color(0xFF2563EB),
      const Color(0xFFDC2626),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFFEC4899),
    ];
    int colorIndex = 0;

    for (final entry in locations.entries) {
      final rider = entry.value;
      final speedKmh = rider.speed != null
          ? (rider.speed! * 3.6).toStringAsFixed(0)
          : '0';

      final trailKey = rider.userId;
      if (!_riderTrails.containsKey(trailKey)) {
        _riderTrails[trailKey] = [];
      }
      _riderTrails[trailKey]!.add(LatLng(rider.latitude, rider.longitude));

      if (_riderTrails[trailKey]!.length > 200) {
        _riderTrails[trailKey] = _riderTrails[trailKey]!.sublist(
          _riderTrails[trailKey]!.length - 200,
        );
      }

      final color = trailColors[colorIndex % trailColors.length];
      if (_riderTrails[trailKey]!.length >= 2) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('trail_${rider.userId}'),
            points: List.from(_riderTrails[trailKey]!),
            color: color,
            width: 4,
            zIndex: 2,
            patterns: [],
          ),
        );
      }

      BitmapDescriptor icon;
      if (rider.avatarUrl != null && rider.avatarUrl!.isNotEmpty) {
        try {
          icon = await MarkerUtils.getMarker(
            avatarUrl: rider.avatarUrl!,
            borderColor: color,
          );
        } catch (_) {
          icon = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          );
        }
      } else {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId(rider.userId),
          position: LatLng(rider.latitude, rider.longitude),
          icon: icon,
          infoWindow: InfoWindow(
            title: rider.displayName,
            snippet: '$speedKmh km/h',
          ),
          rotation: rider.heading ?? 0.0,
          anchor: const Offset(0.5, 1.0),
        ),
      );

      colorIndex++;
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _polylines
          ..clear()
          ..addAll(newPolylines);
      });
    }
  }

  void _onParticipantsChanged() {
    if (mounted) setState(() {});
  }

  Set<Marker> _plannedRouteMarkers() {
    if (_plannedRoutePoints.length < 2) return const {};

    return {
      Marker(
        markerId: const MarkerId('planned_route_start'),
        position: _plannedRoutePoints.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Route start'),
      ),
      Marker(
        markerId: const MarkerId('planned_route_end'),
        position: _plannedRoutePoints.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Route finish'),
      ),
    };
  }

  Future<void> _fitInitialView() async {
    if (_hasFittedInitialView || _mapController == null) return;

    final positions = <LatLng>[
      ..._plannedRoutePoints,
      if (_myPosition != null) _myPosition!,
    ];

    if (positions.isEmpty) return;
    _hasFittedInitialView = true;
    await _fitPositions(positions, padding: 90);
  }

  Future<void> _fitAllMarkers() async {
    final locations = LiveRideService.riderLocations.value;
    if (locations.isEmpty &&
        _myPosition == null &&
        _plannedRoutePoints.isEmpty) {
      return;
    }

    final allPositions = <LatLng>[
      ..._plannedRoutePoints,
      if (_myPosition != null) _myPosition!,
      ...locations.values.map((r) => LatLng(r.latitude, r.longitude)),
    ];

    await _fitPositions(allPositions, padding: 80);
  }

  List<LatLng> _navigationWaypoints() {
    if (_plannedRoutePoints.length < 2) return const [];

    final candidates = _plannedRoutePoints.sublist(
      0,
      _plannedRoutePoints.length - 1,
    );
    const maxWaypoints = 6;
    if (candidates.length <= maxWaypoints) return candidates;

    return List.generate(maxWaypoints, (index) {
      final candidateIndex =
          (index * (candidates.length - 1) / (maxWaypoints - 1)).round();
      return candidates[candidateIndex];
    });
  }

  Future<void> _showNavigationChooser() async {
    if (_plannedRoutePoints.length < 2) {
      AppToast.show(
        context,
        message: 'This live ride does not have a planned route yet.',
        type: ToastType.error,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose navigation',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _voiceService.isConnected
                    ? 'Group voice will remain active while navigating.'
                    : 'Join group voice before navigating to keep talking.',
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ListTile(
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchWazeNavigation();
                },
                leading: const Icon(
                  Icons.navigation_rounded,
                  color: Color(0xFF60A5FA),
                ),
                title: Text(
                  'Waze',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Uses your Waze vehicle and route preferences',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white54,
                ),
              ),
              ListTile(
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchGoogleMapsNavigation();
                },
                leading: const Icon(
                  Icons.map_rounded,
                  color: Color(0xFF34D399),
                ),
                title: Text(
                  'Google Maps',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Includes planned-route shaping points',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchWazeNavigation() async {
    final destination = _plannedRoutePoints.last;
    final appUri = Uri.parse(
      'waze://?ll=${destination.latitude},${destination.longitude}'
      '&navigate=yes',
    );
    final webUri = Uri.https('waze.com', '/ul', {
      'll': '${destination.latitude},${destination.longitude}',
      'navigate': 'yes',
      'utm_source': 'rydmatch',
    });

    try {
      final openedApp = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (openedApp) return;
    } catch (_) {
      // Fall back to Waze's universal link when the app is not installed.
    }

    try {
      final openedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (openedWeb) return;
      throw StateError('Waze could not open the live ride destination');
    } catch (error, stackTrace) {
      await _logNavigationLaunchFailure('waze', error, stackTrace);
    }
  }

  Future<void> _launchGoogleMapsNavigation() async {
    final destination = _plannedRoutePoints.last;
    final params = <String, String>{
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    };

    if (_myPosition != null) {
      params['origin'] = '${_myPosition!.latitude},${_myPosition!.longitude}';
    }

    final waypoints = _navigationWaypoints();
    if (waypoints.isNotEmpty) {
      params['waypoints'] = waypoints
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');
    }

    final navigationUri = Uri.https('www.google.com', '/maps/dir/', params);

    try {
      final opened = await launchUrl(
        navigationUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
      throw StateError('No navigation app could open the planned route');
    } catch (error, stackTrace) {
      await _logNavigationLaunchFailure('google_maps', error, stackTrace);
    }
  }

  Future<void> _logNavigationLaunchFailure(
    String provider,
    Object error,
    StackTrace stackTrace,
  ) async {
    await DiagnosticsService.instance.logError(
      feature: 'live_ride',
      action: 'launch_navigation',
      error: error,
      stackTrace: stackTrace,
      severity: 'warning',
      context: {
        'session_id': widget.sessionId,
        'provider': provider,
        'has_current_position': _myPosition != null,
        'route_point_count': _plannedRoutePoints.length,
      },
    );

    if (!mounted) return;
    AppToast.show(
      context,
      message: 'Could not open turn-by-turn navigation.',
      type: ToastType.error,
    );
  }

  Future<void> _fitPositions(
    List<LatLng> allPositions, {
    double padding = 80,
  }) async {
    if (allPositions.isEmpty) return;

    if (allPositions.length == 1) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(allPositions.first, 15),
      );
      return;
    }

    double minLat = allPositions.first.latitude;
    double maxLat = allPositions.first.latitude;
    double minLng = allPositions.first.longitude;
    double maxLng = allPositions.first.longitude;

    for (final pos in allPositions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }

  Future<void> _handleEndOrLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.isCreator ? 'End Ride?' : 'Leave Ride?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          widget.isCreator
              ? 'This will end the ride for all participants.'
              : 'You will leave the live ride session.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              widget.isCreator ? 'End Ride' : 'Leave',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final participantCount = LiveRideService.participants.value.length;
      final now = DateTime.now();

      DateTime startedAt = now.subtract(const Duration(minutes: 30));
      try {
        final session = await Supabase.instance.client
            .from('live_ride_sessions')
            .select('started_at')
            .eq('id', widget.sessionId)
            .maybeSingle();
        if (session != null && session['started_at'] != null) {
          startedAt = DateTime.parse(session['started_at'] as String);
        }
      } catch (_) {}

      if (widget.isCreator) {
        await LiveRideService.instance.endRide();
      } else {
        await LiveRideService.instance.leaveRide();
      }

      _riderTrails.clear();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RideSummaryScreen(
              sessionId: widget.sessionId,
              startedAt: startedAt,
              endedAt: now,
              participantCount: participantCount,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleVoiceButtonPressed() async {
    if (_voiceService.isConnecting) return;

    if (_voiceService.isConnected) {
      await _voiceService.toggleMute();
      if (!mounted) return;
      AppToast.show(
        context,
        message: _voiceService.isMuted ? 'Voice muted' : 'Voice unmuted',
        type: ToastType.info,
      );
      return;
    }

    final connected = await _voiceService.connect(widget.sessionId);
    if (!mounted) return;

    AppToast.show(
      context,
      message: connected
          ? 'Voice connected'
          : _voiceService.lastError ?? 'Could not connect voice',
      type: connected ? ToastType.success : ToastType.error,
    );
  }

  Color get _voiceButtonColor {
    if (_voiceService.isConnecting) return const Color(0xFF6A1B9A);
    if (_voiceService.isConnected && _voiceService.isMuted) {
      return const Color(0xFFD97706);
    }
    if (_voiceService.isConnected) return const Color(0xFF059669);
    return const Color(0xFF6A1B9A);
  }

  IconData get _voiceButtonIcon {
    if (_voiceService.isConnected && _voiceService.isMuted) {
      return Icons.mic_off_rounded;
    }
    return Icons.mic_rounded;
  }

  String get _voiceButtonTooltip {
    if (_voiceService.isConnecting) return 'Connecting voice';
    if (_voiceService.isConnected && _voiceService.isMuted) {
      return 'Unmute voice';
    }
    if (_voiceService.isConnected) return 'Mute voice';
    return 'Join voice';
  }

  String get _mapTypeLabel {
    switch (_mapType) {
      case MapType.satellite:
        return 'Satellite';
      case MapType.terrain:
        return 'Terrain';
      case MapType.hybrid:
        return 'Hybrid';
      case MapType.normal:
      case MapType.none:
        return 'Normal';
    }
  }

  void _showMapLayersSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateMapType(MapType type) {
              setState(() => _mapType = type);
              setSheetState(() {});
            }

            void updateTraffic(bool value) {
              setState(() => _trafficEnabled = value);
              setSheetState(() {});
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Map layers',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildMapLayerChoice(
                          label: 'Normal',
                          icon: Icons.map_rounded,
                          selected: _mapType == MapType.normal,
                          onTap: () => updateMapType(MapType.normal),
                        ),
                        _buildMapLayerChoice(
                          label: 'Satellite',
                          icon: Icons.satellite_alt_rounded,
                          selected: _mapType == MapType.satellite,
                          onTap: () => updateMapType(MapType.satellite),
                        ),
                        _buildMapLayerChoice(
                          label: 'Terrain',
                          icon: Icons.terrain_rounded,
                          selected: _mapType == MapType.terrain,
                          onTap: () => updateMapType(MapType.terrain),
                        ),
                        _buildMapLayerChoice(
                          label: 'Hybrid',
                          icon: Icons.layers_rounded,
                          selected: _mapType == MapType.hybrid,
                          onTap: () => updateMapType(MapType.hybrid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      value: _trafficEnabled,
                      onChanged: updateTraffic,
                      activeThumbColor: const Color(0xFF2563EB),
                      activeTrackColor: const Color(0xFF93C5FD),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.traffic_rounded,
                        color: Colors.white,
                      ),
                      title: Text(
                        'Traffic',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapLayerChoice({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 136,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB)
              : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF60A5FA) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participantList = LiveRideService.participants.value;
    final riderCount = participantList.length;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _myPosition ?? const LatLng(0, 0),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            polylines: _polylines,
            mapType: _mapType,
            trafficEnabled: _trafficEnabled,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_plannedRoutePoints.isNotEmpty) {
                _fitInitialView();
              } else if (_myPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_myPosition!, 15),
                );
              }
            },
          ),

          // ── Top Bar Overlay ─────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE6000000), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 24,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _plannedRouteName.isNotEmpty
                          ? _plannedRouteName
                          : 'Live Ride',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$riderCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // SOS button
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/emergency-sos-screen'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.red.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sos_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SOS',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Panel ────────────────────────────────────────────────
          if (!_isChatOpen)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF0D0D1A).withAlpha(247),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 24,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (participantList.isNotEmpty)
                      SizedBox(
                        height: 56,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: participantList.length,
                          itemBuilder: (context, index) {
                            final p = participantList[index];
                            final name = _participantName(
                              Map<String, dynamic>.from(p),
                            );
                            final isSharing =
                                p['is_sharing_location'] as bool? ?? false;
                            final initial = name.isNotEmpty
                                ? name[0].toUpperCase()
                                : 'R';

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(
                                      0xFF2563EB,
                                    ).withAlpha(204),
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (isSharing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF0D0D1A),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _isSharingLocation
                                  ? const Color(0xFF2563EB)
                                  : Colors.white54,
                              side: BorderSide(
                                color: _isSharingLocation
                                    ? const Color(0xFF2563EB)
                                    : Colors.white24,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final newValue = !_isSharingLocation;
                              setState(() => _isSharingLocation = newValue);
                              await LiveRideService.instance
                                  .toggleLocationSharing(newValue);
                            },
                            icon: Icon(
                              _isSharingLocation
                                  ? Icons.location_on
                                  : Icons.location_off,
                              size: 16,
                            ),
                            label: Text(
                              _isSharingLocation ? 'Sharing' : 'Hidden',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _fitAllMarkers,
                            icon: const Icon(Icons.fit_screen, size: 16),
                            label: Text(
                              'Fit All',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_plannedRoutePoints.length >= 2) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _showNavigationChooser,
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: Text(
                            'Navigate Route',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _handleEndOrLeave,
                        icon: Icon(
                          widget.isCreator
                              ? Icons.stop_circle_outlined
                              : Icons.exit_to_app,
                          size: 18,
                        ),
                        label: Text(
                          widget.isCreator ? 'End Ride' : 'Leave Ride',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Chat toggle button ──────────────────────────────────────────
          if (!_isChatOpen)
            Positioned(
              right: 16,
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  (_plannedRoutePoints.length >= 2 ? 264 : 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'live_ride_layers',
                    mini: true,
                    backgroundColor: Colors.white.withAlpha(230),
                    foregroundColor: const Color(0xFF111827),
                    tooltip: 'Map layers: $_mapTypeLabel',
                    onPressed: _showMapLayersSheet,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.layers_rounded, size: 20),
                        if (_trafficEnabled)
                          Positioned(
                            right: -3,
                            bottom: -3,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isPremium) ...[
                    FloatingActionButton(
                      heroTag: 'live_ride_voice',
                      mini: true,
                      backgroundColor: _voiceButtonColor,
                      tooltip: _voiceButtonTooltip,
                      onPressed: _voiceService.isConnecting
                          ? null
                          : _handleVoiceButtonPressed,
                      child: _voiceService.isConnecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _voiceButtonIcon,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FloatingActionButton(
                    heroTag: 'live_ride_chat',
                    mini: true,
                    backgroundColor: const Color(0xFF2563EB),
                    tooltip: 'Open chat',
                    onPressed: () {
                      setState(() {
                        _isChatOpen = true;
                        _unreadChatCount = 0;
                      });
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        if (_unreadChatCount > 0)
                          Positioned(
                            top: -12,
                            right: -12,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                _unreadChatCount > 9
                                    ? '9+'
                                    : '$_unreadChatCount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Chat overlay ────────────────────────────────────────────────
          if (_isChatOpen)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RideChatWidget(
                sessionId: widget.sessionId,
                onClose: () => setState(() => _isChatOpen = false),
              ),
            ),
        ],
      ),
    );
  }
}

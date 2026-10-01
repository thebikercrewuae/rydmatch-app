import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackgroundProximityService {
  static final BackgroundProximityService _instance = BackgroundProximityService._();
  factory BackgroundProximityService() => _instance;
  BackgroundProximityService._();

  static const String _notificationChannelId = 'proximity_alerts';

  bool _isRunning = false;
  Timer? _checkTimer;

  bool get isRunning => _isRunning;

  Future<void> initialize() async {
    try {
      final service = FlutterBackgroundService();
      service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: _notificationChannelId,
          initialNotificationTitle: 'RydMatch Nearby Alerts',
          initialNotificationContent: 'Monitoring for nearby riders',
          foregroundServiceNotificationId: 654321,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
    } catch (e) {
      debugPrint('Background proximity config error');
    }
  }

  Future<void> start() async {
    if (_isRunning) return;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('proximity_alerts_enabled') ?? false;
    if (!enabled) return;

    try {
      final service = FlutterBackgroundService();
      service.startService();
      _isRunning = true;
    } catch (e) {
      debugPrint('Background service start error');
    }

    // Foreground fallback timer
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _performProximityCheck();
    });
    _performProximityCheck();
  }

  Future<void> stop() async {
    _checkTimer?.cancel();
    _checkTimer = null;

    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
    } catch (_) {}

    _isRunning = false;
  }

  Future<void> _performProximityCheck() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('proximity_alerts_enabled') ?? false;
      if (!enabled) return;

      final lastCheck = prefs.getInt('last_proximity_check') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCheck < 600000) return;

      prefs.setInt('last_proximity_check', now);

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      await supabase.from('user_profiles').upsert({
        'id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location_updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      final response = await supabase.rpc('check_nearby_matches', params: {
        'p_user_id': userId,
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
      });

      if (response is List && response.isNotEmpty) {
        final count = response.length;
        final nearest = response.first as Map<String, dynamic>;
        final name = nearest['matched_user_name'] as String? ?? 'A rider';
        final kmVal = (nearest['distance_km'] as num?)?.toDouble();
        final km = kmVal != null ? kmVal.toStringAsFixed(1) : '?';

        try {
          final service = FlutterBackgroundService();
          service.invoke('showProximityNotification', {
            'message': count == 1
                ? [name, ' is ', km, ' km away'].join()
                : [count.toString(), ' riders nearby! Nearest: ', km, ' km'].join(),
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Proximity check error');
    }
  }

  @pragma('vm:entry-point')
  static FutureOr<bool> onStart(ServiceInstance service) async {
    Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) return;

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );

        await supabase.from('user_profiles').upsert({
          'id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location_updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');

        final response = await supabase.rpc('check_nearby_matches', params: {
          'p_user_id': userId,
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
        });

        if (response is List && response.isNotEmpty) {
          final count = response.length;
          final nearest = response.first as Map<String, dynamic>;
          final name = nearest['matched_user_name'] as String? ?? 'A rider';
          final kmVal = (nearest['distance_km'] as num?)?.toDouble();
          final km = kmVal != null ? kmVal.toStringAsFixed(1) : '?';

          service.invoke('showProximityNotification', {
            'message': count == 1
                ? [name, ' is ', km, ' km away'].join()
                : [count.toString(), ' riders nearby! Nearest: ', km, ' km'].join(),
          });
        }
      } catch (_) {}
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    return true;
  }

  @pragma('vm:entry-point')
  static FutureOr<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }
}

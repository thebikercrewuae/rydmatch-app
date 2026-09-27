import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProximityResult {
  final String userId;
  final String name;
  final double distanceKm;

  ProximityResult({required this.userId, required this.name, required this.distanceKm});
}

class ProximityService {
  ProximityService._();
  static final ProximityService instance = ProximityService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> isProximityEnabled() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;
      final data = await _client
          .from('user_profiles')
          .select('proximity_alerts_enabled')
          .eq('id', userId)
          .maybeSingle();
      return data?['proximity_alerts_enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setProximityEnabled(bool enabled) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client
          .from('user_profiles')
          .update({'proximity_alerts_enabled': enabled})
          .eq('id', userId);
    } catch (e) {
      debugPrint('ProximityService setEnabled error');
    }
  }

  Future<int> getProximityRadius() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 5;
      final data = await _client
          .from('user_profiles')
          .select('proximity_radius_km')
          .eq('id', userId)
          .maybeSingle();
      return (data?['proximity_radius_km'] as num?)?.toInt() ?? 5;
    } catch (_) {
      return 5;
    }
  }

  Future<void> setProximityRadius(int km) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client
          .from('user_profiles')
          .update({'proximity_radius_km': km})
          .eq('id', userId);
    } catch (e) {
      debugPrint('ProximityService setRadius error');
    }
  }

  Future<List<ProximityResult>> checkNearbyMatches(double lat, double lng) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client.rpc('check_nearby_matches', params: {
        'p_user_id': userId,
        'p_latitude': lat,
        'p_longitude': lng,
      });

      if (response is! List) return [];

      return response.map((e) {
        final m = e as Map<String, dynamic>;
        return ProximityResult(
          userId: m['matched_user_id'] as String,
          name: m['matched_user_name'] as String? ?? 'Rider',
          distanceKm: (m['distance_km'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } catch (e) {
      debugPrint('ProximityService checkNearby error');
      return [];
    }
  }
}

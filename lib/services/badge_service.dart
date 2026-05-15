import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/badge_model.dart';
import './premium_service.dart';
import './profile_service.dart';

class BadgeService {
  static final _client = Supabase.instance.client;

  // ==========================================
  // SINGLE SOURCE OF TRUTH FOR BADGE CRITERIA
  // ==========================================
  static Map<String, bool> _buildCriteria(Map<String, dynamic> activity) {
    final rideCount = activity['rideCount'] as int? ?? 0;
    final totalKm = activity['totalKm'] as double? ?? 0.0;
    final matchCount = activity['matchCount'] as int? ?? 0;
    final groupRideCount = activity['groupRideCount'] as int? ?? 0;
    final bikePhotoCount = activity['bikePhotoCount'] as int? ?? 0;
    final profileComplete = activity['profileComplete'] as bool? ?? false;
    final isPremium = activity['isPremium'] as bool? ?? false;
    final averageRating = activity['averageRating'] as double? ?? 0.0;
    final safetyTagCount = activity['safetyTagCount'] as int? ?? 0;
    final weekendRides = activity['weekendRides'] as int? ?? 0;
    final morningRides = activity['morningRides'] as int? ?? 0;
    final isVerified = activity['isVerified'] as bool? ?? false;
    final rideMode = activity['rideMode'] as String? ?? 'motorcycle';
    final fiveStarRideCount = activity['fiveStarRideCount'] as int? ?? 0;
    final liveRideCount = activity['liveRideCount'] as int? ?? 0;
    final hasNightRide = activity['hasNightRide'] as bool? ?? false;
    final maxSingleRideKm = activity['maxSingleRideKm'] as double? ?? 0.0;
    final maxSpeedKmh = activity['maxSpeedKmh'] as double? ?? 0.0;
    final maxRideDurationHours =
        activity['maxRideDurationHours'] as double? ?? 0.0;
    final maxRideParticipants = activity['maxRideParticipants'] as int? ?? 0;
    final hasLedRide = activity['hasLedRide'] as bool? ?? false;
    final paceMilestoneKmh = rideMode == 'bicycle' ? 45.0 : 120.0;

    return {
      'first_ride': rideCount >= 1,
      'ten_rides': rideCount >= 10,
      'fifty_rides': rideCount >= 50,
      'hundred_km_club': totalKm >= 100,
      'five_hundred_km_club': totalKm >= 500,
      'first_match': matchCount >= 1,
      'five_matches': matchCount >= 5,
      'first_group_ride': groupRideCount >= 1,
      'social_butterfly': matchCount >= 10,
      'verified_rider': rideMode != 'bicycle' && isVerified,
      'safe_rider': safetyTagCount >= 3,
      'reliable': averageRating >= 4.8 && fiveStarRideCount >= 5,
      'profile_complete': profileComplete,
      'photo_pro': bikePhotoCount >= 6,
      'premium_member': isPremium,
      'weekend_warrior': weekendRides >= 5,
      'early_bird': morningRides >= 3,
      'first_live_ride': liveRideCount >= 1,
      'five_live_rides': liveRideCount >= 5,
      'ten_live_rides': liveRideCount >= 10,
      'century_live_ride': maxSingleRideKm >= 100,
      'night_rider': hasNightRide,
      'speed_demon': maxSpeedKmh >= paceMilestoneKmh,
      'marathon_rider': maxRideDurationHours >= 3,
      'squad_leader': hasLedRide && maxRideParticipants >= 4,
    };
  }

  /// Fetch all badges with earned state and real progress for current user
  static Future<List<BadgeModel>> fetchUserBadges() async {
    final user = _client.auth.currentUser;
    final allBadges = BadgeModel.allBadges();

    if (user == null) return allBadges;

    try {
      final earnedResponse = await _client
          .from('user_badges')
          .select('badge_id, earned_at')
          .eq('user_id', user.id);

      final earnedMap = <String, DateTime>{};
      for (final row in earnedResponse as List<dynamic>) {
        final badgeId = row['badge_id'] as String;
        final earnedAt = row['earned_at'] != null
            ? DateTime.tryParse(row['earned_at'].toString())
            : null;
        earnedMap[badgeId] = earnedAt ?? DateTime.now();
      }

      final activity = await _fetchUserActivity(user.id);
      await _autoAwardBadges(user.id, activity, earnedMap);
      final visibleBadges = _visibleBadgesForActivity(allBadges, activity);

      final updatedEarned = await _client
          .from('user_badges')
          .select('badge_id, earned_at')
          .eq('user_id', user.id);

      final updatedEarnedMap = <String, DateTime>{};
      for (final row in updatedEarned as List<dynamic>) {
        final badgeId = row['badge_id'] as String;
        final earnedAt = row['earned_at'] != null
            ? DateTime.tryParse(row['earned_at'].toString())
            : null;
        updatedEarnedMap[badgeId] = earnedAt ?? DateTime.now();
      }

      return visibleBadges.map((badge) {
        final progress = _getProgressForBadge(badge.id, activity);
        if (updatedEarnedMap.containsKey(badge.id)) {
          return badge.copyWith(
            isEarned: true,
            earnedAt: updatedEarnedMap[badge.id],
            progressCurrent: badge.progressTarget ?? 1,
            progressTarget: badge.progressTarget ?? 1,
          );
        }
        return badge.copyWith(
          progressCurrent: progress,
          progressTarget: badge.progressTarget,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ fetchUserBadges failed: $e');
      return allBadges;
    }
  }

  static List<BadgeModel> _visibleBadgesForActivity(
    List<BadgeModel> badges,
    Map<String, dynamic> activity,
  ) {
    final rideMode = activity['rideMode'] as String? ?? 'motorcycle';
    if (rideMode != 'bicycle') return badges;

    return badges.where((badge) => badge.id != 'verified_rider').toList();
  }

  /// Fetch user activity stats from Supabase
  static Future<Map<String, dynamic>> _fetchUserActivity(String userId) async {
    final activity = <String, dynamic>{
      'rideCount': 0,
      'totalKm': 0.0,
      'matchCount': 0,
      'groupRideCount': 0,
      'bikePhotoCount': 0,
      'profileComplete': false,
      'isPremium': false,
      'averageRating': 0.0,
      'safetyTagCount': 0,
      'weekendRides': 0,
      'morningRides': 0,
      'isVerified': false,
      'rideMode': 'motorcycle',
      'fiveStarRideCount': 0,
      'liveRideCount': 0,
      'hasNightRide': false,
      'maxSingleRideKm': 0.0,
      'maxSpeedKmh': 0.0,
      'maxRideDurationHours': 0.0,
      'maxRideParticipants': 0,
      'hasLedRide': false,
    };

    try {
      // Ride ratings
      final ridesResponse = await _client
          .from('ride_ratings')
          .select('stars, safety_tags, created_at')
          .eq('reviewed_id', userId);

      final rides = ridesResponse as List<dynamic>;
      activity['rideCount'] = rides.length;

      if (rides.isNotEmpty) {
        double totalRating = 0;
        int safetyTagCount = 0;
        int fiveStarCount = 0;
        int weekendRides = 0;
        int morningRides = 0;

        for (final ride in rides) {
          final rating = (ride['stars'] as num?)?.toDouble() ?? 0.0;
          totalRating += rating;
          if (rating >= 5.0) fiveStarCount++;

          final rawTags = ride['safety_tags'];
          final tags = rawTags is List ? rawTags : const [];

          for (final tag in tags) {
            if (tag.toString().toLowerCase().contains('safe')) {
              safetyTagCount++;
            }
          }

          final createdAt = ride['created_at'] != null
              ? DateTime.tryParse(ride['created_at'].toString())
              : null;
          if (createdAt != null) {
            if (createdAt.weekday == DateTime.saturday ||
                createdAt.weekday == DateTime.sunday) {
              weekendRides++;
            }
            if (createdAt.hour < 8) {
              morningRides++;
            }
          }
        }

        activity['averageRating'] = totalRating / rides.length;
        activity['safetyTagCount'] = safetyTagCount;
        activity['fiveStarRideCount'] = fiveStarCount;
        activity['weekendRides'] = weekendRides;
        activity['morningRides'] = morningRides;
      }

      // Match count
      try {
        final matchesResponse = await _client
            .from('matches')
            .select('user_id')
            .or('user_id.eq.$userId,matched_user_id.eq.$userId');
        activity['matchCount'] = (matchesResponse as List<dynamic>).length;
      } catch (_) {}

      // Group ride count
      try {
        final groupRidesResponse = await _client
            .from('ride_group_invites')
            .select('invitee_id')
            .eq('invitee_id', userId);
        activity['groupRideCount'] =
            (groupRidesResponse as List<dynamic>).length;
      } catch (_) {}

      // Bike photos
      try {
        final bikesResponse = await _client
            .from('garage_bikes')
            .select('photo_url')
            .eq('user_id', userId);
        int photoCount = 0;
        for (final bike in bikesResponse as List) {
          final photoUrl = bike['photo_url'] as String?;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            photoCount++;
          }
        }
        activity['bikePhotoCount'] = photoCount;
      } catch (_) {}

      // Verification
      try {
        final verificationResponse = await _client
            .from('rider_verifications')
            .select('status')
            .eq('user_id', userId)
            .eq('status', 'approved')
            .maybeSingle();
        activity['isVerified'] = verificationResponse != null;
      } catch (_) {}

      // Profile and premium
      try {
        final profileResponse = await _client
            .from('user_profiles')
            .select('is_profile_complete, is_premium, ride_mode')
            .eq('id', userId)
            .maybeSingle();
        activity['profileComplete'] =
            profileResponse?['is_profile_complete'] as bool? ?? false;
        activity['isPremium'] =
            profileResponse?['is_premium'] as bool? ?? false;
        activity['rideMode'] =
            profileResponse?['ride_mode'] as String? ?? 'motorcycle';
      } catch (e) {
        try {
          activity['profileComplete'] =
              await ProfileService.isProfileComplete();
          activity['isPremium'] = PremiumService().isPremium;
          final profile = await ProfileService.loadProfile();
          activity['rideMode'] =
              profile['rideMode'] as String? ?? 'motorcycle';
        } catch (_) {}
      }

      // Total km from saved routes
      try {
        final routesResponse = await _client
            .from('saved_routes')
            .select('distance_km')
            .eq('user_id', userId);
        double totalKm = 0;
        for (final route in routesResponse as List<dynamic>) {
          totalKm += (route['distance_km'] as num?)?.toDouble() ?? 0.0;
        }
        activity['totalKm'] = totalKm;
      } catch (_) {}

      // Live ride count
      try {
        final liveRidesResponse = await _client
            .from('live_ride_participants')
            .select('session_id')
            .eq('user_id', userId)
            .eq('status', 'left');
        activity['liveRideCount'] = (liveRidesResponse as List<dynamic>).length;
      } catch (_) {}

      // Live ride advanced stats
      try {
        final sessionsResponse = await _client
            .from('live_ride_participants')
            .select(
              'session_id, live_ride_sessions(id, started_by, started_at, ended_at, status)',
            )
            .eq('user_id', userId)
            .eq('status', 'left');

        final sessions = sessionsResponse as List<dynamic>;
        bool hasNightRide = false;
        bool hasLedRide = false;
        double maxSingleRideKm = 0;
        double maxSpeedKmh = 0;
        double maxRideDurationHours = 0;
        int maxRideParticipants = 0;

        for (final session in sessions) {
          final sessionData =
              session['live_ride_sessions'] as Map<String, dynamic>?;
          if (sessionData == null) continue;

          final sessionId = sessionData['id'] as String;
          final startedBy = sessionData['started_by'] as String?;
          final startedAt = sessionData['started_at'] != null
              ? DateTime.tryParse(sessionData['started_at'] as String)
              : null;
          final endedAt = sessionData['ended_at'] != null
              ? DateTime.tryParse(sessionData['ended_at'] as String)
              : null;

          // Check if user led this ride
          if (startedBy == userId) hasLedRide = true;

          // Check night ride (started between 8pm and 5am)
          if (startedAt != null) {
            if (startedAt.hour >= 20 || startedAt.hour < 5) {
              hasNightRide = true;
            }
          }

          // Check duration
          if (startedAt != null && endedAt != null) {
            final durationHours =
                endedAt.difference(startedAt).inMinutes / 60.0;
            if (durationHours > maxRideDurationHours) {
              maxRideDurationHours = durationHours;
            }
          }

          // Check participant count
          try {
            final participantsResponse = await _client
                .from('live_ride_participants')
                .select('user_id')
                .eq('session_id', sessionId);
            final count = (participantsResponse as List<dynamic>).length;
            if (count > maxRideParticipants) {
              maxRideParticipants = count;
            }
          } catch (_) {}

          // Check max speed and distance from location data
          try {
            final locationsResponse = await _client
                .from('live_ride_locations')
                .select('latitude, longitude, speed')
                .eq('session_id', sessionId)
                .eq('user_id', userId)
                .order('created_at', ascending: true);

            final locations = locationsResponse as List<dynamic>;
            double sessionDistance = 0;

            for (int i = 0; i < locations.length; i++) {
              final speed = (locations[i]['speed'] as num?)?.toDouble() ?? 0;
              final speedKmh = speed * 3.6;
              if (speedKmh > maxSpeedKmh) maxSpeedKmh = speedKmh;

              if (i > 0) {
                final lat1 = (locations[i - 1]['latitude'] as num).toDouble();
                final lon1 = (locations[i - 1]['longitude'] as num).toDouble();
                final lat2 = (locations[i]['latitude'] as num).toDouble();
                final lon2 = (locations[i]['longitude'] as num).toDouble();
                sessionDistance += _haversineDistance(lat1, lon1, lat2, lon2);
              }
            }

            if (sessionDistance > maxSingleRideKm) {
              maxSingleRideKm = sessionDistance;
            }
          } catch (_) {}
        }

        activity['hasNightRide'] = hasNightRide;
        activity['hasLedRide'] = hasLedRide;
        activity['maxSingleRideKm'] = maxSingleRideKm;
        activity['maxSpeedKmh'] = maxSpeedKmh;
        activity['maxRideDurationHours'] = maxRideDurationHours;
        activity['maxRideParticipants'] = maxRideParticipants;
      } catch (_) {}
    } catch (_) {}

    return activity;
  }

  /// Haversine distance between two GPS coordinates in km
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Get progress value for a specific badge
  static int _getProgressForBadge(
    String badgeId,
    Map<String, dynamic> activity,
  ) {
    switch (badgeId) {
      case 'first_ride':
      case 'ten_rides':
      case 'fifty_rides':
        return (activity['rideCount'] as int? ?? 0);
      case 'hundred_km_club':
      case 'five_hundred_km_club':
        return (activity['totalKm'] as double? ?? 0.0).toInt();
      case 'first_match':
      case 'five_matches':
      case 'social_butterfly':
        return (activity['matchCount'] as int? ?? 0);
      case 'first_group_ride':
        return (activity['groupRideCount'] as int? ?? 0);
      case 'safe_rider':
        return (activity['safetyTagCount'] as int? ?? 0);
      case 'reliable':
        return (activity['fiveStarRideCount'] as int? ?? 0);
      case 'photo_pro':
        return (activity['bikePhotoCount'] as int? ?? 0);
      case 'weekend_warrior':
        return (activity['weekendRides'] as int? ?? 0);
      case 'early_bird':
        return (activity['morningRides'] as int? ?? 0);
      case 'verified_rider':
        return (activity['isVerified'] as bool? ?? false) ? 1 : 0;
      case 'profile_complete':
        return (activity['profileComplete'] as bool? ?? false) ? 1 : 0;
      case 'premium_member':
        return (activity['isPremium'] as bool? ?? false) ? 1 : 0;
      case 'first_live_ride':
      case 'five_live_rides':
      case 'ten_live_rides':
        return (activity['liveRideCount'] as int? ?? 0);
      case 'century_live_ride':
        return (activity['maxSingleRideKm'] as double? ?? 0.0).toInt();
      case 'night_rider':
        return (activity['hasNightRide'] as bool? ?? false) ? 1 : 0;
      case 'speed_demon':
        return (activity['maxSpeedKmh'] as double? ?? 0.0).toInt();
      case 'marathon_rider':
        return (activity['maxRideDurationHours'] as double? ?? 0.0).toInt();
      case 'squad_leader':
        return (activity['maxRideParticipants'] as int? ?? 0);
      default:
        return 0;
    }
  }

  /// Auto-award badges based on fetched activity
  static Future<void> _autoAwardBadges(
    String userId,
    Map<String, dynamic> activity,
    Map<String, DateTime> alreadyEarned,
  ) async {
    final criteria = _buildCriteria(activity);

    for (final entry in criteria.entries) {
      if (entry.value && !alreadyEarned.containsKey(entry.key)) {
        await _insertBadge(userId, entry.key);
      }
    }
  }

  /// Insert a badge record safely
  static Future<void> _insertBadge(String userId, String badgeId) async {
    try {
      await _client.from('user_badges').upsert({
        'user_id': userId,
        'badge_id': badgeId,
        'earned_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,badge_id');
    } catch (_) {}
  }

  /// Award a badge to the current user, returns true if newly awarded
  static Future<bool> awardBadge(String badgeId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final existing = await _client
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', user.id)
          .eq('badge_id', badgeId)
          .maybeSingle();

      if (existing != null) return false;

      await _client.from('user_badges').insert({
        'user_id': user.id,
        'badge_id': badgeId,
        'earned_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Check and award badges based on user activity data (called externally)
  static Future<List<String>> checkAndAwardBadges({
    int rideCount = 0,
    double totalKm = 0,
    int matchCount = 0,
    int groupRideCount = 0,
    int bikePhotoCount = 0,
    bool profileComplete = false,
    bool isPremium = false,
    double averageRating = 0,
    List<String> safetyTags = const [],
    int weekendRides = 0,
    int morningRides = 0,
    bool isVerified = false,
    int fiveStarRideCount = 0,
    int liveRideCount = 0,
  }) async {
    final newlyEarned = <String>[];

    int safetyTagCount = 0;
    for (final tag in safetyTags) {
      if (tag.toLowerCase().contains('safe')) {
        safetyTagCount++;
      }
    }

    final activity = <String, dynamic>{
      'rideCount': rideCount,
      'totalKm': totalKm,
      'matchCount': matchCount,
      'groupRideCount': groupRideCount,
      'bikePhotoCount': bikePhotoCount,
      'profileComplete': profileComplete,
      'isPremium': isPremium,
      'averageRating': averageRating,
      'safetyTagCount': safetyTagCount,
      'weekendRides': weekendRides,
      'morningRides': morningRides,
      'isVerified': isVerified,
      'fiveStarRideCount': fiveStarRideCount,
      'liveRideCount': liveRideCount,
    };

    final criteria = _buildCriteria(activity);

    for (final entry in criteria.entries) {
      if (entry.value) {
        final awarded = await awardBadge(entry.key);
        if (awarded) newlyEarned.add(entry.key);
      }
    }

    return newlyEarned;
  }

  /// Get earned badge count for a user
  static Future<int> getEarnedBadgeCount() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    try {
      final response = await _client
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', user.id);
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }
}

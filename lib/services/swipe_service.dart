import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SwipeResult {
  final bool isMatch;
  final String? matchId;

  const SwipeResult({required this.isMatch, this.matchId});
}

class SwipeService {
  static final SwipeService instance = SwipeService._();
  SwipeService._();

  final _supabase = Supabase.instance.client;

  Future<SwipeResult> recordSwipe({
    required String swipedId,
    required String direction,
  }) async {
    try {
      final result = await _supabase.rpc(
        'record_swipe',
        params: {'p_swiped_id': swipedId, 'p_direction': direction},
      );

      final data = result as Map<String, dynamic>;
      return SwipeResult(
        isMatch: data['is_match'] as bool? ?? false,
        matchId: data['match_id'] as String?,
      );
    } catch (e) {
      debugPrint('SwipeService.recordSwipe error: $e');
      return const SwipeResult(isMatch: false);
    }
  }

  Future<List<String>> getSwipedIds() async {
    try {
      final result = await _supabase.rpc('get_swiped_ids');
      if (result == null) return [];

      return List<String>.from((result as List).map((e) => e.toString()));
    } catch (e) {
      debugPrint('SwipeService.getSwipedIds error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMatches() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('SwipeService.getMatches: No authenticated user');
        return [];
      }

      final uid = currentUser.id;
      final otherIds = <String>[];
      final matchedAtMap = <String, String>{};

      final matchRows = await _supabase
          .from('rider_matches')
          .select('id, user1_id, user2_id, created_at')
          .or('user1_id.eq.$uid,user2_id.eq.$uid')
          .order('created_at', ascending: false);

      for (final row in matchRows as List<dynamic>) {
        final r = row as Map<String, dynamic>;
        final user1Id = r['user1_id'] as String?;
        final user2Id = r['user2_id'] as String?;

        final otherId = user1Id == uid ? user2Id : user1Id;

        if (otherId != null && otherId.isNotEmpty && otherId != uid) {
          otherIds.add(otherId);
          matchedAtMap[otherId] = (r['created_at'] ?? '').toString();
        }
      }

      return _profilesForIds(otherIds, matchedAtMap);
    } catch (e, stack) {
      debugPrint('SwipeService.getMatches error: $e\n$stack');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInviteableMatches() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('SwipeService.getInviteableMatches: No authenticated user');
        return [];
      }

      final uid = currentUser.id;
      final otherIds = <String>{};
      final matchedAtMap = <String, String>{};

      try {
        final riderMatchRows = await _supabase
            .from('rider_matches')
            .select('id, user1_id, user2_id, created_at')
            .or('user1_id.eq.$uid,user2_id.eq.$uid')
            .order('created_at', ascending: false);

        for (final row in riderMatchRows as List<dynamic>) {
          final r = row as Map<String, dynamic>;
          final user1Id = r['user1_id'] as String?;
          final user2Id = r['user2_id'] as String?;

          final otherId = user1Id == uid ? user2Id : user1Id;

          if (otherId != null && otherId.isNotEmpty && otherId != uid) {
            otherIds.add(otherId);
            matchedAtMap[otherId] = (r['created_at'] ?? '').toString();
          }
        }
      } catch (e) {
        debugPrint(
          'SwipeService.getInviteableMatches rider_matches error: $e',
        );
      }

      try {
        final matchRows = await _supabase
            .from('matches')
            .select('id, user_id, matched_user_id, created_at')
            .or('user_id.eq.$uid,matched_user_id.eq.$uid')
            .order('created_at', ascending: false);

        for (final row in matchRows as List<dynamic>) {
          final r = row as Map<String, dynamic>;
          final userId = r['user_id'] as String?;
          final matchedUserId = r['matched_user_id'] as String?;

          final otherId = userId == uid ? matchedUserId : userId;

          if (otherId != null && otherId.isNotEmpty && otherId != uid) {
            otherIds.add(otherId);
            matchedAtMap[otherId] = (r['created_at'] ?? '').toString();
          }
        }
      } catch (e) {
        debugPrint('SwipeService.getInviteableMatches matches error: $e');
      }

      return _profilesForIds(otherIds.toList(), matchedAtMap);
    } catch (e, stack) {
      debugPrint('SwipeService.getInviteableMatches error: $e\n$stack');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _profilesForIds(
    List<String> ids,
    Map<String, String> matchedAtMap,
  ) async {
    if (ids.isEmpty) return [];

    final uniqueIds = ids.toSet().toList();

    try {
      final profileResponse = await _supabase
          .from('user_profiles')
          .select(
            'id, full_name, email, avatar_url, bike_types, bio, ride_mode, '
            'updated_at',
          )
          .inFilter('id', uniqueIds);

      final profileMap = <String, Map<String, dynamic>>{};

      for (final p in profileResponse as List<dynamic>) {
        final profile = p as Map<String, dynamic>;
        final profileId = profile['id'] as String?;

        if (profileId != null && profileId.isNotEmpty) {
          profileMap[profileId] = profile;
        }
      }

      return uniqueIds.map((otherId) {
        final profile = profileMap[otherId];

        return {
          'id': otherId,
          'full_name': (profile?['full_name'] as String?) ?? '',
          'email': (profile?['email'] as String?) ?? '',
          'avatar_url': _versionedAvatarUrl(profile),
          'bike_types': profile?['bike_types'],
          'ride_mode': profile?['ride_mode'] as String? ?? 'motorcycle',
          'matched_at': matchedAtMap[otherId] ?? '',
        };
      }).toList();
    } catch (e, stack) {
      debugPrint('SwipeService._profilesForIds error: $e\n$stack');
      return [];
    }
  }

  String? _usableAvatarUrl(dynamic value) {
    if (value is! String) return null;

    final url = value.trim();
    if (url.isEmpty || url.startsWith('blob:') || url.startsWith('file:')) {
      return null;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null;
    }

    return url;
  }

  String? _versionedAvatarUrl(Map<String, dynamic>? profile) {
    final avatarUrl = _usableAvatarUrl(profile?['avatar_url']);
    if (avatarUrl == null) return null;

    final updatedAt = profile?['updated_at']?.toString();
    if (updatedAt == null || updatedAt.isEmpty) return avatarUrl;

    final separator = avatarUrl.contains('?') ? '&' : '?';
    return '$avatarUrl${separator}v=${Uri.encodeComponent(updatedAt)}';
  }
}

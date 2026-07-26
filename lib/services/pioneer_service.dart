import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PioneerStatus {
  const PioneerStatus({
    required this.userId,
    required this.number,
    required this.awardedAt,
    required this.earlyAccessEnabled,
  });

  final String userId;
  final int number;
  final DateTime? awardedAt;
  final bool earlyAccessEnabled;

  factory PioneerStatus.fromMap(Map<String, dynamic> map) {
    return PioneerStatus(
      userId: map['user_id'] as String,
      number: (map['pioneer_number'] as num).toInt(),
      awardedAt: DateTime.tryParse(map['awarded_at']?.toString() ?? ''),
      earlyAccessEnabled: map['early_access_enabled'] == true,
    );
  }
}

class PioneerService {
  PioneerService._();

  static final PioneerService instance = PioneerService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<PioneerStatus?> claimCurrentUserMembership() async {
    try {
      final response = await _client.rpc('claim_pioneer_membership');
      final rows = List<Map<String, dynamic>>.from(response as List);
      return rows.isEmpty ? null : PioneerStatus.fromMap(rows.first);
    } catch (error, stackTrace) {
      debugPrint('Pioneer membership claim failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<Map<String, PioneerStatus>> getStatuses(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};

    try {
      final response = await _client.rpc(
        'get_pioneer_status',
        params: {'p_user_ids': ids},
      );
      final rows = List<Map<String, dynamic>>.from(response as List);
      return {
        for (final row in rows)
          if (row['user_id'] != null)
            row['user_id'] as String: PioneerStatus.fromMap(row),
      };
    } catch (error, stackTrace) {
      debugPrint('Pioneer status lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const {};
    }
  }

  Future<PioneerStatus?> getStatus(String userId) async {
    return (await getStatuses([userId]))[userId];
  }

  Future<void> enrichProfiles(List<Map<String, dynamic>> profiles) async {
    final statuses = await getStatuses(
      profiles.map((profile) => _profileId(profile)),
    );

    for (final profile in profiles) {
      final status = statuses[_profileId(profile)];
      profile['is_pioneer'] = status != null;
      profile['pioneer_number'] = status?.number;
      profile['pioneer_awarded_at'] = status?.awardedAt?.toIso8601String();
      profile['pioneer_early_access'] =
          status?.earlyAccessEnabled ?? false;
    }
  }

  String _profileId(Map<String, dynamic> profile) {
    return (profile['id'] ??
            profile['user_id'] ??
            profile['rider_id'] ??
            profile['matched_user_id'] ??
            '')
        .toString();
  }
}


import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './premium_service.dart';
import './supabase_service.dart';

class ReferralStats {
  final String code;
  final int totalReferrals;
  final int trialDaysEarned;
  final int premiumTrialDays;
  final DateTime createdAt;

  ReferralStats({
    required this.code,
    required this.totalReferrals,
    required this.trialDaysEarned,
    required this.premiumTrialDays,
    required this.createdAt,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    final totalReferrals = json['total_referrals'] as int? ?? 0;
    final premiumTrialDays = json['premium_trial_days'] as int? ?? 7;

    return ReferralStats(
      code: json['code'] as String? ?? '',
      totalReferrals: totalReferrals,
      trialDaysEarned: totalReferrals * premiumTrialDays,
      premiumTrialDays: premiumTrialDays,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;

  String _normalizeReferralCode(String code) {
    return code.trim().toUpperCase();
  }

  Future<ReferralStats?> getOrCreateReferralCode() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final existingRows = await _client
          .from('referral_codes')
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      final existingList = List<Map<String, dynamic>>.from(existingRows);
      if (existingList.isNotEmpty) {
        return ReferralStats.fromJson(existingList.first);
      }

      await _client.rpc(
        'get_or_create_referral_code',
        params: {'user_uuid': user.id},
      );

      final createdRows = await _client
          .from('referral_codes')
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      final createdList = List<Map<String, dynamic>>.from(createdRows);
      if (createdList.isEmpty) return null;

      return ReferralStats.fromJson(createdList.first);
    } catch (e) {
      debugPrint('ReferralService.getOrCreateReferralCode error: $e');
      return null;
    }
  }

  Future<bool> applyReferralCode(String code) async {
    final user = _client.auth.currentUser;
    final normalizedCode = _normalizeReferralCode(code);

    if (user == null || normalizedCode.isEmpty) return false;

    try {
      final result = await _client.rpc(
        'apply_referral_code',
        params: {
          'referred_uuid': user.id,
          'referral_code': normalizedCode,
        },
      );

      if (result == true) {
        await PremiumService().activatePremium();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('ReferralService.applyReferralCode error: $e');
      return false;
    }
  }

  Future<bool> validateReferralCode(String code) async {
    final normalizedCode = _normalizeReferralCode(code);
    if (normalizedCode.isEmpty) return false;

    try {
      final result = await _client
          .from('referral_codes')
          .select('id')
          .eq('code', normalizedCode)
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('ReferralService.validateReferralCode error: $e');
      return false;
    }
  }

  Future<ReferralStats?> fetchReferralStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final rows = await _client
          .from('referral_codes')
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return null;

      return ReferralStats.fromJson(list.first);
    } catch (e) {
      debugPrint('ReferralService.fetchReferralStats error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReferredUsers() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final data = await _client
          .from('referral_tracking')
          .select(
            'id, status, trial_days_awarded, referred_user_trial_days_awarded, created_at',
          )
          .eq('referrer_user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('ReferralService.fetchReferredUsers error: $e');
      return [];
    }
  }
}

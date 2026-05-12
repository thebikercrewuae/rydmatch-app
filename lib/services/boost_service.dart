import 'package:supabase_flutter/supabase_flutter.dart';

class BoostService {
  static final BoostService _instance = BoostService._internal();
  factory BoostService() => _instance;
  BoostService._internal();

  static const Duration boostDuration = Duration(minutes: 30);
  static const Duration cooldownDuration = Duration(hours: 3);

  /// Returns the active boost record if one exists and hasn't expired, else null.
  Future<Map<String, dynamic>?> getActiveBoost() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final now = DateTime.now().toUtc().toIso8601String();
      final response = await client
          .from('profile_boosts')
          .select()
          .eq('user_id', userId)
          .gt('expires_at', now)
          .order('boosted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (_) {
      return null;
    }
  }

  /// Returns the most recent boost (active or expired) for cooldown calculation.
  Future<Map<String, dynamic>?> getLastBoost() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await client
          .from('profile_boosts')
          .select()
          .eq('user_id', userId)
          .order('boosted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (_) {
      return null;
    }
  }

  /// Activates a new boost. Returns the boost record or null on failure.
  Future<Map<String, dynamic>?> activateBoost() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final now = DateTime.now().toUtc();
      final expiresAt = now.add(boostDuration);

      final response = await client
          .from('profile_boosts')
          .insert({
            'user_id': userId,
            'boosted_at': now.toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (_) {
      return null;
    }
  }

  /// Returns remaining boost time, or Duration.zero if no active boost.
  Future<Duration> getRemainingBoostTime() async {
    final boost = await getActiveBoost();
    if (boost == null) return Duration.zero;
    final expiresAt = DateTime.parse(boost['expires_at'] as String).toLocal();
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns remaining cooldown time before next boost is allowed.
  Future<Duration> getRemainingCooldown() async {
    final last = await getLastBoost();
    if (last == null) return Duration.zero;
    final boostedAt = DateTime.parse(last['boosted_at'] as String).toLocal();
    final cooldownEnd = boostedAt.add(cooldownDuration);
    final remaining = cooldownEnd.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether the user can boost right now (no active boost, no cooldown).
  Future<bool> canBoost() async {
    final active = await getActiveBoost();
    if (active != null) return false;
    final cooldown = await getRemainingCooldown();
    return cooldown == Duration.zero;
  }

  String formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}h ${minutes}m';
    }
    return '$minutes:$seconds';
  }
}

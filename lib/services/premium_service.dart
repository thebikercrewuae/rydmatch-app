import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'diagnostics_service.dart';

class PremiumService extends ChangeNotifier {
  static final PremiumService _instance = PremiumService._internal();

  factory PremiumService() => _instance;

  PremiumService._internal();

  bool _isPremiumAccount = false;
  bool _isAdmin = false;
  bool _priorityListingsEnabled = false;
  bool _isLoaded = false;

  static const String _localPremiumKey = 'premium_entitlement_active';

  /// Existing app code mostly checks isPremium.
  /// Admin users should receive full access too, so this returns true for either.
  bool get isPremium => _isPremiumAccount || _isAdmin;

  /// The actual paid/trial premium flag from the database.
  bool get isPremiumAccount => _isPremiumAccount;

  /// Admin profile flag from user_profiles.is_admin.
  bool get isAdmin => _isAdmin;

  /// Clearer name for future screens.
  bool get hasFullAccess => isPremium;

  bool get priorityListingsEnabled => _priorityListingsEnabled;
  bool get isLoaded => _isLoaded;

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final localPremium = prefs.getBool(_localPremiumKey) ?? false;

    if (currentUser == null) {
      _isPremiumAccount = localPremium;
      _isAdmin = false;
      _priorityListingsEnabled = false;
      _isLoaded = true;
      notifyListeners();
      return;
    }

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('is_premium, is_admin')
          .eq('id', currentUser.id)
          .maybeSingle();

      _isPremiumAccount = profile?['is_premium'] == true || localPremium;
      _isAdmin = profile?['is_admin'] == true;

      // Admins should have access to priority listings as part of full access.
      if (_isAdmin) {
        _isPremiumAccount = true;
        _priorityListingsEnabled = true;
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('PremiumService.refresh error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'refresh_entitlement',
        error: e,
        context: {'has_local_premium': localPremium},
      );
      _isPremiumAccount = localPremium;
      _isAdmin = false;
      _priorityListingsEnabled = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> activatePremium() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localPremiumKey, true);

    _isPremiumAccount = true;
    notifyListeners();

    try {
      await supabase
          .from('user_profiles')
          .update({
            'is_premium': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentUser.id);
    } catch (e) {
      debugPrint('PremiumService.activatePremium sync error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'activate_premium_sync',
        error: e,
      );
    }
  }

  Future<void> setPriorityListings(bool enabled) async {
    if (_isAdmin) {
      _priorityListingsEnabled = true;
      notifyListeners();
      return;
    }

    _priorityListingsEnabled = enabled && isPremium;
    notifyListeners();
  }

  Future<void> cancelPremium() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localPremiumKey);
      _isPremiumAccount = false;
      _isAdmin = false;
      _priorityListingsEnabled = false;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localPremiumKey);

    await supabase
        .from('user_profiles')
        .update({
          'is_premium': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', currentUser.id);

    _isPremiumAccount = false;

    // Keep admin access even if paid premium is cancelled.
    if (!_isAdmin) {
      _priorityListingsEnabled = false;
    }

    notifyListeners();
  }

  Future<void> clearLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localPremiumKey);
    _isPremiumAccount = false;
    _isAdmin = false;
    _priorityListingsEnabled = false;
    _isLoaded = false;
    notifyListeners();
  }
}

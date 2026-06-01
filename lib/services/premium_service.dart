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
  static const String _localPremiumSourceKey = 'premium_entitlement_source';
  static const String _localPremiumProductKey = 'premium_entitlement_product';
  static const String _localPremiumActivatedAtKey =
      'premium_entitlement_activated_at';
  static const String _localPremiumUserIdKey = 'premium_entitlement_user_id';

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
    await refresh(reason: 'init');
  }

  Future<void> refresh({String reason = 'manual'}) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString(_localPremiumUserIdKey);
    final rawLocalPremium = prefs.getBool(_localPremiumKey) ?? false;
    final localSource = prefs.getString(_localPremiumSourceKey);
    final localProduct = prefs.getString(_localPremiumProductKey);

    if (currentUser == null) {
      _isPremiumAccount = false;
      _isAdmin = false;
      _priorityListingsEnabled = false;
      _isLoaded = true;
      notifyListeners();
      return;
    }

    final localPremium =
        rawLocalPremium &&
        storedUserId != null &&
        storedUserId == currentUser.id;

    if (rawLocalPremium && storedUserId != currentUser.id) {
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'ignored_local_entitlement_for_different_user',
        error: 'Local premium cache belongs to a different user',
        severity: 'warning',
        context: {
          'reason': reason,
          'stored_user_id_present': storedUserId != null,
        },
      );
    }

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('is_premium, is_admin')
          .eq('id', currentUser.id)
          .maybeSingle();

      final remotePremium = profile?['is_premium'] == true;
      _isPremiumAccount = remotePremium || localPremium;
      _isAdmin = profile?['is_admin'] == true;

      if (remotePremium && !localPremium) {
        await prefs.setBool(_localPremiumKey, true);
        await prefs.setString(_localPremiumSourceKey, 'remote_profile');
      }

      if (localPremium && !remotePremium) {
        await _syncLocalEntitlementToProfile(
          supabase: supabase,
          userId: currentUser.id,
          source: localSource ?? 'local_cache',
          productId: localProduct,
          reason: reason,
        );
      }

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
        context: {
          'has_local_premium': localPremium,
          'raw_local_premium': rawLocalPremium,
          'stored_user_id_matches': storedUserId == currentUser.id,
          'local_source': localSource,
          'reason': reason,
        },
      );
      _isPremiumAccount = localPremium;
      _isAdmin = false;
      _priorityListingsEnabled = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> activatePremium({
    String source = 'manual',
    String? productId,
    Map<String, dynamic>? purchaseContext,
  }) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localPremiumKey, true);
    await prefs.setString(_localPremiumUserIdKey, currentUser.id);
    await prefs.setString(_localPremiumSourceKey, source);
    await prefs.setString(
      _localPremiumActivatedAtKey,
      DateTime.now().toIso8601String(),
    );
    if (productId != null && productId.isNotEmpty) {
      await prefs.setString(_localPremiumProductKey, productId);
    }

    _isPremiumAccount = true;
    notifyListeners();

    try {
      await _syncLocalEntitlementToProfile(
        supabase: supabase,
        userId: currentUser.id,
        source: source,
        productId: productId,
        reason: 'activate',
        purchaseContext: purchaseContext,
      );
    } catch (e) {
      debugPrint('PremiumService.activatePremium sync error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'activate_premium_sync',
        error: e,
        context: {
          'source': source,
          'product_id': productId,
          if (purchaseContext != null) 'purchase': purchaseContext,
        },
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
    final prefs = await SharedPreferences.getInstance();

    await _clearStoredEntitlement(prefs);

    if (currentUser == null) {
      _isPremiumAccount = false;
      _isAdmin = false;
      _priorityListingsEnabled = false;
      notifyListeners();
      return;
    }

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
    await _clearStoredEntitlement(prefs);
    _isPremiumAccount = false;
    _isAdmin = false;
    _priorityListingsEnabled = false;
    _isLoaded = false;
    notifyListeners();
  }

  Future<void> _clearStoredEntitlement(SharedPreferences prefs) async {
    await prefs.remove(_localPremiumKey);
    await prefs.remove(_localPremiumSourceKey);
    await prefs.remove(_localPremiumProductKey);
    await prefs.remove(_localPremiumActivatedAtKey);
    await prefs.remove(_localPremiumUserIdKey);
  }

  Future<void> _syncLocalEntitlementToProfile({
    required SupabaseClient supabase,
    required String userId,
    required String source,
    required String reason,
    String? productId,
    Map<String, dynamic>? purchaseContext,
  }) async {
    await supabase
        .from('user_profiles')
        .update({
          'is_premium': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);

    await DiagnosticsService.instance.logError(
      feature: 'premium',
      action: 'entitlement_synced',
      error: 'Premium entitlement synced to profile',
      severity: 'info',
      context: {
        'source': source,
        'reason': reason,
        'product_id': productId,
        if (purchaseContext != null) 'purchase': purchaseContext,
      },
    );
  }
}

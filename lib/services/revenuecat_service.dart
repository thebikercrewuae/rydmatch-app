import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'diagnostics_service.dart';

class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const String premiumEntitlementId = String.fromEnvironment(
    'REVENUECAT_PREMIUM_ENTITLEMENT',
    defaultValue: 'premium',
  );
  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );
  static const String _webApiKey = String.fromEnvironment(
    'REVENUECAT_WEB_API_KEY',
  );

  bool _configured = false;
  String? _configuredUserId;
  Package? _premiumPackage;

  bool get isConfigured => _configured;
  Package? get premiumPackage => _premiumPackage;
  String? get premiumPrice => _premiumPackage?.storeProduct.priceString;

  String? get _platformApiKey {
    if (kIsWeb) {
      return _webApiKey.trim().isEmpty ? null : _webApiKey.trim();
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidApiKey.trim().isEmpty ? null : _androidApiKey.trim();
      case TargetPlatform.iOS:
        return _iosApiKey.trim().isEmpty ? null : _iosApiKey.trim();
      default:
        return null;
    }
  }

  Future<bool> configureForCurrentUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return false;

    final apiKey = _platformApiKey;
    if (apiKey == null) {
      _configured = false;
      _configuredUserId = null;
      return false;
    }

    if (_configured && _configuredUserId == userId) return true;

    try {
      if (_configured) {
        await Purchases.logIn(userId);
      } else {
        await Purchases.setLogLevel(LogLevel.warn);
        await Purchases.configure(
          PurchasesConfiguration(apiKey)..appUserID = userId,
        );
      }
      _configured = true;
      _configuredUserId = userId;
      await _loadPremiumPackage();
      return true;
    } catch (e) {
      _configured = false;
      _configuredUserId = null;
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'revenuecat_configure',
        error: e,
        context: {'platform': defaultTargetPlatform.name},
      );
      return false;
    }
  }

  Future<bool> refreshPremiumEntitlement() async {
    final configured = await configureForCurrentUser();
    if (!configured) return false;

    try {
      final info = await Purchases.getCustomerInfo();
      return _hasPremiumEntitlement(info);
    } catch (e) {
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'revenuecat_refresh_entitlement',
        error: e,
        severity: 'warning',
      );
      return false;
    }
  }

  Future<Package?> loadPremiumPackage() async {
    final configured = await configureForCurrentUser();
    if (!configured) return null;
    return _loadPremiumPackage();
  }

  Future<bool> purchasePremiumPackage() async {
    final package = await loadPremiumPackage();
    if (package == null) {
      throw StateError('RevenueCat premium package is not configured.');
    }

    final result = await Purchases.purchase(PurchaseParams.package(package));
    return _hasPremiumEntitlement(result.customerInfo);
  }

  Future<bool> restorePurchases() async {
    final configured = await configureForCurrentUser();
    if (!configured) return false;

    final info = await Purchases.restorePurchases();
    return _hasPremiumEntitlement(info);
  }

  Future<Package?> _loadPremiumPackage() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null || current.availablePackages.isEmpty) {
        _premiumPackage = null;
        return null;
      }

      _premiumPackage =
          current.monthly ??
          current.availablePackages.firstWhere(
            (package) =>
                package.storeProduct.identifier.contains('premium') ||
                package.identifier.contains('premium'),
            orElse: () => current.availablePackages.first,
          );
      return _premiumPackage;
    } catch (e) {
      _premiumPackage = null;
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'revenuecat_load_offerings',
        error: e,
        severity: 'warning',
      );
      return null;
    }
  }

  bool _hasPremiumEntitlement(CustomerInfo info) {
    return info.entitlements.active[premiumEntitlementId]?.isActive == true;
  }
}

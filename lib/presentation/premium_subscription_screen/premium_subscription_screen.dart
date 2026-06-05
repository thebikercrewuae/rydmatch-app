import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/premium_service.dart';
import '../../services/analytics_service.dart';
import '../../services/diagnostics_service.dart';
import '../../services/profile_service.dart';
import '../../services/revenuecat_service.dart';
import './widgets/feature_card_widget.dart';
import '../../widgets/app_icons.dart';

class PremiumSubscriptionScreen extends StatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  State<PremiumSubscriptionScreen> createState() =>
      _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen>
    with SingleTickerProviderStateMixin {
  static const String _premiumProductId = 'rydmatch_premium_monthly';
  static const bool _betaPremiumUnlockEnabled = bool.fromEnvironment(
    'BETA_PREMIUM_UNLOCK_ENABLED',
    defaultValue: true,
  );

  bool _isProcessing = false;
  bool _showSuccess = false;
  bool _priorityListings = false;
  late AnimationController _successController;
  late Animation<double> _scaleAnimation;
  String? _referralCode;
  bool _loadingReferral = true;
  String? _premiumPrice;
  bool _revenueCatAvailable = false;
  bool _loadingStoreProduct = true;

  static const Color _orange = Color(0xFFE85A4F);
  static const Color _gold = Color(0xFFFFB347);
  static const Color _deepBlue = Color(0xFF0D1B3E);

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
    _priorityListings = PremiumService().priorityListingsEnabled;
    AnalyticsService.instance.logPremiumScreenView();
    _loadReferralCode();
    _loadStoreProduct();
  }

  Future<void> _loadReferralCode() async {
    final profile = await ProfileService.loadProfile();
    final name = (profile['riderName'] as String? ?? '').trim();
    if (mounted) {
      setState(() {
        _referralCode =
            '1N23456${name.isNotEmpty ? name.replaceAll(' ', '') : ''}';
        _loadingReferral = false;
      });
    }
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreProduct() async {
    try {
      final package = await RevenueCatService.instance.loadPremiumPackage();

      if (!mounted) return;
      setState(() {
        _revenueCatAvailable = RevenueCatService.instance.isConfigured;
        _premiumPrice = package?.storeProduct.priceString;
        _loadingStoreProduct = false;
      });
    } catch (e) {
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'load_store_product',
        error: e,
        severity: 'warning',
      );
      if (!mounted) return;
      setState(() {
        _revenueCatAvailable = false;
        _loadingStoreProduct = false;
      });
    }
  }

  Future<void> _handleSubscribe() async {
    final package = RevenueCatService.instance.premiumPackage;
    await AnalyticsService.instance.logPremiumSubscribeStarted(
      betaUnlockEnabled: _betaPremiumUnlockEnabled,
      price: package?.storeProduct.priceString,
      currencyCode: package?.storeProduct.currencyCode,
    );

    if (_betaPremiumUnlockEnabled) {
      await _activatePremiumForBeta();
      return;
    }

    if (!_revenueCatAvailable || package == null) {
      await AnalyticsService.instance.logPremiumPurchaseResult(
        status: 'store_unavailable',
        source: 'subscribe_button',
        productId: package?.storeProduct.identifier,
        price: package?.storeProduct.priceString,
        currencyCode: package?.storeProduct.currencyCode,
      );
      _showStoreMessage(
        'Subscription is not available yet. Please try again later.',
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final active = await RevenueCatService.instance.purchasePremiumPackage();
      if (!active) {
        await AnalyticsService.instance.logPremiumPurchaseResult(
          status: 'missing_entitlement',
          source: 'revenuecat_purchase',
          productId: package.storeProduct.identifier,
          price: package.storeProduct.priceString,
          currencyCode: package.storeProduct.currencyCode,
        );
        await DiagnosticsService.instance.logError(
          feature: 'premium',
          action: 'revenuecat_purchase_without_entitlement',
          error: 'RevenueCat purchase completed without premium entitlement',
          context: _revenueCatPackageContext(),
        );
        if (mounted) {
          setState(() => _isProcessing = false);
          _showStoreMessage(
            'Purchase completed, but Premium did not unlock. Please contact support.',
          );
        }
        return;
      }

      await AnalyticsService.instance.logPremiumPurchaseResult(
        status: 'success',
        source: 'revenuecat_purchase',
        productId: package.storeProduct.identifier,
        price: package.storeProduct.priceString,
        currencyCode: package.storeProduct.currencyCode,
      );
      await _finishPremiumActivation(
        source: 'revenuecat_purchase',
        productId: package.storeProduct.identifier,
        purchaseContext: _revenueCatPackageContext(),
        analyticsPlan: 'premium',
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      await AnalyticsService.instance.logPremiumPurchaseResult(
        status: 'error',
        source: 'revenuecat_purchase',
        productId: package.storeProduct.identifier,
        price: package.storeProduct.priceString,
        currencyCode: package.storeProduct.currencyCode,
        errorCode: e.code,
      );
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'revenuecat_purchase_error',
        error: e.message ?? e.code,
        context: {
          ..._revenueCatPackageContext(),
          'code': e.code,
          'details': e.details?.toString(),
        },
        severity: 'warning',
      );
      setState(() => _isProcessing = false);
      _showStoreMessage('Purchase could not be completed.');
    } catch (e) {
      if (!mounted) return;
      await AnalyticsService.instance.logPremiumPurchaseResult(
        status: 'error',
        source: 'revenuecat_purchase',
        productId: package.storeProduct.identifier,
        price: package.storeProduct.priceString,
        currencyCode: package.storeProduct.currencyCode,
      );
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'revenuecat_purchase_error',
        error: e,
        context: _revenueCatPackageContext(),
      );
      setState(() => _isProcessing = false);
      _showStoreMessage('Purchase could not be completed.');
    }
  }

  Future<void> _activatePremiumForBeta() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    await PremiumService().activatePremium(
      source: 'beta_subscribe_button',
      productId: _premiumProductId,
      purchaseContext: {
        'beta_unlock_enabled': true,
        'revenuecat_available': _revenueCatAvailable,
        'revenuecat_package_loaded':
            RevenueCatService.instance.premiumPackage != null,
      },
    );

    if (_priorityListings) {
      await PremiumService().setPriorityListings(true);
    }

    await PremiumService().refresh(reason: 'beta_subscribe_button');
    await AnalyticsService.instance.logPremiumPurchaseResult(
      status: 'success',
      source: 'beta_subscribe_button',
      productId: _premiumProductId,
    );
    await AnalyticsService.instance.logPremiumConverted(plan: 'beta_premium');

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _showSuccess = true;
    });
    _successController.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _handleRestorePurchase() async {
    if (!_revenueCatAvailable) {
      _showStoreMessage('Subscriptions are not available on this device.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final active = await RevenueCatService.instance.restorePurchases();
      if (!active) {
        await AnalyticsService.instance.logPremiumPurchaseResult(
          status: 'no_active_subscription',
          source: 'revenuecat_restore',
          productId: RevenueCatService
              .instance
              .premiumPackage
              ?.storeProduct
              .identifier,
        );
        if (mounted) {
          setState(() => _isProcessing = false);
          _showStoreMessage('No active Premium subscription was found.');
        }
        return;
      }

      await AnalyticsService.instance.logPremiumPurchaseResult(
        status: 'success',
        source: 'revenuecat_restore',
        productId:
            RevenueCatService.instance.premiumPackage?.storeProduct.identifier,
      );
      await _finishPremiumActivation(
        source: 'revenuecat_restore',
        productId:
            RevenueCatService.instance.premiumPackage?.storeProduct.identifier,
        purchaseContext: _revenueCatPackageContext(),
        analyticsPlan: 'premium_restore',
      );
    } catch (e) {
      if (!mounted) return;
      await AnalyticsService.instance.logPremiumPurchaseResult(
        status: 'error',
        source: 'revenuecat_restore',
        productId:
            RevenueCatService.instance.premiumPackage?.storeProduct.identifier,
      );
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'revenuecat_restore_error',
        error: e,
        severity: 'warning',
      );
      setState(() => _isProcessing = false);
      _showStoreMessage('Restore could not be completed.');
    }
  }

  Future<void> _finishPremiumActivation({
    required String source,
    required String analyticsPlan,
    String? productId,
    Map<String, dynamic>? purchaseContext,
  }) async {
    await PremiumService().activatePremium(
      source: source,
      productId: productId,
      purchaseContext: purchaseContext,
    );
    if (_priorityListings) {
      await PremiumService().setPriorityListings(true);
    }
    await PremiumService().refresh(reason: source);

    if (!PremiumService().isPremium) {
      await DiagnosticsService.instance.logError(
        feature: 'premium',
        action: 'premium_activation_completed_but_locked',
        error:
            'Premium activation completed but PremiumService remained locked',
        context: purchaseContext,
      );
      if (mounted) {
        setState(() => _isProcessing = false);
        _showStoreMessage('Premium did not unlock. Please contact support.');
      }
      return;
    }

    await AnalyticsService.instance.logPremiumConverted(plan: analyticsPlan);

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _showSuccess = true;
    });
    _successController.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop(true);
  }

  Map<String, dynamic> _revenueCatPackageContext() {
    final package = RevenueCatService.instance.premiumPackage;
    return {
      'entitlement_id': RevenueCatService.premiumEntitlementId,
      'package_id': package?.identifier,
      'product_id': package?.storeProduct.identifier,
      'price': package?.storeProduct.priceString,
      'currency_code': package?.storeProduct.currencyCode,
      'revenuecat_configured': RevenueCatService.instance.isConfigured,
    };
  }

  void _showStoreMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans(fontSize: 13.sp)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: _showSuccess ? _buildSuccessState() : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B3E), Color(0xFF1B365D), Color(0xFF2A1A0E)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Opacity(
        opacity: 0.06,
        child: Image.network(
          'https://images.pexels.com/photos/2611686/pexels-photo-2611686.jpeg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          semanticLabel: 'Motorcycle on open road at sunset with dramatic sky',
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _gold, width: 2),
              ),
              child: Icon(AppIcons.help, color: _gold, size: 32),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'Welcome to Premium!',
            style: GoogleFonts.dmSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'All premium features are now unlocked.',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 2.h),
                _buildHeroSection(),
                SizedBox(height: 3.h),
                _buildFeaturesSection(),
                SizedBox(height: 2.5.h),
                _buildPriorityToggle(),
                SizedBox(height: 3.h),
                _buildPricingSection(),
                SizedBox(height: 2.h),
                _buildSubscribeButton(),
                SizedBox(height: 1.5.h),
                _buildRestoreLink(),
                SizedBox(height: 2.h),
                _buildReferralSection(),
                SizedBox(height: 1.5.h),
                _buildLegalLinks(),
                SizedBox(height: 3.h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      child: Row(
        children: [
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_rounded, color: _gold, size: 18),
              SizedBox(width: 2.w),
              Text(
                'RydMatch Premium',
                style: GoogleFonts.dmSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [_gold.withValues(alpha: 0.25), Colors.transparent],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: _gold,
            size: 44,
          ),
        ),
        SizedBox(height: 1.5.h),
        Text(
          'Ride Further Together',
          style: GoogleFonts.dmSans(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 0.8.h),
        Text(
          'Unlock the tools that help riders plan, coordinate, and stand out in the RydMatch community.',
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: Colors.white.withValues(alpha: 0.65),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT YOU GET',
          style: GoogleFonts.dmSans(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: _gold,
            letterSpacing: 1.4,
          ),
        ),
        SizedBox(height: 1.5.h),
        FeatureCardWidget(
          icon: AppIcons.group,
          title: 'Ride Groups',
          description:
              'Create group rides with up to 6 riders, plan routes, and coordinate with matched riders.',
          accentColor: const Color(0xFF4FC3F7),
        ),
        SizedBox(height: 1.2.h),
        FeatureCardWidget(
          icon: AppIcons.analytics,
          title: 'Ride Analytics',
          description:
              'Track distance, riding streaks, favourite routes, and weekly activity insights.',
          accentColor: const Color(0xFF81C784),
        ),
        SizedBox(height: 1.2.h),
        FeatureCardWidget(
          icon: Icons.rocket_launch_rounded,
          title: 'Priority Listings',
          description:
              'Boost your profile so nearby riders are more likely to discover you.',
          accentColor: _gold,
        ),
        SizedBox(height: 1.2.h),
        FeatureCardWidget(
          icon: Icons.photo_library_rounded,
          title: 'Ride Feed',
          description:
              'Share ride photos, routes, and distances with matched riders. Like and comment on their adventures.',
          accentColor: const Color(0xFFE85A4F),
        ),
        SizedBox(height: 1.2.h),
        FeatureCardWidget(
          icon: Icons.cloud_outlined,
          title: 'Route Weather',
          description:
              'Check route conditions, wind, rain, and ride readiness before you go.',
          accentColor: const Color(0xFF4FC3F7),
        ),
        SizedBox(height: 1.2.h),
        FeatureCardWidget(
          icon: Icons.emoji_events_rounded,
          title: 'Leaderboard',
          description:
              'Compare riding activity, completed rides, badges, and progress.',
          accentColor: _gold,
        ),
      ],
    );
  }

  Widget _buildPriorityToggle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.rocket, color: _gold, size: 22),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Priority Listings',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Boost your profile in discovery feeds',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _priorityListings,
            onChanged: (v) => setState(() => _priorityListings = v),
            activeThumbColor: _gold,
            activeTrackColor: _gold.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    final priceText = _premiumPrice;
    final hasStorePrice = priceText != null && priceText.isNotEmpty;
    final displayPrice = _betaPremiumUnlockEnabled
        ? 'Free during beta'
        : hasStorePrice
        ? priceText
        : _loadingStoreProduct
        ? 'Loading price'
        : 'See store price';
    final detailText = _betaPremiumUnlockEnabled
        ? hasStorePrice
              ? 'Beta access is open. Store price loaded: $priceText/month'
              : _loadingStoreProduct
              ? 'Beta access is open. Loading store price'
              : 'Tap Subscribe to unlock all Premium features for testing'
        : 'Billed monthly via your app store - Cancel anytime';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 2.5.h, horizontal: 4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_orange.withValues(alpha: 0.9), const Color(0xFFB03A31)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayPrice,
                style: GoogleFonts.dmSans(
                  fontSize: hasStorePrice && !_betaPremiumUnlockEnabled
                      ? 28.sp
                      : 20.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              if (!_betaPremiumUnlockEnabled)
                Padding(
                  padding: EdgeInsets.only(top: 1.5.h),
                  child: Text(
                    '/month',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 0.8.h),
          Text(
            detailText,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 11.sp,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          SizedBox(height: 0.5.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              _betaPremiumUnlockEnabled
                  ? 'Beta tester access'
                  : _revenueCatAvailable
                  ? 'Secure checkout via app store'
                  : 'Store connection unavailable',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _handleSubscribe,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 1.8.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          elevation: 0,
        ),
        child: _isProcessing
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AppIcons.lock, size: 16),
                  SizedBox(width: 2.w),
                  Text(
                    _betaPremiumUnlockEnabled
                        ? 'Unlock Premium'
                        : _revenueCatAvailable
                        ? 'Subscribe Securely'
                        : 'Store Unavailable',
                    style: GoogleFonts.dmSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRestoreLink() {
    return Center(
      child: TextButton(
        onPressed: _handleRestorePurchase,
        child: Text(
          'Restore Purchase',
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: Colors.white.withValues(alpha: 0.6),
            decoration: TextDecoration.underline,
            decorationColor: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLinks() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/terms-of-service-screen'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Terms of Service',
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
          Text(
            '-',
            style: GoogleFonts.dmSans(
              fontSize: 10.sp,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/privacy-policy-screen'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Privacy Policy',
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: _gold, size: 20),
              SizedBox(width: 2.w),
              Text(
                'YOUR REFERRAL CODE',
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: _gold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'Share with friends - you both get a 7-day free Premium trial.',
            style: GoogleFonts.dmSans(
              fontSize: 11.sp,
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.4,
            ),
          ),
          SizedBox(height: 1.5.h),
          _loadingReferral
              ? Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: _gold,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : _referralCode == null
              ? Text(
                  'Could not load referral code. Please try again.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4.w,
                              vertical: 1.4.h,
                            ),
                            decoration: BoxDecoration(
                              color: _deepBlue.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: _gold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _referralCode!,
                              style: GoogleFonts.dmSans(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: _referralCode!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Referral code copied!',
                                  style: GoogleFonts.dmSans(fontSize: 12.sp),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: _gold.withValues(alpha: 0.9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                margin: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 2.h,
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: _gold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              Icons.copy_rounded,
                              color: _gold,
                              size: 22,
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        GestureDetector(
                          onTap: () {
                            final shareText =
                                'Join me on RydMatch. Use my referral code $_referralCode to sign up and we both get a 7-day free Premium trial.';
                            SharePlus.instance.share(
                              ShareParams(
                                text: shareText,
                                subject: 'RydMatch Referral Code',
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: _orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: _orange.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              Icons.share_rounded,
                              color: _orange,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.2.h),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _gold.withValues(alpha: 0.7),
                          size: 14,
                        ),
                        SizedBox(width: 1.5.w),
                        Expanded(
                          child: Text(
                            'When a friend signs up with your code, you both receive 7 days of free Premium.',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: Colors.white.withValues(alpha: 0.5),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

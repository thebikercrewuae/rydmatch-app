import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import './widgets/unit_system_widget.dart';
import './widgets/settings_section_widget.dart';
import '../../services/premium_service.dart';
import '../../services/theme_service.dart';
import '../../services/session_service.dart';
import '../../services/haptic_service.dart';
import '../../services/referral_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_logo_widget.dart';
import '../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _unitPrefKey = 'unit_system_metric';

  bool _isMetric = true;
  bool _rideAlerts = true;
  bool _messages = true;
  bool _matchNotifications = true;
  bool _dataSharing = false;
  bool _locationVisible = true;
  bool _profileVisible = true;
  bool _isLoading = true;
  bool _isPremium = false;
  bool _priorityListings = false;
  bool _hapticEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;
  ReferralStats? _referralStats;
  bool _referralLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isMetric = prefs.getBool(_unitPrefKey) ?? true;
        _isPremium = PremiumService().isPremium;
        _priorityListings = PremiumService().priorityListingsEnabled;
        _themeMode = ThemeService().themeMode;
        _hapticEnabled = HapticService.instance.isEnabled;
        _isLoading = false;
      });
    }
    _loadReferralStats();
  }

  Future<void> _loadReferralStats() async {
    if (mounted) setState(() => _referralLoading = true);
    final stats = await ReferralService().getOrCreateReferralCode();
    if (mounted) {
      setState(() {
        _referralStats = stats;
        _referralLoading = false;
      });
    }
  }

  Future<void> _copyReferralCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Referral code copied!',
            style: GoogleFonts.dmSans(fontSize: 13.sp),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2D5A27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        ),
      );
    }
  }

  Future<void> _setUnitSystem(bool isMetric) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unitPrefKey, isMetric);
    await prefs.setBool('isMetric', isMetric);
    await prefs.setString(
      'profile_speed_unit',
      isMetric ? 'metric' : 'imperial',
    );
    if (mounted) {
      setState(() => _isMetric = isMetric);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Switched to ${isMetric ? 'Metric' : 'Imperial'} units',
            style: GoogleFonts.dmSans(fontSize: 13.sp),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        ),
      );
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await ThemeService().setThemeMode(mode);
    if (mounted) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(size: 28),
            SizedBox(width: 2.w),
            Text(
              'Settings',
              style: GoogleFonts.dmSans(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: const Color(0xFFE85A4F)),
            )
          : ListView(
              padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
              children: [
                // ── Premium ────────────────────────────────────────────
                _buildPremiumBanner(theme),
                SizedBox(height: 1.h),

                // ── Referral Program ───────────────────────────────────
                _buildReferralSection(theme),
                SizedBox(height: 1.h),

                // ── Premium Features ───────────────────────────────────
                if (_isPremium) ..._buildPremiumFeatureRows(theme),

                // ── Unit System (featured) ──────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 0.5.h),
                  child: Text(
                    'UNITS',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                UnitSystemWidget(
                  isMetric: _isMetric,
                  onChanged: _setUnitSystem,
                ),
                SizedBox(height: 1.h),

                // ── Appearance ─────────────────────────────────────────
                _buildAppearanceSection(theme),
                SizedBox(height: 1.h),

                // ── Account ────────────────────────────────────────────
                SettingsSectionWidget(
                  title: 'Account',
                  children: [
                    SettingsRowWidget(
                      icon: AppIcons.edit,
                      title: 'Edit Profile',
                      subtitle: 'Update your name, bio and photos',
                      onTap: () =>
                          Navigator.pushNamed(context, '/profile-setup-screen'),
                    ),
                    SettingsRowWidget(
                      icon: AppIcons.lock,
                      title: 'Change Password',
                      subtitle: 'Update your account password',
                      onTap: () => _showChangePasswordSheet(context),
                    ),
                    SettingsRowWidget(
                      icon: AppIcons.logout,
                      title: 'Sign Out',
                      iconColor: theme.colorScheme.error,
                      onTap: () => _showSignOutDialog(context),
                    ),
                    SettingsRowWidget(
                      icon: Icons.pause_circle_outline_rounded,
                      title: 'Deactivate Account',
                      subtitle: 'Temporarily hide your profile',
                      iconColor: const Color(0xFFE8A020),
                      onTap: () => _showDeactivateDialog(context),
                    ),
                    SettingsRowWidget(
                      icon: Icons.delete_forever_rounded,
                      title: 'Delete Account',
                      subtitle: 'Permanently remove your account',
                      iconColor: theme.colorScheme.error,
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                  ],
                ),

                // ── Notifications ──────────────────────────────────────
                SettingsSectionWidget(
                  title: 'Notifications',
                  children: [
                    SettingsRowWidget(
                      icon: AppIcons.route,
                      title: 'Ride Alerts',
                      subtitle: 'Notifications for upcoming rides',
                      trailing: Switch(
                        value: _rideAlerts,
                        onChanged: (v) => setState(() => _rideAlerts = v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SettingsRowWidget(
                      icon: AppIcons.help,
                      title: 'Messages',
                      subtitle: 'New message notifications',
                      trailing: Switch(
                        value: _messages,
                        onChanged: (v) => setState(() => _messages = v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SettingsRowWidget(
                      icon: AppIcons.help,
                      title: 'Match Notifications',
                      subtitle: 'When someone matches with you',
                      trailing: Switch(
                        value: _matchNotifications,
                        onChanged: (v) =>
                            setState(() => _matchNotifications = v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),

                // ── Haptic Feedback ────────────────────────────────────
                SettingsSectionWidget(
                  title: 'Accessibility',
                  children: [
                    SettingsRowWidget(
                      icon: Icons.vibration_rounded,
                      title: 'Haptic Feedback',
                      subtitle: 'Vibrations on swipes, likes & SOS',
                      trailing: Switch(
                        value: _hapticEnabled,
                        onChanged: (v) async {
                          await HapticService.instance.setEnabled(v);
                          if (v) HapticService.instance.light();
                          if (mounted) setState(() => _hapticEnabled = v);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),

                // ── Privacy ────────────────────────────────────────────
                SettingsSectionWidget(
                  title: 'Privacy',
                  children: [
                    SettingsRowWidget(
                      icon: AppIcons.share,
                      title: 'Data Sharing',
                      subtitle: 'Share ride data with partners',
                      trailing: Switch(
                        value: _dataSharing,
                        onChanged: (v) => setState(() => _dataSharing = v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SettingsRowWidget(
                      icon: AppIcons.help,
                      title: 'Location Visibility',
                      subtitle: 'Show your general location to matches',
                      trailing: Switch(
                        value: _locationVisible,
                        onChanged: (v) => setState(() => _locationVisible = v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SettingsRowWidget(
                      icon: AppIcons.visibility,
                      title: 'Profile Visibility',
                      subtitle: 'Allow others to discover your profile',
                      trailing: Switch(
                        value: _profileVisible,
                        onChanged: (v) => setState(() => _profileVisible = v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SettingsRowWidget(
                      icon: Icons.block,
                      title: 'Blocked Users',
                      subtitle: 'Manage users you have blocked',
                      onTap: () =>
                          Navigator.pushNamed(context, '/blocked-users-screen'),
                    ),
                  ],
                ),

                // ── Legal ──────────────────────────────────────────────
                SettingsSectionWidget(
                  title: 'Legal',
                  children: [
                    SettingsRowWidget(
                      icon: Icons.gavel_rounded,
                      title: 'Terms of Service',
                      subtitle: 'Read our terms and conditions',
                      onTap: () => Navigator.pushNamed(context, '/terms'),
                    ),
                    SettingsRowWidget(
                      icon: Icons.shield_rounded,
                      title: 'Privacy Policy',
                      subtitle: 'How we handle your data',
                      onTap: () => Navigator.pushNamed(context, '/privacy'),
                    ),
                    SettingsRowWidget(
                      icon: AppIcons.help,
                      title: 'Contact Support',
                      subtitle: 'Get help from our team',
                      onTap: () => _showContactSupportSheet(context),
                    ),
                    SettingsRowWidget(
                      icon: Icons.delete_forever_rounded,
                      title: 'Delete Account',
                      subtitle: 'Permanently remove your account',
                      iconColor: theme.colorScheme.error,
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                  ],
                ),

                // App version
                Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Center(
                    child: Text(
                      'RydMatch v1.0.0',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildPremiumFeatureRows(ThemeData theme) {
    const gold = Color(0xFFFFB347);
    return [
      SettingsSectionWidget(
        title: 'Premium Features',
        children: [
          SettingsRowWidget(
            icon: AppIcons.group,
            iconColor: const Color(0xFF4FC3F7),
            title: 'Ride Groups',
            subtitle: 'Create & manage group rides',
            onTap: () => Navigator.pushNamed(context, '/ride-groups-screen'),
          ),
          SettingsRowWidget(
            icon: AppIcons.analytics,
            iconColor: gold,
            title: 'Ride Analytics',
            subtitle: 'View your riding statistics',
            onTap: () => Navigator.pushNamed(context, '/ride-analytics-screen'),
          ),
          SettingsRowWidget(
            icon: AppIcons.rocket,
            iconColor: const Color(0xFFE85A4F),
            title: 'Priority Listings',
            subtitle: 'Boost your profile in discovery feeds',
            trailing: Switch(
              value: _priorityListings,
              onChanged: (v) async {
                await PremiumService().setPriorityListings(v);
                if (mounted) setState(() => _priorityListings = v);
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      SizedBox(height: 1.h),
    ];
  }

  Widget _buildPremiumBanner(ThemeData theme) {
    const gold = Color(0xFFFFB347);
    const orange = Color(0xFFE85A4F);
    if (_isPremium) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D1B3E), Color(0xFF1B365D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            children: [
              SizedBox(),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RydMatch Premium',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Active subscription',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: gold.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: gold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            '/premium-subscription-screen',
          );
          if (result == true && mounted) {
            setState(() => _isPremium = PremiumService().isPremium);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [orange.withValues(alpha: 0.9), const Color(0xFFB03A31)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            children: [
              SizedBox(),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Premium',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Ride Groups · Analytics · Priority',
                      style: GoogleFonts.dmSans(
                        fontSize: 10.sp,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final outline = theme.colorScheme.outline;

    final options = [
      _ThemeOption(
        mode: ThemeMode.system,
        label: 'System Default',
        subtitle: 'Match phone setting',
        icon: Icons.phone_android_rounded,
      ),
      _ThemeOption(
        mode: ThemeMode.light,
        label: 'Light',
        subtitle: 'Always light mode',
        icon: Icons.light_mode_rounded,
      ),
      _ThemeOption(
        mode: ThemeMode.dark,
        label: 'Dark',
        subtitle: 'Always dark mode',
        icon: Icons.dark_mode_rounded,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 0.5.h),
            child: Text(
              'APPEARANCE',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: options.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                final isSelected = _themeMode == opt.mode;
                return Column(
                  children: [
                    InkWell(
                      onTap: () => _setThemeMode(opt.mode),
                      borderRadius: BorderRadius.circular(12.0),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 1.5.h,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primary.withValues(alpha: 0.12)
                                    : outline.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Icon(
                                opt.icon,
                                color: isSelected
                                    ? primary
                                    : onSurface.withValues(alpha: 0.5),
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.label,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13.sp,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: onSurface,
                                    ),
                                  ),
                                  Text(
                                    opt.subtitle,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10.sp,
                                      color: onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: primary,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: outline.withValues(alpha: 0.4),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (idx < options.length - 1)
                      Divider(
                        height: 1,
                        indent: 4.w + 36 + 3.w,
                        color: outline.withValues(alpha: 0.1),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralSection(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final outline = theme.colorScheme.outline;
    const green = Color(0xFF2D5A27);
    const lightGreen = Color(0xFFE8F5E9);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 0.5.h),
            child: Text(
              'REFERRAL PROGRAM',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: outline.withValues(alpha: 0.15)),
            ),
            child: _referralLoading
                ? Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: primary,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : _referralStats == null
                ? Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Text(
                      'Upgrade to receive your referral code.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Header banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2D5A27), Color(0xFF4CAF50)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16.0),
                            topRight: Radius.circular(16.0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invite Friends, Earn Rewards',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'You & your friend each get ${_referralStats!.premiumTrialDays} premium trial days',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10.sp,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Referral code display
                      Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Referral Code',
                              style: GoogleFonts.dmSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            GestureDetector(
                              onTap: () =>
                                  _copyReferralCode(_referralStats!.code),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 1.5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: lightGreen,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: green.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _referralStats!.code,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        color: green,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.copy_rounded,
                                          color: green,
                                          size: 18,
                                        ),
                                        SizedBox(width: 1.w),
                                        Text(
                                          'Copy',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                            color: green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            // Stats row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildReferralStatCard(
                                    icon: Icons.people_rounded,
                                    label: 'Friends Referred',
                                    value: _referralStats!.totalReferrals
                                        .toString(),
                                    color: const Color(0xFF1B365D),
                                    theme: theme,
                                  ),
                                ),
                                SizedBox(width: 3.w),
                                Expanded(
                                  child: _buildReferralStatCard(
                                    icon: Icons.star_rounded,
                                    label: 'Trial Days Earned',
                                    value:
                                        '${_referralStats!.trialDaysEarned}d',
                                    color: const Color(0xFFE85A4F),
                                    theme: theme,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 1.5.h),
                            Text(
                              'Share your code with friends. When they sign up, you both earn ${_referralStats!.premiumTrialDays} days of Premium!',
                              style: GoogleFonts.dmSans(
                                fontSize: 10.sp,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 0.5.h),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showContactSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final surface = theme.colorScheme.surface;
        final onSurface = theme.colorScheme.onSurface;
        final outline = theme.colorScheme.outline;
        const orange = Color(0xFFE85A4F);
        const navy = Color(0xFF1B365D);

        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
          ),
          padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Contact Support',
                style: GoogleFonts.dmSans(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                'Our team is here to help you',
                style: GoogleFonts.dmSans(
                  fontSize: 11.sp,
                  color: onSurface.withValues(alpha: 0.55),
                ),
              ),
              SizedBox(height: 2.h),
              _buildSupportOption(
                ctx,
                icon: Icons.email_outlined,
                title: 'Email Support',
                subtitle: 'support@rydmatch.app',
                color: navy,
                onTap: () => Navigator.pop(ctx),
              ),
              SizedBox(height: 1.h),
              _buildSupportOption(
                ctx,
                icon: Icons.bug_report_outlined,
                title: 'Report a Bug',
                subtitle: 'bugs@rydmatch.app',
                color: orange,
                onTap: () => Navigator.pop(ctx),
              ),
              SizedBox(height: 1.h),
              _buildSupportOption(
                ctx,
                icon: Icons.gavel_rounded,
                title: 'Legal Enquiries',
                subtitle: 'legal@rydmatch.app',
                color: const Color(0xFF7B61FF),
                onTap: () => Navigator.pop(ctx),
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: navy, size: 16),
                    SizedBox(width: 2.w),
                    Text(
                      'Response time: typically within 24–48 hours',
                      style: GoogleFonts.dmSans(
                        fontSize: 10.sp,
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(fontSize: 10.sp, color: color),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: onSurface.withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChangePasswordSheet(),
    );
  }

  void _showDeactivateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Deactivate Account',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your profile will be hidden from discovery and matches until you reactivate by signing back in.',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: const Color(0xFFE8A020).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFE8A020),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can reactivate anytime by logging back in.',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF7A5000),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.dmSans()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final userId =
                    SupabaseService.instance.client.auth.currentUser?.id;
                if (userId != null) {
                  await SupabaseService.instance.client
                      .from('profiles')
                      .update({'is_active': false})
                      .eq('id', userId);
                }
                await SessionService.clearSession();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login-screen', (route) => false);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to deactivate account. Please try again.',
                        style: GoogleFonts.dmSans(fontSize: 13),
                      ),
                      backgroundColor: const Color(0xFFE85A4F),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8A020),
            ),
            child: Text(
              'Deactivate',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Delete Account',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action is permanent and cannot be undone. All your data, matches, and messages will be deleted.',
                style: GoogleFonts.dmSans(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                'Type DELETE to confirm',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                onChanged: (_) => setDialogState(() {}),
                style: GoogleFonts.dmSans(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: GoogleFonts.dmSans(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                confirmController.dispose();
                Navigator.of(ctx).pop();
              },
              child: Text('Cancel', style: GoogleFonts.dmSans()),
            ),
            ElevatedButton(
              onPressed: confirmController.text.trim() == 'DELETE'
                  ? () async {
                      Navigator.of(ctx).pop();
                      try {
                        final userId = SupabaseService
                            .instance
                            .client
                            .auth
                            .currentUser
                            ?.id;
                        if (userId != null) {
                          await SupabaseService.instance.client
                              .from('profiles')
                              .delete()
                              .eq('id', userId);
                          await SupabaseService.instance.client.auth.signOut();
                        }
                        await SessionService.clearSession();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login-screen',
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to delete account. Please try again.',
                                style: GoogleFonts.dmSans(fontSize: 13),
                              ),
                              backgroundColor: const Color(0xFFE85A4F),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          );
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                disabledBackgroundColor: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.3),
              ),
              child: Text(
                'Delete Account',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.dmSans()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await SessionService.clearSession();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login-screen', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption {
  final ThemeMode mode;
  final String label;
  final String subtitle;
  final IconData icon;

  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

class _ChangePasswordSheet extends StatefulWidget {
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseService.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password updated successfully',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            backgroundColor: const Color(0xFF2D5A27),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update password. Please try again.',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFE85A4F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Password',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter a new password for your account',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                style: GoogleFonts.dmSans(fontSize: 14, color: onSurface),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: GoogleFonts.dmSans(
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: primary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: onSurface.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: GoogleFonts.dmSans(fontSize: 14, color: onSurface),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: GoogleFonts.dmSans(
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: primary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: onSurface.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (v != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Update Password',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/profile_service.dart';
import '../../services/premium_service.dart';
import '../../services/verification_service.dart';
import '../../services/boost_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/profile_header_widget.dart';
import './widgets/profile_info_card_widget.dart';
import './widgets/skill_badges_widget.dart';
import './widgets/speed_display_widget.dart';
import './widgets/bike_types_display_widget.dart';
import './widgets/preferred_roads_display_widget.dart';
import './widgets/ride_times_display_widget.dart';
import '../report_user_screen/report_user_screen.dart';
import '../block_user_confirmation_screen/block_user_confirmation_screen.dart';
import '../post_ride_rating_screen/widgets/trust_badges_widget.dart';
import './widgets/badge_progress_card_widget.dart';
import './widgets/referral_stats_card_widget.dart';
import './widgets/strava_integration_card_widget.dart';
import '../profile_setup_screen/widgets/skill_level_widget.dart';
import '../profile_setup_screen/widgets/speed_selection_widget.dart';
import '../profile_setup_screen/widgets/bike_type_widget.dart';
import '../profile_setup_screen/widgets/preferred_roads_widget.dart';
import '../profile_setup_screen/widgets/ride_times_widget.dart';
import '../live_ride/ride_history_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  bool _isLoading = true;
  bool _initialized = false;
  double _ridingSpeed = 60.0;
  List<String> _skillLevels = [];
  List<String> _bikeTypes = [];
  List<String> _preferredRoads = [];
  Map<String, List<String>> _rideTimes = {};
  String? _riderPhotoPath;
  List<String> _bikePhotoPaths = [];
  String _riderName = '';
  String _riderBio = '';
  bool _isMetric = true;
  String? _gender;
  bool _sameGenderMatching = false;
  String _rideMode = 'motorcycle';
  bool _mixedCommunityMatching = false;
  double _averageRating = 0.0;
  int _totalRatings = 0;
  List<String> _allSafetyTags = [];
  bool _isVerified = false;
  int _pendingVerificationRequests = 0;

  // Boost state
  bool _isBoostActive = false;
  bool _isBoostLoading = false;
  Duration _boostRemaining = Duration.zero;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _boostTimer;

  bool _profileIsVerified(Map<String, dynamic> profile) {
    return profile['is_verified'] == true ||
        profile['verification_status'] == 'approved';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadProfile();
      _loadBoostState();
      _loadAdminVerificationCount();
    }
  }

  @override
  void dispose() {
    _boostTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoostState() async {
    final boost = await BoostService().getActiveBoost();
    if (!mounted) return;
    if (boost != null) {
      final expiresAt = DateTime.parse(boost['expires_at'] as String).toLocal();
      final remaining = expiresAt.difference(DateTime.now());
      setState(() {
        _isBoostActive = true;
        _boostRemaining = remaining.isNegative ? Duration.zero : remaining;
        _cooldownRemaining = Duration.zero;
      });
      _startBoostCountdown();
    } else {
      final cooldown = await BoostService().getRemainingCooldown();
      if (mounted) {
        setState(() {
          _isBoostActive = false;
          _cooldownRemaining = cooldown;
          _boostRemaining = Duration.zero;
        });
        if (cooldown > Duration.zero) _startCooldownCountdown();
      }
    }
  }

  void _startBoostCountdown() {
    _boostTimer?.cancel();
    _boostTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_boostRemaining.inSeconds > 0) {
          _boostRemaining -= const Duration(seconds: 1);
        } else {
          _isBoostActive = false;
          _boostRemaining = Duration.zero;
          timer.cancel();
          _loadBoostState();
        }
      });
    });
  }

  void _startCooldownCountdown() {
    _boostTimer?.cancel();
    _boostTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownRemaining.inSeconds > 0) {
          _cooldownRemaining -= const Duration(seconds: 1);
        } else {
          _cooldownRemaining = Duration.zero;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleBoost() async {
    if (!PremiumService().isPremium) {
      await Navigator.pushNamed(context, '/premium-subscription-screen');
      return;
    }
    if (_isBoostActive || _cooldownRemaining > Duration.zero) return;

    setState(() => _isBoostLoading = true);
    final result = await BoostService().activateBoost();
    if (!mounted) return;
    if (result != null) {
      final expiresAt = DateTime.parse(
        result['expires_at'] as String,
      ).toLocal();
      final remaining = expiresAt.difference(DateTime.now());
      setState(() {
        _isBoostActive = true;
        _boostRemaining = remaining.isNegative ? Duration.zero : remaining;
        _cooldownRemaining = Duration.zero;
        _isBoostLoading = false;
      });
      _startBoostCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🚀 Profile boosted for 30 minutes!',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFFFFB347),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        ),
      );
    } else {
      setState(() => _isBoostLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to activate boost. Try again.',
            style: GoogleFonts.dmSans(fontSize: 13.sp),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        ),
      );
    }
  }

  Future<void> _loadAdminVerificationCount() async {
    if (!PremiumService().isAdmin) return;

    final count = await VerificationService.instance
        .pendingVerificationRequestCount();
    if (!mounted) return;

    setState(() => _pendingVerificationRequests = count);
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final args = ModalRoute.of(context)?.settings.arguments;
    final isOtherUser = args is Map<String, dynamic>
        ? (args['isOtherUser'] as bool? ?? false)
        : false;
    final otherUserId = args is Map<String, dynamic>
        ? args['userId'] as String?
        : null;
    final otherUserName = args is Map<String, dynamic>
        ? args['userName'] as String?
        : null;
    final otherUserImage = args is Map<String, dynamic>
        ? args['userImage'] as String?
        : null;

    List<String> stringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return <String>[];
    }

    Map<String, List<String>> rideTimesMap(dynamic value) {
      if (value is Map) {
        return value.map(
          (day, times) => MapEntry(
            day.toString(),
            times is List
                ? times.map((time) => time.toString()).toList()
                : <String>[],
          ),
        )..removeWhere((_, times) => times.isEmpty);
      }
      return <String, List<String>>{};
    }

    final localProfile = await ProfileService.loadProfile();
    final preferredIsMetric = localProfile['isMetric'] as bool? ?? true;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (isOtherUser && otherUserId != null && otherUserId.isNotEmpty) {
      try {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select(
              'id, full_name, email, avatar_url, bio, skill_levels, bike_types, '
              'preferred_roads, ride_times, riding_speed, gender, is_verified, '
              'verification_status, ride_mode, mixed_community_matching, '
              'bike_photo_urls',
            )
            .eq('id', otherUserId)
            .maybeSingle();

        if (!mounted) return;

        if (profile == null) {
          setState(() {
            _riderName = otherUserName ?? 'Rider';
            _riderPhotoPath = otherUserImage;
            _riderBio = '';
            _skillLevels = [];
            _bikeTypes = [];
            _preferredRoads = [];
            _rideTimes = {};
            _ridingSpeed = 60.0;
            _isMetric = preferredIsMetric;
            _gender = null;
            _sameGenderMatching = false;
            _rideMode = 'motorcycle';
            _mixedCommunityMatching = false;
            _isVerified = false;
            _isLoading = false;
          });
          return;
        }

        final fullName = profile['full_name'] as String?;
        final email = profile['email'] as String?;
        final avatarUrl = await ProfileService.resolveUserProfilePhotoUrl(
          userId: otherUserId,
          avatarUrl: profile['avatar_url'] as String?,
        );
        final fallbackAvatarUrl = await ProfileService.resolvePhotoUrl(
          otherUserImage,
        );
        final bikePhotoUrls = await ProfileService.resolvePhotoUrls(
          stringList(profile['bike_photo_urls']),
        );
        final canUseLocalFallback = otherUserId == currentUserId;
        final skillLevels = stringList(profile['skill_levels']);
        final bikeTypes = stringList(profile['bike_types']);
        final preferredRoads = stringList(profile['preferred_roads']);
        final rideTimes = rideTimesMap(profile['ride_times']);

        setState(() {
          _riderName = fullName?.trim().isNotEmpty == true
              ? fullName!.trim()
              : otherUserName ??
                    (email?.isNotEmpty == true
                        ? email!.split('@').first
                        : 'Rider');

          _riderBio = profile['bio'] as String? ?? '';
          _riderPhotoPath = avatarUrl?.trim().isNotEmpty == true
              ? avatarUrl
              : fallbackAvatarUrl;

          _skillLevels = skillLevels.isNotEmpty || !canUseLocalFallback
              ? skillLevels
              : List<String>.from(localProfile['skillLevels'] as List);
          _bikeTypes = bikeTypes.isNotEmpty || !canUseLocalFallback
              ? bikeTypes
              : List<String>.from(localProfile['bikeTypes'] as List);
          _preferredRoads = preferredRoads.isNotEmpty || !canUseLocalFallback
              ? preferredRoads
              : List<String>.from(localProfile['preferredRoads'] as List);
          _rideTimes = rideTimes.isNotEmpty || !canUseLocalFallback
              ? rideTimes
              : Map<String, List<String>>.from(
                  localProfile['rideTimes'] as Map<String, List<String>>,
                );

          _ridingSpeed = (profile['riding_speed'] as num?)?.toDouble() ?? 60.0;
          _isMetric = preferredIsMetric;
          _gender = profile['gender'] as String?;
          _sameGenderMatching = false;
          _rideMode = profile['ride_mode'] as String? ?? 'motorcycle';
          _mixedCommunityMatching =
              (profile['mixed_community_matching'] as bool?) ?? false;
          _bikePhotoPaths = bikePhotoUrls.where(_canOpenPhoto).toList();
          _isVerified = _profileIsVerified(profile);
          _isLoading = false;
        });

        if (!_isVerified) {
          await _loadOtherUserVerification(otherUserId);
        }
        await _loadRatings(otherUserId);
        return;
      } catch (e) {
        debugPrint('ProfileViewScreen: failed to load other profile: $e');

        if (!mounted) return;

        setState(() {
          _riderName = otherUserName ?? 'Rider';
          _riderPhotoPath = otherUserImage;
          _riderBio = '';
          _skillLevels = [];
          _bikeTypes = [];
          _preferredRoads = [];
          _rideTimes = {};
          _ridingSpeed = 60.0;
          _isMetric = preferredIsMetric;
          _gender = null;
          _sameGenderMatching = false;
          _rideMode = 'motorcycle';
          _mixedCommunityMatching = false;
          _isVerified = false;
          _isLoading = false;
        });
        return;
      }
    }

    final data = await ProfileService.loadProfile();

    if (mounted) {
      setState(() {
        _ridingSpeed = data['ridingSpeed'] as double;
        _skillLevels = List<String>.from(data['skillLevels'] as List);
        _bikeTypes = List<String>.from(data['bikeTypes'] as List);
        _preferredRoads = List<String>.from(data['preferredRoads'] as List);
        _rideTimes = data['rideTimes'] as Map<String, List<String>>;
        _riderPhotoPath = data['riderPhotoPath'] as String?;
        _bikePhotoPaths = List<String>.from(data['bikePhotoPaths'] as List);
        _riderName = data['riderName'] as String;
        _riderBio = data['riderBio'] as String;
        _isMetric = data['isMetric'] as bool? ?? true;
        _gender = data['gender'] as String?;
        _sameGenderMatching = (data['sameGenderMatching'] as bool?) ?? false;
        _rideMode = data['rideMode'] as String? ?? 'motorcycle';
        _mixedCommunityMatching =
            (data['mixedCommunityMatching'] as bool?) ?? false;
        _isLoading = false;
      });
    }

    final isVerified = currentUserId == null
        ? false
        : await VerificationService.instance.isUserVerified(currentUserId);

    await PremiumService().refresh();

    if (mounted) {
      setState(() {
        _isVerified = isVerified;
      });
    }
  }

  Future<void> _loadRatings(String userId) async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('ride_ratings')
          .select('stars, safety_tags')
          .eq('reviewed_id', userId);
      if (mounted && response.isNotEmpty) {
        final ratings = response as List<dynamic>;
        final total = ratings.length;
        final avgStars =
            ratings.fold<double>(
              0.0,
              (sum, r) => sum + ((r['stars'] as int?) ?? 0),
            ) /
            total;
        final tags = <String>[];
        for (final r in ratings) {
          final t = r['safety_tags'];
          if (t is List) tags.addAll(t.cast<String>());
        }
        setState(() {
          _averageRating = avgStars;
          _totalRatings = total;
          _allSafetyTags = tags;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOtherUserVerification(String userId) async {
    final verified = await VerificationService.instance.isUserVerified(userId);
    if (mounted) setState(() => _isVerified = verified);
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed('/profile-setup-screen', arguments: {'editMode': true});
    _loadProfile();
  }

  Future<void> _savePreference({
    List<String>? skillLevels,
    double? ridingSpeed,
    bool? isMetric,
    List<String>? bikeTypes,
    List<String>? preferredRoads,
    Map<String, List<String>>? rideTimes,
  }) async {
    await ProfileService.saveProfile(
      ridingSpeed: ridingSpeed ?? _ridingSpeed,
      skillLevels: skillLevels ?? _skillLevels,
      bikeTypes: bikeTypes ?? _bikeTypes,
      preferredRoads: preferredRoads ?? _preferredRoads,
      rideTimes: rideTimes ?? _rideTimes,
      riderPhotoPath: _riderPhotoPath,
      bikePhotoPaths: _bikePhotoPaths,
      riderName: _riderName,
      riderBio: _riderBio,
      isMetric: isMetric ?? _isMetric,
      gender: _gender,
      sameGenderMatching: _sameGenderMatching,
      rideMode: _rideMode,
      mixedCommunityMatching: _mixedCommunityMatching,
    );
    await _loadProfile();
  }

  void _editSkillLevel() {
    List<String> tempLevels = List.from(_skillLevels);
    _showEditSheet(
      title: 'Edit Skill Level',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => SkillLevelWidget(
          selectedLevels: tempLevels,
          onLevelsChanged: (updated) {
            setSheetState(() => tempLevels = updated);
          },
        ),
      ),
      onSave: () async {
        await _savePreference(skillLevels: tempLevels);
      },
    );
  }

  void _editRidingSpeed() {
    double tempSpeed = _ridingSpeed;
    bool tempMetric = _isMetric;
    _showEditSheet(
      title: 'Edit Riding Speed',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => SpeedSelectionWidget(
          ridingSpeed: tempSpeed,
          isMetric: tempMetric,
          onSpeedChanged: (val) {
            setSheetState(() => tempSpeed = val);
          },
          onUnitChanged: (val) {
            setSheetState(() => tempMetric = val);
          },
          rideMode: _rideMode,
        ),
      ),
      onSave: () async {
        await _savePreference(ridingSpeed: tempSpeed, isMetric: tempMetric);
      },
    );
  }

  void _editBikeTypes() {
    List<String> tempBikes = List.from(_bikeTypes);
    _showEditSheet(
      title: _rideMode == 'bicycle'
          ? 'Edit Cycle Types'
          : 'Edit Motorcycle Types',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => BikeTypeWidget(
          selectedBikes: tempBikes,
          onBikesChanged: (updated) {
            setSheetState(() => tempBikes = updated);
          },
          rideMode: _rideMode,
        ),
      ),
      onSave: () async {
        await _savePreference(bikeTypes: tempBikes);
      },
    );
  }

  void _editPreferredRoads() {
    List<String> tempRoads = List.from(_preferredRoads);
    _showEditSheet(
      title: 'Edit Preferred Roads',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => PreferredRoadsWidget(
          selectedRoads: tempRoads,
          onRoadsChanged: (updated) {
            setSheetState(() => tempRoads = updated);
          },
        ),
      ),
      onSave: () async {
        await _savePreference(preferredRoads: tempRoads);
      },
    );
  }

  void _editRideTimes() {
    Map<String, List<String>> tempTimes = Map.from(
      _rideTimes.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    _showEditSheet(
      title: 'Edit Ride Times',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => RideTimesWidget(
          rideTimes: tempTimes,
          onTimesChanged: (updated) {
            setSheetState(() => tempTimes = updated);
          },
        ),
      ),
      onSave: () async {
        await _savePreference(rideTimes: tempTimes);
      },
    );
  }

  void _showEditSheet({
    required String title,
    required Widget child,
    required Future<void> Function() onSave,
  }) {
    bool isSaving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            height: 85.h,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.only(top: 1.2.h),
                  width: 10.w,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 1.5.h,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.dmSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 4.5.h,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setSheetState(() => isSaving = true);
                                  await onSave();
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 5.w),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Save',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 2.h,
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    final isOtherUser = args is Map<String, dynamic>
        ? (args['isOtherUser'] as bool? ?? false)
        : false;
    final otherUserId = args is Map<String, dynamic>
        ? args['userId'] as String?
        : null;
    final otherUserName = args is Map<String, dynamic>
        ? args['userName'] as String?
        : null;
    final otherUserImage = args is Map<String, dynamic>
        ? args['userImage'] as String?
        : null;

    if (isOtherUser &&
        otherUserId != null &&
        _totalRatings == 0 &&
        !_isLoading) {
      _loadRatings(otherUserId);
      _loadOtherUserVerification(otherUserId);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
            ),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            AppLogoMark(size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOtherUser
                    ? (_riderName.isNotEmpty
                          ? _riderName
                          : otherUserName ?? 'Profile')
                    : 'My Profile',
                style: GoogleFonts.dmSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isOtherUser) ...[
            IconButton(
              onPressed: () {
                ReportUserScreen.show(
                  context,
                  reportedUserId: otherUserId ?? 'unknown',
                  reportedUserName: otherUserName ?? 'User',
                );
              },
              icon: const Icon(Icons.flag_outlined),
              color: Colors.white,
              tooltip: 'Report',
            ),
            IconButton(
              onPressed: () async {
                final blocked = await BlockUserConfirmationScreen.show(
                  context,
                  blockedUserId: otherUserId ?? 'unknown',
                  blockedUserName: otherUserName ?? 'User',
                  blockedUserImage: otherUserImage,
                );
                if (blocked && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.block),
              color: const Color(0xFFE85A4F),
              tooltip: 'Block',
            ),
          ] else
            IconButton(
              onPressed: _openEditProfile,
              icon: CustomIconWidget(
                iconName: 'edit',
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ProfileHeaderWidget(
                        riderPhotoPath: _riderPhotoPath,
                        riderName: _riderName,
                        riderBio: _riderBio,
                        isVerified: _rideMode != 'bicycle' && _isVerified,
                        onPhotoTap: _canOpenPhoto(_riderPhotoPath)
                            ? () => _showPhotoExpanded(
                                context,
                                _riderPhotoPath!,
                                gallery: _profileGalleryPhotos,
                              )
                            : null,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    ProfileInfoCardWidget(
                      title: 'Skill Level',
                      icon: AppIcons.help,
                      onEdit: isOtherUser ? null : _editSkillLevel,
                      child: SkillBadgesWidget(skillLevels: _skillLevels),
                    ),
                    if (!isOtherUser && _gender != null)
                      ProfileInfoCardWidget(
                        title: 'Gender',
                        icon: Icons.person_outline,
                        child: _buildGenderDisplay(theme),
                      ),
                    ProfileInfoCardWidget(
                      title: 'Riding Speed',
                      icon: AppIcons.speed,
                      onEdit: isOtherUser ? null : _editRidingSpeed,
                      child: SpeedDisplayWidget(
                        ridingSpeed: _ridingSpeed,
                        isMetric: _isMetric,
                      ),
                    ),
                    ProfileInfoCardWidget(
                      title: _rideMode == 'bicycle'
                          ? 'Cycle Types'
                          : 'Motorcycle Types',
                      icon: _rideMode == 'bicycle'
                          ? Icons.directions_bike_rounded
                          : AppIcons.motorcycle,
                      onEdit: isOtherUser ? null : _editBikeTypes,
                      child: BikeTypesDisplayWidget(bikeTypes: _bikeTypes),
                    ),
                    if (!isOtherUser && _rideMode == 'bicycle')
                      ProfileInfoCardWidget(
                        title: 'Cycling Integrations',
                        icon: Icons.link_rounded,
                        child: StravaIntegrationCardWidget(
                          isPremium: PremiumService().isPremium,
                        ),
                      ),
                    ProfileInfoCardWidget(
                      title: 'Preferred Roads',
                      icon: AppIcons.map,
                      onEdit: isOtherUser ? null : _editPreferredRoads,
                      child: PreferredRoadsDisplayWidget(
                        preferredRoads: _preferredRoads,
                      ),
                    ),
                    ProfileInfoCardWidget(
                      title: 'Ride Times',
                      icon: AppIcons.schedule,
                      onEdit: isOtherUser ? null : _editRideTimes,
                      child: RideTimesDisplayWidget(rideTimes: _rideTimes),
                    ),
                    if (!isOtherUser) ...[
                      ProfileInfoCardWidget(
                        title: 'Achievements',
                        icon: Icons.military_tech_rounded,
                        child: const BadgeProgressCardWidget(),
                      ),
                    ],
                    if (isOtherUser && _totalRatings > 0)
                      ProfileInfoCardWidget(
                        title: 'Rider Reputation',
                        icon: Icons.star_rounded,
                        child: TrustBadgesWidget(
                          averageRating: _averageRating,
                          totalRatings: _totalRatings,
                          safetyTags: _allSafetyTags,
                        ),
                      ),
                    if (_bikePhotoPaths.isNotEmpty)
                      ProfileInfoCardWidget(
                        title: _rideMode == 'bicycle'
                            ? 'Cycle Photos'
                            : 'Motorcycle Photos',
                        icon: Icons.photo_library,
                        child: _buildBikePhotos(theme),
                      ),
                    if (!isOtherUser) ...[
                      SizedBox(height: 1.h),
                      ProfileInfoCardWidget(
                        title: 'Referral Stats',
                        icon: Icons.people_alt_rounded,
                        child: const ReferralStatsCardWidget(),
                      ),
                    ],
                    SizedBox(height: 2.h),
                    if (!isOtherUser) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton.icon(
                          onPressed: _openEditProfile,
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: Text(
                            'Edit Profile',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      _buildBoostButton(theme),
                      SizedBox(height: 1.5.h),
                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/emergency-sos-screen',
                          ),
                          icon: const Icon(
                            Icons.sos_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Emergency SOS',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB71C1C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/route-planner-screen',
                          ),
                          icon: const Icon(
                            Icons.map_outlined,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Plan a Ride',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B365D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RideHistoryScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.history_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Ride History',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/leaderboard-screen',
                          ),
                          icon: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            PremiumService().isPremium
                                ? 'Leaderboard'
                                : 'Leaderboard (Premium)',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB347),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      if (PremiumService().isAdmin) ...[
                        SizedBox(height: 1.5.h),
                        _buildAdminVerificationButton(),
                        SizedBox(height: 1.5.h),
                        _buildAdminDiagnosticsButton(),
                        SizedBox(height: 1.5.h),
                        _buildAdminGrowthDashboardButton(),
                      ],
                      if (_rideMode != 'bicycle') ...[
                        SizedBox(height: 1.5.h),
                        SizedBox(
                          width: double.infinity,
                          height: 6.h,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.pushNamed(
                                context,
                                '/verification-screen',
                              );
                              _loadProfile();
                            },
                            icon: Icon(
                              _isVerified
                                  ? Icons.verified_rounded
                                  : Icons.verified_outlined,
                              color: Colors.white,
                            ),
                            label: Text(
                              _isVerified ? 'Verified Rider ✓' : 'Get Verified',
                              style: GoogleFonts.dmSans(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isVerified
                                  ? const Color(0xFF1565C0)
                                  : const Color(0xFF1976D2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ReportUserScreen.show(
                              context,
                              reportedUserId: otherUserId ?? 'unknown',
                              reportedUserName: otherUserName ?? 'User',
                            );
                          },
                          icon: const Icon(
                            Icons.flag_outlined,
                            color: Color(0xFFB7791F),
                          ),
                          label: Text(
                            'Report User',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB7791F),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFB7791F),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final blocked =
                                await BlockUserConfirmationScreen.show(
                                  context,
                                  blockedUserId: otherUserId ?? 'unknown',
                                  blockedUserName: otherUserName ?? 'User',
                                  blockedUserImage: otherUserImage,
                                );
                            if (blocked && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.block, color: Colors.white),
                          label: Text(
                            'Block User',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE85A4F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 3.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAdminVerificationButton() {
    final count = _pendingVerificationRequests;

    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(
                  context,
                  '/admin-verification-screen',
                );
                await _loadAdminVerificationCount();
              },
              icon: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
              ),
              label: Text(
                count > 0
                    ? 'Admin Verification Review ($count)'
                    : 'Admin Verification Review',
                style: GoogleFonts.dmSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              top: -7,
              right: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE85A4F),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminDiagnosticsButton() {
    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/admin-diagnostics-screen');
        },
        icon: const Icon(Icons.bug_report_rounded, color: Colors.white),
        label: Text(
          'Admin Diagnostics',
          style: GoogleFonts.dmSans(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF263238),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminGrowthDashboardButton() {
    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/admin-growth-dashboard-screen');
        },
        icon: const Icon(Icons.trending_up_rounded, color: Colors.white),
        label: Text(
          'Growth & Revenue Dashboard',
          style: GoogleFonts.dmSans(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }

  Widget _buildBoostButton(ThemeData theme) {
    const Color boostActiveColor = Color(0xFFFF6B35);
    const Color boostReadyColor = Color(0xFF7B2FBE);

    if (_isBoostLoading) {
      return SizedBox(
        width: double.infinity,
        height: 6.h,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: boostReadyColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          child: const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_isBoostActive) {
      return Container(
        width: double.infinity,
        height: 6.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: boostActiveColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Text(
              '🚀 Boost Active — ',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              BoostService().formatDuration(_boostRemaining),
              style: GoogleFonts.dmSans(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    if (_cooldownRemaining > Duration.zero) {
      return Container(
        width: double.infinity,
        height: 6.h,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            SizedBox(width: 2.w),
            Text(
              'Next boost in ',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              BoostService().formatDuration(_cooldownRemaining),
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    if (!PremiumService().isPremium) {
      return SizedBox(
        width: double.infinity,
        height: 6.h,
        child: ElevatedButton.icon(
          onPressed: _handleBoost,
          icon: const Icon(
            Icons.rocket_launch_rounded,
            color: Colors.white,
            size: 18,
          ),
          label: Text(
            'Boost Profile (Go Premium)',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: boostReadyColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: ElevatedButton.icon(
        onPressed: _handleBoost,
        icon: const Icon(
          Icons.rocket_launch_rounded,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          'Boost Profile — 30 min',
          style: GoogleFonts.dmSans(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: boostReadyColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildBikePhotos(ThemeData theme) {
    final gallery = _profileGalleryPhotos;

    return SizedBox(
      height: 18.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _bikePhotoPaths.length,
        separatorBuilder: (_, __) => SizedBox(width: 2.w),
        itemBuilder: (context, index) {
          final path = _bikePhotoPaths[index];
          return GestureDetector(
            onTap: () => _showPhotoExpanded(
              context,
              path,
              gallery: gallery,
              initialIndex: gallery.indexOf(path),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: _buildBikePhotoImage(path, theme),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBikePhotoImage(String path, ThemeData theme) {
    final isNetworkUrl =
        path.startsWith('http://') || path.startsWith('https://');

    if (isNetworkUrl) {
      return Image.network(
        path,
        width: 30.w,
        height: 18.h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoPlaceholder(theme),
      );
    }

    if (!kIsWeb) {
      return Image.file(
        File(path),
        width: 30.w,
        height: 18.h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoPlaceholder(theme),
      );
    }

    return _photoPlaceholder(theme);
  }

  bool _canOpenPhoto(String? path) {
    if (path == null) return false;

    final value = path.trim();
    if (value.isEmpty || value.startsWith('blob:')) return false;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return true;
    }

    return !kIsWeb;
  }

  List<String> get _profileGalleryPhotos {
    final photos = <String>[];

    if (_canOpenPhoto(_riderPhotoPath)) {
      photos.add(_riderPhotoPath!.trim());
    }

    for (final path in _bikePhotoPaths) {
      final value = path.trim();
      if (_canOpenPhoto(value) && !photos.contains(value)) {
        photos.add(value);
      }
    }

    return photos;
  }

  Widget _buildGenderDisplay(ThemeData theme) {
    final genderLabels = {
      'male': 'Male',
      'female': 'Female',
      'prefer_not_to_say': 'Prefer not to say',
    };
    final genderIcons = {
      'male': Icons.man,
      'female': Icons.woman,
      'prefer_not_to_say': Icons.shield_outlined,
    };
    final label = genderLabels[_gender] ?? _gender ?? '';
    final icon = genderIcons[_gender] ?? Icons.person_outline;
    final showSameGenderPreference =
        _gender != null && _gender != 'prefer_not_to_say';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 0.2.h),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showSameGenderPreference) ...[
                SizedBox(height: 0.5.h),
                Text(
                  _sameGenderMatching
                      ? 'Only show same-gender matches'
                      : 'Open to all genders',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder(ThemeData theme) {
    return Container(
      width: 30.w,
      height: 18.h,
      color: theme.colorScheme.outline.withValues(alpha: 0.2),
      child: Center(
        child: Icon(
          Icons.motorcycle,
          color: theme.colorScheme.onSurfaceVariant,
          size: 32,
        ),
      ),
    );
  }

  void _showPhotoExpanded(
    BuildContext context,
    String path, {
    List<String>? gallery,
    int initialIndex = 0,
  }) {
    final photos = (gallery == null || gallery.isEmpty) ? [path] : gallery;
    final safeInitialIndex = initialIndex >= 0 && initialIndex < photos.length
        ? initialIndex
        : 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: PageView.builder(
              controller: PageController(initialPage: safeInitialIndex),
              itemCount: photos.length,
              itemBuilder: (_, index) {
                final photo = photos[index];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(child: _buildExpandedPhoto(photo)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedPhoto(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        semanticLabel: 'Expanded profile photo',
      );
    }

    if (!kIsWeb) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        semanticLabel: 'Expanded profile photo',
      );
    }

    return const SizedBox.shrink();
  }
}

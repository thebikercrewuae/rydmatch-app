import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/match_success_screen/match_success_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/diagnostics_service.dart';
import '../../services/haptic_service.dart';
import '../../services/premium_service.dart';
import '../../services/profile_service.dart';
import '../../services/swipe_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/skeleton_loader_widget.dart';
import '../../widgets/toast_widget.dart';
import './widgets/action_buttons_widget.dart';
import './widgets/empty_state_widget.dart';
import './widgets/filter_panel_widget.dart';
import './widgets/match_category_modal_widget.dart';
import './widgets/match_interaction_overlay.dart';
import './widgets/rider_card_widget.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _showFilterPanel = false;
  final CardSwiperController _swiperController = CardSwiperController();

  FilterState _activeFilters = const FilterState();

  final List<Map<String, dynamic>> _allRiders = [];
  List<Map<String, dynamic>> _filteredRiders = [];

  int _currentCardIndex = 0;
  bool _isEmpty = true;
  bool _isLoading = true;
  bool _isMetric = true;

  double? _myLat;
  double? _myLng;

  Map<String, dynamic>? _lastSwipedRider;
  bool get _canUndo => _lastSwipedRider != null;

  final Set<String> _swipedIds = {};

  String _myName = 'You';
  String? _myPhoto;
  String? _myGender;
  bool _sameGenderMatching = false;
  String _myRideMode = 'motorcycle';
  bool _mixedCommunityMatching = false;

  bool _showMatchOverlay = false;
  String? _overlayLeftPhoto;
  String? _overlayRightPhoto;

  @override
  void initState() {
    super.initState();
    _initLocationAndLoad();
  }

  Future<void> _initLocationAndLoad() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      await Future.delayed(const Duration(seconds: 1));
      final retryUser = supabase.auth.currentUser;
      if (retryUser == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isEmpty = true;
          });
        }
        return;
      }
    }

    await Future.wait([
      _loadUnitPreference(),
      _loadSwipedIds(),
      _loadMyProfile(),
    ]);

    _loadRiders();

    _fetchAndStoreLocation().then((_) {
      if (mounted && _allRiders.isNotEmpty) {
        setState(() {
          for (int i = 0; i < _allRiders.length; i++) {
            final p = _allRiders[i];
            final otherLat = p['_rawLat'] as double?;
            final otherLng = p['_rawLng'] as double?;

            if (_myLat != null &&
                _myLng != null &&
                otherLat != null &&
                otherLng != null) {
              final d = _distanceMiles(_myLat!, _myLng!, otherLat, otherLng);
              _allRiders[i] = {
                ..._allRiders[i],
                'distance': _formatDistance(d),
                'distanceMiles': d,
              };
            }
          }

          _filteredRiders = _applyFiltersToList(_allRiders, _activeFilters);
          _isEmpty = _filteredRiders.isEmpty;
        });
      }
    });
  }

  Future<bool> _loadUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();

    final settingsMetric = prefs.getBool('unit_system_metric');
    final profileUnit = prefs.getString('profile_speed_unit');
    final legacyMetric = prefs.getBool('isMetric');

    final nextIsMetric =
        settingsMetric ?? legacyMetric ?? (profileUnit != 'imperial');
    final changed = _isMetric != nextIsMetric;
    _isMetric = nextIsMetric;

    return changed;
  }

  String _formatDistance(double miles) {
    if (_isMetric) {
      final km = miles * 1.609344;
      return km < 1 ? '< 1 km' : '${km.round()} km';
    }

    return miles < 1 ? '< 1 mi' : '${miles.round()} mi';
  }

  Future<void> _loadSwipedIds() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final data = await supabase
          .from('swipes')
          .select('swiped_id')
          .eq('swiper_id', currentUser.id)
          .eq('direction', 'right');

      final ids = List<Map<String, dynamic>>.from(
        data,
      ).map((row) => row['swiped_id'] as String).toList();

      _swipedIds.addAll(ids);
    } catch (e) {
      debugPrint('DiscoveryScreen: _loadSwipedIds error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'discovery',
        action: 'load_swiped_ids',
        error: e,
        severity: 'warning',
      );
    }
  }

  Future<void> _loadMyProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final data = await supabase
          .from('user_profiles')
          .select(
            'full_name, email, avatar_url, gender, same_gender_matching, ride_mode, mixed_community_matching',
          )
          .eq('id', currentUser.id)
          .single();

      final name = (data['full_name'] as String?)?.isNotEmpty == true
          ? data['full_name'] as String
          : (data['email'] as String?)?.split('@').first ?? 'You';

      final photo = await ProfileService.resolveUserProfilePhotoUrl(
        userId: currentUser.id,
        avatarUrl: data['avatar_url'] as String?,
      );

      if (mounted) {
        setState(() {
          _myName = name;
          _myPhoto = (photo != null && photo.isNotEmpty) ? photo : null;
          _myGender = data['gender'] as String?;
          _sameGenderMatching =
              (data['same_gender_matching'] as bool?) ?? false;
          _myRideMode = data['ride_mode'] as String? ?? 'motorcycle';
          _mixedCommunityMatching =
              (data['mixed_community_matching'] as bool?) ?? false;
        });
      }
    } catch (e) {
      await DiagnosticsService.instance.logError(
        feature: 'discovery',
        action: 'load_my_profile',
        error: e,
        severity: 'warning',
      );
    }
  }

  Future<void> _fetchAndStoreLocation() async {
    var locationAttempts = 0;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position position;
      try {
        locationAttempts = 1;
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } on TimeoutException {
        locationAttempts = 2;
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      }

      _myLat = position.latitude;
      _myLng = position.longitude;

      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        await supabase.from('user_profiles').upsert({
          'id': currentUser.id,
          'latitude': _myLat,
          'longitude': _myLng,
          'location_updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
      }
    } catch (e) {
      final isLocationTimeout = e is TimeoutException;
      await DiagnosticsService.instance.logError(
        feature: 'discovery',
        action: 'fetch_and_store_location',
        error: e,
        severity: isLocationTimeout ? 'info' : 'warning',
        context: {
          'location_attempts': locationAttempts,
          if (isLocationTimeout) 'transient_location_timeout': true,
        },
      );
    }
  }

  double _distanceMiles(double lat1, double lng1, double lat2, double lng2) {
    final meters = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return meters / 1609.344;
  }

  bool _profileIsVerified(Map<String, dynamic> profile) {
    return profile['is_verified'] == true ||
        profile['verification_status'] == 'approved';
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

  bool _isBlank(dynamic value) {
    return value is! String || value.trim().isEmpty;
  }

  Future<void> _hydrateDiscoveryProfileFields(
    List<Map<String, dynamic>> profiles,
  ) async {
    final ids = profiles
        .map((profile) => profile['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return;

    try {
      final rows = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'id, full_name, avatar_url, bio, is_verified, verification_status',
          )
          .inFilter('id', ids);
      final byId = {
        for (final row in List<Map<String, dynamic>>.from(rows))
          row['id']?.toString(): row,
      };

      for (final profile in profiles) {
        final row = byId[profile['id']?.toString()];
        if (row == null) continue;

        final avatarUrl = await ProfileService.resolveUserProfilePhotoUrl(
          userId: profile['id']?.toString() ?? '',
          avatarUrl: row['avatar_url'] as String?,
        );
        if (avatarUrl != null) {
          profile['avatar_url'] = avatarUrl;
        }

        if (_isBlank(profile['full_name']) && !_isBlank(row['full_name'])) {
          profile['full_name'] = (row['full_name'] as String).trim();
        }

        if (_isBlank(profile['bio']) && !_isBlank(row['bio'])) {
          profile['bio'] = (row['bio'] as String).trim();
        }

        profile['is_verified'] = row['is_verified'];
        profile['verification_status'] = row['verification_status'];
      }
    } catch (e) {
      await DiagnosticsService.instance.logError(
        feature: 'discovery',
        action: 'hydrate_profile_fields',
        error: e,
        severity: 'warning',
        context: {'profile_count': profiles.length},
      );
    }
  }

  Future<void> _loadRiders() async {
    await _loadUnitPreference();

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEmpty = true;
      });
      return;
    }

    List<Map<String, dynamic>> allProfiles = [];
    var usedDiscoveryRpc = false;

    try {
      final rawAll = await supabase.rpc(
        'get_discovery_profiles',
        params: {
          'p_current_user_id': currentUser.id,
          'p_excluded_ids': _swipedIds.toList(),
        },
      );

      allProfiles = List<Map<String, dynamic>>.from(rawAll as List<dynamic>);
      usedDiscoveryRpc = true;
    } catch (e) {
      debugPrint('DiscoveryScreen: RPC discovery failed, using fallback: $e');
      await DiagnosticsService.instance.logError(
        feature: 'discovery',
        action: 'load_profiles_rpc',
        error: e,
        severity: 'warning',
        context: {'excluded_count': _swipedIds.length},
      );

      try {
        final rawAll = await supabase
            .from('user_profiles')
            .select(
              'id, full_name, email, skill_levels, bike_types, preferred_roads, riding_speed, gender, same_gender_matching, avatar_url, bio, latitude, longitude, ride_mode, mixed_community_matching',
            )
            .limit(150);

        allProfiles = List<Map<String, dynamic>>.from(rawAll);
      } catch (fallbackError) {
        debugPrint(
          'DiscoveryScreen: failed to fetch fallback profiles: $fallbackError',
        );
        await DiagnosticsService.instance.logError(
          feature: 'discovery',
          action: 'load_profiles_fallback',
          error: fallbackError,
          context: {'excluded_count': _swipedIds.length},
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isEmpty = true;
          });
        }
        return;
      }
    }

    await _hydrateDiscoveryProfileFields(allProfiles);

    final afterExcludeSelf = allProfiles
        .where((p) => p['id'] != currentUser.id)
        .toList();

    final afterExcludeSwiped = _swipedIds.isEmpty
        ? List<Map<String, dynamic>>.from(afterExcludeSelf)
        : afterExcludeSelf.where((p) => !_swipedIds.contains(p['id'])).toList();

    List<String> blockedIds = [];

    if (!usedDiscoveryRpc) {
      try {
        final blockedData = await supabase
            .from('user_blocks')
            .select('blocked_id')
            .eq('blocker_id', currentUser.id);

        blockedIds = List<Map<String, dynamic>>.from(
          blockedData,
        ).map((b) => b['blocked_id'] as String).toList();
      } catch (_) {}
    }

    final afterExcludeBlocked = blockedIds.isEmpty
        ? List<Map<String, dynamic>>.from(afterExcludeSwiped)
        : afterExcludeSwiped
              .where((p) => !blockedIds.contains(p['id']))
              .toList();

    final afterCommunityFilter = afterExcludeBlocked
        .where(_canShowForRideCommunity)
        .where(_canShowForGenderPreference)
        .toList();

    final riders = afterCommunityFilter.map((p) {
      final name = (p['full_name'] as String?)?.isNotEmpty == true
          ? p['full_name'] as String
          : (p['email'] as String?)?.split('@').first ?? 'Rider';

      final bikeTypes = List<String>.from(p['bike_types'] as List? ?? []);
      final skillLevels = List<String>.from(p['skill_levels'] as List? ?? []);
      final preferredRoads = List<String>.from(
        p['preferred_roads'] as List? ?? [],
      );

      final avatarUrl = _usableAvatarUrl(p['avatar_url']);
      final bikeType = bikeTypes.isNotEmpty ? bikeTypes.first : 'All';
      final skillLevel = skillLevels.isNotEmpty
          ? skillLevels.first
          : 'Intermediate';

      final imageUrl =
          avatarUrl ??
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400';

      final otherLat = (p['latitude'] as num?)?.toDouble();
      final otherLng = (p['longitude'] as num?)?.toDouble();
      final rideMode = p['ride_mode'] as String? ?? 'motorcycle';
      final rideModeLabel = _rideModeLabel(rideMode);

      String distanceLabel = _isMetric ? '— km' : '— mi';
      double? distanceMilesValue;

      if (_myLat != null &&
          _myLng != null &&
          otherLat != null &&
          otherLng != null) {
        final d = _distanceMiles(_myLat!, _myLng!, otherLat, otherLng);
        distanceMilesValue = d;
        distanceLabel = _formatDistance(d);
      }

      return <String, dynamic>{
        'id': p['id'],
        'name': name,
        'photo': imageUrl,
        'image': imageUrl,
        'photos': <String>[imageUrl],
        'semanticLabel':
            '$name ${rideModeLabel.toLowerCase()} rider profile photo',
        'rideMode': rideMode,
        'rideModeLabel': rideModeLabel,
        'age': p['age'] as int? ?? '',
        'isVerified': _profileIsVerified(p),
        'bikeModel': bikeType,
        'bikeName': bikeType,
        'bikeType': bikeType,
        'bikeBrand': 'All',
        'ridingStyle': 'All',
        'rideStyle': 'All',
        'skillLevel': skillLevel,
        'engineSize': 600.0,
        'isOnline': false,
        'distance': distanceLabel,
        'distanceMiles': distanceMilesValue,
        'compatibility': _calcCompatibility(p),
        'bio': p['bio'] as String? ?? '',
        'bikeTypes': bikeTypes,
        'skillLevels': skillLevels,
        'preferredRoads': preferredRoads,
        'preferredRoutes': preferredRoads.join(', '),
        'availability': 'Weekends',
        'tags': <String>[
          rideModeLabel,
          bikeType,
          skillLevel,
          ...preferredRoads,
        ],
        '_rawLat': otherLat,
        '_rawLng': otherLng,
      };
    }).toList();

    final filtered = _applyFiltersToList(riders, _activeFilters);

    if (mounted) {
      setState(() {
        _allRiders
          ..clear()
          ..addAll(riders);
        _filteredRiders = filtered;
        _isEmpty = _filteredRiders.isEmpty;
        _isLoading = false;
      });
    }
  }

  int _calcCompatibility(Map<String, dynamic> otherProfile) {
    return 70 + (otherProfile['id'].hashCode.abs() % 25);
  }

  bool _canShowForRideCommunity(Map<String, dynamic> profile) {
    final otherRideMode = profile['ride_mode'] as String? ?? 'motorcycle';
    if (otherRideMode == _myRideMode) return true;

    final otherMixed = (profile['mixed_community_matching'] as bool?) ?? false;
    return _mixedCommunityMatching && otherMixed;
  }

  bool _canShowForGenderPreference(Map<String, dynamic> profile) {
    final myGender = _myGender?.trim();
    final otherGender = (profile['gender'] as String?)?.trim();
    final otherSameGenderOnly =
        (profile['same_gender_matching'] as bool?) ?? false;

    if (_sameGenderMatching) {
      if (myGender == null ||
          myGender.isEmpty ||
          myGender == 'prefer_not_to_say') {
        return false;
      }

      return otherGender == myGender;
    }

    if (otherSameGenderOnly) {
      if (myGender == null ||
          myGender.isEmpty ||
          myGender == 'prefer_not_to_say') {
        return false;
      }

      return otherGender == myGender;
    }

    return true;
  }

  String _rideModeLabel(String rideMode) {
    return rideMode == 'bicycle' ? 'Bicycle' : 'Motorcycle';
  }

  List<Map<String, dynamic>> _applyFiltersToList(
    List<Map<String, dynamic>> riders,
    FilterState filters,
  ) {
    return riders.where((rider) {
      final distanceMiles = rider['distanceMiles'] as double?;

      final distanceLimitMiles = _isMetric
          ? filters.distance / 1.609344
          : filters.distance;

      if (filters.distance < 500 &&
          _myLat != null &&
          _myLng != null &&
          distanceMiles != null) {
        if (distanceMiles > distanceLimitMiles) return false;
      }

      if (filters.skillLevel != 'All') {
        final skill = rider['skillLevel'] as String? ?? '';
        if (skill != filters.skillLevel) return false;
      }

      if (filters.rideCommunity != 'All') {
        final rideMode = rider['rideMode'] as String? ?? 'motorcycle';
        if (rideMode != filters.rideCommunity) return false;
      }

      if (filters.bikeType != 'All') {
        final bikeTypes = List<String>.from(rider['bikeTypes'] as List? ?? []);
        if (bikeTypes.isNotEmpty && !bikeTypes.contains(filters.bikeType)) {
          return false;
        }
      }

      if (!(filters.ridingStyles.length == 1 &&
          filters.ridingStyles.first == 'All')) {
        final style = rider['ridingStyle'] as String? ?? '';
        if (!filters.ridingStyles.contains(style)) return false;
      }

      return true;
    }).toList();
  }

  void _applyFilters(FilterState filters) {
    setState(() {
      _activeFilters = filters;
      _filteredRiders = _applyFiltersToList(_allRiders, filters);
      _currentCardIndex = 0;
      _isEmpty = _filteredRiders.isEmpty;
    });
  }

  void _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    if (!kIsWeb) HapticService.instance.selection();

    if (previousIndex < 0 || previousIndex >= _filteredRiders.length) return;

    final rider = _filteredRiders[previousIndex];
    final swipedId = rider['id'] as String? ?? '';
    final swipedName = rider['name'] as String?;
    final dirStr = direction == CardSwiperDirection.right
        ? 'right'
        : direction == CardSwiperDirection.top
        ? 'top'
        : 'left';

    AnalyticsService.instance.logSwipe(
      direction: dirStr,
      swipedUserId: swipedId,
      swipedUserName: swipedName,
    );

    _lastSwipedRider = rider;
    if (swipedId.isNotEmpty && direction != CardSwiperDirection.left) {
      _swipedIds.add(swipedId);
    }

    if (swipedId.isNotEmpty) {
      final dbDirection =
          direction == CardSwiperDirection.right ||
              direction == CardSwiperDirection.top
          ? 'right'
          : 'left';

      _saveSwipe(
        swipedId: swipedId,
        swipedName: swipedName ?? 'Rider',
        swipedPhoto: rider['photo'] as String?,
        direction: dbDirection,
      );
    }

    if (direction == CardSwiperDirection.left) {
      _moveRiderToEnd(swipedId);
    } else {
      _allRiders.removeWhere((r) => r['id'] == swipedId);
      _filteredRiders.removeWhere((r) => r['id'] == swipedId);
    }

    if (currentIndex == null) {
      setState(() => _isEmpty = true);
    }

    if (direction == CardSwiperDirection.top) {
      AppToast.show(
        context,
        message: 'Super liked! They\'ll know you\'re keen',
        type: ToastType.success,
      );
    } else if (direction == CardSwiperDirection.left) {
      AppToast.show(
        context,
        message: 'Passed. Next rider coming up',
        type: ToastType.info,
      );
    }
  }

  Future<void> _saveSwipe({
    required String swipedId,
    required String swipedName,
    String? swipedPhoto,
    required String direction,
  }) async {
    try {
      if (direction == 'right') {
        _swipedIds.add(swipedId);
      }

      final result = await SwipeService.instance.recordSwipe(
        swipedId: swipedId,
        direction: direction,
      );

      if (result.isMatch && mounted) {
        await AnalyticsService.instance.logMatchCreated(
          matchedUserId: swipedId,
        );
        if (!mounted) return;

        await MatchSuccessScreen.show(
          context,
          currentUserName: _myName,
          currentUserPhoto: _myPhoto,
          matchedUserName: swipedName,
          matchedUserPhoto: swipedPhoto,
          matchedUserId: swipedId,
          onStartChat: () {
            Navigator.of(context).pop();
            Navigator.of(context, rootNavigator: true).pushNamed(
              '/chat-screen',
              arguments: {
                'name': swipedName,
                'image': swipedPhoto,
                'userId': swipedId,
                'bike': 'Ride partner',
                'isOnline': false,
              },
            );
          },
          onKeepSwiping: () {
            Navigator.of(context).pop();
          },
        );
      }
    } catch (e, stack) {
      debugPrint('DiscoveryScreen: save swipe error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'matching',
        action: 'save_swipe_from_discovery',
        error: e,
        stackTrace: stack,
        context: {'swiped_id': swipedId, 'direction': direction},
      );
    }
  }

  void _moveRiderToEnd(String riderId) {
    if (riderId.isEmpty) return;

    void moveInList(List<Map<String, dynamic>> riders) {
      final index = riders.indexWhere((rider) => rider['id'] == riderId);
      if (index < 0 || index >= riders.length - 1) return;

      final rider = riders.removeAt(index);
      riders.add(rider);
    }

    setState(() {
      moveInList(_allRiders);
      moveInList(_filteredRiders);
    });
  }

  void _handlePass() {
    Navigator.of(context).maybePop();
    _swiperController.swipe(CardSwiperDirection.left);
  }

  void _handleMatch() {
    Navigator.of(context).maybePop();

    if (_filteredRiders.isNotEmpty) {
      final currentRider =
          _filteredRiders[_currentCardIndex < _filteredRiders.length
              ? _currentCardIndex
              : 0];

      setState(() {
        _showMatchOverlay = true;
        _overlayLeftPhoto = _myPhoto;
        _overlayRightPhoto = currentRider['photo'] as String?;
      });
    } else {
      _showMatchCategoryModal();
    }
  }

  void _onMatchOverlayComplete() {
    setState(() => _showMatchOverlay = false);
    _showMatchCategoryModal();
  }

  void _showMatchCategoryModal() {
    if (_filteredRiders.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MatchCategoryModalWidget(
        riderName:
            _filteredRiders[_currentCardIndex < _filteredRiders.length
                    ? _currentCardIndex
                    : 0]["name"]
                as String,
        onCategorySelected: (category) {
          Navigator.pop(ctx);
          _swiperController.swipe(CardSwiperDirection.right);
          _showMatchToast(category);
        },
      ),
    );
  }

  Future<void> _handleUndo() async {
    final isPremium = PremiumService().isPremium;

    if (!isPremium) {
      _showUndoPremiumGate();
      return;
    }

    if (_lastSwipedRider == null) {
      AppToast.show(context, message: 'Nothing to undo', type: ToastType.info);
      return;
    }

    final rider = _lastSwipedRider!;
    final riderId = rider['id'] as String;

    _swipedIds.remove(riderId);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        await supabase
            .from('swipes')
            .delete()
            .eq('swiper_id', currentUser.id)
            .eq('swiped_id', riderId);
      }
    } catch (e) {
      debugPrint('DiscoveryScreen: undo delete swipe error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'discovery',
        action: 'undo_swipe_delete',
        error: e,
        severity: 'warning',
        context: {'rider_id': riderId},
      );
    }

    _allRiders.insert(0, rider);
    _swiperController.undo();

    setState(() {
      _filteredRiders = _applyFiltersToList(_allRiders, _activeFilters);
      _isEmpty = _filteredRiders.isEmpty;
      _lastSwipedRider = null;
    });

    if (!mounted) return;
    AppToast.show(context, message: 'Last swipe undone', type: ToastType.info);
  }

  void _showMatchToast(String category) {
    AppToast.show(
      context,
      message: "It's a match! $category ride planned",
      type: ToastType.success,
    );
  }

  void _expandRadius() {
    setState(() => _activeFilters = const FilterState());
    _loadRiders();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search radius expanded. Showing all riders'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showUndoPremiumGate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10.w,
              height: 4,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            Container(
              width: 16.w,
              height: 16.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF9B59B6), Color(0xFF6C3483)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.replay_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Undo Last Swipe',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 1.h),
            Text(
              'Accidentally passed on someone? Rewind your last swipe with Premium.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(
                    context,
                  ).pushNamed('/premium-subscription-screen');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B59B6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                child: Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: 1.5.h),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Maybe later',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRiderProfileSheet(Map<String, dynamic> rider) {
    final photos = <String>{
      if ((rider['photo'] as String?)?.isNotEmpty == true)
        rider['photo'] as String,
      ...List<String>.from(rider['photos'] as List? ?? []),
      ...List<String>.from(rider['bikePhotoUrls'] as List? ?? []),
    }.toList();

    final bio = (rider['bio'] as String?)?.trim();
    final rideMode = rider['rideMode'] as String? ?? 'motorcycle';
    final bikeTypes = List<String>.from(rider['bikeTypes'] as List? ?? []);
    final skillLevels = List<String>.from(rider['skillLevels'] as List? ?? []);
    final preferredRoads = List<String>.from(
      rider['preferredRoads'] as List? ?? [],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);

        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24.0),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(height: 1.2.h),
                  Center(
                    child: Container(
                      width: 11.w,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(height: 1.5.h),
                  SizedBox(
                    height: 34.h,
                    child: PageView.builder(
                      itemCount: photos.isEmpty ? 1 : photos.length,
                      itemBuilder: (_, index) {
                        final imageUrl = photos.isEmpty
                            ? rider['photo'] as String
                            : photos[index];

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18.0),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: Icon(Icons.person_rounded, size: 44),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 3.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rider['name'] as String? ?? 'Rider',
                                style: GoogleFonts.dmSans(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 3.w,
                                vertical: 0.8.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE85A4F,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${rider['compatibility'] ?? 0}% match',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFE85A4F),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: 1.w),
                            Text(
                              rider['distance'] as String? ??
                                  (_isMetric ? '— km' : '— mi'),
                              style: GoogleFonts.dmSans(
                                fontSize: 12.sp,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.speed_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: 1.w),
                            Text(
                              rider['skillLevel'] as String? ?? 'Rider',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.sp,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.5.h),
                        _sectionTitle(theme, 'Bio'),
                        SizedBox(height: 0.8.h),
                        Text(
                          bio == null || bio.isEmpty
                              ? 'No bio added yet.'
                              : bio,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5.sp,
                            height: 1.45,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.78,
                            ),
                          ),
                        ),
                        SizedBox(height: 2.5.h),
                        _sectionTitle(theme, 'Ride Setup'),
                        SizedBox(height: 1.h),
                        if (bikeTypes.isEmpty)
                          Text(
                            'No ride setup details added yet.',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 2.w,
                            runSpacing: 1.h,
                            children: bikeTypes
                                .map(
                                  (bike) => _chip(
                                    theme,
                                    rideMode == 'bicycle'
                                        ? Icons.directions_bike_rounded
                                        : Icons.two_wheeler_rounded,
                                    bike,
                                  ),
                                )
                                .toList(),
                          ),
                        SizedBox(height: 2.5.h),
                        _sectionTitle(theme, 'Riding Profile'),
                        SizedBox(height: 1.h),
                        Wrap(
                          spacing: 2.w,
                          runSpacing: 1.h,
                          children: [
                            ...skillLevels.map(
                              (level) =>
                                  _chip(theme, Icons.speed_rounded, level),
                            ),
                            ...preferredRoads.map(
                              (road) => _chip(theme, Icons.route_rounded, road),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _handlePass,
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Pass'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFE85A4F),
                                  side: const BorderSide(
                                    color: Color(0xFFE85A4F),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: 1.6.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _handleMatch,
                                icon: const Icon(Icons.favorite_rounded),
                                label: const Text('Like'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 1.6.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 13.sp,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.9.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          SizedBox(width: 1.w),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterBadge = _activeFilters.activeCount;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.route_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'RydMatch',
                        style: GoogleFonts.dmSans(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pushNamed('/matches-screen'),
                        child: Icon(
                          Icons.sports_motorsports,
                          color: theme.colorScheme.primary,
                          size: 26,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      GestureDetector(
                        onTap: () {
                          setState(() => _showFilterPanel = !_showFilterPanel);
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              AppIcons.tune,
                              color: filterBadge > 0
                                  ? const Color(0xFFE85A4F)
                                  : theme.colorScheme.primary,
                              size: 26,
                            ),
                            if (filterBadge > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE85A4F),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$filterBadge',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 4.w),
                      GestureDetector(
                        onTap: () =>
                            Navigator.of(context).pushNamed('/settings-screen'),
                        child: Icon(
                          Icons.settings_rounded,
                          color: theme.colorScheme.primary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _showFilterPanel
                    ? FilterPanelWidget(
                        key: const ValueKey('filter'),
                        initialState: _activeFilters,
                        onClose: () => setState(() => _showFilterPanel = false),
                        onApply: _applyFilters,
                      )
                    : const SizedBox.shrink(key: ValueKey('no-filter')),
              ),
              Expanded(
                child: _isLoading
                    ? _buildSkeletonStack()
                    : _isEmpty
                    ? EmptyStateWidget(onExpandRadius: _expandRadius)
                    : Stack(
                        children: [
                          CardSwiper(
                            controller: _swiperController,
                            cardsCount: _filteredRiders.length,
                            isLoop: false,
                            numberOfCardsDisplayed: _filteredRiders.length < 3
                                ? _filteredRiders.length
                                : 3,
                            onSwipe: (previousIndex, currentIndex, direction) {
                              _onSwipe(previousIndex, currentIndex, direction);
                              return true;
                            },
                            onEnd: () {
                              setState(() {
                                _filteredRiders.clear();
                                _isEmpty = true;
                              });
                            },
                            backCardOffset: const Offset(0, 20),
                            scale: 0.95,
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 1.h,
                            ),
                            cardBuilder:
                                (
                                  context,
                                  index,
                                  percentThresholdX,
                                  percentThresholdY,
                                ) {
                                  if (index >= _filteredRiders.length) {
                                    return const SizedBox.shrink();
                                  }

                                  return RiderCardWidget(
                                    rider: _filteredRiders[index],
                                    swipePercent: percentThresholdX.toDouble(),
                                    onTap: () {
                                      setState(() => _currentCardIndex = index);
                                      _showRiderProfileSheet(
                                        _filteredRiders[index],
                                      );
                                    },
                                  );
                                },
                          ),
                          if (_showMatchOverlay)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                child: MatchInteractionOverlay(
                                  leftPhotoUrl: _overlayLeftPhoto,
                                  rightPhotoUrl: _overlayRightPhoto,
                                  onComplete: _onMatchOverlayComplete,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              SizedBox(height: 1.h),
              _isLoading || _isEmpty
                  ? const SizedBox.shrink()
                  : ActionButtonsWidget(
                      onSwipeLeft: _handlePass,
                      onSwipeRight: _handleMatch,
                      onSuperLike: () =>
                          _swiperController.swipe(CardSwiperDirection.top),
                      onUndo: _handleUndo,
                      canUndo: _canUndo,
                    ),
              SizedBox(height: 1.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonStack() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 2.h,
          left: 4.w,
          right: 4.w,
          bottom: 0,
          child: Opacity(
            opacity: 0.5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
        Positioned(
          top: 1.h,
          left: 2.w,
          right: 2.w,
          bottom: 0,
          child: Opacity(
            opacity: 0.75,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
        const DiscoveryCardSkeleton(),
      ],
    );
  }
}

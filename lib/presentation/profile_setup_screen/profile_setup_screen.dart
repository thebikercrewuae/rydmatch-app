import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/profile_service.dart';
import '../../services/analytics_service.dart';
import '../../widgets/toast_widget.dart';
import './widgets/bike_type_widget.dart';
import './widgets/photo_upload_widget.dart';
import './widgets/preferred_roads_widget.dart';
import './widgets/ride_times_widget.dart';
import './widgets/skill_level_widget.dart';
import './widgets/speed_selection_widget.dart';
import './widgets/gender_selection_widget.dart';
import './widgets/emergency_contact_setup_widget.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 9;
  bool _isEditMode = false;
  bool _isLoading = true;

  static const String _contactNameKey = 'sos_contact_name';
  static const String _contactPhoneKey = 'sos_contact_phone';

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  double _ridingSpeed = 60.0;
  bool _isMetric = true;
  DateTime? _dateOfBirth;
  String? _gender;
  bool _sameGenderMatching = false;
  String _rideMode = 'motorcycle';
  bool _mixedCommunityMatching = false;
  List<String> _skillLevels = [];
  List<String> _bikeTypes = [];
  List<String> _preferredRoads = [];
  Map<String, List<String>> _rideTimes = {};
  XFile? _riderPhoto;
  List<XFile> _bikePhotos = [];
  String? _existingRiderPhotoUrl;
  List<String> _existingBikePhotoUrls = [];
  String _emergencyContactName = '';
  String _emergencyContactPhone = '';

  bool get _canContinue {
    switch (_currentPage) {
      case 0:
        return _firstNameController.text.trim().isNotEmpty &&
            _dateOfBirth != null &&
            _meetsMinimumAge;
      case 1:
        return _ridingSpeed > 0;
      case 2:
        return _gender != null;
      case 3:
        return _skillLevels.isNotEmpty;
      case 4:
        return _bikeTypes.isNotEmpty;
      case 5:
        return _preferredRoads.isNotEmpty;
      case 6:
        return _rideTimes.isNotEmpty;
      case 7:
        return true;
      case 8:
        if (_emergencyContactPhone.isEmpty) return true;
        final phoneDigits = _emergencyContactPhone.replaceAll(
          RegExp(r'[\s\-\+\(\)]'),
          '',
        );
        return phoneDigits.length >= 7 &&
            RegExp(r'^\d+$').hasMatch(phoneDigits);
      default:
        return false;
    }
  }

  final List<String> _pageTitles = [
    'Your Profile',
    'Riding Speed',
    'Gender',
    'Skill Level',
    'Bike Type',
    'Preferred Roads',
    'Ride Times',
    'Photos',
    'Emergency SOS',
  ];

  int get _minimumAge => _rideMode == 'motorcycle' || _mixedCommunityMatching
      ? 18
      : 16;

  bool get _meetsMinimumAge {
    final birthDate = _dateOfBirth;
    if (birthDate == null) return false;
    return _ageOn(DateTime.now(), birthDate) >= _minimumAge;
  }

  int _ageOn(DateTime date, DateTime birthDate) {
    var age = date.year - birthDate.year;
    if (date.month < birthDate.month ||
        (date.month == birthDate.month && date.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initScreen());
  }

  Future<void> _initScreen() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map && args['editMode'] == true) {
        _isEditMode = true;

        final data = await ProfileService.loadProfile();
        final prefs = await SharedPreferences.getInstance();

        if (!mounted) return;

        final storedName = data['riderName'] as String? ?? '';
        final nameParts = storedName.trim().split(RegExp(r'\s+'));
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : '';

        final rawRideTimes = data['rideTimes'] as Map? ?? {};
        var existingRiderPhotoUrl = data['riderPhotoPath'] as String?;
        var existingBikePhotoUrls = List<String>.from(
          data['bikePhotoPaths'] as List? ?? [],
        ).where((url) => url.startsWith('http')).toList();

        try {
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser != null) {
            final remoteProfile = await Supabase.instance.client
                .from('user_profiles')
                .select('avatar_url, bike_photo_urls')
                .eq('id', currentUser.id)
                .maybeSingle();

            final remoteAvatar = remoteProfile?['avatar_url'] as String?;
            if (remoteAvatar != null && remoteAvatar.startsWith('http')) {
              existingRiderPhotoUrl = remoteAvatar;
            }

            final remoteBikePhotos = remoteProfile?['bike_photo_urls'];
            if (remoteBikePhotos is List) {
              existingBikePhotoUrls = remoteBikePhotos
                  .map((url) => url.toString())
                  .where((url) => url.startsWith('http'))
                  .toList();
            }
          }
        } catch (_) {}

        setState(() {
          _firstNameController.text = firstName;
          _lastNameController.text = lastName;
          _bioController.text = data['riderBio'] as String? ?? '';

          _ridingSpeed = (data['ridingSpeed'] as num?)?.toDouble() ?? 60.0;
          _isMetric = data['isMetric'] as bool? ?? true;
          final savedBirthDate = data['dateOfBirth'] as String?;
          _dateOfBirth = savedBirthDate == null
              ? null
              : DateTime.tryParse(savedBirthDate);
          _gender = data['gender'] as String?;
          _sameGenderMatching =
              (data['sameGenderMatching'] as bool?) ?? false;
          _rideMode = data['rideMode'] as String? ?? 'motorcycle';
          _mixedCommunityMatching =
              (data['mixedCommunityMatching'] as bool?) ?? false;

          _skillLevels = List<String>.from(data['skillLevels'] ?? []);
          _bikeTypes = List<String>.from(data['bikeTypes'] ?? []);
          _preferredRoads = List<String>.from(data['preferredRoads'] ?? []);

          _rideTimes = rawRideTimes.map(
            (key, value) =>
                MapEntry(key.toString(), List<String>.from(value ?? [])),
          );

          _existingRiderPhotoUrl = existingRiderPhotoUrl;
          _existingBikePhotoUrls = existingBikePhotoUrls;

          _emergencyContactName = prefs.getString(_contactNameKey) ?? '';
          _emergencyContactPhone = prefs.getString(_contactPhoneKey) ?? '';
          _isLoading = false;
        });
      } else {
        final data = await ProfileService.loadProfile();

        if (mounted) {
          setState(() {
            _isMetric = data['isMetric'] as bool? ?? true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      AppToast.show(
        context,
        message: 'Could not load profile. Please try again.',
        type: ToastType.error,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _onFinishTapped();
    }
  }

  Future<void> _onFinishTapped() async {
    if (_emergencyContactPhone.isNotEmpty) {
      final confirmed = await _showContactConfirmationDialog();
      if (confirmed != true) return;
    }
    await _saveAndFinish();
  }

  Future<bool?> _showContactConfirmationDialog() {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sos_rounded, color: Color(0xFFE53935), size: 24),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Confirm Emergency Contact',
                style: GoogleFonts.dmSans(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please confirm the details below are correct. This contact will receive your GPS location during an SOS alert.',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_emergencyContactName.isNotEmpty) ...[
                    Text(
                      'Name',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 0.4.h),
                    Text(
                      _emergencyContactName,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                  ],
                  Text(
                    'Phone Number',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    _emergencyContactPhone,
                    style: GoogleFonts.dmSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE53935),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 1.5.h),
            Text(
              'Double-check for typos — a wrong number means help won\'t reach your contact.',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Edit',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Confirm & Save',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndFinish() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      await Future.delayed(const Duration(seconds: 2));
      final retryUser = supabase.auth.currentUser;

      if (retryUser == null) {
        if (mounted) {
          AppToast.show(
            context,
            message: 'Not signed in — please log in first',
            type: ToastType.error,
          );
        }
        return;
      }
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = lastName.isNotEmpty ? '$firstName $lastName' : firstName;

    if (!_meetsMinimumAge) {
      AppToast.show(
        context,
        message: _minimumAge == 18
            ? 'Motorcycle and mixed matching users must be at least 18.'
            : 'Bicycle users must be at least 16.',
        type: ToastType.error,
      );
      return;
    }

    if (_riderPhoto != null && mounted) {
      AppToast.show(
        context,
        message: 'Uploading photo...',
        type: ToastType.info,
      );
    }

    await ProfileService.saveProfile(
      ridingSpeed: _ridingSpeed,
      skillLevels: _skillLevels,
      bikeTypes: _bikeTypes,
      preferredRoads: _preferredRoads,
      rideTimes: _rideTimes,
      riderPhotoPath: _riderPhoto?.path,
      riderPhotoFile: _riderPhoto,
      existingRiderPhotoUrl: _existingRiderPhotoUrl,
      bikePhotoPaths: _existingBikePhotoUrls,
      bikePhotoFiles: _bikePhotos,
      isMetric: _isMetric,
      dateOfBirth: _dateOfBirth,
      minimumAgeConfirmed: _minimumAge,
      gender: _gender,
      sameGenderMatching: _sameGenderMatching,
      rideMode: _rideMode,
      mixedCommunityMatching: _mixedCommunityMatching,
      riderName: fullName,
      riderBio: _bioController.text.trim(),
    );

    final prefs = await SharedPreferences.getInstance();

    if (_emergencyContactName.isEmpty && _emergencyContactPhone.isEmpty) {
      await prefs.remove(_contactNameKey);
      await prefs.remove(_contactPhoneKey);
    } else {
      await prefs.setString(_contactNameKey, _emergencyContactName);
      await prefs.setString(_contactPhoneKey, _emergencyContactPhone);
    }

    if (_isEditMode) {
      await AnalyticsService.instance.logProfileUpdated();
    } else {
      await AnalyticsService.instance.logProfileCreated();
    }

    if (mounted) {
      AppToast.show(
        context,
        message: _isEditMode
            ? 'Profile updated successfully'
            : 'Profile created! Welcome to RydMatch',
        type: ToastType.success,
      );
      if (_isEditMode) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          '/profile-view-screen',
          (route) => route.settings.name == '/main-screen' || route.isFirst,
        );
      }
    }
  }

  void _skip() {
    if (_isEditMode) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/discovery-screen', (route) => false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
          child: Column(
            children: [
              _buildHeader(theme),
              SizedBox(height: 1.h),
              _buildProgressIndicator(theme),
              SizedBox(height: 2.h),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  children: [
                    _buildNameInputPage(theme),
                    SpeedSelectionWidget(
                      ridingSpeed: _ridingSpeed,
                      isMetric: _isMetric,
                      onSpeedChanged: (val) =>
                          setState(() => _ridingSpeed = val),
                      onUnitChanged: (val) => setState(() => _isMetric = val),
                      rideMode: _rideMode,
                    ),
                    GenderSelectionWidget(
                      selectedGender: _gender,
                      sameGenderMatching: _sameGenderMatching,
                      onGenderChanged: (val) => setState(() {
                        _gender = val;
                        if (val == 'prefer_not_to_say') {
                          _sameGenderMatching = false;
                        }
                      }),
                      onSameGenderMatchingChanged: (val) =>
                          setState(() => _sameGenderMatching = val),
                    ),
                    SkillLevelWidget(
                      selectedLevels: _skillLevels,
                      onLevelsChanged: (val) =>
                          setState(() => _skillLevels = val),
                    ),
                    BikeTypeWidget(
                      selectedBikes: _bikeTypes,
                      onBikesChanged: (val) => setState(() => _bikeTypes = val),
                      rideMode: _rideMode,
                    ),
                    PreferredRoadsWidget(
                      selectedRoads: _preferredRoads,
                      onRoadsChanged: (val) =>
                          setState(() => _preferredRoads = val),
                    ),
                    RideTimesWidget(
                      rideTimes: _rideTimes,
                      onTimesChanged: (val) => setState(() => _rideTimes = val),
                    ),
                    PhotoUploadWidget(
                      riderPhoto: _riderPhoto,
                      existingRiderPhotoUrl: _existingRiderPhotoUrl,
                      existingBikePhotoUrls: _existingBikePhotoUrls,
                      bikePhotos: _bikePhotos,
                      onRiderPhotoChanged: (val) =>
                          setState(() {
                            _riderPhoto = val;
                            if (val != null || _existingRiderPhotoUrl != null) {
                              _existingRiderPhotoUrl = null;
                            }
                          }),
                      onExistingBikePhotoUrlsChanged: (val) =>
                          setState(() => _existingBikePhotoUrls = val),
                      onBikePhotosChanged: (val) =>
                          setState(() => _bikePhotos = val),
                    ),
                    EmergencyContactSetupWidget(
                      contactName: _emergencyContactName,
                      contactPhone: _emergencyContactPhone,
                      onNameChanged: (val) =>
                          setState(() => _emergencyContactName = val),
                      onPhoneChanged: (val) =>
                          setState(() => _emergencyContactPhone = val),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              _buildContinueButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _currentPage > 0
            ? GestureDetector(
                onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                ),
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: theme.colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              )
            : SizedBox(width: 10.w),
        Column(
          children: [
            Text(
              'Step ${_currentPage + 1} of $_totalPages',
              style: theme.textTheme.labelMedium,
            ),
            Text(
              _isEditMode
                  ? 'Edit ${_pageTitles[_currentPage]}'
                  : _pageTitles[_currentPage],
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        _isEditMode
            ? TextButton(
                onPressed: _skip,
                child: Text(
                  'Cancel',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            : SizedBox(width: 10.w),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return SmoothPageIndicator(
      controller: _pageController,
      count: _totalPages,
      effect: WormEffect(
        dotHeight: 8,
        dotWidth: 8,
        activeDotColor: theme.colorScheme.primary,
        dotColor: theme.colorScheme.outline,
        spacing: 6,
      ),
    );
  }

  Widget _buildContinueButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: ElevatedButton(
        onPressed: _canContinue ? _nextPage : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _canContinue
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _currentPage == _totalPages - 1
              ? (_isEditMode ? 'Save Changes' : 'Get Started')
              : 'Continue',
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildNameInputPage(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell riders about you',
            style: GoogleFonts.dmSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Add your name and a short bio for your rider profile.',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 3.h),
          _buildTextLabel(theme, 'First Name *'),
          SizedBox(height: 1.h),
          _buildTextField(
            theme: theme,
            controller: _firstNameController,
            hintText: 'Enter your first name',
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: 2.5.h),
          _buildTextLabel(theme, 'Last Name'),
          SizedBox(height: 1.h),
          _buildTextField(
            theme: theme,
            controller: _lastNameController,
            hintText: 'Enter your last name (optional)',
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: 2.5.h),
          _buildDateOfBirthField(theme),
          SizedBox(height: 2.5.h),
          _buildRideCommunitySection(theme),
          SizedBox(height: 2.5.h),
          _buildTextLabel(theme, 'Bio'),
          SizedBox(height: 1.h),
          TextField(
            controller: _bioController,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            minLines: 4,
            maxLines: 6,
            maxLength: 300,
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText:
                  'Share your riding style, favorite roads, or what kind of riders you want to meet.',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                height: 1.4,
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 4.w,
                vertical: 1.8.h,
              ),
              counterStyle: GoogleFonts.dmSans(
                fontSize: 10.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCommunitySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextLabel(theme, 'Ride Community'),
        SizedBox(height: 1.h),
        Row(
          children: [
            Expanded(
              child: _buildRideModeButton(
                theme: theme,
                value: 'motorcycle',
                label: 'Motorcycle',
                icon: Icons.two_wheeler_rounded,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildRideModeButton(
                theme: theme,
                value: 'bicycle',
                label: 'Bicycle',
                icon: Icons.directions_bike_rounded,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.5.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Open to mixed motorcycle and bicycle matches',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Switch(
                value: _mixedCommunityMatching,
                activeColor: theme.colorScheme.primary,
                onChanged: (value) =>
                    setState(() => _mixedCommunityMatching = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateOfBirthField(ThemeData theme) {
    final hasError = _dateOfBirth != null && !_meetsMinimumAge;
    final valueText = _dateOfBirth == null
        ? 'Select your date of birth'
        : _formatDate(_dateOfBirth!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextLabel(theme, 'Date of Birth *'),
        SizedBox(height: 1.h),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectDateOfBirth(theme),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? theme.colorScheme.error
                    : theme.colorScheme.outline,
                width: hasError ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: hasError
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    valueText,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: _dateOfBirth == null
                          ? FontWeight.w500
                          : FontWeight.w600,
                      color: _dateOfBirth == null
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 0.8.h),
        Text(
          'Minimum age: $_minimumAge+ for your selected ride community.',
          style: GoogleFonts.dmSans(
            fontSize: 11.sp,
            color: hasError
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: hasError ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateOfBirth(ThemeData theme) async {
    final now = DateTime.now();
    final initialDate =
        _dateOfBirth ?? DateTime(now.year - _minimumAge, now.month, now.day);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select date of birth',
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return;
    setState(() => _dateOfBirth = selectedDate);
  }

  Widget _buildRideModeButton({
    required ThemeData theme,
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _rideMode == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_rideMode != value) {
            _rideMode = value;
            _bikeTypes = [];
            if (value == 'bicycle' && _ridingSpeed > 35) {
              _ridingSpeed = 15;
            } else if (value == 'motorcycle' && _ridingSpeed < 20) {
              _ridingSpeed = 60;
            }
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 26,
            ),
            SizedBox(height: 0.7.h),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextLabel(ThemeData theme, String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildTextField({
    required ThemeData theme,
    required TextEditingController controller,
    required String hintText,
    required TextCapitalization textCapitalization,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      textCapitalization: textCapitalization,
      style: GoogleFonts.dmSans(
        fontSize: 14.sp,
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 13.sp,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 4.w,
          vertical: 1.8.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}

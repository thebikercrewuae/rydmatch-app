import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'diagnostics_service.dart';

class ProfileService {
  static String? _lastUploadError;
  static String? get lastUploadError => _lastUploadError;

  static const String _keyIsProfileComplete = 'is_profile_complete';

  static const String _keyRidingSpeed = 'profile_riding_speed';
  static const String _keySkillLevels = 'profile_skill_levels';
  static const String _keyBikeTypes = 'profile_bike_types';
  static const String _keyPreferredRoads = 'profile_preferred_roads';
  static const String _keyRideTimes = 'profile_ride_times';
  static const String _keyRiderPhotoPath = 'profile_rider_photo_path';
  static const String _keyBikePhotoPaths = 'profile_bike_photo_paths';
  static const String _keyRiderName = 'profile_rider_name';
  static const String _keyRiderBio = 'profile_rider_bio';
  static const String _keySpeedUnit =
      'profile_speed_unit'; // 'metric' or 'imperial'
  static const String _keyGender = 'profile_gender';
  static const String _keySameGenderMatching = 'profile_same_gender_matching';
  static const String _keyDateOfBirth = 'profile_date_of_birth';
  static const String _keyMinimumAgeConfirmed = 'profile_minimum_age_confirmed';
  static const String _keyRideMode = 'profile_ride_mode';
  static const String _keyMixedCommunityMatching =
      'profile_mixed_community_matching';

  static Future<bool> isProfileComplete() async {
    final prefs = await SharedPreferences.getInstance();
    _lastUploadError = null;
    return prefs.getBool(_keyIsProfileComplete) ?? false;
  }

  /// Upload an XFile image to Supabase Storage and return the public URL.
  /// Returns null if upload fails.
  static Future<String?> uploadPhoto(XFile photo, String folder) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ uploadPhoto: No authenticated user');
        return null;
      }

      final ext = photo.name.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)
          ? ext
          : 'jpg';
      final fileName = folder == 'profile'
          ? 'avatar.$safeExt'
          : '${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      final filePath = '${currentUser.id}/$folder/$fileName';

      // Read bytes from the XFile — works on both web and mobile
      final bytes = await photo.readAsBytes();

      // Check we actually got data
      if (bytes.isEmpty) {
        debugPrint('❌ uploadPhoto: Empty bytes for ${photo.name}');
        return null;
      }

      debugPrint(
        '📤 uploadPhoto: Uploading ${bytes.length} bytes to user-photos/$filePath',
      );

      final String contentType;
      if (safeExt == 'png') {
        contentType = 'image/png';
      } else if (safeExt == 'gif') {
        contentType = 'image/gif';
      } else if (safeExt == 'webp') {
        contentType = 'image/webp';
      } else {
        contentType = 'image/jpeg';
      }

      await supabase.storage
          .from('user-photos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = supabase.storage
          .from('user-photos')
          .getPublicUrl(filePath);

      debugPrint('✅ uploadPhoto: Public URL = $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ uploadPhoto failed: $e');
      _lastUploadError = e.toString();
      await DiagnosticsService.instance.logError(
        feature: 'profile_media',
        action: 'upload_photo',
        error: e,
        context: {'folder': folder, 'photo_name': photo.name},
      );
      return null;
    }
  }

  static Future<String?> resolvePhotoUrl(String? url) async {
    if (url == null) return null;

    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('blob:') ||
        trimmed.startsWith('file:')) {
      return null;
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }

    final storagePath = _storagePathFromUserPhotosUrl(trimmed);
    if (storagePath == null) return trimmed;

    try {
      return await Supabase.instance.client.storage
          .from('user-photos')
          .createSignedUrl(storagePath, 3600);
    } catch (e) {
      debugPrint('resolvePhotoUrl: failed to sign photo URL: $e');
      await DiagnosticsService.instance.logError(
        feature: 'profile_media',
        action: 'sign_photo_url',
        error: e,
        context: {'url': trimmed},
        severity: 'warning',
      );
      return trimmed;
    }
  }

  static Future<String?> resolveUserProfilePhotoUrl({
    required String userId,
    String? avatarUrl,
  }) async {
    final resolvedAvatarUrl = await resolvePhotoUrl(avatarUrl);
    if (resolvedAvatarUrl != null) return resolvedAvatarUrl;

    if (userId.trim().isEmpty) return null;

    try {
      for (final extension in const ['jpg', 'jpeg', 'png', 'webp']) {
        final storagePath = '${userId.trim()}/profile/avatar.$extension';
        try {
          return await Supabase.instance.client.storage
              .from('user-photos')
              .createSignedUrl(storagePath, 3600);
        } catch (_) {}
      }

      final files = await Supabase.instance.client.storage
          .from('user-photos')
          .list(path: '${userId.trim()}/profile');
      final imageFiles =
          files
              .where(
                (file) =>
                    !file.name.startsWith('.') &&
                    RegExp(
                      r'\.(jpe?g|png|webp|gif)$',
                      caseSensitive: false,
                    ).hasMatch(file.name),
              )
              .toList()
            ..sort((a, b) => b.name.compareTo(a.name));

      if (imageFiles.isEmpty) return null;

      final storagePath = '${userId.trim()}/profile/${imageFiles.first.name}';
      try {
        return await Supabase.instance.client.storage
            .from('user-photos')
            .createSignedUrl(storagePath, 3600);
      } catch (_) {
        return Supabase.instance.client.storage
            .from('user-photos')
            .getPublicUrl(storagePath);
      }
    } catch (e) {
      debugPrint('resolveUserProfilePhotoUrl: failed to find photo: $e');
      await DiagnosticsService.instance.logError(
        feature: 'profile_media',
        action: 'resolve_user_profile_photo',
        error: e,
        context: {'target_user_id': userId},
        severity: 'warning',
      );
      return null;
    }
  }

  static String? _storagePathFromUserPhotosUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    const publicMarker = '/storage/v1/object/public/user-photos/';
    const signedMarker = '/storage/v1/object/sign/user-photos/';
    final path = uri.path;
    final marker = path.contains(publicMarker)
        ? publicMarker
        : path.contains(signedMarker)
        ? signedMarker
        : null;
    if (marker == null) return null;

    final storagePath = Uri.decodeComponent(path.split(marker).last);
    return storagePath.isEmpty ? null : storagePath;
  }

  static Future<void> saveProfile({
    required double ridingSpeed,
    required List<String> skillLevels,
    required List<String> bikeTypes,
    required List<String> preferredRoads,
    required Map<String, List<String>> rideTimes,
    String? riderPhotoPath,
    String? existingRiderPhotoUrl,
    List<String> bikePhotoPaths = const [],
    List<XFile> bikePhotoFiles = const [],
    String riderName = '',
    String riderBio = '',
    bool isMetric = true,
    DateTime? dateOfBirth,
    int? minimumAgeConfirmed,
    String? gender,
    bool sameGenderMatching = false,
    String rideMode = 'motorcycle',
    bool mixedCommunityMatching = false,
    XFile? riderPhotoFile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _lastUploadError = null;

    await prefs.setDouble(_keyRidingSpeed, ridingSpeed);
    await prefs.setStringList(_keySkillLevels, skillLevels);
    await prefs.setStringList(_keyBikeTypes, bikeTypes);
    await prefs.setStringList(_keyPreferredRoads, preferredRoads);
    await prefs.setString(_keyRideTimes, jsonEncode(rideTimes));

    // Check auth BEFORE attempting upload
    final supabase = Supabase.instance.client;
    var currentUser = supabase.auth.currentUser;

    // If no session, wait briefly for it to restore
    if (currentUser == null) {
      debugPrint('⚠️ No auth session in saveProfile — waiting...');
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          debugPrint('✅ Session recovered after ${(i + 1) * 500}ms');
          break;
        }
      }
    }

    // Upload rider photo to Supabase Storage if a new file was provided
    // Keep the existing photo unless a new one is uploaded or the user removed it
    String? resolvedPhotoUrl = existingRiderPhotoUrl;
    if ((resolvedPhotoUrl == null || resolvedPhotoUrl.isEmpty) &&
        riderPhotoPath != null &&
        (riderPhotoPath.startsWith('http://') ||
            riderPhotoPath.startsWith('https://'))) {
      resolvedPhotoUrl = riderPhotoPath;
    }

    if (riderPhotoFile != null) {
      debugPrint('📸 saveProfile: Uploading rider photo...');
      final uploadedUrl = await uploadPhoto(riderPhotoFile, 'profile');

      if (uploadedUrl == null ||
          uploadedUrl.isEmpty ||
          uploadedUrl.startsWith('blob:')) {
        throw Exception(
          'Photo upload failed${_lastUploadError != null ? ': $_lastUploadError' : ''}',
        );
      }

      resolvedPhotoUrl = uploadedUrl;
      debugPrint('✅ saveProfile: Photo uploaded → $resolvedPhotoUrl');
    }

    // Extra safety: never save blob: URLs — they are temporary browser references
    if (resolvedPhotoUrl != null && resolvedPhotoUrl.startsWith('blob:')) {
      debugPrint('❌ saveProfile: Discarding blob URL: $resolvedPhotoUrl');
      resolvedPhotoUrl = null;
    }

    final resolvedBikePhotoUrls = <String>[
      ...bikePhotoPaths.where(
        (path) =>
            path.isNotEmpty &&
            !path.startsWith('blob:') &&
            (path.startsWith('http://') || path.startsWith('https://')),
      ),
    ];

    for (final bikePhoto in bikePhotoFiles) {
      final uploadedUrl = await uploadPhoto(bikePhoto, 'profile-bikes');
      if (uploadedUrl != null &&
          uploadedUrl.isNotEmpty &&
          !uploadedUrl.startsWith('blob:')) {
        resolvedBikePhotoUrls.add(uploadedUrl);
      }
    }

    if (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty) {
      await prefs.setString(_keyRiderPhotoPath, resolvedPhotoUrl);
    } else {
      await prefs.remove(_keyRiderPhotoPath);
    }
    await prefs.setStringList(_keyBikePhotoPaths, resolvedBikePhotoUrls);
    await prefs.setString(_keyRiderName, riderName);
    await prefs.setString(_keyRiderBio, riderBio);
    await prefs.setString(_keySpeedUnit, isMetric ? 'metric' : 'imperial');
    await prefs.setBool('unit_system_metric', isMetric);
    await prefs.setBool('isMetric', isMetric);
    final effectiveSameGenderMatching = gender == 'prefer_not_to_say'
        ? false
        : sameGenderMatching;
    if (dateOfBirth != null) {
      await prefs.setString(
        _keyDateOfBirth,
        DateTime(
          dateOfBirth.year,
          dateOfBirth.month,
          dateOfBirth.day,
        ).toIso8601String(),
      );
    }
    if (minimumAgeConfirmed != null) {
      await prefs.setInt(_keyMinimumAgeConfirmed, minimumAgeConfirmed);
    }
    await prefs.setString(_keyRideMode, rideMode);
    await prefs.setBool(_keyMixedCommunityMatching, mixedCommunityMatching);
    if (gender != null) {
      await prefs.setString(_keyGender, gender);
    }
    await prefs.setBool(_keySameGenderMatching, effectiveSameGenderMatching);
    await prefs.setBool(_keyIsProfileComplete, true);

    // Sync to Supabase (only if authenticated)
    if (currentUser != null) {
      await _syncToSupabase(
        ridingSpeed: ridingSpeed,
        skillLevels: skillLevels,
        bikeTypes: bikeTypes,
        preferredRoads: preferredRoads,
        riderName: riderName,
        riderBio: riderBio,
        gender: gender,
        sameGenderMatching: effectiveSameGenderMatching,
        minimumAgeConfirmed: minimumAgeConfirmed,
        rideMode: rideMode,
        mixedCommunityMatching: mixedCommunityMatching,
        avatarUrl: resolvedPhotoUrl,
        bikePhotoUrls: resolvedBikePhotoUrls,
      );
    } else {
      debugPrint('⚠️ Skipping Supabase sync — no auth. Profile saved locally.');
      // Mark that we need to sync later
      await prefs.setBool('_pending_supabase_sync', true);
    }
  }

  /// Sync rider profile data to Supabase user_profiles table
  static Future<void> _syncToSupabase({
    required double ridingSpeed,
    required List<String> skillLevels,
    required List<String> bikeTypes,
    required List<String> preferredRoads,
    String riderName = '',
    String riderBio = '',
    String? gender,
    bool sameGenderMatching = false,
    int? minimumAgeConfirmed,
    String rideMode = 'motorcycle',
    bool mixedCommunityMatching = false,
    String? avatarUrl,
    List<String> bikePhotoUrls = const [],
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ SYNC FAILED: No authenticated user');
        return;
      }

      debugPrint('🔄 Syncing profile to Supabase...');
      debugPrint('   avatarUrl: $avatarUrl');

      final updates = <String, dynamic>{
        'id': currentUser.id,
        'email': currentUser.email,
        'skill_levels': skillLevels,
        'bike_types': bikeTypes,
        'preferred_roads': preferredRoads,
        'riding_speed': ridingSpeed,
        'ride_mode': rideMode,
        'mixed_community_matching': mixedCommunityMatching,
        'same_gender_matching': sameGenderMatching,
        'bio': riderBio,
        'is_profile_complete': true,
        'avatar_url': avatarUrl,
        'bike_photo_urls': bikePhotoUrls,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (riderName.isNotEmpty) {
        updates['full_name'] = riderName;
      }
      if (gender != null) {
        updates['gender'] = gender;
      }
      if (minimumAgeConfirmed != null) {
        updates['minimum_age_confirmed'] = minimumAgeConfirmed;
        updates['age_verified_at'] = DateTime.now().toIso8601String();
      }

      try {
        await supabase.from('user_profiles').upsert(updates, onConflict: 'id');
      } catch (e) {
        if (e is! PostgrestException) rethrow;

        var shouldRetry = false;
        if (e.message.contains('bike_photo_urls')) {
          updates.remove('bike_photo_urls');
          shouldRetry = true;
        }
        if (e.message.contains('same_gender_matching')) {
          updates.remove('same_gender_matching');
          shouldRetry = true;
        }

        if (!shouldRetry) rethrow;
        await supabase.from('user_profiles').upsert(updates, onConflict: 'id');
      }
      debugPrint('✅ Profile synced successfully');
    } catch (e) {
      debugPrint('❌ SYNC FAILED: $e');
      await DiagnosticsService.instance.logError(
        feature: 'profile',
        action: 'sync_to_supabase',
        error: e,
        context: {
          'has_avatar_url': avatarUrl != null && avatarUrl.isNotEmpty,
          'bike_photo_count': bikePhotoUrls.length,
          'ride_mode': rideMode,
        },
      );
    }
  }

  static Future<Map<String, dynamic>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final rideTimesJson = prefs.getString(_keyRideTimes);
    Map<String, List<String>> rideTimes = {};
    if (rideTimesJson != null) {
      final decoded = jsonDecode(rideTimesJson) as Map<String, dynamic>;
      rideTimes = decoded.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      );
    }
    final settingsMetric = prefs.getBool('unit_system_metric');
    final legacyMetric = prefs.getBool('isMetric');
    final speedUnit = prefs.getString(_keySpeedUnit);
    final isMetric =
        settingsMetric ?? legacyMetric ?? (speedUnit != 'imperial');

    return {
      'ridingSpeed': prefs.getDouble(_keyRidingSpeed) ?? 60.0,
      'skillLevels': prefs.getStringList(_keySkillLevels) ?? [],
      'bikeTypes': prefs.getStringList(_keyBikeTypes) ?? [],
      'preferredRoads': prefs.getStringList(_keyPreferredRoads) ?? [],
      'rideTimes': rideTimes,
      'riderPhotoPath': prefs.getString(_keyRiderPhotoPath),
      'bikePhotoPaths': prefs.getStringList(_keyBikePhotoPaths) ?? [],
      'riderName': prefs.getString(_keyRiderName) ?? '',
      'riderBio': prefs.getString(_keyRiderBio) ?? '',
      'isMetric': isMetric,
      'dateOfBirth': prefs.getString(_keyDateOfBirth),
      'minimumAgeConfirmed': prefs.getInt(_keyMinimumAgeConfirmed),
      'gender': prefs.getString(_keyGender),
      'sameGenderMatching': prefs.getBool(_keySameGenderMatching) ?? false,
      'rideMode': prefs.getString(_keyRideMode) ?? 'motorcycle',
      'mixedCommunityMatching':
          prefs.getBool(_keyMixedCommunityMatching) ?? false,
    };
  }

  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsProfileComplete);
    await prefs.remove(_keyRidingSpeed);
    await prefs.remove(_keySkillLevels);
    await prefs.remove(_keyBikeTypes);
    await prefs.remove(_keyPreferredRoads);
    await prefs.remove(_keyRideTimes);
    await prefs.remove(_keyRiderPhotoPath);
    await prefs.remove(_keyBikePhotoPaths);
    await prefs.remove(_keyRiderName);
    await prefs.remove(_keyRiderBio);
    await prefs.remove(_keyDateOfBirth);
    await prefs.remove(_keyMinimumAgeConfirmed);
    await prefs.remove(_keyGender);
    await prefs.remove(_keySameGenderMatching);
    await prefs.remove(_keyRideMode);
    await prefs.remove(_keyMixedCommunityMatching);
  }

  /// Fetches the profile from Supabase and restores it to SharedPreferences.
  /// Call this after login to ensure profile data persists across sign-outs.
  static Future<void> restoreProfileFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (response == null) return;

      final isComplete = response['is_profile_complete'] as bool? ?? false;
      if (!isComplete) return;

      final prefs = await SharedPreferences.getInstance();

      // Restore riding speed
      final ridingSpeed = (response['riding_speed'] as num?)?.toDouble();
      if (ridingSpeed != null) {
        await prefs.setDouble(_keyRidingSpeed, ridingSpeed);
      }

      // Restore skill levels
      final skillLevels = response['skill_levels'];
      if (skillLevels != null) {
        await prefs.setStringList(
          _keySkillLevels,
          List<String>.from(skillLevels as List),
        );
      }

      // Restore bike types
      final bikeTypes = response['bike_types'];
      if (bikeTypes != null) {
        await prefs.setStringList(
          _keyBikeTypes,
          List<String>.from(bikeTypes as List),
        );
      }

      // Restore preferred roads
      final preferredRoads = response['preferred_roads'];
      if (preferredRoads != null) {
        await prefs.setStringList(
          _keyPreferredRoads,
          List<String>.from(preferredRoads as List),
        );
      }

      // Restore name and bio
      final fullName = response['full_name'] as String?;
      if (fullName != null) {
        await prefs.setString(_keyRiderName, fullName);
      }
      final bio = response['bio'] as String?;
      if (bio != null) {
        await prefs.setString(_keyRiderBio, bio);
      }

      // Restore gender
      final gender = response['gender'] as String?;
      if (gender != null) {
        await prefs.setString(_keyGender, gender);
      }

      final sameGenderMatching = response['same_gender_matching'] as bool?;
      if (sameGenderMatching != null) {
        await prefs.setBool(_keySameGenderMatching, sameGenderMatching);
      }

      final rideMode = response['ride_mode'] as String?;
      if (rideMode != null && rideMode.isNotEmpty) {
        await prefs.setString(_keyRideMode, rideMode);
      }

      final mixedCommunityMatching =
          response['mixed_community_matching'] as bool?;
      if (mixedCommunityMatching != null) {
        await prefs.setBool(_keyMixedCommunityMatching, mixedCommunityMatching);
      }

      // Restore avatar/photo URL
      final avatarUrl = response['avatar_url'] as String?;
      if (avatarUrl != null) {
        await prefs.setString(_keyRiderPhotoPath, avatarUrl);
      }

      final bikePhotoUrls = response['bike_photo_urls'];
      if (bikePhotoUrls is List) {
        await prefs.setStringList(
          _keyBikePhotoPaths,
          bikePhotoUrls
              .map((url) => url.toString())
              .where((url) => url.isNotEmpty && !url.startsWith('blob:'))
              .toList(),
        );
      }

      // Mark profile as complete locally
      await prefs.setBool(_keyIsProfileComplete, true);
    } catch (_) {
      // Non-critical — local state remains unchanged
    }
  }
}

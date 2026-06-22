import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'diagnostics_service.dart';

class AppUpdateInfo {
  final String platform;
  final String latestVersionName;
  final int latestBuildNumber;
  final int minimumBuildNumber;
  final String title;
  final String message;
  final String storeUrl;
  final String? releaseNotes;
  final int currentBuildNumber;

  const AppUpdateInfo({
    required this.platform,
    required this.latestVersionName,
    required this.latestBuildNumber,
    required this.minimumBuildNumber,
    required this.title,
    required this.message,
    required this.storeUrl,
    this.releaseNotes,
    required this.currentBuildNumber,
  });

  bool get isUpdateAvailable => latestBuildNumber > currentBuildNumber;

  bool get isForced => minimumBuildNumber > currentBuildNumber;
}

class AppUpdateService extends ChangeNotifier {
  static AppUpdateService? _instance;
  static AppUpdateService get instance => _instance ??= AppUpdateService._();

  AppUpdateService._();

  final SupabaseClient _client = Supabase.instance.client;

  AppUpdateInfo? _updateInfo;
  bool _isChecking = false;

  AppUpdateInfo? get updateInfo => _updateInfo;

  bool get hasUpdate => _updateInfo != null;

  Future<void> checkForUpdate() async {
    if (_isChecking) return;

    _isChecking = true;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final platform = _platformKey();

      final row = await _client
          .from('app_update_config')
          .select()
          .eq('id', platform)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) {
        _setUpdateInfo(null);
        return;
      }

      final latestBuildNumber = _readInt(row['latest_build_number']);
      final latestVersionName =
          row['latest_version_name'] as String? ?? packageInfo.version;

      if (latestBuildNumber <= currentBuildNumber) {
        _setUpdateInfo(null);
        return;
      }

      _setUpdateInfo(
        AppUpdateInfo(
          platform: row['platform'] as String? ?? platform,
          latestVersionName: latestVersionName,
          latestBuildNumber: latestBuildNumber,
          minimumBuildNumber: _readInt(row['minimum_build_number']),
          title: row['title'] as String? ?? 'RydMatch update available',
          message:
              row['message'] as String? ??
              'A newer version of RydMatch is available.',
          storeUrl:
              row['store_url'] as String? ??
              'https://play.google.com/store/apps/details?id=com.rydmatch.app',
          releaseNotes: row['release_notes'] as String?,
          currentBuildNumber: currentBuildNumber,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('AppUpdateService: failed to check app update: $e');
      await DiagnosticsService.instance.logError(
        feature: 'app_update',
        action: 'check_for_update',
        error: e,
        stackTrace: stackTrace,
        severity: 'warning',
      );
    } finally {
      _isChecking = false;
    }
  }

  Future<void> launchUpdate() async {
    final info = _updateInfo;
    if (info == null) return;

    final uri = Uri.tryParse(info.storeUrl);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await DiagnosticsService.instance.logError(
        feature: 'app_update',
        action: 'launch_store',
        error: StateError('Could not launch update URL'),
        severity: 'warning',
        context: {'store_url': info.storeUrl},
      );
    }
  }

  void _setUpdateInfo(AppUpdateInfo? info) {
    final previousBuild = _updateInfo?.latestBuildNumber;
    _updateInfo = info;
    if (previousBuild != info?.latestBuildNumber) {
      notifyListeners();
    }
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _platformKey() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
      default:
        return 'android';
    }
  }
}

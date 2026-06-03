import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'diagnostics_service.dart';

class StravaService extends ChangeNotifier {
  static StravaService? _instance;
  static StravaService get instance => _instance ??= StravaService._();

  StravaService._();

  static const String _clientId = String.fromEnvironment('STRAVA_CLIENT_ID');
  static const String _redirectUri = String.fromEnvironment(
    'STRAVA_REDIRECT_URI',
    defaultValue: 'rydmatch://strava-callback',
  );
  static const String _statePrefsKey = 'strava_oauth_state';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _initialized = false;
  bool _isLoading = false;
  bool _isConnected = false;
  String? _athleteName;
  String? _lastError;

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get athleteName => _athleteName;
  String? get lastError => _lastError;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      try {
        final initialLink = await _appLinks.getInitialLink();
        if (initialLink != null) {
          unawaited(handleUri(initialLink));
        }

        _linkSubscription = _appLinks.uriLinkStream.listen(
          (uri) => unawaited(handleUri(uri)),
          onError: (Object error, StackTrace stackTrace) {
            unawaited(
              DiagnosticsService.instance.logError(
                feature: 'strava',
                action: 'deep_link_listener',
                error: error,
                stackTrace: stackTrace,
                severity: 'warning',
              ),
            );
          },
        );
      } catch (e, stack) {
        debugPrint('StravaService.init deep link setup failed: $e');
        await DiagnosticsService.instance.logError(
          feature: 'strava',
          action: 'init',
          error: e,
          stackTrace: stack,
          severity: 'warning',
        );
      }
    }

    await refreshStatus();
  }

  Future<bool> connect() async {
    if (_clientId.isEmpty) {
      _lastError = 'Strava setup needs STRAVA_CLIENT_ID.';
      notifyListeners();
      return false;
    }

    final state = _generateState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statePrefsKey, state);

    final authUri = Uri.https('www.strava.com', '/oauth/mobile/authorize', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'approval_prompt': 'auto',
      'scope': 'read,activity:read',
      'state': state,
    });

    final opened = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      _lastError = 'Could not open Strava.';
      notifyListeners();
    }

    return opened;
  }

  Future<void> refreshStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _isConnected = false;
      _athleteName = null;
      notifyListeners();
      return;
    }

    await _invokeStatusAction('status');
  }

  Future<bool> disconnect() async {
    return _invokeStatusAction('disconnect');
  }

  Future<bool> refreshAthlete() async {
    return _invokeStatusAction('refresh');
  }

  Future<bool> handleUri(Uri uri) async {
    if (!_isStravaCallback(uri)) return false;

    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      _lastError = error == 'access_denied'
          ? 'Strava connection was cancelled.'
          : 'Strava returned an error: $error';
      notifyListeners();
      return true;
    }

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code == null || code.isEmpty) {
      _lastError = 'Strava did not return an authorization code.';
      notifyListeners();
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final expectedState = prefs.getString(_statePrefsKey);
    await prefs.remove(_statePrefsKey);

    if (expectedState == null || expectedState != state) {
      _lastError = 'Strava security check failed. Please try again.';
      notifyListeners();
      await DiagnosticsService.instance.logError(
        feature: 'strava',
        action: 'oauth_state_mismatch',
        error: 'OAuth state mismatch',
        context: {
          'has_expected_state': expectedState != null,
          'has_returned_state': state != null,
        },
        severity: 'warning',
      );
      return true;
    }

    return _exchangeCode(code);
  }

  Future<bool> _exchangeCode(String code) async {
    _setLoading(true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'strava-auth',
        body: {'action': 'exchange', 'code': code},
      );

      _applyResponse(response.data);
      _lastError = null;
      _setLoading(false);
      return _isConnected;
    } catch (e, stack) {
      await DiagnosticsService.instance.logError(
        feature: 'strava',
        action: 'exchange_code',
        error: e,
        stackTrace: stack,
      );
      _lastError = 'Could not connect Strava.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> _invokeStatusAction(String action) async {
    _setLoading(true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'strava-auth',
        body: {'action': action},
      );

      _applyResponse(response.data);
      _lastError = null;
      _setLoading(false);
      return true;
    } catch (e, stack) {
      await DiagnosticsService.instance.logError(
        feature: 'strava',
        action: action,
        error: e,
        stackTrace: stack,
        severity: action == 'status' ? 'warning' : 'error',
      );
      _lastError = 'Could not update Strava status.';
      _setLoading(false);
      return false;
    }
  }

  void _applyResponse(Object? data) {
    if (data is! Map) return;

    _isConnected = data['connected'] == true;
    final athlete = data['athlete'];
    if (athlete is Map) {
      final firstname = athlete['firstname'] as String?;
      final lastname = athlete['lastname'] as String?;
      final username = athlete['username'] as String?;
      _athleteName = [
        firstname,
        lastname,
      ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
      if (_athleteName == null || _athleteName!.isEmpty) {
        _athleteName = username;
      }
    } else if (!_isConnected) {
      _athleteName = null;
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  bool _isStravaCallback(Uri uri) {
    return uri.scheme == 'rydmatch' && uri.host == 'strava-callback';
  }

  String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
}

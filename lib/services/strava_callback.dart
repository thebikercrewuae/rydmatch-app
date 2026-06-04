class StravaCallback {
  static const String scheme = 'rydmatch';
  static const String host = 'rydmatch.com';
  static const String path = '/strava-callback';

  final String? code;
  final String? state;
  final String? error;

  const StravaCallback({
    required this.code,
    required this.state,
    required this.error,
  });

  static bool matches(Uri uri) {
    return uri.scheme == scheme && uri.host == host && uri.path == path;
  }

  static StravaCallback? tryParse(Uri uri) {
    if (!matches(uri)) return null;

    return StravaCallback(
      code: uri.queryParameters['code'],
      state: uri.queryParameters['state'],
      error: uri.queryParameters['error'],
    );
  }
}

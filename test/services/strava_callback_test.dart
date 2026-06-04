import 'package:flutter_test/flutter_test.dart';
import 'package:rydmatch/services/strava_callback.dart';

void main() {
  group('StravaCallback', () {
    test('accepts the configured callback and extracts OAuth values', () {
      final callback = StravaCallback.tryParse(
        Uri.parse(
          'rydmatch://rydmatch.com/strava-callback?code=auth-code&state=secure-state',
        ),
      );

      expect(callback, isNotNull);
      expect(callback!.code, 'auth-code');
      expect(callback.state, 'secure-state');
      expect(callback.error, isNull);
    });

    test('extracts an OAuth cancellation error', () {
      final callback = StravaCallback.tryParse(
        Uri.parse(
          'rydmatch://rydmatch.com/strava-callback?error=access_denied&state=secure-state',
        ),
      );

      expect(callback, isNotNull);
      expect(callback!.error, 'access_denied');
      expect(callback.state, 'secure-state');
      expect(callback.code, isNull);
    });

    test('rejects callbacks with the wrong scheme, host, or path', () {
      final invalidUris = [
        Uri.parse('https://rydmatch.com/strava-callback?code=one'),
        Uri.parse('rydmatch://example.com/strava-callback?code=two'),
        Uri.parse('rydmatch://rydmatch.com/other?code=three'),
      ];

      for (final uri in invalidUris) {
        expect(StravaCallback.tryParse(uri), isNull, reason: uri.toString());
      }
    });
  });
}

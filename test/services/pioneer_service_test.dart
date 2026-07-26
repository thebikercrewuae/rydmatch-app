import 'package:flutter_test/flutter_test.dart';
import 'package:rydmatch/services/pioneer_service.dart';

void main() {
  group('PioneerStatus.fromMap', () {
    test('parses a fully populated membership row', () {
      final status = PioneerStatus.fromMap({
        'user_id': '11111111-1111-1111-1111-111111111111',
        'pioneer_number': 42,
        'awarded_at': '2026-07-25T12:00:00Z',
        'early_access_enabled': true,
      });

      expect(status.userId, '11111111-1111-1111-1111-111111111111');
      expect(status.number, 42);
      expect(status.earlyAccessEnabled, isTrue);
      expect(status.awardedAt, DateTime.parse('2026-07-25T12:00:00Z'));
    });

    test('coerces numeric pioneer numbers to int', () {
      final status = PioneerStatus.fromMap({
        'user_id': 'user-1',
        'pioneer_number': 7.0,
        'awarded_at': null,
        'early_access_enabled': false,
      });

      expect(status.number, 7);
      expect(status.number, isA<int>());
      expect(status.awardedAt, isNull);
      expect(status.earlyAccessEnabled, isFalse);
    });

    test('treats a missing early access flag as disabled', () {
      final status = PioneerStatus.fromMap({
        'user_id': 'user-2',
        'pioneer_number': 1,
        'awarded_at': '2026-01-01T00:00:00Z',
      });

      expect(status.earlyAccessEnabled, isFalse);
      expect(status.number, 1);
    });

    test('tolerates an unparseable awarded_at timestamp', () {
      final status = PioneerStatus.fromMap({
        'user_id': 'user-3',
        'pioneer_number': 500,
        'awarded_at': 'not-a-date',
        'early_access_enabled': true,
      });

      expect(status.awardedAt, isNull);
      expect(status.number, 500);
    });
  });

  group('PioneerStatus bounds', () {
    test('reflects the lowest and highest member numbers', () {
      final first = PioneerStatus.fromMap({
        'user_id': 'user-first',
        'pioneer_number': 1,
        'awarded_at': '2026-07-25T00:00:00Z',
        'early_access_enabled': true,
      });
      final last = PioneerStatus.fromMap({
        'user_id': 'user-last',
        'pioneer_number': 500,
        'awarded_at': '2026-07-25T00:00:00Z',
        'early_access_enabled': true,
      });

      expect(first.number, lessThanOrEqualTo(last.number));
    });
  });
}
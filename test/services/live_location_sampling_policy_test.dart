import 'package:flutter_test/flutter_test.dart';
import 'package:rydmatch/services/live_location_sampling_policy.dart';

void main() {
  group('LiveLocationSamplingPolicy', () {
    final start = DateTime.utc(2026, 7, 2, 8);

    test('writes the first current and history samples immediately', () {
      final policy = LiveLocationSamplingPolicy();

      expect(policy.shouldWriteCurrent(start), isTrue);
      expect(policy.shouldWriteHistory(start, movedEnough: false), isTrue);
    });

    test('throttles current location writes to the configured interval', () {
      final policy = LiveLocationSamplingPolicy();
      policy.markCurrentWritten(start);

      expect(
        policy.shouldWriteCurrent(start.add(const Duration(seconds: 14))),
        isFalse,
      );
      expect(
        policy.shouldWriteCurrent(start.add(const Duration(seconds: 15))),
        isTrue,
      );
    });

    test('requires time and movement before adding history samples', () {
      final policy = LiveLocationSamplingPolicy();
      policy.markHistoryWritten(start);

      expect(
        policy.shouldWriteHistory(
          start.add(const Duration(seconds: 59)),
          movedEnough: true,
        ),
        isFalse,
      );
      expect(
        policy.shouldWriteHistory(
          start.add(const Duration(seconds: 60)),
          movedEnough: false,
        ),
        isFalse,
      );
      expect(
        policy.shouldWriteHistory(
          start.add(const Duration(seconds: 60)),
          movedEnough: true,
        ),
        isTrue,
      );
    });

    test('reset makes both streams immediately writable again', () {
      final policy = LiveLocationSamplingPolicy();
      policy.markCurrentWritten(start);
      policy.markHistoryWritten(start);
      policy.reset();

      expect(policy.shouldWriteCurrent(start), isTrue);
      expect(policy.shouldWriteHistory(start, movedEnough: false), isTrue);
    });
  });
}

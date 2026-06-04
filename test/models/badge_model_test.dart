import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rydmatch/models/badge_model.dart';

BadgeModel buildBadge({
  bool isEarned = false,
  int? progressCurrent,
  int? progressTarget,
}) {
  return BadgeModel(
    id: 'test_badge',
    name: 'Test Badge',
    description: 'A badge used by automated tests.',
    unlockCriteria: 'Pass the test',
    category: BadgeCategory.profile,
    icon: Icons.check,
    color: Colors.green,
    isEarned: isEarned,
    progressCurrent: progressCurrent,
    progressTarget: progressTarget,
  );
}

void main() {
  group('BadgeModel progress', () {
    test('returns zero when progress is unavailable', () {
      expect(buildBadge().progressRatio, 0);
      expect(
        buildBadge(progressCurrent: 1, progressTarget: 0).progressRatio,
        0,
      );
    });

    test('calculates progress and clamps it to one', () {
      expect(
        buildBadge(progressCurrent: 5, progressTarget: 10).progressRatio,
        0.5,
      );
      expect(
        buildBadge(progressCurrent: 15, progressTarget: 10).progressRatio,
        1,
      );
    });

    test('earned badges always report complete progress', () {
      expect(buildBadge(isEarned: true).progressRatio, 1);
    });

    test('copyWith preserves identity and updates progress', () {
      final original = buildBadge(progressCurrent: 2, progressTarget: 10);
      final updated = original.copyWith(progressCurrent: 7, isEarned: true);

      expect(updated.id, original.id);
      expect(updated.progressCurrent, 7);
      expect(updated.progressTarget, 10);
      expect(updated.isEarned, isTrue);
    });
  });
}

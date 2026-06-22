import 'package:flutter_test/flutter_test.dart';
import 'package:rydmatch/services/public_content_safety_service.dart';

void main() {
  test('allows normal ride captions', () {
    final result = PublicContentSafetyService.assessText(
      'Great morning ride through the mountains.',
    );

    expect(result.allowed, isTrue);
  });

  test('blocks obvious graphic real-world violence wording', () {
    final result = PublicContentSafetyService.assessText(
      'Posting a graphic injury from the crash.',
    );

    expect(result.allowed, isFalse);
    expect(result.reason, PublicContentSafetyService.blockedMessage);
  });
}

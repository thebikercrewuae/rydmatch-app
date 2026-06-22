import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rydmatch/services/photo_safety_service.dart';

Uint8List _solidImageBytes(int r, int g, int b) {
  final image = img.Image(width: 80, height: 80);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  test('allows low-skin bike-like images', () async {
    final result = await PhotoSafetyService.assessBytes(
      _solidImageBytes(20, 80, 35),
    );

    expect(result.allowed, isTrue);
  });

  test('blocks images dominated by likely exposed skin tones', () async {
    final result = await PhotoSafetyService.assessBytes(
      _solidImageBytes(205, 145, 105),
    );

    expect(result.allowed, isFalse);
    expect(result.reason, PhotoSafetyService.blockedMessage);
  });

  test('blocks images dominated by blood-like red tones', () async {
    final result = await PhotoSafetyService.assessBytes(
      _solidImageBytes(125, 20, 20),
    );

    expect(result.allowed, isFalse);
    expect(result.reason, PhotoSafetyService.graphicViolenceBlockedMessage);
  });
}

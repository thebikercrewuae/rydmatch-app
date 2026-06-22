import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class PhotoSafetyResult {
  final bool allowed;
  final double skinRatio;
  final double centralSkinRatio;
  final double lowerSkinRatio;
  final double bloodRedRatio;
  final double centralBloodRedRatio;
  final String? reason;

  const PhotoSafetyResult._({
    required this.allowed,
    required this.skinRatio,
    required this.centralSkinRatio,
    required this.lowerSkinRatio,
    required this.bloodRedRatio,
    required this.centralBloodRedRatio,
    this.reason,
  });

  factory PhotoSafetyResult.allowed({
    required double skinRatio,
    required double centralSkinRatio,
    required double lowerSkinRatio,
    double bloodRedRatio = 0,
    double centralBloodRedRatio = 0,
  }) {
    return PhotoSafetyResult._(
      allowed: true,
      skinRatio: skinRatio,
      centralSkinRatio: centralSkinRatio,
      lowerSkinRatio: lowerSkinRatio,
      bloodRedRatio: bloodRedRatio,
      centralBloodRedRatio: centralBloodRedRatio,
    );
  }

  factory PhotoSafetyResult.blocked({
    required double skinRatio,
    required double centralSkinRatio,
    required double lowerSkinRatio,
    double bloodRedRatio = 0,
    double centralBloodRedRatio = 0,
    required String reason,
  }) {
    return PhotoSafetyResult._(
      allowed: false,
      skinRatio: skinRatio,
      centralSkinRatio: centralSkinRatio,
      lowerSkinRatio: lowerSkinRatio,
      bloodRedRatio: bloodRedRatio,
      centralBloodRedRatio: centralBloodRedRatio,
      reason: reason,
    );
  }
}

class PhotoSafetyService {
  static const String blockedMessage =
      'This photo could not be accepted. Please choose a clear, appropriate rider or bike photo.';
  static const String graphicViolenceBlockedMessage =
      'This photo could not be accepted because it may show graphic real-world violence. Please choose a safe rider or bike photo.';

  static Future<PhotoSafetyResult> assessBytes(Uint8List bytes) {
    return compute(_assessBytes, bytes);
  }
}

PhotoSafetyResult _assessBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width < 24 || decoded.height < 24) {
    return PhotoSafetyResult.allowed(
      skinRatio: 0,
      centralSkinRatio: 0,
      lowerSkinRatio: 0,
      bloodRedRatio: 0,
      centralBloodRedRatio: 0,
    );
  }

  final image = decoded.width > 180
      ? img.copyResize(
          decoded,
          width: 180,
          interpolation: img.Interpolation.average,
        )
      : decoded;

  var total = 0;
  var skin = 0;
  var centralTotal = 0;
  var centralSkin = 0;
  var lowerTotal = 0;
  var lowerSkin = 0;
  var bloodRed = 0;
  var centralBloodRed = 0;

  final centralLeft = (image.width * 0.18).round();
  final centralRight = (image.width * 0.82).round();
  final centralTop = (image.height * 0.18).round();
  final centralBottom = (image.height * 0.88).round();
  final lowerTop = (image.height * 0.42).round();

  for (var y = 0; y < image.height; y += 2) {
    for (var x = 0; x < image.width; x += 2) {
      final pixel = image.getPixel(x, y);
      final isSkin = _isLikelySkinPixel(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );

      total++;
      if (isSkin) skin++;
      final isBloodRed = _isLikelyBloodRedPixel(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      if (isBloodRed) bloodRed++;

      final isCentral =
          x >= centralLeft &&
          x <= centralRight &&
          y >= centralTop &&
          y <= centralBottom;
      if (isCentral) {
        centralTotal++;
        if (isSkin) centralSkin++;
        if (isBloodRed) centralBloodRed++;
      }

      if (y >= lowerTop) {
        lowerTotal++;
        if (isSkin) lowerSkin++;
      }
    }
  }

  final skinRatio = total == 0 ? 0.0 : skin / total;
  final centralSkinRatio = centralTotal == 0 ? 0.0 : centralSkin / centralTotal;
  final lowerSkinRatio = lowerTotal == 0 ? 0.0 : lowerSkin / lowerTotal;
  final bloodRedRatio = total == 0 ? 0.0 : bloodRed / total;
  final centralBloodRedRatio = centralTotal == 0
      ? 0.0
      : centralBloodRed / centralTotal;

  final highOverallSkin = skinRatio >= 0.58 && centralSkinRatio >= 0.46;
  final highBodySkin =
      skinRatio >= 0.44 && centralSkinRatio >= 0.42 && lowerSkinRatio >= 0.38;
  final veryHighCentralSkin =
      centralSkinRatio >= 0.66 && lowerSkinRatio >= 0.32;

  if (highOverallSkin || highBodySkin || veryHighCentralSkin) {
    return PhotoSafetyResult.blocked(
      skinRatio: skinRatio,
      centralSkinRatio: centralSkinRatio,
      lowerSkinRatio: lowerSkinRatio,
      bloodRedRatio: bloodRedRatio,
      centralBloodRedRatio: centralBloodRedRatio,
      reason: PhotoSafetyService.blockedMessage,
    );
  }

  final likelyGraphicViolence =
      bloodRedRatio >= 0.16 ||
      (bloodRedRatio >= 0.08 && centralBloodRedRatio >= 0.1);

  if (likelyGraphicViolence) {
    return PhotoSafetyResult.blocked(
      skinRatio: skinRatio,
      centralSkinRatio: centralSkinRatio,
      lowerSkinRatio: lowerSkinRatio,
      bloodRedRatio: bloodRedRatio,
      centralBloodRedRatio: centralBloodRedRatio,
      reason: PhotoSafetyService.graphicViolenceBlockedMessage,
    );
  }

  return PhotoSafetyResult.allowed(
    skinRatio: skinRatio,
    centralSkinRatio: centralSkinRatio,
    lowerSkinRatio: lowerSkinRatio,
    bloodRedRatio: bloodRedRatio,
    centralBloodRedRatio: centralBloodRedRatio,
  );
}

bool _isLikelySkinPixel(int r, int g, int b) {
  if (r < 45 || g < 25 || b < 15) return false;
  if (r <= g || r <= b) return false;

  final maxChannel = [r, g, b].reduce((a, c) => a > c ? a : c);
  final minChannel = [r, g, b].reduce((a, c) => a < c ? a : c);
  final spread = maxChannel - minChannel;
  if (spread < 15) return false;

  final y = 0.299 * r + 0.587 * g + 0.114 * b;
  final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
  final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;

  final ycbcrSkin = y > 50 && cb >= 77 && cb <= 135 && cr >= 133 && cr <= 180;
  final rgbSkin =
      r > 95 && g > 40 && b > 20 && spread > 15 && (r - g).abs() > 15;

  return ycbcrSkin && rgbSkin;
}

bool _isLikelyBloodRedPixel(int r, int g, int b) {
  final maxChannel = [r, g, b].reduce((a, c) => a > c ? a : c);
  final minChannel = [r, g, b].reduce((a, c) => a < c ? a : c);
  final saturationSpread = maxChannel - minChannel;

  if (r < 95 || saturationSpread < 55) return false;
  if (g > 95 || b > 95) return false;
  if (r < g * 1.45 || r < b * 1.45) return false;

  final brightness = (r + g + b) / 3;
  return brightness >= 35 && brightness <= 135;
}

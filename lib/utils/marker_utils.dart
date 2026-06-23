import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerUtils {
  MarkerUtils._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Returns a rider avatar marker with a colored border and map pointer.
  static Future<BitmapDescriptor> getMarker({
    required String avatarUrl,
    Color borderColor = Colors.blue,
    double size = 80,
    double borderWidth = 4,
    double pointerHeight = 16,
  }) async {
    final cacheKey =
        '${avatarUrl.trim()}_${borderColor.toARGB32()}_${size.toStringAsFixed(0)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final avatar = await _loadNetworkImage(avatarUrl);
      if (avatar == null) {
        return _fallbackMarker(borderColor, cacheKey);
      }

      final bytes = await _drawAvatarMarker(
        avatar: avatar,
        borderColor: borderColor,
        size: size,
        borderWidth: borderWidth,
        pointerHeight: pointerHeight,
      );

      final descriptor = BitmapDescriptor.bytes(
        bytes,
        width: size,
        height: size + pointerHeight,
      );
      _cache[cacheKey] = descriptor;
      return descriptor;
    } catch (_) {
      return _fallbackMarker(borderColor, cacheKey);
    }
  }

  static Future<ui.Image?> _loadNetworkImage(String avatarUrl) async {
    final uri = Uri.tryParse(avatarUrl.trim());
    if (uri == null || !uri.hasScheme) return null;

    final completer = Completer<ui.Image?>();
    final stream = NetworkImage(avatarUrl).resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (imageInfo, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(imageInfo.image);
        }
      },
      onError: (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    stream.addListener(listener);

    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        stream.removeListener(listener);
        return null;
      },
    );
  }

  static Future<Uint8List> _drawAvatarMarker({
    required ui.Image avatar,
    required Color borderColor,
    required double size,
    required double borderWidth,
    required double pointerHeight,
  }) async {
    final imageSize = (size * 2).round();
    final pointerSize = (pointerHeight * 2).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final outputSize = Size(
      imageSize.toDouble(),
      (imageSize + pointerSize).toDouble(),
    );
    final center = Offset(outputSize.width / 2, imageSize / 2);
    final radius = imageSize / 2;
    final innerRadius = radius - borderWidth * 2;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center.translate(0, 5), radius - 3, shadowPaint);

    final pointerPath = Path()
      ..moveTo(center.dx - pointerSize * 0.28, imageSize - borderWidth * 1.4)
      ..lineTo(center.dx + pointerSize * 0.28, imageSize - borderWidth * 1.4)
      ..lineTo(center.dx, imageSize + pointerSize * 0.5)
      ..close();
    canvas.drawPath(pointerPath, Paint()..color = borderColor);

    canvas.drawCircle(center, radius - 2, Paint()..color = borderColor);
    canvas.drawCircle(
      center,
      innerRadius + borderWidth,
      Paint()..color = Colors.white,
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius)),
    );

    final src = _coverSourceRect(avatar);
    final dst = Rect.fromCircle(center: center, radius: innerRadius);
    canvas.drawImageRect(avatar, src, dst, Paint()..isAntiAlias = true);
    canvas.restore();

    canvas.drawCircle(
      center,
      innerRadius + borderWidth / 2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth / 2,
    );

    final image = await recorder.endRecording().toImage(
      outputSize.width.round(),
      outputSize.height.round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Rect _coverSourceRect(ui.Image image) {
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final sourceAspect = width / height;

    if (sourceAspect > 1) {
      final croppedWidth = height;
      final left = (width - croppedWidth) / 2;
      return Rect.fromLTWH(left, 0, croppedWidth, height);
    }

    final croppedHeight = width;
    final top = math.max(0.0, (height - croppedHeight) / 2);
    return Rect.fromLTWH(0, top, width, croppedHeight);
  }

  static BitmapDescriptor _fallbackMarker(Color borderColor, String cacheKey) {
    final descriptor = BitmapDescriptor.defaultMarkerWithHue(
      _colorToHue(borderColor),
    );
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Convert a Color to the nearest BitmapDescriptor hue value.
  static double _colorToHue(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl.hue.clamp(0.0, 360.0);
  }

  static void clearCache() => _cache.clear();
}

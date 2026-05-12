import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerUtils {
  MarkerUtils._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Returns a colored [BitmapDescriptor] marker.
  /// On web, custom image markers aren't supported so we use colored default markers.
  static Future<BitmapDescriptor> getMarker({
    required String avatarUrl,
    Color borderColor = Colors.blue,
    double size = 80,
    double borderWidth = 4,
    double pointerHeight = 16,
  }) async {
    final cacheKey = '${borderColor.value}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Map border color to nearest hue for default marker
      final hue = _colorToHue(borderColor);
      final descriptor = BitmapDescriptor.defaultMarkerWithHue(hue);
      _cache[cacheKey] = descriptor;
      return descriptor;
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  /// Convert a Color to the nearest BitmapDescriptor hue value
  static double _colorToHue(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl.hue.clamp(0.0, 360.0);
  }

  static void clearCache() => _cache.clear();
}

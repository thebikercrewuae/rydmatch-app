class DiscoveryDistanceFilter {
  static const double _kilometresPerMile = 1.609344;
  static const double _metresPerMile = 1609.344;

  const DiscoveryDistanceFilter._();

  static double radiusMetres({required double radius, required bool isMetric}) {
    if (!radius.isFinite || radius <= 0) return 0;
    return isMetric ? radius * 1000 : radius * _metresPerMile;
  }

  static bool includes({
    required bool hasViewerLocation,
    required double? distanceMiles,
    required double radius,
    required bool isMetric,
  }) {
    if (!hasViewerLocation ||
        distanceMiles == null ||
        !distanceMiles.isFinite ||
        radius <= 0) {
      return false;
    }

    final limitMiles = isMetric ? radius / _kilometresPerMile : radius;
    return distanceMiles <= limitMiles;
  }
}

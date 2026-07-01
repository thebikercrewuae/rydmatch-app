class DiscoveryDistanceFilter {
  static const double _kilometresPerMile = 1.609344;

  const DiscoveryDistanceFilter._();

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

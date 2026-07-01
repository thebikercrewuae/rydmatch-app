import 'package:flutter_test/flutter_test.dart';
import 'package:rydmatch/services/discovery_distance_filter.dart';

void main() {
  group('DiscoveryDistanceFilter', () {
    test('enforces the maximum 500 kilometre radius', () {
      expect(
        DiscoveryDistanceFilter.includes(
          hasViewerLocation: true,
          distanceMiles: 300,
          radius: 500,
          isMetric: true,
        ),
        isTrue,
      );
      expect(
        DiscoveryDistanceFilter.includes(
          hasViewerLocation: true,
          distanceMiles: 400,
          radius: 500,
          isMetric: true,
        ),
        isFalse,
      );
    });

    test('uses miles directly for imperial radius', () {
      expect(
        DiscoveryDistanceFilter.includes(
          hasViewerLocation: true,
          distanceMiles: 100,
          radius: 100,
          isMetric: false,
        ),
        isTrue,
      );
      expect(
        DiscoveryDistanceFilter.includes(
          hasViewerLocation: true,
          distanceMiles: 100.1,
          radius: 100,
          isMetric: false,
        ),
        isFalse,
      );
    });

    test('rejects profiles when distance cannot be verified', () {
      expect(
        DiscoveryDistanceFilter.includes(
          hasViewerLocation: false,
          distanceMiles: 10,
          radius: 500,
          isMetric: true,
        ),
        isFalse,
      );
      expect(
        DiscoveryDistanceFilter.includes(
          hasViewerLocation: true,
          distanceMiles: null,
          radius: 500,
          isMetric: true,
        ),
        isFalse,
      );
    });
  });
}

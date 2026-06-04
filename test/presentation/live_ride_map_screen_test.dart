import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rydmatch/presentation/live_ride/live_ride_map_screen.dart';

void main() {
  test('live ride screen accepts the planned route from the group flow', () {
    const routePoints = [LatLng(25.2048, 55.2708), LatLng(25.1181, 55.2006)];

    const screen = LiveRideMapScreen(
      sessionId: 'session-id',
      isCreator: false,
      initialRouteName: 'Dubai to Al Qudra',
      initialRoutePoints: routePoints,
    );

    expect(screen.initialRouteName, 'Dubai to Al Qudra');
    expect(screen.initialRoutePoints, routePoints);
    expect(screen.initialRoutePoints.length, 2);
  });
}

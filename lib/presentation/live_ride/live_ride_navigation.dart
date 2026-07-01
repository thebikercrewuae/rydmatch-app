import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/live_ride_service.dart';
import '../../widgets/toast_widget.dart';
import 'live_ride_map_screen.dart';

class LiveRideNavigation {
  const LiveRideNavigation._();

  static Future<bool> open(
    BuildContext context, {
    required String sessionId,
    bool isCreator = false,
    bool useRootNavigator = false,
    String initialRouteName = '',
    List<LatLng> initialRoutePoints = const [],
    List<LatLng> initialWaypointPoints = const [],
  }) async {
    final trimmedSessionId = sessionId.trim();
    if (trimmedSessionId.isEmpty) {
      AppToast.show(
        context,
        message: 'Live ride session is missing.',
        type: ToastType.error,
      );
      return false;
    }

    if (LiveRideService.instance.currentSessionId != trimmedSessionId) {
      final joined = await LiveRideService.instance.joinRide(trimmedSessionId);
      if (!context.mounted) return false;

      if (!joined) {
        AppToast.show(
          context,
          message:
              LiveRideService.instance.lastError ?? 'Failed to join live ride',
          type: ToastType.error,
        );
        return false;
      }
    }

    if (!context.mounted) return false;

    await Navigator.of(context, rootNavigator: useRootNavigator).push(
      MaterialPageRoute(
        builder: (_) => LiveRideMapScreen(
          sessionId: trimmedSessionId,
          isCreator: isCreator,
          initialRouteName: initialRouteName,
          initialRoutePoints: initialRoutePoints,
          initialWaypointPoints: initialWaypointPoints,
        ),
      ),
    );
    return true;
  }
}

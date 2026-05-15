import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/premium_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/toast_widget.dart';
import '../ride_groups_screen/widgets/create_group_modal_widget.dart';
import './widgets/route_location_field_widget.dart';
import './widgets/route_summary_card_widget.dart';
import './widgets/route_type_selector_widget.dart';
import './widgets/route_weather_widget.dart';
import './widgets/waypoint_list_widget.dart';
import './widgets/weather_premium_gate_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/app_logo_widget.dart';
import '../ride_groups_screen/ride_groups_screen.dart';


class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  GoogleMapController? _mapController;

  final List<String> _waypoints = [];
  final List<LatLng> _waypointPoints = [];
  String _routeType = 'fastest';
  bool _isSaving = false;
  bool _isMetric = true;
  bool _isGeocodingStart = false;
  bool _isGeocodingDest = false;
  bool _isFetchingRoute = false;

  // Map state
  LatLng _startPoint = const LatLng(20.0, 0.0);
  LatLng _endPoint = const LatLng(20.5, 0.5);
  bool _routeSet = false;
  bool _startSet = false;

  // Route stats
  double _distanceKm = 0;
  int _estimatedMinutes = 0;

  // Directions API data
  List<LatLng> _routePolylinePoints = [];
  List<Map<String, dynamic>> _navigationSteps = [];

  // Navigation mode
  bool _isNavigating = false;
  int _currentStepIndex = 0;
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  Marker? _userLocationMarker;

  // Weather
  String? _weatherLocation;
  bool _isPremium = false;
  String _rideMode = 'motorcycle';

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  static const String _mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  bool get _isBicycleMode => _rideMode == 'bicycle';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPremium();
  }

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    _mapController?.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  void _showNavigationOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Navigation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              if (!_isBicycleMode)
                ListTile(
                  leading: const Icon(Icons.navigation, color: Colors.blue),
                  title: const Text('Open in Waze'),
                  subtitle: const Text('Real-time traffic & hazard alerts'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final opened = await NavigationLauncher.launchWaze(
                      destination: _endPoint,
                    );
                    if (!opened && mounted) {
                      AppToast.show(
                        context,
                        message: 'Could not open Waze on this device.',
                        type: ToastType.error,
                      );

                      await NavigationLauncher.launchGoogleMaps(
                        destination: _endPoint,
                        origin: _startPoint,
                        waypoints: _waypointPoints.isNotEmpty
                            ? _waypointPoints
                            : null,
                      );
                    }
                  },
                ),
              ListTile(
                leading: Icon(
                  _isBicycleMode
                      ? Icons.directions_bike_rounded
                      : Icons.map,
                  color: Colors.green,
                ),
                title: const Text('Open in Google Maps'),
                subtitle: Text(
                  _isBicycleMode
                      ? 'Cycling route with waypoints'
                      : 'Full route with waypoints',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await NavigationLauncher.launchGoogleMaps(
                    destination: _endPoint,
                    origin: _startPoint,
                    waypoints: _waypointPoints.isNotEmpty
                        ? _waypointPoints
                        : null,
                    travelMode: _isBicycleMode ? 'bicycling' : 'driving',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.explore, color: Color(0xFF1B365D)),
                title: const Text('Navigate In-App'),
                subtitle: const Text('Turn-by-turn within RydMatch'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startNavigation();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = await ProfileService.loadProfile();
      setState(() {
        _isMetric = prefs.getBool('isMetric') ?? true;
        _rideMode = profile['rideMode'] as String? ?? 'motorcycle';
      });
    } catch (_) {}
  }

  Future<void> _checkPremium() async {
    await PremiumService().init();
    if (mounted) {
      setState(() {
        _isPremium = PremiumService().isPremium;
      });
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'address': address.trim(), 'key': _mapsApiKey},
      );
      final data = response.data;
      if (data['status'] == 'OK' &&
          data['results'] != null &&
          (data['results'] as List).isNotEmpty) {
        final loc = data['results'][0]['geometry']['location'];
        return LatLng(loc['lat'] as double, loc['lng'] as double);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _reverseGeocode(LatLng point) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${point.latitude},${point.longitude}',
          'key': _mapsApiKey,
        },
      );
      final data = response.data;
      if (data['status'] == 'OK' &&
          data['results'] != null &&
          (data['results'] as List).isNotEmpty) {
        return data['results'][0]['formatted_address'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Decode a Google Maps encoded polyline string into a list of LatLng points
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Strip HTML tags from direction instruction text
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Fetch real route from Google Directions API
  Future<void> _fetchDirectionsRoute() async {
    final originText = _startController.text.trim();
    final destText = _destinationController.text.trim();
    if (originText.isEmpty || destText.isEmpty) return;

    setState(() => _isFetchingRoute = true);

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 15);

      String waypointsParam = '';
      if (_waypoints.isNotEmpty) {
        waypointsParam = _waypoints.join('|');
      }

      final queryParams = <String, String>{
        'origin': originText,
        'destination': destText,
        'mode': _isBicycleMode ? 'bicycling' : 'driving',
        'alternatives': 'false',
        'key': _mapsApiKey,
      };

      if (waypointsParam.isNotEmpty) {
        queryParams['waypoints'] = waypointsParam;
      }

      if (_routeType == 'avoid_motorways') {
        queryParams['avoid'] = 'highways';
      } else if (_routeType == 'scenic') {
        queryParams['avoid'] = 'highways|tolls';
      }

      // Build the Google API URL
      final String requestUrl;
      if (kIsWeb) {
        final supabaseUrl = 'https://tbdmucmrsftbrgvszvxa.supabase.co';

        requestUrl =
            '$supabaseUrl/functions/v1/directions-proxy?${Uri(queryParameters: queryParams).query}';
      } else {
        requestUrl = Uri.https(
          'maps.googleapis.com',
          '/maps/api/directions/json',
          queryParams,
        ).toString();
      }

      final response = await dio.get(
        requestUrl,
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (kIsWeb)
              'Authorization':
                  'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiZG11Y21yc2Z0YnJndnN6dnhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4OTgxMTAsImV4cCI6MjA4ODQ3NDExMH0.CSJu5W3MCIM79lSydCgTkVDwLTcgkzW5YTOrDrD0fkg',
            if (kIsWeb)
              'apikey':
                  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiZG11Y21yc2Z0YnJndnN6dnhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4OTgxMTAsImV4cCI6MjA4ODQ3NDExMH0.CSJu5W3MCIM79lSydCgTkVDwLTcgkzW5YTOrDrD0fkg',
          },
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('[Directions] Raw type: ${response.data.runtimeType}');
      print(
        '[Directions] Raw preview: ${response.data.toString().substring(0, response.data.toString().length.clamp(0, 300))}',
      );

      final Map<String, dynamic> data;
      if (response.data is Map<String, dynamic>) {
        data = response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else {
        throw Exception('Unexpected response format');
      }
      final status = data['status'] as String? ?? 'UNKNOWN';

      debugPrint('[Directions API] Status: $status');

      if (status == 'OK' &&
          data['routes'] != null &&
          (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0] as Map<String, dynamic>;
        final overviewPolyline = route['overview_polyline']['points'] as String;
        final decodedPoints = _decodePolyline(overviewPolyline);

        debugPrint('[Directions API] Decoded ${decodedPoints.length} points');

        final legs = route['legs'] as List;
        if (legs.isNotEmpty) {
          final firstLeg = legs.first as Map<String, dynamic>;
          final lastLeg = legs.last as Map<String, dynamic>;

          final startLoc = firstLeg['start_location'] as Map<String, dynamic>;
          final endLoc = lastLeg['end_location'] as Map<String, dynamic>;

          _startPoint = LatLng(
            (startLoc['lat'] as num).toDouble(),
            (startLoc['lng'] as num).toDouble(),
          );
          _endPoint = LatLng(
            (endLoc['lat'] as num).toDouble(),
            (endLoc['lng'] as num).toDouble(),
          );
          _startSet = true;
        }

        double totalDistanceM = 0;
        int totalDurationSec = 0;
        final List<Map<String, dynamic>> steps = [];

        for (final legDyn in legs) {
          final leg = legDyn as Map<String, dynamic>;
          totalDistanceM += (leg['distance']['value'] as num).toDouble();
          totalDurationSec += (leg['duration']['value'] as num).toInt();

          for (final stepDyn in leg['steps'] as List) {
            final step = stepDyn as Map<String, dynamic>;
            final stepPolyline = _decodePolyline(
              step['polyline']['points'] as String,
            );
            steps.add({
              'instruction': _stripHtml(step['html_instructions'] as String),
              'distance': step['distance']['text'] as String,
              'duration': step['duration']['text'] as String,
              'maneuver': step['maneuver'] as String? ?? '',
              'startLocation': LatLng(
                (step['start_location']['lat'] as num).toDouble(),
                (step['start_location']['lng'] as num).toDouble(),
              ),
              'endLocation': LatLng(
                (step['end_location']['lat'] as num).toDouble(),
                (step['end_location']['lng'] as num).toDouble(),
              ),
              'polylinePoints': stepPolyline,
            });
          }
        }

        if (mounted) {
          setState(() {
            _routePolylinePoints = decodedPoints;
            _navigationSteps = steps;
            _routeSet = true;
            _distanceKm = totalDistanceM / 1000.0;
            _estimatedMinutes = (totalDurationSec / 60).round().clamp(1, 9999);
            _weatherLocation = destText;
            _isFetchingRoute = false;
          });
          _rebuildMapOverlays();

          if (decodedPoints.isNotEmpty) {
            _fitCameraToRoute(decodedPoints);
          }
        }
      } else {
        debugPrint('[Directions API] Non-OK: $status');
        if (mounted) {
          setState(() => _isFetchingRoute = false);
          _updateRouteFallback();
          AppToast.show(
            context,
            message: 'Route error: $status. Showing estimated path.',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      debugPrint('[Directions API] Exception: $e');
      print('[Directions API] FULL ERROR: $e');

      if (mounted) {
        setState(() => _isFetchingRoute = false);
        _updateRouteFallback();
        AppToast.show(
          context,
          message: 'Route fetch failed. Showing estimated path.',
          type: ToastType.error,
        );
      }
    }
  }

  void _fitCameraToRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          60,
        ),
      );
    } catch (_) {}
  }

  Future<void> _useCurrentLocationForStart() async {
    if (kIsWeb) {
      AppToast.show(
        context,
        message: 'GPS not available in web preview. Type your start location.',
        type: ToastType.error,
      );
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppToast.show(
            context,
            message: 'Location services are disabled.',
            type: ToastType.error,
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppToast.show(
              context,
              message: 'Location permission denied.',
              type: ToastType.error,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppToast.show(
            context,
            message: 'Location permission permanently denied.',
            type: ToastType.error,
          );
        }
        return;
      }

      setState(() => _isGeocodingStart = true);

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);
      final address = await _reverseGeocode(latLng);

      if (mounted) {
        setState(() {
          _startPoint = latLng;
          _startSet = true;
          _startController.text =
              address ??
              '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
          _isGeocodingStart = false;
        });
        _rebuildMapOverlays();
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 13));
        _updateRoute();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeocodingStart = false);
        AppToast.show(
          context,
          message: 'Could not get current location.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _geocodeStartAddress() async {
    final text = _startController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isGeocodingStart = true);
    final latLng = await _geocodeAddress(text);
    if (mounted) {
      setState(() => _isGeocodingStart = false);
      if (latLng != null) {
        setState(() {
          _startPoint = latLng;
          _startSet = true;
        });
        _rebuildMapOverlays();
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 13));
        _updateRoute();
      } else {
        AppToast.show(
          context,
          message: 'Location not found. Try a different search.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _geocodeDestAddress() async {
    final text = _destinationController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isGeocodingDest = true);
    final latLng = await _geocodeAddress(text);
    if (mounted) {
      setState(() => _isGeocodingDest = false);
      if (latLng != null) {
        setState(() {
          _endPoint = latLng;
          _weatherLocation = text;
        });
        _updateRoute();
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 13));
      } else {
        AppToast.show(
          context,
          message: 'Destination not found. Try a different search.',
          type: ToastType.error,
        );
      }
    }
  }

  void _updateRoute() {
    if (_startController.text.isNotEmpty &&
        _destinationController.text.isNotEmpty) {
      // Fetch real directions from Google
      _fetchDirectionsRoute();
    }
  }

  /// Fallback straight-line route estimate when Directions API fails
  void _updateRouteFallback() {
    final latDiff = (_endPoint.latitude - _startPoint.latitude).abs();
    final lngDiff = (_endPoint.longitude - _startPoint.longitude).abs();
    final approxKm = (latDiff + lngDiff) * 111.0;

    double multiplier = 1.0;
    if (_routeType == 'scenic') multiplier = 1.4;
    if (_routeType == 'avoid_motorways') multiplier = 1.25;

    setState(() {
      _routeSet = true;
      _distanceKm = approxKm * multiplier;
      final fallbackSpeedKmh = _isBicycleMode ? 22.0 : 60.0;
      _estimatedMinutes = (_distanceKm / fallbackSpeedKmh * 60)
          .round()
          .clamp(5, 999);
      _weatherLocation = _destinationController.text.trim();
      _routePolylinePoints = [_startPoint, ..._waypointPoints, _endPoint];
    });

    _rebuildMapOverlays();

    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _startPoint.latitude < _endPoint.latitude
              ? _startPoint.latitude
              : _endPoint.latitude,
          _startPoint.longitude < _endPoint.longitude
              ? _startPoint.longitude
              : _endPoint.longitude,
        ),
        northeast: LatLng(
          _startPoint.latitude > _endPoint.latitude
              ? _startPoint.latitude
              : _endPoint.latitude,
          _startPoint.longitude > _endPoint.longitude
              ? _startPoint.longitude
              : _endPoint.longitude,
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (_) {}
  }

  void _rebuildMapOverlays() {
    final newMarkers = <Marker>{};

    if (_startSet || _startController.text.isNotEmpty) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: _startPoint,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: 'Start',
            snippet: _startController.text,
          ),
        ),
      );
    }

    for (int i = 0; i < _waypointPoints.length; i++) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: _waypointPoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}',
            snippet: _waypoints.length > i ? _waypoints[i] : '',
          ),
        ),
      );
    }

    if (_routeSet) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: _endPoint,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _destinationController.text,
          ),
        ),
      );
    }

    // Add live user location marker during navigation
    if (_isNavigating && _currentPosition != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'You are here'),
          zIndex: 10,
        ),
      );
    }

    final newPolylines = <Polyline>{};
    final routePoints = _routePolylinePoints.isNotEmpty
        ? _routePolylinePoints
        : (_routeSet
              ? [_startPoint, ..._waypointPoints, _endPoint]
              : <LatLng>[]);

    if (routePoints.length >= 2) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: const Color(0xFF1B365D),
          width: 6,
          patterns: [],
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
    });
  }

  void _onMapTap(LatLng point) async {
    if (_isNavigating) return;

    if (!_startSet && _startController.text.isEmpty) {
      setState(() {
        _startPoint = point;
        _startSet = true;
        _startController.text =
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      });
      _rebuildMapOverlays();
      final address = await _reverseGeocode(point);
      if (address != null && mounted) {
        setState(() {
          _startController.text = address;
        });
        _rebuildMapOverlays();
      }
    } else if (!_routeSet && _destinationController.text.isEmpty) {
      setState(() {
        _endPoint = point;
        _destinationController.text =
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      });
      _updateRoute();
      final address = await _reverseGeocode(point);
      if (address != null && mounted) {
        setState(() {
          _destinationController.text = address;
          _weatherLocation = address;
        });
        _rebuildMapOverlays();
      }
    } else if (_routeSet && _waypoints.length < 5) {
      final wpLabel =
          '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      setState(() {
        _waypoints.add(wpLabel);
        _waypointPoints.add(point);
      });
      _rebuildMapOverlays();
      AppToast.show(
        context,
        message: 'Waypoint ${_waypoints.length} added',
        type: ToastType.success,
      );

      final address = await _reverseGeocode(point);
      if (address != null && mounted) {
        setState(() {
          _waypoints[_waypoints.length - 1] = address;
        });
        _rebuildMapOverlays();
      }

      _updateRoute();
    }
  }

  // ─── Navigation Mode ────────────────────────────────────────────────────────

  /// Returns the maneuver icon for a given maneuver string
  IconData _maneuverIcon(String maneuver) {
    switch (maneuver) {
      case 'turn-left':
      case 'sharp-left':
      case 'slight-left':
        return Icons.turn_left_rounded;
      case 'turn-right':
      case 'sharp-right':
      case 'slight-right':
        return Icons.turn_right_rounded;
      case 'uturn-left':
      case 'uturn-right':
        return Icons.u_turn_left_rounded;
      case 'roundabout-left':
      case 'roundabout-right':
        return Icons.roundabout_left_rounded;
      case 'merge':
        return Icons.merge_rounded;
      case 'fork-left':
        return Icons.fork_left_rounded;
      case 'fork-right':
        return Icons.fork_right_rounded;
      case 'ramp-left':
      case 'ramp-right':
        return Icons.ramp_right_rounded;
      case 'ferry':
        return Icons.directions_boat_rounded;
      default:
        return Icons.straight_rounded;
    }
  }

  Future<void> _startNavigation() async {
    if (!_routeSet || _navigationSteps.isEmpty) {
      AppToast.show(
        context,
        message: 'Please set a route first.',
        type: ToastType.error,
      );
      return;
    }

    if (kIsWeb) {
      AppToast.show(
        context,
        message: 'Live navigation requires the mobile app.',
        type: ToastType.error,
      );
      return;
    }

    // Request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Location permission required for navigation.',
          type: ToastType.error,
        );
      }
      return;
    }

    // Get initial position
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _isNavigating = true;
        _currentStepIndex = 0;
      });
    } catch (_) {
      setState(() {
        _currentPosition = _startPoint;
        _isNavigating = true;
        _currentStepIndex = 0;
      });
    }

    _rebuildMapOverlays();

    // Zoom into current position
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition ?? _startPoint,
          zoom: 16,
          tilt: 45,
          bearing: 0,
        ),
      ),
    );

    // Start listening to position updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // update every 10 metres
      ),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position position) {
    if (!mounted || !_isNavigating) return;

    final newPos = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentPosition = newPos;
    });

    _rebuildMapOverlays();

    // Advance camera to follow user
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: newPos,
          zoom: 17,
          tilt: 50,
          bearing: position.heading,
        ),
      ),
    );

    // Auto-advance step when user is close to the end of current step
    if (_currentStepIndex < _navigationSteps.length) {
      final step = _navigationSteps[_currentStepIndex];
      final stepEnd = step['endLocation'] as LatLng;
      final distToStepEnd = _haversineDistance(newPos, stepEnd);

      if (distToStepEnd < 30 &&
          _currentStepIndex < _navigationSteps.length - 1) {
        setState(() => _currentStepIndex++);
      }
    }

    // Check if arrived at destination
    final distToDest = _haversineDistance(newPos, _endPoint);
    if (distToDest < 50) {
      _onArrived();
    }
  }

  /// Haversine distance in metres between two LatLng points
  double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    return R * c;
  }

  void _onArrived() {
    _positionStream?.cancel();
    _positionStream = null;
    setState(() {
      _isNavigating = false;
    });
    _rebuildMapOverlays();
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Row(
            children: [
              const Icon(Icons.flag_rounded, color: Color(0xFF2D5A27)),
              SizedBox(width: 2.w),
              Text(
                'You have arrived!',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            'You have reached your destination: ${_destinationController.text}',
            style: GoogleFonts.dmSans(fontSize: 12.sp),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _stopNavigation() {
    _positionStream?.cancel();
    _positionStream = null;
    setState(() {
      _isNavigating = false;
      _currentStepIndex = 0;
    });
    _rebuildMapOverlays();
    // Zoom back out to show full route
    if (_routePolylinePoints.isNotEmpty) {
      _fitCameraToRoute(_routePolylinePoints);
    }
  }

  // ─── Waypoints ──────────────────────────────────────────────────────────────

  void _addWaypointManually() {
    if (_waypoints.length >= 5) {
      AppToast.show(
        context,
        message: 'Maximum 5 waypoints allowed',
        type: ToastType.error,
      );
      return;
    }
    _showAddWaypointDialog();
  }

  void _showAddWaypointDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Add Waypoint',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter location name or address',
            hintStyle: GoogleFonts.dmSans(fontSize: 12.sp),
          ),
          style: GoogleFonts.dmSans(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.dmSans()),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);

              // Show loading toast
              AppToast.show(
                context,
                message: 'Adding waypoint...',
                type: ToastType.info,
              );

              // Geocode the waypoint
              final latLng = await _geocodeAddress(text);

              if (latLng != null && mounted) {
                setState(() {
                  _waypoints.add(text);
                  _waypointPoints.add(latLng);
                });
                _rebuildMapOverlays();

                AppToast.show(
                  context,
                  message: 'Waypoint ${_waypoints.length} added',
                  type: ToastType.success,
                );

                // Re-fetch route with waypoints included
                _updateRoute();
              } else if (mounted) {
                AppToast.show(
                  context,
                  message:
                      'Could not find that location. Try a different search.',
                  type: ToastType.error,
                );
              }
            },
            child: Text('Add', style: GoogleFonts.dmSans()),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRoute() async {
    if (_startController.text.isEmpty || _destinationController.text.isEmpty) {
      AppToast.show(
        context,
        message: 'Please set start and destination',
        type: ToastType.error,
      );
      return;
    }

    final nameController = TextEditingController(
      text: '${_startController.text} → ${_destinationController.text}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Save Route',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Give your route a name:',
              style: GoogleFonts.dmSans(fontSize: 12.sp),
            ),
            SizedBox(height: 1.5.h),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Route name',
                hintStyle: GoogleFonts.dmSans(fontSize: 12.sp),
              ),
              style: GoogleFonts.dmSans(fontSize: 13.sp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.dmSans()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save', style: GoogleFonts.dmSans()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      final waypointsData = [
        {'label': _startController.text, 'type': 'start'},
        ..._waypoints.map((w) => {'label': w, 'type': 'waypoint'}),
        {'label': _destinationController.text, 'type': 'end'},
      ];

      await client.from('saved_routes').insert({
        'user_id': userId,
        'name': nameController.text.trim(),
        'waypoints': waypointsData,
        'distance_km': _distanceKm,
        'estimated_minutes': _estimatedMinutes,
        'route_type': _routeType,
      });

      if (mounted) {
        AppToast.show(
          context,
          message: 'Route saved successfully!',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Failed to save route. Please try again.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _shareRoute() {
    if (_startController.text.isEmpty || _destinationController.text.isEmpty) {
      AppToast.show(
        context,
        message: 'Please set start and destination first',
        type: ToastType.error,
      );
      return;
    }
    _showShareOptions();
  }

  void _showShareOptions() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 10.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Share Route',
              style: GoogleFonts.dmSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 2.h),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _buildAndSendRouteMessage();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 11.w,
                      height: 11.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE85A4F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFFE85A4F),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send to Rider',
                            style: GoogleFonts.dmSans(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Share route details via chat',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 1.5.h),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _createGroupRide();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B365D).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: const Color(0xFF1B365D).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 11.w,
                      height: 11.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B365D).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: const Icon(
                        Icons.group_add_rounded,
                        color: Color(0xFF1B365D),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Group Ride',
                            style: GoogleFonts.dmSans(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B365D),
                            ),
                          ),
                          Text(
                            'Pre-fill group with this route & invite riders',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF1B365D),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  void _buildAndSendRouteMessage() {
    final distanceStr = _isMetric
        ? '${_distanceKm.toStringAsFixed(1)} km'
        : '${(_distanceKm * 0.621371).toStringAsFixed(1)} mi';

    final timeStr = _estimatedMinutes > 0
        ? (_estimatedMinutes < 60
              ? '${_estimatedMinutes}m'
              : '${_estimatedMinutes ~/ 60}h ${_estimatedMinutes % 60}m')
        : 'TBD';

    final routeTypeLabel =
        (_isBicycleMode
            ? {
                'fastest': 'Direct Cycle Route',
                'scenic': 'Scenic Cycle Route',
                'avoid_motorways': 'Low-Traffic Cycle Route',
              }
            : {
                'fastest': 'Fastest Route',
                'scenic': 'Scenic Route',
                'avoid_motorways': 'Back Roads',
              })[_routeType] ??
        'Route';

    final waypointText = _waypoints.isNotEmpty
        ? '\n📍 Via: ${_waypoints.join(' → ')}'
        : '';

    final mapsLink =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${Uri.encodeComponent(_startController.text)}'
        '&destination=${Uri.encodeComponent(_destinationController.text)}';

    final message =
        '🏍️ Ride Proposal\n'
        '📍 From: ${_startController.text}\n'
        '🏁 To: ${_destinationController.text}$waypointText\n'
        '🗺️ Type: $routeTypeLabel\n'
        '📏 Distance: $distanceStr\n'
        '⏱️ Est. Time: $timeStr\n'
        '🔗 Map: $mapsLink\n'
        '\nWant to join me? 🤙';

    _showRiderPickerSheet(message);
  }

  void _createGroupRide() {
  final routeDescription = _waypoints.isNotEmpty
      ? '${_startController.text} → ${_waypoints.join(' → ')} → ${_destinationController.text}'
      : '${_startController.text} → ${_destinationController.text}';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CreateGroupModalWidget(
      prefillRoute: routeDescription,
      prefillDate: DateTime.now().add(const Duration(days: 3)),
      prefillDistanceKm: _distanceKm > 0 ? _distanceKm : null,
      prefillRouteType: _routeType,
      prefillWaypoints: _waypoints.isNotEmpty
          ? List<String>.from(_waypoints)
          : null,
      onCreate: (group, invitees) async {
        try {
          final supabase = Supabase.instance.client;
          final currentUser = supabase.auth.currentUser;

          if (currentUser == null) {
            if (mounted) {
              AppToast.show(
                context,
                message: 'You must be signed in to create a ride',
                type: ToastType.error,
              );
            }
            return;
          }

          final inserted = await supabase
              .from('ride_groups')
              .insert({
                'creator_id': currentUser.id,
                'name': group.name,
                'route': group.route,
                'ride_date': group.date.toIso8601String(),
                'max_riders': group.maxRiders,
                'member_count': 1,
                'leader_name': 'You',
                'ride_community': group.rideCommunity,
                'ride_type': group.rideType,
                'difficulty': group.difficulty,
                'duration': group.duration,
                'route_image_url': group.routeImageUrl,
              })
              .select()
              .single();

          final groupId = inserted['id'] as String?;

          if (groupId != null && invitees.isNotEmpty) {
            final inviteRows = invitees
                .map(
                  (inviteeId) => {
                    'group_id': groupId,
                    'group_name': group.name,
                    'inviter_id': currentUser.id,
                    'invitee_id': inviteeId,
                    'status': 'pending',
                    'created_at': DateTime.now().toIso8601String(),
                  },
                )
                .toList();

            await supabase.from('ride_group_invites').insert(inviteRows);
          }

          if (mounted) {
            AppToast.show(
              context,
              message: invitees.isNotEmpty
                  ? 'Group ride created & ${invitees.length} rider${invitees.length > 1 ? 's' : ''} invited!'
                  : 'Group ride created!',
              type: ToastType.success,
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RideGroupsScreen(),
              ),
            );
          }
        } catch (e) {
          debugPrint('RoutePlannerScreen: create group ride failed: $e');

          if (mounted) {
            AppToast.show(
              context,
              message: 'Could not create group ride',
              type: ToastType.error,
            );
          }
        }
      },
    ),
  );
}

  Future<void> _showRiderPickerSheet(String routeMessage) async {
    List<Map<String, dynamic>> matches = [];
    bool isLoading = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (isLoading) {
              _loadMatchedRiders().then((riders) {
                if (ctx.mounted) {
                  setSheetState(() {
                    matches = riders;
                    isLoading = false;
                  });
                }
              });
            }

            return Container(
              height: 70.h,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 1.2.h),
                    width: 10.w,
                    height: 0.5.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.5.h,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Send Route to Rider',
                          style: GoogleFonts.dmSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1B365D),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE85A4F),
                            ),
                          )
                        : matches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 1.5.h),
                                Text(
                                  'No matched riders yet',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  'Match with riders to share routes',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.sp,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4.w,
                              vertical: 1.h,
                            ),
                            itemCount: matches.length,
                            itemBuilder: (ctx, index) {
                              final rider = matches[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      rider['image'] != null &&
                                          rider['image'].isNotEmpty
                                      ? NetworkImage(rider['image'])
                                      : null,
                                  child:
                                      rider['image'] == null ||
                                          rider['image'].isEmpty
                                      ? Text(
                                          (rider['name'] as String)
                                              .substring(0, 1)
                                              .toUpperCase(),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  rider['name'] as String,
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  rider['bikeModel'] as String? ?? '',
                                  style: GoogleFonts.dmSans(fontSize: 11.sp),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _sendRouteToRider(
                                      rider['userId'] as String,
                                      routeMessage,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE85A4F),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 3.w,
                                      vertical: 0.8.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  child: Text(
                                    'Send',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendRouteToRider(String riderId, String message) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final existingConv = await supabase
          .from('conversations')
          .select('id')
          .or(
            'and(user1_id.eq.${currentUser.id},user2_id.eq.$riderId),and(user1_id.eq.$riderId,user2_id.eq.${currentUser.id})',
          )
          .maybeSingle();

      String conversationId;
      if (existingConv != null) {
        conversationId = existingConv['id'] as String;
      } else {
        final newConv = await supabase
            .from('conversations')
            .insert({'user1_id': currentUser.id, 'user2_id': riderId})
            .select('id')
            .single();
        conversationId = newConv['id'] as String;
      }

      await supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUser.id,
        'content': message,
        'message_type': 'text',
      });

      if (mounted) {
        AppToast.show(
          context,
          message: 'Route sent! 🏍️',
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Route sent! 🏍️',
          type: ToastType.success,
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadMatchedRiders() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return [];

      final rows = await supabase
          .from('matches')
          .select('user1_id, user2_id')
          .or('user1_id.eq.${currentUser.id},user2_id.eq.${currentUser.id}')
          .limit(50);

      final matchedUserIds = <String>[];
      for (final row in rows) {
        final u1 = row['user1_id'] as String?;
        final u2 = row['user2_id'] as String?;
        if (u1 != null && u1 != currentUser.id) matchedUserIds.add(u1);
        if (u2 != null && u2 != currentUser.id) matchedUserIds.add(u2);
      }

      if (matchedUserIds.isEmpty) return [];

      final profiles = await supabase
          .from('profiles')
          .select('id, name, profile_photo_url, bike_types')
          .inFilter('id', matchedUserIds);

      return (profiles as List).map((p) {
        final bikeTypes = p['bike_types'];
        String bikeModel = '';
        if (bikeTypes is List && bikeTypes.isNotEmpty) {
          bikeModel = bikeTypes.first.toString();
        } else if (bikeTypes is String && bikeTypes.isNotEmpty) {
          bikeModel = bikeTypes;
        }
        return {
          'userId': p['id'] as String,
          'name': p['name'] as String? ?? 'Rider',
          'image': p['profile_photo_url'] as String? ?? '',
          'bikeModel': bikeModel,
          'isOnline': false,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _isNavigating
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1B365D),
              elevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLogoMark(size: 7.w),
                  SizedBox(width: 2.w),
                  Text(
                    _isBicycleMode ? 'Plan Cycle Route' : 'Plan Route',
                    style: GoogleFonts.dmSans(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: _shareRoute,
                  tooltip: 'Share Route',
                ),
                IconButton(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 22),
                  onPressed: _isSaving ? null : _saveRoute,
                  tooltip: 'Save Route',
                ),
              ],
            ),
      body: _isNavigating
          ? _buildNavigationView(theme)
          : _buildPlannerView(theme),
    );
  }

  // ─── Navigation View (full-screen) ──────────────────────────────────────────

  Widget _buildNavigationView(ThemeData theme) {
    final currentStep =
        _navigationSteps.isNotEmpty &&
            _currentStepIndex < _navigationSteps.length
        ? _navigationSteps[_currentStepIndex]
        : null;

    final remainingSteps = _navigationSteps.length - _currentStepIndex;
    final distanceStr = _isMetric
        ? '${_distanceKm.toStringAsFixed(1)} km'
        : '${(_distanceKm * 0.621371).toStringAsFixed(1)} mi';
    final timeStr = _estimatedMinutes < 60
        ? '$_estimatedMinutes min'
        : '${_estimatedMinutes ~/ 60}h ${_estimatedMinutes % 60}m';

    return Stack(
      children: [
        // Full-screen map
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            if (_currentPosition != null) {
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _currentPosition!, zoom: 17, tilt: 50),
                ),
              );
            }
          },
          initialCameraPosition: CameraPosition(
            target: _currentPosition ?? _startPoint,
            zoom: 17,
            tilt: 50,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
          compassEnabled: true,
          trafficEnabled: true,
        ),

        // Top instruction banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1B365D),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: currentStep != null
                  ? Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.5.h,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12.w,
                            height: 12.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Icon(
                              _maneuverIcon(
                                currentStep['maneuver'] as String? ?? '',
                              ),
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentStep['instruction'] as String,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 0.3.h),
                                Text(
                                  '${currentStep['distance']}  •  ${currentStep['duration']}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10.sp,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$remainingSteps',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'steps',
                                style: GoogleFonts.dmSans(
                                  fontSize: 9.sp,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.5.h,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'Navigating to ${_destinationController.text}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),

        // Step list panel (swipe up from bottom)
        if (_navigationSteps.length > 1)
          Positioned(
            bottom: 14.h,
            left: 3.w,
            right: 3.w,
            child: Container(
              constraints: BoxConstraints(maxHeight: 18.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.list_alt_rounded,
                          size: 16,
                          color: Color(0xFF1B365D),
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'Upcoming Steps',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1B365D),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$distanceStr  •  $timeStr',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(vertical: 0.5.h),
                      itemCount: math.min(
                        _navigationSteps.length - _currentStepIndex,
                        4,
                      ),
                      itemBuilder: (ctx, i) {
                        final idx = _currentStepIndex + i;
                        final step = _navigationSteps[idx];
                        final isActive = i == 0;
                        return Container(
                          color: isActive
                              ? const Color(0xFF1B365D).withValues(alpha: 0.06)
                              : Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 0.7.h,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _maneuverIcon(
                                  step['maneuver'] as String? ?? '',
                                ),
                                size: 18,
                                color: isActive
                                    ? const Color(0xFF1B365D)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Text(
                                  step['instruction'] as String,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10.sp,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isActive
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                step['distance'] as String,
                                style: GoogleFonts.dmSans(
                                  fontSize: 9.sp,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom stop navigation button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              child: ElevatedButton.icon(
                onPressed: _showNavigationOptions,
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                label: Text(
                  'Stop Navigation',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85A4F),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Planner View ────────────────────────────────────────────────────────────

  Widget _buildPlannerView(ThemeData theme) {
    return Column(
      children: [
        // Google Map
        SizedBox(
          height: 30.h,
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                initialCameraPosition: const CameraPosition(
                  target: LatLng(20.0, 0.0),
                  zoom: 2,
                ),
                onTap: _onMapTap,
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                mapType: MapType.normal,
                compassEnabled: true,
                trafficEnabled: false,
              ),
              // Loading overlay while fetching route
              if (_isFetchingRoute)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1B365D),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              // Map hint overlay
              if (!_isFetchingRoute)
                Positioned(
                  bottom: 1.5.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 0.8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Text(
                        !_startSet
                            ? 'Tap map to set start point'
                            : !_routeSet
                            ? 'Tap map to set destination'
                            : 'Tap map to add waypoints',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Controls panel
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route summary
                RouteSummaryCardWidget(
                  distanceKm: _distanceKm,
                  estimatedMinutes: _estimatedMinutes,
                  isMetric: _isMetric,
                  rideMode: _rideMode,
                ),
                SizedBox(height: 2.h),
                // Start field
                RouteLocationFieldWidget(
                  controller: _startController,
                  label: 'Start Point',
                  hint: 'Type a location or tap the map',
                  dotColor: const Color(0xFF2D5A27),
                  onUseCurrentLocation: _useCurrentLocationForStart,
                  isLoading: _isGeocodingStart,
                  onSearch: _geocodeStartAddress,
                  onChanged: (_) {},
                ),
                SizedBox(height: 1.5.h),
                // Destination field
                RouteLocationFieldWidget(
                  controller: _destinationController,
                  label: 'Destination',
                  hint: 'Type a location or tap the map',
                  dotColor: const Color(0xFFE85A4F),
                  isLoading: _isGeocodingDest,
                  onSearch: _geocodeDestAddress,
                  onChanged: (_) {},
                ),
                SizedBox(height: 2.h),
                // Weather widget
                if (_weatherLocation != null && _weatherLocation!.isNotEmpty)
                  _isPremium
                      ? RouteWeatherWidget(locationName: _weatherLocation)
                      : WeatherPremiumGateWidget(
                          onUpgrade: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              AppRoutes.premiumSubscription,
                            );
                            if (result == true && mounted) {
                              setState(() {
                                _isPremium = PremiumService().isPremium;
                              });
                            }
                          },
                        ),
                if (_weatherLocation != null && _weatherLocation!.isNotEmpty)
                  SizedBox(height: 2.h),
                // Waypoints
                WaypointListWidget(
                  waypoints: _waypoints,
                  onAdd: _addWaypointManually,
                  onRemove: (index) {
                    setState(() {
                      _waypoints.removeAt(index);
                      if (index < _waypointPoints.length) {
                        _waypointPoints.removeAt(index);
                      }
                    });
                    _rebuildMapOverlays();
                    // Re-fetch route without removed waypoint
                    _updateRoute();
                  },
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _waypoints.removeAt(oldIndex);
                      _waypoints.insert(newIndex, item);
                      if (oldIndex < _waypointPoints.length) {
                        final pt = _waypointPoints.removeAt(oldIndex);
                        if (newIndex <= _waypointPoints.length) {
                          _waypointPoints.insert(newIndex, pt);
                        }
                      }
                    });
                    _rebuildMapOverlays();
                    // Re-fetch route with new waypoint order
                    _updateRoute();
                  },
                ),

                SizedBox(height: 2.h),
                // Route type
                RouteTypeSelectorWidget(
                  selectedType: _routeType,
                  rideMode: _rideMode,
                  onChanged: (type) {
                    setState(() => _routeType = type);
                    _updateRoute();
                  },
                ),
                SizedBox(height: 2.h),
                // Start Navigation button (shown when route is ready)
                if (_routeSet && _navigationSteps.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showNavigationOptions,
                      icon: const Icon(
                        Icons.navigation_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Start Navigation',
                        style: GoogleFonts.dmSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5A27),
                        padding: EdgeInsets.symmetric(vertical: 1.8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),
                if (_routeSet && _navigationSteps.isNotEmpty)
                  SizedBox(height: 2.h),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareRoute,
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: Text(
                          'Share Route',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveRoute,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Route',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
} // end _RoutePlannerScreenState

// ─── Navigation Launcher Utility ─────────────────────────────────────────────

class NavigationLauncher {
  static Future<bool> launchWaze({
    required LatLng destination,
    LatLng? origin,
  }) async {
    final lat = destination.latitude;
    final lng = destination.longitude;

    final wazeAppUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');

    final wazeWebUri = Uri.parse(
      'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
    );

    if (!kIsWeb) {
      try {
        final openedApp = await launchUrl(
          wazeAppUri,
          mode: LaunchMode.externalApplication,
        );

        if (openedApp) return true;
      } catch (_) {
        // Waze app is probably not installed.
      }
    }

    try {
      return await launchUrl(wazeWebUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchGoogleMaps({
    required LatLng destination,
    LatLng? origin,
    List<LatLng>? waypoints,
    String travelMode = 'driving',
  }) async {
    final params = <String, String>{
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': travelMode,
    };

    if (origin != null) {
      params['origin'] = '${origin.latitude},${origin.longitude}';
    }

    if (waypoints != null && waypoints.isNotEmpty) {
      params['waypoints'] = waypoints
          .map((wp) => '${wp.latitude},${wp.longitude}')
          .join('|');
    }

    final googleMapsUri = Uri.https('www.google.com', '/maps/dir/', params);

    try {
      return await launchUrl(
        googleMapsUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

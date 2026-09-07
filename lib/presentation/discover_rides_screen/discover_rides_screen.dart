import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/toast_widget.dart';

class DiscoverRidesScreen extends StatefulWidget {
  const DiscoverRidesScreen({super.key});

  @override
  State<DiscoverRidesScreen> createState() => _DiscoverRidesScreenState();
}

class _DiscoverRidesScreenState extends State<DiscoverRidesScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool _isLoading = true;
  bool _locationError = false;
  final double _radiusKm = 50;
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() {
      _isLoading = true;
      _locationError = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = true;
          _isLoading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = true;
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _myLat = position.latitude;
      _myLng = position.longitude;

      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final result = await supabase.rpc(
        'get_discover_rides',
        params: {
          'p_user_id': currentUser.id,
          'p_latitude': _myLat,
          'p_longitude': _myLng,
          'p_radius_meters': _radiusKm * 1000,
        },
      );

      if (mounted) {
        setState(() {
          _rides = List<Map<String, dynamic>>.from(result as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DiscoverRides: load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _rides = [];
        });
      }
    }
  }

  Future<void> _joinRide(String groupId, String rideName) async {
    try {
      final supabase = Supabase.instance.client;
      final result = await supabase.rpc(
        'join_open_ride',
        params: {'p_group_id': groupId},
      );
      final data = result as Map<String, dynamic>;

      if (data['success'] == true) {
        if (mounted) {
          AppToast.show(
            context,
            message: 'Joined ${data['group_name']}!',
            type: ToastType.success,
          );
          _loadRides();
        }
      } else {
        final error = data['error'] as String? ?? 'Could not join ride';
        if (mounted && error != 'already_joined') {
          AppToast.show(context, message: error, type: ToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Could not join ride. Please try again.',
          type: ToastType.error,
        );
      }
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m away';
    return '${(meters / 1000).toStringAsFixed(1)}km away';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Discover Rides',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRides,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _locationError
              ? _buildLocationError(theme)
              : _rides.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildRidesList(theme),
    );
  }

  Widget _buildLocationError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded, size: 56, color: theme.colorScheme.error.withValues(alpha: 0.5)),
            SizedBox(height: 2.h),
            Text('Location needed', style: GoogleFonts.dmSans(fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 1.h),
            Text('Turn on location to discover open rides near you.', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant)),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: _loadRides,
              icon: const Icon(Icons.location_searching_rounded, size: 18),
              label: Text('Enable Location', style: GoogleFonts.dmSans(fontSize: 12.sp, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_rounded, size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            SizedBox(height: 2.h),
            Text('No open rides nearby', style: GoogleFonts.dmSans(fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 1.h),
            Text('No open rides found within ${_radiusKm.round()}km. Try expanding your search radius or check back later.', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant)),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: _loadRides,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Refresh', style: GoogleFonts.dmSans(fontSize: 12.sp, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRidesList(ThemeData theme) {
    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: _rides.length,
      itemBuilder: (context, index) {
        final ride = _rides[index];
        final groupId = ride['id'] as String;
        final name = ride['name'] as String? ?? 'Group Ride';
        final route = ride['route'] as String? ?? '';
        final rideDate = ride['ride_date'] as String? ?? '';
        final maxRiders = ride['max_riders'] as int? ?? 0;
        final memberCount = ride['member_count'] as int? ?? 0;
        final leaderName = ride['leader_name'] as String? ?? 'Rider';
        final rideCommunity = ride['ride_community'] as String? ?? 'motorcycle';
        final distanceMeters = (ride['distance_meters'] as num?)?.toDouble() ?? 0;
        final isBicycle = rideCommunity == 'bicycle';

        return Card(
          margin: EdgeInsets.only(bottom: 2.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isBicycle ? Colors.green.withValues(alpha: 0.1) : const Color(0xFF1B365D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isBicycle ? 'Bicycle' : 'Motorcycle',
                        style: GoogleFonts.dmSans(fontSize: 9.sp, fontWeight: FontWeight.w700, color: isBicycle ? Colors.green : const Color(0xFF1B365D)),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B1A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDistance(distanceMeters),
                        style: GoogleFonts.dmSans(fontSize: 9.sp, fontWeight: FontWeight.w700, color: const Color(0xFFFF6B1A)),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.people_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    SizedBox(width: 1.w),
                    Text('$memberCount/$maxRiders', style: GoogleFonts.dmSans(fontSize: 10.sp, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
                SizedBox(height: 1.5.h),
                Text(name, style: GoogleFonts.dmSans(fontSize: 14.sp, fontWeight: FontWeight.w800)),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    Icon(Icons.route_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    SizedBox(width: 1.w),
                    Expanded(child: Text(route, style: GoogleFonts.dmSans(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    SizedBox(width: 1.w),
                    Text(_formatDate(rideDate), style: GoogleFonts.dmSans(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant)),
                    SizedBox(width: 3.w),
                    Icon(Icons.person_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    SizedBox(width: 1.w),
                    Text(leaderName, style: GoogleFonts.dmSans(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _joinRide(groupId, name),
                    icon: const Icon(Icons.group_add_rounded, size: 18),
                    label: Text('Join Ride', style: GoogleFonts.dmSans(fontSize: 12.sp, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B365D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

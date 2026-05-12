import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './ride_summary_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rides = [];

  final List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadRideHistory();
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _loadRideHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('live_ride_participants')
          .select(
            'session_id, joined_at, left_at, live_ride_sessions(id, ride_group_id, started_by, started_at, ended_at, status, ride_groups(name))',
          )
          .eq('user_id', user.id)
          .eq('status', 'left')
          .order('joined_at', ascending: false)
          .limit(50);

      final List<Map<String, dynamic>> rides = [];

      for (final participant in response as List) {
        final sessionId = participant['session_id'] as String?;
        if (sessionId == null) continue;

        final session = participant['live_ride_sessions'];
        if (session == null) continue;

        final rideGroup = session['ride_groups'];
        final groupName = rideGroup != null
            ? (rideGroup['name'] as String? ?? 'Unknown Group')
            : 'Unknown Group';

        final startedAt = session['started_at'] != null
            ? DateTime.tryParse(session['started_at'].toString())
            : null;
        final endedAt = session['ended_at'] != null
            ? DateTime.tryParse(session['ended_at'].toString())
            : null;

        Duration duration = Duration.zero;
        if (startedAt != null && endedAt != null) {
          duration = endedAt.difference(startedAt);
        }

        // Calculate distance using Haversine
        double distanceKm = 0.0;
        try {
          final locationData = await Supabase.instance.client
              .from('live_ride_locations')
              .select('latitude, longitude')
              .eq('session_id', sessionId)
              .eq('user_id', user.id)
              .order('created_at', ascending: true);

          final locations = locationData as List;
          for (int i = 1; i < locations.length; i++) {
            final prev = locations[i - 1];
            final curr = locations[i];
            final lat1 = (prev['latitude'] as num).toDouble();
            final lon1 = (prev['longitude'] as num).toDouble();
            final lat2 = (curr['latitude'] as num).toDouble();
            final lon2 = (curr['longitude'] as num).toDouble();
            distanceKm += _haversineDistance(lat1, lon1, lat2, lon2);
          }
        } catch (_) {}

        // Get participant count
        int participantCount = 0;
        try {
          final countResponse = await Supabase.instance.client
              .from('live_ride_participants')
              .select('id')
              .eq('session_id', sessionId);
          participantCount = (countResponse as List).length;
        } catch (_) {}

        final wasCreator = session['started_by'] == user.id;

        rides.add({
          'sessionId': sessionId,
          'groupName': groupName,
          'startedAt': startedAt,
          'endedAt': endedAt,
          'duration': duration,
          'distanceKm': distanceKm,
          'participantCount': participantCount,
          'wasCreator': wasCreator,
        });
      }

      setState(() {
        _rides = rides;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown date';
    final month = _monthNames[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month $day, $year • $hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        title: Text(
          'Ride History',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : _rides.isEmpty
          ? _buildEmptyState()
          : _buildRideList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.motorcycle, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(
            'No rides yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed live rides will appear here.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRideList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rides.length,
      itemBuilder: (context, index) {
        final ride = _rides[index];
        return _buildRideCard(ride);
      },
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final groupName = ride['groupName'] as String;
    final wasCreator = ride['wasCreator'] as bool;
    final startedAt = ride['startedAt'] as DateTime?;
    final endedAt = ride['endedAt'] as DateTime?;
    final duration = ride['duration'] as Duration;
    final distanceKm = ride['distanceKm'] as double;
    final participantCount = ride['participantCount'] as int;
    final sessionId = ride['sessionId'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2563EB).withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: group name + leader chip
          Row(
            children: [
              Expanded(
                child: Text(
                  groupName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (wasCreator) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(38),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Leader',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Date row
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                _formatDate(startedAt),
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildStat(
                  icon: Icons.timer_outlined,
                  value: _formatDuration(duration),
                  label: 'Duration',
                  color: const Color(0xFF2563EB),
                ),
              ),
              Expanded(
                child: _buildStat(
                  icon: Icons.straighten,
                  value: '${distanceKm.toStringAsFixed(1)} km',
                  label: 'Distance',
                  color: const Color(0xFF059669),
                ),
              ),
              Expanded(
                child: _buildStat(
                  icon: Icons.people,
                  value: '$participantCount',
                  label: 'Riders',
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // View Summary button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RideSummaryScreen(
                      sessionId: sessionId,
                      startedAt: startedAt ?? DateTime.now(),
                      endedAt: endedAt ?? DateTime.now(),
                      participantCount: participantCount,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: BorderSide(color: const Color(0xFF2563EB).withAlpha(77)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'View Summary',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}

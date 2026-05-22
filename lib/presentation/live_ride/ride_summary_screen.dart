import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/badge_service.dart';

class RideSummaryScreen extends StatefulWidget {
  final String sessionId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int participantCount;

  const RideSummaryScreen({
    super.key,
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.participantCount,
  });

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isLoading = true;
  double _totalDistanceKm = 0.0;
  double _avgSpeedKmh = 0.0;
  double _maxSpeedKmh = 0.0;
  int _gpsPointCount = 0;
  String? _newBadgeId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _loadRideStats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRideStats() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await client
          .from('live_ride_locations')
          .select('latitude, longitude, speed, created_at')
          .eq('session_id', widget.sessionId)
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final points = response as List<dynamic>;
      _gpsPointCount = points.length;

      double totalDistance = 0.0;
      double speedSum = 0.0;
      int speedCount = 0;
      double maxSpeed = 0.0;

      for (int i = 0; i < points.length; i++) {
        final speedMs = (points[i]['speed'] as num?)?.toDouble() ?? 0.0;
        final speedKmh = speedMs * 3.6;

        if (speedMs > 0) {
          speedSum += speedKmh;
          speedCount++;
        }
        if (speedKmh > maxSpeed) {
          maxSpeed = speedKmh;
        }

        if (i > 0) {
          final lat1 = (points[i - 1]['latitude'] as num).toDouble();
          final lon1 = (points[i - 1]['longitude'] as num).toDouble();
          final lat2 = (points[i]['latitude'] as num).toDouble();
          final lon2 = (points[i]['longitude'] as num).toDouble();
          totalDistance += _haversineDistance(lat1, lon1, lat2, lon2);
        }
      }

      _totalDistanceKm = totalDistance;
      _avgSpeedKmh = speedCount > 0 ? speedSum / speedCount : 0.0;
      _maxSpeedKmh = maxSpeed;

      final awarded = await BadgeService.awardBadge('first_live_ride');
      if (awarded) {
        _newBadgeId = 'first_live_ride';
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.endedAt.difference(widget.startedAt);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Trophy icon with scale animation
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withAlpha(102),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.motorcycle_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      Text(
                        'Ride Complete! 🏍️',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        "Great ride! Here's your summary.",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Row 1: Duration | Distance
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.timer_outlined,
                              color: const Color(0xFF2563EB),
                              value: _formatDuration(duration),
                              label: 'Duration',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.straighten_rounded,
                              color: const Color(0xFF059669),
                              value:
                                  '${_totalDistanceKm.toStringAsFixed(1)} km',
                              label: 'Distance',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 2: Avg Speed | Riders
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.speed_rounded,
                              color: const Color(0xFFD97706),
                              value: '${_avgSpeedKmh.toStringAsFixed(1)} km/h',
                              label: 'Avg Speed',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.people_rounded,
                              color: const Color(0xFF7C3AED),
                              value: '${widget.participantCount}',
                              label: 'Riders',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 3: Max Speed | GPS Points
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.rocket_launch_rounded,
                              color: const Color(0xFFDC2626),
                              value: '${_maxSpeedKmh.toStringAsFixed(1)} km/h',
                              label: 'Max Speed',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.location_on_rounded,
                              color: const Color(0xFF0891B2),
                              value: '$_gpsPointCount',
                              label: 'GPS Points',
                            ),
                          ),
                        ],
                      ),
                      // Badge unlock section
                      if (_newBadgeId != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text('🏆', style: TextStyle(fontSize: 36)),
                              const SizedBox(height: 8),
                              Text(
                                'Badge Unlocked!',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFB300),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'First Live Ride',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You completed your first live group ride!',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(217),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      // Done button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/main-screen',
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

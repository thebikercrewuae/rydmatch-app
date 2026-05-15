import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class RouteSummaryCardWidget extends StatelessWidget {
  final double distanceKm;
  final int estimatedMinutes;
  final bool isMetric;
  final String rideMode;

  const RouteSummaryCardWidget({
    super.key,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.isMetric,
    this.rideMode = 'motorcycle',
  });

  String get _formattedDistance {
    if (isMetric) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      final miles = distanceKm * 0.621371;
      return '${miles.toStringAsFixed(1)} mi';
    }
  }

  String get _formattedTime {
    if (estimatedMinutes < 60) {
      return '${estimatedMinutes}m';
    }
    final hours = estimatedMinutes ~/ 60;
    final mins = estimatedMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBicycle = rideMode == 'bicycle';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: isBicycle
                  ? Icons.directions_bike_rounded
                  : Icons.route_rounded,
              label: 'Distance',
              value: distanceKm > 0 ? _formattedDistance : '--',
            ),
          ),
          Container(
            width: 1,
            height: 4.h,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.timer_outlined,
              label: 'Est. Ride Time',
              value: estimatedMinutes > 0 ? _formattedTime : '--',
            ),
          ),
          Container(
            width: 1,
            height: 4.h,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.place_outlined,
              label: 'Waypoints',
              value: distanceKm > 0 ? 'Set' : 'None',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9.sp,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

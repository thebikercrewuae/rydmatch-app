import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class PerformanceMetricsWidget extends StatelessWidget {
  final double avgSpeed;
  final double totalElevation;
  final double completionRate;
  final String speedUnit;

  const PerformanceMetricsWidget({
    super.key,
    required this.avgSpeed,
    required this.totalElevation,
    required this.completionRate,
    required this.speedUnit,
  });

  static const Color _primary = Color(0xFF1B365D);
  static const Color _orange = Color(0xFFE85A4F);
  static const Color _teal = Color(0xFF26A69A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(AppIcons.speed, color: _teal, size: 16),
              ),
              SizedBox(width: 2.w),
              Text(
                'Performance',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              _buildMetricTile(
                context,
                icon: AppIcons.speed,
                label: 'Avg Speed',
                value: avgSpeed.toStringAsFixed(0),
                unit: speedUnit,
                color: _teal,
              ),
              SizedBox(width: 3.w),
              _buildMetricTile(
                context,
                icon: AppIcons.terrain,
                label: 'Elevation',
                value: totalElevation.toStringAsFixed(0),
                unit: 'm',
                color: _primary,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildCompletionRate(context),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 3.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(height: 0.8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    height: 1.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    ' $unit',
                    style: GoogleFonts.dmSans(
                      fontSize: 9.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionRate(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(AppIcons.help, color: _orange, size: 16),
                SizedBox(width: 1.5.w),
                Text(
                  'Ride Completion Rate',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Text(
              '${completionRate.toStringAsFixed(0)}%',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: _orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 0.8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(6.0),
          child: LinearProgressIndicator(
            value: completionRate / 100,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(_orange),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

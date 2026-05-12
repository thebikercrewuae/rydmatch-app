import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class RidingStreakWidget extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final List<bool> last28Days;

  const RidingStreakWidget({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.last28Days,
  });

  static const Color _primary = Color(0xFF1B365D);
  static const Color _orange = Color(0xFFE85A4F);

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
                  color: _orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(AppIcons.help, color: _orange, size: 16),
              ),
              SizedBox(width: 2.w),
              Text(
                'Riding Streak',
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
              _buildStreakStat(
                context,
                currentStreak.toString(),
                'Current Streak',
                _orange,
              ),
              SizedBox(width: 4.w),
              _buildStreakStat(
                context,
                longestStreak.toString(),
                'Longest Streak',
                _primary,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Last 28 Days',
            style: GoogleFonts.dmSans(
              fontSize: 10.sp,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 1.h),
          _buildHeatmap(context),
        ],
      ),
    );
  }

  Widget _buildStreakStat(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 3.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    ' days',
                    style: GoogleFonts.dmSans(
                      fontSize: 10.sp,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 0.3.h),
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

  Widget _buildHeatmap(BuildContext context) {
    final theme = Theme.of(context);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days
              .map(
                (d) => SizedBox(
                  width: 8.w,
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 8.sp,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: 0.5.h),
        ...List.generate(4, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final hasRide = idx < last28Days.length && last28Days[idx];
                return Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: hasRide
                        ? _orange.withValues(alpha: 0.75)
                        : theme.colorScheme.outline.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}

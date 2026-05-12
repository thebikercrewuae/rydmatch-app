import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class SpeedDisplayWidget extends StatelessWidget {
  final double ridingSpeed; // always stored in mph
  final bool isMetric;

  const SpeedDisplayWidget({
    super.key,
    required this.ridingSpeed,
    this.isMetric = false,
  });

  double get _displaySpeed => isMetric ? (ridingSpeed * 1.60934) : ridingSpeed;

  String get _unitLabel => isMetric ? 'km/h' : 'mph';

  String get _speedLabel {
    if (ridingSpeed <= 40) return 'Casual Cruiser';
    if (ridingSpeed <= 65) return 'Relaxed Rider';
    if (ridingSpeed <= 85) return 'Spirited Rider';
    if (ridingSpeed <= 100) return 'Fast & Focused';
    return 'Track Pace';
  }

  Color _speedColor(ThemeData theme) {
    if (ridingSpeed <= 40) return theme.colorScheme.tertiary;
    if (ridingSpeed <= 65) return theme.colorScheme.primary;
    if (ridingSpeed <= 85) return const Color(0xFFB7791F);
    return theme.colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _speedColor(theme);
    return Row(
      children: [
        Container(
          width: 14.w,
          height: 14.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_displaySpeed.round()}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                _unitLabel,
                style: TextStyle(
                  fontSize: 8.sp,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 4.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                _speedLabel,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            SizedBox(height: 0.5.h),
            SizedBox(
              width: 55.w,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.1),
                  inactiveTrackColor: theme.colorScheme.outline,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: ridingSpeed,
                  min: 20,
                  max: 120,
                  onChanged: null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

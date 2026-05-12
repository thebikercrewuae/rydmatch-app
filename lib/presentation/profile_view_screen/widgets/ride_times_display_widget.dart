import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class RideTimesDisplayWidget extends StatelessWidget {
  final Map<String, List<String>> rideTimes;

  const RideTimesDisplayWidget({super.key, required this.rideTimes});

  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _times = [
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rideTimes.isEmpty) {
      return Text(
        'No ride times selected',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 12.w),
            ..._days.map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 0.5.h),
        ..._times.map(
          (time) => Padding(
            padding: EdgeInsets.only(bottom: 0.5.h),
            child: Row(
              children: [
                SizedBox(
                  width: 12.w,
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 8.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ..._days.map((day) {
                  // Keys are stored as short day names: 'Mon', 'Tue', etc.
                  final times = rideTimes[day] ?? [];
                  // Values are stored as capitalized: 'Morning', 'Afternoon', etc.
                  final isSelected = times.contains(time);
                  return Expanded(
                    child: Center(
                      child: Container(
                        width: 7.w,
                        height: 3.h,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.2,
                                ),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

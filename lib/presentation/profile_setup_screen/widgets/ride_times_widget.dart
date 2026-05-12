import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../widgets/app_icons.dart';

class RideTimesWidget extends StatelessWidget {
  final Map<String, List<String>> rideTimes;
  final ValueChanged<Map<String, List<String>>> onTimesChanged;

  const RideTimesWidget({
    super.key,
    required this.rideTimes,
    required this.onTimesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final timeSlots = ['Morning', 'Afternoon', 'Evening', 'Night'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('When do you ride?', style: theme.textTheme.headlineSmall),
          SizedBox(height: 1.h),
          Text(
            'Tap to select your typical riding availability.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 3.h),
          ...days.map((day) {
            final dayTimes = rideTimes[day] ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 10.w,
                      child: Text(
                        day,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Wrap(
                        spacing: 2.w,
                        children: timeSlots.map((slot) {
                          final isSelected = dayTimes.contains(slot);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              final updated = Map<String, List<String>>.from(
                                rideTimes,
                              );
                              final dayList = List<String>.from(
                                updated[day] ?? [],
                              );
                              isSelected
                                  ? dayList.remove(slot)
                                  : dayList.add(slot);
                              if (dayList.isEmpty) {
                                updated.remove(day);
                              } else {
                                updated[day] = dayList;
                              }
                              onTimesChanged(updated);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: EdgeInsets.only(bottom: 0.8.h),
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.5.w,
                                vertical: 0.6.h,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                              child: Text(
                                slot,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
              ],
            );
          }),
          SizedBox(height: 1.h),
          _buildLegend(theme),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    final legend = [
      {'label': 'Morning', 'time': '6AM - 12PM'},
      {'label': 'Afternoon', 'time': '12PM - 5PM'},
      {'label': 'Evening', 'time': '5PM - 9PM'},
      {'label': 'Night', 'time': '9PM - 12AM'},
    ];
    return Wrap(
      spacing: 4.w,
      runSpacing: 0.5.h,
      children: legend.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.schedule,
              color: theme.colorScheme.onSurfaceVariant,
              size: 12,
            ),
            SizedBox(width: 1.w),
            Text(
              '${item['label']}: ${item['time']}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}

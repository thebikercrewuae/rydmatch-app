import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class SkillLevelWidget extends StatelessWidget {
  final List<String> selectedLevels;
  final ValueChanged<List<String>> onLevelsChanged;

  const SkillLevelWidget({
    super.key,
    required this.selectedLevels,
    required this.onLevelsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levels = [
      {
        'id': 'beginner',
        'title': 'Beginner',
        'subtitle': 'Less than 2 years riding',
        'description':
            'Still learning the basics, prefer calm roads and patient partners.',
        'icon': 'school',
        'color': theme.colorScheme.tertiary,
      },
      {
        'id': 'intermediate',
        'title': 'Intermediate',
        'subtitle': '2-5 years riding',
        'description':
            'Comfortable on most roads, enjoy group rides and exploring new routes.',
        'icon': 'trending_up',
        'color': theme.colorScheme.primary,
      },
      {
        'id': 'advanced',
        'title': 'Advanced',
        'subtitle': '5+ years riding',
        'description':
            'Experienced rider, comfortable with challenging roads and high speeds.',
        'icon': 'military_tech',
        'color': const Color(0xFFB7791F),
      },
      {
        'id': 'expert',
        'title': 'Expert / Track',
        'subtitle': 'Professional level',
        'description':
            'Track days, advanced techniques, and pushing the limits safely.',
        'icon': 'emoji_events',
        'color': theme.colorScheme.secondary,
      },
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your skill level?',
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: 1.h),
          Text(
            'Select all that apply — it helps us find your perfect riding partner.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 1.h),
          selectedLevels.isNotEmpty
              ? Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 0.8.h,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'check_circle',
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${selectedLevels.length} selected',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
          SizedBox(height: 2.h),
          ...levels.map((level) {
            final isSelected = selectedLevels.contains(level['id']);
            final color = level['color'] as Color;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                final updated = List<String>.from(selectedLevels);
                isSelected
                    ? updated.remove(level['id'])
                    : updated.add(level['id'] as String);
                onLevelsChanged(updated);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 1.5.h),
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : theme.colorScheme.outline,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.2)
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: CustomIconWidget(
                          iconName: level['icon'] as String,
                          color: isSelected
                              ? color
                              : theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                level['title'] as String,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: isSelected
                                      ? color
                                      : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                level['subtitle'] as String,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            level['description'] as String,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 2.w),
                    isSelected
                        ? CustomIconWidget(
                            iconName: 'check_circle',
                            color: color,
                            size: 22,
                          )
                        : CustomIconWidget(
                            iconName: 'radio_button_unchecked',
                            color: theme.colorScheme.outline,
                            size: 22,
                          ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

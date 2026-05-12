import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class PreferredRoadsWidget extends StatelessWidget {
  final List<String> selectedRoads;
  final ValueChanged<List<String>> onRoadsChanged;

  const PreferredRoadsWidget({
    super.key,
    required this.selectedRoads,
    required this.onRoadsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roadOptions = [
      {
        'id': 'mountain',
        'label': 'Mountain Roads',
        'icon': 'landscape',
        'desc': 'Twisties & switchbacks',
      },
      {
        'id': 'highway',
        'label': 'Highway',
        'icon': 'add_road',
        'desc': 'Long distance cruising',
      },
      {
        'id': 'city',
        'label': 'City Streets',
        'icon': 'location_city',
        'desc': 'Urban riding',
      },
      {
        'id': 'coastal',
        'label': 'Coastal Routes',
        'icon': 'waves',
        'desc': 'Scenic ocean roads',
      },
      {
        'id': 'backroads',
        'label': 'Back Roads',
        'icon': 'forest',
        'desc': 'Rural & countryside',
      },
      {
        'id': 'track',
        'label': 'Race Track',
        'icon': 'flag',
        'desc': 'Circuit & track days',
      },
      {
        'id': 'offroad',
        'label': 'Off-Road / Dirt',
        'icon': 'terrain',
        'desc': 'Trails & gravel',
      },
      {
        'id': 'canyon',
        'label': 'Canyon Carving',
        'icon': 'filter_hdr',
        'desc': 'Technical canyon roads',
      },
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preferred road types?', style: theme.textTheme.headlineSmall),
          SizedBox(height: 1.h),
          Text(
            'Select all that apply — we\'ll find riders who love the same roads.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 1.h),
          selectedRoads.isNotEmpty
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
                        '${selectedRoads.length} selected',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
          SizedBox(height: 2.h),
          ...roadOptions.map((road) {
            final isSelected = selectedRoads.contains(road['id']);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                final updated = List<String>.from(selectedRoads);
                isSelected
                    ? updated.remove(road['id'])
                    : updated.add(road['id'] as String);
                onRoadsChanged(updated);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 1.h),
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: road['icon'] as String,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            road['label'] as String,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            road['desc'] as String,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    isSelected
                        ? CustomIconWidget(
                            iconName: 'check_circle',
                            color: theme.colorScheme.primary,
                            size: 22,
                          )
                        : CustomIconWidget(
                            iconName: 'add_circle_outline',
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

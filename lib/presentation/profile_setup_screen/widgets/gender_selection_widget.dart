import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/haptic_service.dart';
import '../../../widgets/custom_icon_widget.dart';

class GenderSelectionWidget extends StatelessWidget {
  final String? selectedGender;
  final bool sameGenderMatching;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<bool> onSameGenderMatchingChanged;

  const GenderSelectionWidget({
    super.key,
    required this.selectedGender,
    required this.sameGenderMatching,
    required this.onGenderChanged,
    required this.onSameGenderMatchingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final genders = [
      {
        'id': 'male',
        'title': 'Male',
        'icon': 'man',
        'color': theme.colorScheme.primary,
      },
      {
        'id': 'female',
        'title': 'Female',
        'icon': 'woman',
        'color': theme.colorScheme.secondary,
      },
      {
        'id': 'prefer_not_to_say',
        'title': 'Prefer not to say',
        'icon': 'shield',
        'color': theme.colorScheme.tertiary,
      },
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How do you identify?', style: theme.textTheme.headlineSmall),
          SizedBox(height: 1.h),
          Text(
            'This helps us personalise your experience.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 3.h),
          ...genders.map((gender) {
            final isSelected = selectedGender == gender['id'];
            final color = gender['color'] as Color;
            return GestureDetector(
              onTap: () {
                HapticService.instance.selection();
                onGenderChanged(gender['id'] as String);
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
                          iconName: gender['icon'] as String,
                          color: isSelected
                              ? color
                              : theme.colorScheme.onSurfaceVariant,
                          size: 28,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        gender['title'] as String,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isSelected
                              ? color
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
          if (selectedGender != null &&
              selectedGender != 'prefer_not_to_say') ...[
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ride with the same gender only',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          'Only show riders who selected the same gender.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: sameGenderMatching,
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: (value) {
                      HapticService.instance.selection();
                      onSameGenderMatchingChanged(value);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

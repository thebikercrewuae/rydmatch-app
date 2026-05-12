import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class SafetyTagsWidget extends StatelessWidget {
  final Set<String> selectedTags;
  final ValueChanged<Set<String>> onChanged;

  const SafetyTagsWidget({
    super.key,
    required this.selectedTags,
    required this.onChanged,
  });

  static const List<Map<String, dynamic>> _positiveTags = [
    {'label': 'Rode safely', 'icon': Icons.verified_user_outlined},
    {'label': 'Respected pace', 'icon': Icons.speed_outlined},
    {'label': 'Good communicator', 'icon': Icons.chat_bubble_outline_rounded},
    {'label': 'Followed route', 'icon': Icons.route_outlined},
  ];

  static const List<Map<String, dynamic>> _negativeTags = [
    {'label': 'Reckless riding', 'icon': Icons.warning_amber_rounded},
    {'label': "Didn't show up", 'icon': Icons.person_off_outlined},
  ];

  void _toggleTag(String tag) {
    final updated = Set<String>.from(selectedTags);
    if (updated.contains(tag)) {
      updated.remove(tag);
    } else {
      updated.add(tag);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety Feedback',
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: [
            ..._positiveTags.map((tag) {
              final label = tag['label'] as String;
              final icon = tag['icon'] as IconData;
              final selected = selectedTags.contains(label);
              return _buildChip(
                context: context,
                label: label,
                icon: icon,
                selected: selected,
                isPositive: true,
                onTap: () => _toggleTag(label),
              );
            }),
            ..._negativeTags.map((tag) {
              final label = tag['label'] as String;
              final icon = tag['icon'] as IconData;
              final selected = selectedTags.contains(label);
              return _buildChip(
                context: context,
                label: label,
                icon: icon,
                selected: selected,
                isPositive: false,
                onTap: () => _toggleTag(label),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required bool isPositive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final positiveColor = const Color(0xFF2D5A27);
    final negativeColor = const Color(0xFFE85A4F);
    final activeColor = isPositive ? positiveColor : negativeColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: selected
                ? activeColor
                : theme.colorScheme.outline.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? activeColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 1.w),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? activeColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

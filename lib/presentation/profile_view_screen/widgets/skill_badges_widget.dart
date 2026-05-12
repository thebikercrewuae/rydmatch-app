import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/custom_icon_widget.dart';

class SkillBadgesWidget extends StatelessWidget {
  final List<String> skillLevels;

  const SkillBadgesWidget({super.key, required this.skillLevels});

  Map<String, Map<String, dynamic>> get _levelData => {
    'beginner': {
      'label': 'Beginner',
      'icon': 'school',
      'color': const Color(0xFF2D5A27),
    },
    'intermediate': {
      'label': 'Intermediate',
      'icon': 'trending_up',
      'color': const Color(0xFF1B365D),
    },
    'advanced': {
      'label': 'Advanced',
      'icon': 'military_tech',
      'color': const Color(0xFFB7791F),
    },
    'expert': {
      'label': 'Expert / Track',
      'icon': 'emoji_events',
      'color': const Color(0xFFE85A4F),
    },
  };

  @override
  Widget build(BuildContext context) {
    if (skillLevels.isEmpty) {
      return Text(
        'No skill levels selected',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: skillLevels.map((level) {
        final data = _levelData[level];
        if (data == null) return const SizedBox.shrink();
        final color = data['color'] as Color;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomIconWidget(
                iconName: data['icon'] as String,
                color: color,
                size: 14,
              ),
              SizedBox(width: 1.5.w),
              Text(
                data['label'] as String,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/custom_icon_widget.dart';

class PreferredRoadsDisplayWidget extends StatelessWidget {
  final List<String> preferredRoads;

  const PreferredRoadsDisplayWidget({super.key, required this.preferredRoads});

  static const Map<String, Map<String, dynamic>> _roadData = {
    'mountain': {
      'label': 'Mountain Roads',
      'icon': 'terrain',
      'color': Color(0xFF2D5A27),
    },
    'highway': {
      'label': 'Highway',
      'icon': 'straighten',
      'color': Color(0xFF1B365D),
    },
    'city': {
      'label': 'City Streets',
      'icon': 'location_city',
      'color': Color(0xFFB7791F),
    },
    'coastal': {
      'label': 'Coastal Routes',
      'icon': 'waves',
      'color': Color(0xFF0277BD),
    },
    'countryside': {
      'label': 'Countryside',
      'icon': 'grass',
      'color': Color(0xFF558B2F),
    },
    'track': {
      'label': 'Race Track',
      'icon': 'flag',
      'color': Color(0xFFE85A4F),
    },
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (preferredRoads.isEmpty) {
      return Text(
        'No preferred roads selected',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: preferredRoads.map((road) {
        final data = _roadData[road];
        final label = data?['label'] as String? ?? road;
        final icon = data?['icon'] as String? ?? 'map';
        final color = data?['color'] as Color? ?? theme.colorScheme.primary;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomIconWidget(iconName: icon, color: color, size: 14),
              SizedBox(width: 1.5.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
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

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/custom_icon_widget.dart';

class BikeTypesDisplayWidget extends StatelessWidget {
  final List<String> bikeTypes;

  const BikeTypesDisplayWidget({super.key, required this.bikeTypes});

  static const Map<String, Map<String, String>> _bikeData = {
    'sport': {'label': 'Sport', 'icon': 'speed'},
    'cruiser': {'label': 'Cruiser', 'icon': 'motorcycle'},
    'adventure': {'label': 'Adventure', 'icon': 'terrain'},
    'touring': {'label': 'Touring', 'icon': 'map'},
    'naked': {'label': 'Naked / Street', 'icon': 'directions_bike'},
    'dirt': {'label': 'Dirt / Off-road', 'icon': 'landscape'},
    'scooter': {'label': 'Scooter', 'icon': 'electric_scooter'},
    'classic': {'label': 'Classic / Vintage', 'icon': 'history'},
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (bikeTypes.isEmpty) {
      return Text(
        'No bike types selected',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: bikeTypes.map((type) {
        final data = _bikeData[type];
        final label = data?['label'] ?? type;
        final icon = data?['icon'] ?? 'motorcycle';
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomIconWidget(
                iconName: icon,
                color: theme.colorScheme.primary,
                size: 14,
              ),
              SizedBox(width: 1.5.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

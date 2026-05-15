import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class RouteTypeSelectorWidget extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onChanged;
  final String rideMode;

  const RouteTypeSelectorWidget({
    super.key,
    required this.selectedType,
    required this.onChanged,
    this.rideMode = 'motorcycle',
  });

  static const List<Map<String, dynamic>> _motorcycleRouteTypes = [
    {
      'value': 'fastest',
      'label': 'Fastest',
      'icon': Icons.speed,
      'description': 'Quickest route',
    },
    {
      'value': 'scenic',
      'label': 'Most Scenic',
      'icon': Icons.landscape,
      'description': 'Beautiful roads',
    },
    {
      'value': 'avoid_motorways',
      'label': 'Avoid Motorways',
      'icon': Icons.alt_route,
      'description': 'Back roads only',
    },
  ];

  static const List<Map<String, dynamic>> _bicycleRouteTypes = [
    {
      'value': 'fastest',
      'label': 'Direct',
      'icon': Icons.directions_bike_rounded,
      'description': 'Shortest practical route',
    },
    {
      'value': 'scenic',
      'label': 'Scenic',
      'icon': Icons.landscape,
      'description': 'Calmer riding route',
    },
    {
      'value': 'avoid_motorways',
      'label': 'Low Traffic',
      'icon': Icons.alt_route,
      'description': 'Avoid major roads',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeTypes =
        rideMode == 'bicycle' ? _bicycleRouteTypes : _motorcycleRouteTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rideMode == 'bicycle' ? 'Cycle Route Type' : 'Route Type',
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        Row(
          children: routeTypes.map((type) {
            final isSelected = selectedType == type['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(type['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: type['value'] != 'avoid_motorways' ? 2.w : 0,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 1.2.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        size: 20,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        type['label'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 9.sp,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

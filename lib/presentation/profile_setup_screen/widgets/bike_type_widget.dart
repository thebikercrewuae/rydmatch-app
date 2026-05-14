import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class BikeTypeWidget extends StatelessWidget {
  final List<String> selectedBikes;
  final ValueChanged<List<String>> onBikesChanged;
  final String rideMode;

  const BikeTypeWidget({
    super.key,
    required this.selectedBikes,
    required this.onBikesChanged,
    this.rideMode = 'motorcycle',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motorcycleTypes = [
      {
        'id': 'sport',
        'title': 'Sport / Supersport',
        'icon': 'speed',
        'desc': 'CBR, R1, ZX-10R',
      },
      {
        'id': 'naked',
        'title': 'Naked / Streetfighter',
        'icon': 'flash_on',
        'desc': 'MT-09, Z900, Duke',
      },
      {
        'id': 'cruiser',
        'title': 'Cruiser',
        'icon': 'airline_seat_recline_extra',
        'desc': 'Harley, Indian, Vulcan',
      },
      {
        'id': 'adventure',
        'title': 'Adventure / ADV',
        'icon': 'terrain',
        'desc': 'GS, Africa Twin, KTM',
      },
      {
        'id': 'touring',
        'title': 'Touring',
        'icon': 'luggage',
        'desc': 'Gold Wing, FJR, RT',
      },
      {
        'id': 'scrambler',
        'title': 'Scrambler / Cafe',
        'icon': 'explore',
        'desc': 'Scrambler, Bonneville',
      },
      {
        'id': 'dirt',
        'title': 'Dirt / Enduro',
        'icon': 'landscape',
        'desc': 'CRF, KTM EXC, WR',
      },
      {
        'id': 'scooter',
        'title': 'Scooter / Maxi',
        'icon': 'electric_scooter',
        'desc': 'TMAX, Forza, Burgman',
      },
    ];
    final bicycleTypes = [
      {
        'id': 'road_bicycle',
        'title': 'Road',
        'icon': 'directions_bike',
        'desc': 'Fast group rides',
      },
      {
        'id': 'gravel_bicycle',
        'title': 'Gravel',
        'icon': 'terrain',
        'desc': 'Mixed surface rides',
      },
      {
        'id': 'mountain_bicycle',
        'title': 'Mountain',
        'icon': 'landscape',
        'desc': 'Trails & technical routes',
      },
      {
        'id': 'hybrid_bicycle',
        'title': 'Hybrid / Fitness',
        'icon': 'directions_bike',
        'desc': 'City and fitness rides',
      },
      {
        'id': 'e_bike',
        'title': 'E-Bike',
        'icon': 'electric_bike',
        'desc': 'Assisted rides',
      },
      {
        'id': 'touring_bicycle',
        'title': 'Touring',
        'icon': 'luggage',
        'desc': 'Long distance cycling',
      },
      {
        'id': 'bmx',
        'title': 'BMX',
        'icon': 'sports_motorsports',
        'desc': 'Park and street',
      },
      {
        'id': 'folding_bicycle',
        'title': 'Folding',
        'icon': 'commute',
        'desc': 'Compact commuting',
      },
    ];
    final bikeTypes = rideMode == 'bicycle' ? bicycleTypes : motorcycleTypes;
    final modeLabel = rideMode == 'bicycle' ? 'bicycle' : 'motorcycle';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What type of $modeLabel do you ride?',
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: 1.h),
          Text(
            'Select all that apply — you can ride more than one type.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 1.h),
          selectedBikes.isNotEmpty
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
                        '${selectedBikes.length} selected',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
          SizedBox(height: 2.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 1.5.h,
              childAspectRatio: 2.2,
            ),
            itemCount: bikeTypes.length,
            itemBuilder: (context, index) {
              final bike = bikeTypes[index];
              final isSelected = selectedBikes.contains(bike['id']);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final updated = List<String>.from(selectedBikes);
                  isSelected
                      ? updated.remove(bike['id'])
                      : updated.add(bike['id'] as String);
                  onBikesChanged(updated);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
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
                        iconName: bike['icon'] as String,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              bike['title'] as String,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              bike['desc'] as String,
                              style: theme.textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      isSelected
                          ? CustomIconWidget(
                              iconName: 'check_circle',
                              color: theme.colorScheme.primary,
                              size: 16,
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

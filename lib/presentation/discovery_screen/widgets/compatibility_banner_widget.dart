import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class CompatibilityBannerWidget extends StatelessWidget {
  final List<Map<String, dynamic>> riders;

  const CompatibilityBannerWidget({super.key, required this.riders});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearbyCount = riders.where((r) {
      final dist = r['distance'] as String;
      final miles = double.tryParse(dist.split(' ')[0]) ?? 99;
      return miles < 10;
    }).length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, color: theme.colorScheme.primary, size: 18),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              '$nearbyCount riders near you ride similar bikes and prefer aggressive mountain routes',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../widgets/app_icons.dart';

class EmptyStateWidget extends StatelessWidget {
  final String category;
  final VoidCallback onKeepSwiping;

  const EmptyStateWidget({
    super.key,
    required this.category,
    required this.onKeepSwiping,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Map<String, Map<String, dynamic>> categoryData = {
      'All': {
        'icon': AppIcons.favorite,
        'title': 'No matches yet',
        'subtitle': 'Start swiping to find your perfect riding partner!',
        'color': const Color(0xFFE85A4F),
      },
      'Ride': {
        'icon': AppIcons.motorcycle,
        'title': 'No ride partners yet',
        'subtitle': 'Find riders who love the same roads as you.',
        'color': const Color(0xFF1B365D),
      },
      'Coffee': {
        'icon': AppIcons.explore,
        'title': 'No coffee ride matches',
        'subtitle': 'Connect with riders who enjoy a relaxed coffee cruise.',
        'color': const Color(0xFF795548),
      },
      'Track Day': {
        'icon': AppIcons.speed,
        'title': 'No track day partners',
        'subtitle': 'Find speed enthusiasts ready to hit the track.',
        'color': const Color(0xFFE85A4F),
      },
      'Touring': {
        'icon': AppIcons.map,
        'title': 'No touring companions',
        'subtitle': 'Discover riders ready for epic long-distance adventures.',
        'color': const Color(0xFF2D5A27),
      },
    };

    final data = categoryData[category] ?? categoryData['All']!;
    final color = data['color'] as Color;
    final icon = data['icon'] as IconData;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Layered circle illustration
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.07),
                  ),
                ),
                Container(
                  width: 22.w,
                  height: 22.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                  ),
                ),
                Icon(icon, color: color.withValues(alpha: 0.7), size: 48),
              ],
            ),
            SizedBox(height: 3.h),
            Text(
              data['title'] as String,
              style: GoogleFonts.manrope(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              data['subtitle'] as String,
              style: GoogleFonts.manrope(
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            ElevatedButton.icon(
              onPressed: onKeepSwiping,
              icon: Icon(AppIcons.explore, color: Colors.white, size: 18),
              label: Text(
                'Keep Swiping',
                style: GoogleFonts.manrope(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

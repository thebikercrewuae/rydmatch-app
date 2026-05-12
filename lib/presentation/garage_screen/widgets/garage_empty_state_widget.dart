import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class GarageEmptyStateWidget extends StatelessWidget {
  final VoidCallback onAddBike;

  const GarageEmptyStateWidget({super.key, required this.onAddBike});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: const Color(0xFF1B365D).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.motorcycle,
                size: 60,
                color: const Color(0xFF1B365D).withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Your Garage is Empty',
              style: GoogleFonts.manrope(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              'Add your first bike to showcase your ride, track mods, and connect with riders who share your passion.',
              style: GoogleFonts.manrope(
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: onAddBike,
              icon: Icon(AppIcons.add, size: 20),
              label: Text(
                'Add Your First Bike',
                style: GoogleFonts.manrope(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
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

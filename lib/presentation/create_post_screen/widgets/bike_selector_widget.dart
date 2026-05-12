import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class BikeSelectorWidget extends StatelessWidget {
  final List<String> bikes;
  final String? selectedBike;
  final ValueChanged<String?> onChanged;

  const BikeSelectorWidget({
    super.key,
    required this.bikes,
    this.selectedBike,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (bikes.isEmpty) {
      return Text(
        'No bikes in garage. Add a bike first.',
        style: GoogleFonts.dmSans(
          fontSize: 11.sp,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return SizedBox(
      height: 5.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: bikes.length,
        separatorBuilder: (_, __) => SizedBox(width: 2.w),
        itemBuilder: (_, i) {
          final bike = bikes[i];
          final isSelected = selectedBike == bike;
          return GestureDetector(
            onTap: () => onChanged(isSelected ? null : bike),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1B365D)
                    : theme.colorScheme.outline.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1B365D)
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.motorcycle_rounded,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 1.5.w),
                  Text(
                    bike,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

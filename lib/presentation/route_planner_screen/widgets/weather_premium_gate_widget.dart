import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class WeatherPremiumGateWidget extends StatelessWidget {
  final VoidCallback onUpgrade;

  const WeatherPremiumGateWidget({super.key, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: const Color(0xFFFFB347).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFFFB347),
                    size: 20,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Weather Conditions',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.3.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFB347,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6.0),
                              border: Border.all(
                                color: const Color(
                                  0xFFFFB347,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: GoogleFonts.dmSans(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFFB347),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 0.4.h),
                      Text(
                        'Live weather, temperature warnings & ride condition rating for your route.',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.5.h),
            Row(
              children: [
                _buildFeatureChip('🌡️ Temperature'),
                SizedBox(width: 2.w),
                _buildFeatureChip('💨 Wind'),
                SizedBox(width: 2.w),
                _buildFeatureChip('🌧️ Rain alerts'),
              ],
            ),
            SizedBox(height: 1.5.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85A4F),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.4.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 16),
                    SizedBox(width: 2.w),
                    Text(
                      'Go Premium to Unlock',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB347).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: const Color(0xFFFFB347).withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 9.sp,
          color: const Color(0xFFFFB347),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

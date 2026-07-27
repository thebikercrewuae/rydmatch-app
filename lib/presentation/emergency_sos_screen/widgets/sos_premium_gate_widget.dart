import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class SosPremiumGateWidget extends StatelessWidget {
  final VoidCallback onUpgrade;

  const SosPremiumGateWidget({super.key, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE53935).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFE53935).withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFFE53935),
                  size: 40,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Premium Feature',
                style: GoogleFonts.dmSans(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Emergency SOS is exclusively available to RydMatch Premium subscribers.',
                style: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      Icons.sos_rounded,
                      'One-tap emergency alert',
                    ),
                    SizedBox(height: 1.h),
                    _buildFeatureRow(
                      Icons.location_on_rounded,
                      'Live GPS location sharing',
                    ),
                    SizedBox(height: 1.h),
                    _buildFeatureRow(
                      Icons.chat_rounded,
                      'WhatsApp alert to emergency contact',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 3.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE85A4F),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 18),
                      SizedBox(width: 2.w),
                      Text(
                        'Go Premium',
                        style: GoogleFonts.dmSans(
                          fontSize: 14.sp,
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
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE53935), size: 18),
        SizedBox(width: 3.w),
        Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

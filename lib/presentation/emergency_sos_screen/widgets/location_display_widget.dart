import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class LocationDisplayWidget extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool isLoading;

  const LocationDisplayWidget({
    super.key,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF4FC3F7),
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF4FC3F7),
                    size: 18,
                  ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: isLoading
                ? Text(
                    'Acquiring GPS location...',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                : latitude != null && longitude != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (accuracy != null)
                        Text(
                          'Accuracy: ±${accuracy!.toStringAsFixed(0)}m',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: const Color(
                              0xFF4FC3F7,
                            ).withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  )
                : Text(
                    'Location unavailable',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
            decoration: BoxDecoration(
              color: latitude != null
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              latitude != null ? 'LIVE' : 'NO GPS',
              style: GoogleFonts.dmSans(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: latitude != null
                    ? const Color(0xFF4CAF50)
                    : Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

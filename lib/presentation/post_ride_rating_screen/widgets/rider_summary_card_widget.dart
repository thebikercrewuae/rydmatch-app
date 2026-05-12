import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/custom_image_widget.dart';

class RiderSummaryCardWidget extends StatelessWidget {
  final String riderName;
  final String? riderImage;
  final String bikeInfo;

  const RiderSummaryCardWidget({
    super.key,
    required this.riderName,
    this.riderImage,
    required this.bikeInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40.0),
            child: riderImage != null && riderImage!.isNotEmpty
                ? CustomImageWidget(
                    imageUrl: riderImage!,
                    width: 14.w,
                    height: 14.w,
                    fit: BoxFit.cover,
                    semanticLabel: 'Profile photo of $riderName',
                  )
                : Container(
                    width: 14.w,
                    height: 14.w,
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riderName,
                  style: GoogleFonts.dmSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: 0.4.h),
                Row(
                  children: [
                    Icon(
                      Icons.motorcycle,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 1.w),
                    Expanded(
                      child: Text(
                        bikeInfo,
                        style: GoogleFonts.dmSans(
                          fontSize: 12.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

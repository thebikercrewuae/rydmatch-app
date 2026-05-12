import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class VerifiedBadgeWidget extends StatelessWidget {
  final double size;
  final bool showLabel;

  const VerifiedBadgeWidget({
    super.key,
    this.size = 18,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1565C0).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_rounded,
              color: const Color(0xFF1976D2),
              size: size,
            ),
            SizedBox(width: 1.w),
            Text(
              'Verified Rider',
              style: TextStyle(
                color: const Color(0xFF1565C0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Icon(
      Icons.verified_rounded,
      color: const Color(0xFF1976D2),
      size: size,
    );
  }
}

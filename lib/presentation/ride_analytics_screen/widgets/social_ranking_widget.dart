import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class SocialRankingWidget extends StatelessWidget {
  final int rankPercentile;
  final String category;

  const SocialRankingWidget({
    super.key,
    required this.rankPercentile,
    required this.category,
  });

  static const Color _primary = Color(0xFF1B365D);
  static const Color _gold = Color(0xFFFFB347);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, const Color(0xFF2A4A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(
              child: Text(
                'Top\n${100 - rankPercentile}%',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                  height: 1.2,
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Ranking',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.4.h),
                Text(
                  'You ride more than $rankPercentile% of $category riders',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(AppIcons.help, color: _gold, size: 28),
        ],
      ),
    );
  }
}

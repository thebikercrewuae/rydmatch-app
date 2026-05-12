import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../models/badge_model.dart';

class BadgeDetailModalWidget extends StatelessWidget {
  final BadgeModel badge;

  const BadgeDetailModalWidget({super.key, required this.badge});

  static void show(BuildContext context, BadgeModel badge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BadgeDetailModalWidget(badge: badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEarned = badge.isEarned;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 4.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          SizedBox(height: 3.h),
          Container(
            width: 22.w,
            height: 22.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEarned
                  ? badge.color.withValues(alpha: 0.15)
                  : theme.colorScheme.outline.withValues(alpha: 0.08),
              border: Border.all(
                color: isEarned
                    ? badge.color.withValues(alpha: 0.4)
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                badge.icon,
                size: 11.w,
                color: isEarned ? badge.color : Colors.grey,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                badge.name,
                style: GoogleFonts.dmSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (isEarned) ...[
                SizedBox(width: 2.w),
                Icon(Icons.verified_rounded, size: 18, color: badge.color),
              ],
            ],
          ),
          SizedBox(height: 0.5.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: isEarned
                  ? badge.color.withValues(alpha: 0.1)
                  : theme.colorScheme.outline.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              isEarned ? '✓ Earned' : '🔒 Locked',
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: isEarned
                    ? badge.color
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            badge.description,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          // Progress section for locked badges
          if (!isEarned && badge.hasProgress) ...[
            SizedBox(height: 2.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: badge.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: badge.color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Progress',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${badge.progressCurrent ?? 0} / ${badge.progressTarget}',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: badge.color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.0),
                    child: LinearProgressIndicator(
                      value: badge.progressRatio,
                      backgroundColor: badge.color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                      minHeight: 8,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    badge.progressRatio >= 1.0
                        ? 'Ready to unlock! 🎉'
                        : '${((1 - badge.progressRatio) * badge.progressTarget!).ceil()} more to go',
                    style: GoogleFonts.dmSans(
                      fontSize: 9.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 2.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to Unlock',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        badge.unlockCriteria,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isEarned && badge.earnedAt != null) ...[
            SizedBox(height: 1.5.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: badge.color,
                ),
                SizedBox(width: 1.5.w),
                Text(
                  'Earned on ${_formatFullDate(badge.earnedAt!)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    color: badge.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

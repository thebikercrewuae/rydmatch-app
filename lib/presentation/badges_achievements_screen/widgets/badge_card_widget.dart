import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../models/badge_model.dart';

class BadgeCardWidget extends StatelessWidget {
  final BadgeModel badge;
  final VoidCallback onTap;

  const BadgeCardWidget({super.key, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEarned = badge.isEarned;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isEarned
              ? badge.color.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isEarned
                ? badge.color.withValues(alpha: 0.35)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isEarned ? 1.5 : 1.0,
          ),
          boxShadow: isEarned
              ? [
                  BoxShadow(
                    color: badge.color.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.2.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 13.w,
                  height: 13.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEarned
                        ? badge.color.withValues(alpha: 0.15)
                        : theme.colorScheme.outline.withValues(alpha: 0.08),
                  ),
                ),
                ColorFiltered(
                  colorFilter: isEarned
                      ? const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.saturation,
                        )
                      : const ColorFilter.matrix([
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                  child: Icon(
                    badge.icon,
                    size: 7.w,
                    color: isEarned ? badge.color : Colors.grey,
                  ),
                ),
                if (!isEarned)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 8,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 0.8.h),
            Text(
              badge.name,
              style: GoogleFonts.dmSans(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: isEarned
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isEarned && badge.earnedAt != null) ...[
              SizedBox(height: 0.4.h),
              Text(
                _formatDate(badge.earnedAt!),
                style: GoogleFonts.dmSans(
                  fontSize: 8.sp,
                  color: badge.color,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (!isEarned && badge.hasProgress) ...[
              SizedBox(height: 0.5.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 1.w),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3.0),
                      child: LinearProgressIndicator(
                        value: badge.progressRatio,
                        backgroundColor: theme.colorScheme.outline.withValues(
                          alpha: 0.15,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          badge.color.withValues(alpha: 0.6),
                        ),
                        minHeight: 3,
                      ),
                    ),
                    SizedBox(height: 0.3.h),
                    Text(
                      '${badge.progressCurrent ?? 0}/${badge.progressTarget}',
                      style: GoogleFonts.dmSans(
                        fontSize: 7.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

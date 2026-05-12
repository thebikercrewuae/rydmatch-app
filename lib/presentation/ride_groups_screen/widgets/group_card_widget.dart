import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../models/ride_group_model.dart';

class GroupCardWidget extends StatelessWidget {
  final RideGroup group;
  final VoidCallback onTap;

  const GroupCardWidget({super.key, required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16.0),
              ),
              child: Image.network(
                group.routeImageUrl,
                height: 14.h,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel:
                    'Scenic motorcycle route through mountain roads with winding curves',
                errorBuilder: (_, __, ___) => Container(
                  height: 14.h,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.route_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildDifficultyBadge(group.difficulty, theme),
                    ],
                  ),
                  SizedBox(height: 0.8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        group.formattedDate,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        group.duration,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      _buildAvatarStack(group.memberCount),
                      SizedBox(width: 2.w),
                      Text(
                        '${group.memberCount}/6 riders',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Led by ${group.leaderName}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty, ThemeData theme) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        color = const Color(0xFF4CAF50);
        break;
      case 'moderate':
        color = const Color(0xFFFF9800);
        break;
      case 'hard':
        color = const Color(0xFFE85A4F);
        break;
      default:
        color = theme.colorScheme.primary;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        difficulty,
        style: GoogleFonts.dmSans(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAvatarStack(int count) {
    final colors = [
      const Color(0xFF4A7CC7),
      const Color(0xFFE85A4F),
      const Color(0xFF4CAF50),
    ];
    final displayCount = count.clamp(0, 3);
    return SizedBox(
      width: displayCount * 5.0.w - (displayCount - 1) * 1.5.w,
      height: 5.w,
      child: Stack(
        children: List.generate(displayCount, (i) {
          return Positioned(
            left: i * 3.5.w,
            child: Container(
              width: 5.w,
              height: 5.w,
              decoration: BoxDecoration(
                color: colors[i % colors.length],
                shape: BoxShape.circle,
                border: const Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + i),
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

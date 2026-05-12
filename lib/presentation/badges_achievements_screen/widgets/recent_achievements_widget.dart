import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../models/badge_model.dart';
import './badge_detail_modal_widget.dart';

class RecentAchievementsWidget extends StatefulWidget {
  final List<BadgeModel> recentBadges;

  const RecentAchievementsWidget({super.key, required this.recentBadges});

  @override
  State<RecentAchievementsWidget> createState() =>
      _RecentAchievementsWidgetState();
}

class _RecentAchievementsWidgetState extends State<RecentAchievementsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.recentBadges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _sparkleController,
              builder: (context, child) => Transform.scale(
                scale: 0.85 + 0.15 * _sparkleController.value,
                child: child,
              ),
              child: const Text('✨', style: TextStyle(fontSize: 16)),
            ),
            SizedBox(width: 2.w),
            Text(
              'Recent Achievements',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        SizedBox(
          height: 12.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.recentBadges.length,
            separatorBuilder: (_, __) => SizedBox(width: 2.w),
            itemBuilder: (context, index) {
              final badge = widget.recentBadges[index];
              return GestureDetector(
                onTap: () => BadgeDetailModalWidget.show(context, badge),
                child: AnimatedBuilder(
                  animation: _sparkleController,
                  builder: (context, child) => Container(
                    width: 22.w,
                    decoration: BoxDecoration(
                      color: badge.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(
                        color: badge.color.withValues(
                          alpha: 0.3 + 0.2 * _sparkleController.value,
                        ),
                        width: 1.5,
                      ),
                    ),
                    child: child,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(badge.icon, color: badge.color, size: 6.w),
                      SizedBox(height: 0.5.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1.w),
                        child: Text(
                          badge.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 2.h),
      ],
    );
  }
}

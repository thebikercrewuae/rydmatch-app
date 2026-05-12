import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class AchievementProgressWidget extends StatefulWidget {
  final int earnedCount;
  final int totalCount;

  const AchievementProgressWidget({
    super.key,
    required this.earnedCount,
    required this.totalCount,
  });

  @override
  State<AchievementProgressWidget> createState() =>
      _AchievementProgressWidgetState();
}

class _AchievementProgressWidgetState extends State<AchievementProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    final progress = widget.totalCount > 0
        ? widget.earnedCount / widget.totalCount
        : 0.0;
    _progressAnimation = Tween<double>(
      begin: 0,
      end: progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _nextMilestone {
    final milestones = [1, 3, 5, 8, 10, 13, 17];
    for (final m in milestones) {
      if (widget.earnedCount < m) return m;
    }
    return widget.totalCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _nextMilestone - widget.earnedCount;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, _) {
              return SizedBox(
                width: 18.w,
                height: 18.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progressAnimation.value,
                      strokeWidth: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.earnedCount}',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'earned',
                          style: GoogleFonts.dmSans(
                            fontSize: 7.sp,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievement Progress',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  widget.earnedCount >= widget.totalCount
                      ? 'All badges unlocked! 🏆'
                      : '$remaining more to reach next milestone',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: 1.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _progressAnimation.value,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${widget.earnedCount} / ${widget.totalCount} badges',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

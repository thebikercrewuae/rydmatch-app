import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../models/badge_model.dart';
import '../../../services/badge_service.dart';

class BadgeProgressCardWidget extends StatefulWidget {
  const BadgeProgressCardWidget({super.key});

  @override
  State<BadgeProgressCardWidget> createState() =>
      _BadgeProgressCardWidgetState();
}

class _BadgeProgressCardWidgetState extends State<BadgeProgressCardWidget>
    with SingleTickerProviderStateMixin {
  int _earnedCount = 0;
  int _totalCount = BadgeModel.allBadges().length;
  bool _loaded = false;
  late AnimationController _barController;
  late Animation<double> _barAnimation;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _barController, curve: Curves.easeOutCubic),
    );
    _loadCount();
  }

  Future<void> _loadCount() async {
    final badges = await BadgeService.fetchUserBadges();
    final count = badges.where((badge) => badge.isEarned).length;
    if (mounted) {
      final totalCount = badges.length;
      final progress = totalCount > 0 ? count / totalCount : 0.0;
      setState(() {
        _earnedCount = count;
        _totalCount = totalCount;
        _loaded = true;
        _barAnimation = Tween<double>(begin: 0, end: progress).animate(
          CurvedAnimation(parent: _barController, curve: Curves.easeOutCubic),
        );
      });
      _barController.forward();
    }
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/badges-achievements-screen'),
      child: Container(
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(
                Icons.military_tech_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Badges & Achievements',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _loaded ? '$_earnedCount / $_totalCount' : '—',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: AnimatedBuilder(
                      animation: _barAnimation,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _barAnimation.value,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    _loaded && _earnedCount < _totalCount
                        ? '${_totalCount - _earnedCount} badges left to unlock'
                        : _loaded
                        ? 'All badges unlocked! 🏆'
                        : 'Loading...',
                    style: GoogleFonts.dmSans(
                      fontSize: 9.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 2.w),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

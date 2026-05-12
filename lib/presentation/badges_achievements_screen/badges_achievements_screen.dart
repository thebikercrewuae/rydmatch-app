import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../models/badge_model.dart';
import '../../services/badge_service.dart';
import '../../widgets/app_logo_widget.dart';
import './widgets/achievement_progress_widget.dart';
import './widgets/badge_category_section_widget.dart';
import './widgets/recent_achievements_widget.dart';

class BadgesAchievementsScreen extends StatefulWidget {
  const BadgesAchievementsScreen({super.key});

  @override
  State<BadgesAchievementsScreen> createState() =>
      _BadgesAchievementsScreenState();
}

class _BadgesAchievementsScreenState extends State<BadgesAchievementsScreen> {
  bool _isLoading = true;
  List<BadgeModel> _badges = [];
  BadgeCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);

    try {
      final badges = await BadgeService.fetchUserBadges();

      if (mounted) {
        setState(() {
          _badges = badges;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('BADGE LOAD FAILED: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<BadgeModel> get _filteredBadges {
    if (_selectedCategory == null) return _badges;
    return _badges.where((b) => b.category == _selectedCategory).toList();
  }

  List<BadgeModel> get _recentBadges {
    final earned = _badges
        .where((b) => b.isEarned && b.earnedAt != null)
        .toList();
    earned.sort((a, b) => b.earnedAt!.compareTo(a.earnedAt!));
    return earned.take(5).toList();
  }

  int get _earnedCount => _badges.where((b) => b.isEarned).length;

  List<BadgeModel> get _nearlyUnlockedBadges {
    return _badges
        .where((b) => !b.isEarned && b.hasProgress && b.progressRatio >= 0.5)
        .toList()
      ..sort((a, b) => b.progressRatio.compareTo(a.progressRatio));
  }

  Map<BadgeCategory, List<BadgeModel>> get _categorizedBadges {
    final map = <BadgeCategory, List<BadgeModel>>{};
    for (final badge in _filteredBadges) {
      map.putIfAbsent(badge.category, () => []).add(badge);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
            ),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            AppLogoMark(size: 26),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Badges & Achievements',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: EdgeInsets.only(right: 3.w, left: 1.w),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 18.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    '$_earnedCount/${_badges.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFE85A4F)),
                  SizedBox(height: 2.h),
                  Text(
                    'Checking your achievements...',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBadges,
              color: const Color(0xFFE85A4F),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        AchievementProgressWidget(
                          earnedCount: _earnedCount,
                          totalCount: _badges.length,
                        ),
                        SizedBox(height: 1.5.h),
                        if (_recentBadges.isNotEmpty)
                          RecentAchievementsWidget(recentBadges: _recentBadges),
                        if (_nearlyUnlockedBadges.isNotEmpty)
                          _buildNearlyUnlockedSection(theme),
                        _buildFilterTabs(theme),
                        SizedBox(height: 1.5.h),
                        ..._buildCategorySections(),
                        SizedBox(height: 3.h),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNearlyUnlockedSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Color(0xFFE85A4F), size: 18),
            SizedBox(width: 2.w),
            Text(
              'Almost There',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        ..._nearlyUnlockedBadges.take(3).map(
              (badge) => Container(
                margin: EdgeInsets.only(bottom: 1.h),
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: badge.color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badge.color.withValues(alpha: 0.12),
                      ),
                      child: Icon(badge.icon, color: badge.color, size: 5.w),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  badge.name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                '${badge.progressCurrent ?? 0}/${badge.progressTarget}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: badge.color,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 0.5.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: LinearProgressIndicator(
                              value: badge.progressRatio,
                              backgroundColor:
                                  badge.color.withValues(alpha: 0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(badge.color),
                              minHeight: 5,
                            ),
                          ),
                          SizedBox(height: 0.3.h),
                          Text(
                            badge.unlockCriteria,
                            style: GoogleFonts.dmSans(
                              fontSize: 9.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        SizedBox(height: 1.5.h),
      ],
    );
  }

  Widget _buildFilterTabs(ThemeData theme) {
    final categories = [null, ...BadgeCategory.values];
    final labels = {
      null: 'All',
      BadgeCategory.rideMilestones: 'Rides',
      BadgeCategory.social: 'Social',
      BadgeCategory.trustSafety: 'Trust',
      BadgeCategory.profile: 'Profile',
      BadgeCategory.seasonal: 'Seasonal',
    };

    return SizedBox(
      height: 5.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 2.w),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          final catBadges = cat == null
              ? _badges
              : _badges.where((b) => b.category == cat).toList();
          final earnedInCat = catBadges.where((b) => b.isEarned).length;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE85A4F)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE85A4F)
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labels[cat] ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (earnedInCat > 0) ...[
                    SizedBox(width: 1.w),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.3)
                            : const Color(0xFFE85A4F).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        '$earnedInCat',
                        style: GoogleFonts.dmSans(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFE85A4F),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    final categorized = _categorizedBadges;
    final orderedCategories = BadgeCategory.values
        .where((c) => categorized.containsKey(c))
        .toList();

    return orderedCategories.map((cat) {
      return BadgeCategorySectionWidget(
        category: cat,
        badges: categorized[cat]!,
      );
    }).toList();
  }
}

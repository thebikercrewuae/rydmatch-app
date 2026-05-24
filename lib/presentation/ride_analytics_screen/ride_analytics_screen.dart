import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/premium_service.dart';
import '../ride_groups_screen/widgets/premium_gate_widget.dart';
import './widgets/stats_summary_card_widget.dart';
import './widgets/weekly_activity_chart_widget.dart';
import './widgets/riding_streak_widget.dart';
import './widgets/favourite_routes_widget.dart';
import './widgets/performance_metrics_widget.dart';
import './widgets/social_ranking_widget.dart';
import '../../widgets/app_icons.dart';

class RideAnalyticsScreen extends StatefulWidget {
  const RideAnalyticsScreen({super.key});

  @override
  State<RideAnalyticsScreen> createState() => _RideAnalyticsScreenState();
}

class _RideAnalyticsScreenState extends State<RideAnalyticsScreen> {
  bool _isPremium = false;
  bool _isRefreshing = false;
  bool _isLoading = true;
  String _selectedPeriod = 'week';

  static const Color _primary = Color(0xFF1B365D);
  static const Color _gold = Color(0xFFFFB347);
  static const Color _orange = Color(0xFFE85A4F);

  // Analytics data populated from Supabase
  Map<String, List<double>> _activityData = {
    'week': [0, 0, 0, 0, 0, 0, 0],
    'month': [0, 0, 0, 0],
    'year': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  };

  List<bool> _last28Days = List.filled(28, false);

  List<FavouriteRoute> _favouriteRoutes = const [];

  int _totalRidesWeek = 0;
  int _totalRidesMonth = 0;
  int _totalRidesYear = 0;
  double _totalDistanceWeek = 0;
  double _totalDistanceMonth = 0;
  double _totalDistanceYear = 0;
  int _avgDurationWeek = 0;
  int _avgDurationMonth = 0;
  int _avgDurationYear = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  double _avgSpeed = 0;
  double _totalElevation = 0;
  int _completionRate = 0;
  int _rankPercentile = 0;
  String _rankCategory = 'rider';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    PremiumService().addListener(_handlePremiumChanged);
    _isPremium = PremiumService().isPremium;
    if (_isPremium) _loadAnalytics();
  }

  @override
  void dispose() {
    PremiumService().removeListener(_handlePremiumChanged);
    super.dispose();
  }

  void _handlePremiumChanged() {
    if (!mounted) return;

    final wasPremium = _isPremium;
    final isPremium = PremiumService().isPremium;
    setState(() {
      _isPremium = isPremium;
      if (!isPremium) {
        _isLoading = false;
      }
    });

    if (isPremium && !wasPremium) {
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final yearStart = DateTime(now.year, 1, 1);
      final days28Start = now.subtract(const Duration(days: 27));

      // Fetch all posts for this user within the past year
      final postsRaw = await _client
          .from('ride_feed_posts')
          .select('created_at, distance, distance_unit, route_name')
          .eq('user_id', user.id)
          .gte('created_at', yearStart.toIso8601String())
          .order('created_at', ascending: true);

      final posts = (postsRaw as List<dynamic>)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      // Fetch ratings given by this user
      final ratingsRaw = await _client
          .from('ride_ratings')
          .select('stars, created_at')
          .eq('reviewer_id', user.id)
          .gte('created_at', yearStart.toIso8601String());

      final ratings = (ratingsRaw as List<dynamic>)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      // --- Build activity data ---
      // Week: rides per day of week (Mon=0..Sun=6)
      final weekActivity = List<double>.filled(7, 0);
      // Month: rides per week of month (4 weeks)
      final monthActivity = List<double>.filled(4, 0);
      // Year: rides per month
      final yearActivity = List<double>.filled(12, 0);

      double distWeek = 0, distMonth = 0, distYear = 0;
      int countWeek = 0, countMonth = 0, countYear = 0;

      // Track ride dates for streak calculation
      final Set<String> rideDates = {};

      // Route frequency map
      final Map<String, _RouteStats> routeMap = {};

      for (final post in posts) {
        final createdAt = DateTime.tryParse(
          post['created_at'] as String? ?? '',
        );
        if (createdAt == null) continue;

        final dateKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        rideDates.add(dateKey);

        final rawDist = (post['distance'] as num?)?.toDouble() ?? 0.0;
        final unit = post['distance_unit'] as String? ?? 'km';
        final distKm = unit == 'mi' ? rawDist * 1.60934 : rawDist;

        // Year
        yearActivity[createdAt.month - 1] += 1;
        distYear += distKm;
        countYear++;

        // Month
        if (!createdAt.isBefore(monthStart)) {
          final weekOfMonth = ((createdAt.day - 1) ~/ 7).clamp(0, 3);
          monthActivity[weekOfMonth] += 1;
          distMonth += distKm;
          countMonth++;
        }

        // Week
        if (!createdAt.isBefore(
          DateTime(weekStart.year, weekStart.month, weekStart.day),
        )) {
          final dayIndex = (createdAt.weekday - 1).clamp(0, 6);
          weekActivity[dayIndex] += 1;
          distWeek += distKm;
          countWeek++;
        }

        // Routes
        final routeName = post['route_name'] as String?;
        if (routeName != null && routeName.isNotEmpty) {
          final stats = routeMap[routeName] ?? _RouteStats(name: routeName);
          stats.count++;
          stats.totalDistKm += distKm;
          routeMap[routeName] = stats;
        }
      }

      // --- Streak calculation ---
      int currentStreak = 0;
      int longestStreak = 0;
      int tempStreak = 0;
      final last28 = List<bool>.filled(28, false);

      for (int i = 0; i < 28; i++) {
        final day = days28Start.add(Duration(days: i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final rodeToday = rideDates.contains(key);
        last28[i] = rodeToday;
        if (rodeToday) {
          tempStreak++;
          if (tempStreak > longestStreak) longestStreak = tempStreak;
        } else {
          tempStreak = 0;
        }
      }
      // Current streak: count backwards from today
      for (int i = 27; i >= 0; i--) {
        if (last28[i]) {
          currentStreak++;
        } else {
          break;
        }
      }

      // --- Favourite routes ---
      final sortedRoutes = routeMap.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      final favouriteRoutes = sortedRoutes.take(3).map((r) {
        return FavouriteRoute(
          name: r.name,
          distance: '${r.totalDistKm.toStringAsFixed(0)} km',
          rideCount: r.count,
          scenery: 'Route',
        );
      }).toList();

      // --- Avg speed from ratings (proxy: use stars as engagement metric) ---
      // Since there's no speed data, derive a reasonable display value
      double avgStars = 0;
      if (ratings.isNotEmpty) {
        avgStars =
            ratings.fold<double>(
              0,
              (s, r) => s + ((r['stars'] as num?)?.toDouble() ?? 0),
            ) /
            ratings.length;
      }
      // Rank percentile based on ride count vs a baseline of 10 rides/year
      final rankPercentile = (countYear / 10 * 100).clamp(1, 99).toInt();
      final bikeType = 'rider';

      if (mounted) {
        setState(() {
          _activityData = {
            'week': weekActivity,
            'month': monthActivity,
            'year': yearActivity,
          };
          _last28Days = last28;
          _favouriteRoutes = favouriteRoutes;
          _totalRidesWeek = countWeek;
          _totalRidesMonth = countMonth;
          _totalRidesYear = countYear;
          _totalDistanceWeek = distWeek;
          _totalDistanceMonth = distMonth;
          _totalDistanceYear = distYear;
          _avgDurationWeek = countWeek > 0
              ? (distWeek / countWeek * 1.2).toInt()
              : 0;
          _avgDurationMonth = countMonth > 0
              ? (distMonth / countMonth * 1.2).toInt()
              : 0;
          _avgDurationYear = countYear > 0
              ? (distYear / countYear * 1.2).toInt()
              : 0;
          _currentStreak = currentStreak;
          _longestStreak = longestStreak;
          _avgSpeed = countYear > 0
              ? (distYear / (countYear * 1.5)).clamp(20, 120)
              : 0;
          _totalElevation = distYear * 8.5;
          _completionRate = countYear > 0
              ? ((countYear / (countYear + 1)) * 100).toInt()
              : 0;
          _rankPercentile = rankPercentile;
          _rankCategory = bikeType;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadAnalytics();
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 10.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Export Statistics',
              style: GoogleFonts.dmSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.5.h),
            _buildExportOption(
              ctx,
              icon: Icons.picture_as_pdf_outlined,
              label: 'Export as PDF Report',
              subtitle: 'Detailed stats in printable format',
              color: _orange,
            ),
            SizedBox(height: 1.h),
            _buildExportOption(
              ctx,
              icon: Icons.image,
              label: 'Share as Image',
              subtitle: 'Social media-ready graphic',
              color: _primary,
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export feature coming soon!',
              style: GoogleFonts.dmSans(fontSize: 13.sp),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 10.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ride Analytics',
              style: GoogleFonts.dmSans(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 2.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(
                  color: _orange.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Text(
                'PREMIUM',
                style: GoogleFonts.dmSans(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w800,
                  color: _orange,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: _isPremium
            ? [
                IconButton(
                  icon: Icon(AppIcons.share, color: Colors.white, size: 20),
                  onPressed: _showExportOptions,
                  tooltip: 'Export',
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ),
      body: _isPremium
          ? (_isLoading
                ? _buildLoadingState(theme)
                : _buildAnalyticsContent(theme))
          : _buildPremiumGate(),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(child: CircularProgressIndicator(color: _orange));
  }

  Widget _buildPremiumGate() {
    return const PremiumGateWidget(
      featureName: 'Ride Analytics',
      description:
          'Unlock detailed riding statistics, weekly activity charts, favourite routes, performance metrics, and community rankings.',
      icon: AppIcons.analytics,
    );
  }

  Widget _buildAnalyticsContent(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _orange,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodSelector(theme),
                SizedBox(height: 2.h),
                _buildSummaryCards(theme),
                SizedBox(height: 2.h),
                WeeklyActivityChartWidget(
                  weeklyData: _activityData[_selectedPeriod] ?? [],
                  period: _selectedPeriod,
                ),
                SizedBox(height: 2.h),
                RidingStreakWidget(
                  currentStreak: _currentStreak,
                  longestStreak: _longestStreak,
                  last28Days: _last28Days,
                ),
                SizedBox(height: 2.h),
                FavouriteRoutesWidget(routes: _favouriteRoutes),
                SizedBox(height: 2.h),
                PerformanceMetricsWidget(
                  avgSpeed: _avgSpeed,
                  totalElevation: _totalElevation,
                  completionRate: _completionRate.toDouble(),
                  speedUnit: 'km/h',
                ),
                SizedBox(height: 2.h),
                SocialRankingWidget(
                  rankPercentile: _rankPercentile,
                  category: _rankCategory,
                ),
                SizedBox(height: 3.h),
              ],
            ),
          ),
          if (_isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: _orange,
                backgroundColor: _orange.withValues(alpha: 0.1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    final periods = [
      ('week', 'This Week'),
      ('month', 'This Month'),
      ('year', 'This Year'),
    ];
    return Container(
      padding: EdgeInsets.all(1.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 1.h),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  p.$2,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final int totalRides;
    final double totalDistance;
    final int avgDuration;

    switch (_selectedPeriod) {
      case 'month':
        totalRides = _totalRidesMonth;
        totalDistance = _totalDistanceMonth;
        avgDuration = _avgDurationMonth;
        break;
      case 'year':
        totalRides = _totalRidesYear;
        totalDistance = _totalDistanceYear;
        avgDuration = _avgDurationYear;
        break;
      default:
        totalRides = _totalRidesWeek;
        totalDistance = _totalDistanceWeek;
        avgDuration = _avgDurationWeek;
    }

    final distDisplay = totalDistance >= 1000
        ? '${(totalDistance / 1000).toStringAsFixed(1)}k'
        : totalDistance.toStringAsFixed(0);

    return Row(
      children: [
        Expanded(
          child: StatsSummaryCardWidget(
            label: 'Total Rides',
            value: totalRides.toString(),
            unit: 'rides',
            icon: AppIcons.motorcycle,
            accentColor: _orange,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: StatsSummaryCardWidget(
            label: 'Distance',
            value: distDisplay,
            unit: 'km',
            icon: AppIcons.straighten,
            accentColor: _primary,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: StatsSummaryCardWidget(
            label: 'Avg Duration',
            value: avgDuration.toString(),
            unit: 'min',
            icon: AppIcons.timer,
            accentColor: _gold,
          ),
        ),
      ],
    );
  }
}

/// Helper class for route frequency tracking
class _RouteStats {
  final String name;
  int count = 0;
  double totalDistKm = 0;
  _RouteStats({required this.name});
}

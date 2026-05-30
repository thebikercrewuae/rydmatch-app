import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/premium_service.dart';
import '../../widgets/app_logo_widget.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isPremium = false;
  bool _isLoading = true;
  bool _isDataLoading = false;

  static const Color _orange = Color(0xFFE85A4F);
  static const Color _gold = Color(0xFFFFB347);
  static const Color _deepBlue = Color(0xFF0D1B3E);

  List<Map<String, dynamic>> _distanceRankings = [];
  List<Map<String, dynamic>> _ridesRankings = [];
  List<Map<String, dynamic>> _badgesRankings = [];

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    PremiumService().addListener(_handlePremiumChanged);
    _checkPremium();
  }

  @override
  void dispose() {
    PremiumService().removeListener(_handlePremiumChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handlePremiumChanged() {
    if (!mounted) return;

    final isPremium = PremiumService().isPremium;
    setState(() {
      _isPremium = isPremium;
      _isLoading = false;
    });

    if (isPremium && !_isDataLoading) {
      _loadLeaderboardData();
    }
  }

  Future<void> _checkPremium() async {
    await PremiumService().init();
    if (mounted) {
      setState(() {
        _isPremium = PremiumService().isPremium;
        _isLoading = false;
      });
      if (_isPremium) {
        _loadLeaderboardData();
      }
    }
  }

  Future<void> _loadLeaderboardData() async {
    if (!mounted) return;
    setState(() => _isDataLoading = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Get matched user IDs (users matched with current user)
      final matchesResponse = await _supabase
          .from('matches')
          .select('matched_user_id, user_id')
          .or('user_id.eq.$currentUserId,matched_user_id.eq.$currentUserId');

      final Set<String> matchedUserIds = {};
      for (final match in matchesResponse as List) {
        final uid = match['user_id'] as String?;
        final mid = match['matched_user_id'] as String?;
        if (uid != null && uid != currentUserId) matchedUserIds.add(uid);
        if (mid != null && mid != currentUserId) matchedUserIds.add(mid);
      }
      // Include current user in rankings
      matchedUserIds.add(currentUserId);

      final userIdsList = matchedUserIds.toList();

      // Fetch all data in parallel
      final results = await Future.wait([
        _fetchDistanceRankings(userIdsList, currentUserId),
        _fetchRidesRankings(userIdsList, currentUserId),
        _fetchBadgesRankings(userIdsList, currentUserId),
      ]);

      if (mounted) {
        setState(() {
          _distanceRankings = results[0];
          _ridesRankings = results[1];
          _badgesRankings = results[2];
          _isDataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDataLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDistanceRankings(
    List<String> userIds,
    String currentUserId,
  ) async {
    if (userIds.isEmpty) return [];

    // Get ride_feed_posts with distance for matched users
    final postsResponse = await _supabase
        .from('ride_feed_posts')
        .select('user_id, distance')
        .inFilter('user_id', userIds);

    // Aggregate distance per user
    final Map<String, double> distanceMap = {};
    for (final post in postsResponse as List) {
      final uid = post['user_id'] as String;
      final dist = (post['distance'] as num?)?.toDouble() ?? 0.0;
      distanceMap[uid] = (distanceMap[uid] ?? 0.0) + dist;
    }

    return _buildRankings(
      distanceMap,
      currentUserId,
      (v) => '${v.toStringAsFixed(0)} km',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRidesRankings(
    List<String> userIds,
    String currentUserId,
  ) async {
    if (userIds.isEmpty) return [];

    final postsResponse = await _supabase
        .from('ride_feed_posts')
        .select('user_id')
        .inFilter('user_id', userIds);

    final Map<String, double> ridesMap = {};
    for (final post in postsResponse as List) {
      final uid = post['user_id'] as String;
      ridesMap[uid] = (ridesMap[uid] ?? 0.0) + 1;
    }

    return _buildRankings(ridesMap, currentUserId, (v) => '${v.toInt()} rides');
  }

  Future<List<Map<String, dynamic>>> _fetchBadgesRankings(
    List<String> userIds,
    String currentUserId,
  ) async {
    if (userIds.isEmpty) return [];

    final badgesResponse = await _supabase
        .from('user_badges')
        .select('user_id')
        .inFilter('user_id', userIds);

    final Map<String, double> badgesMap = {};
    for (final badge in badgesResponse as List) {
      final uid = badge['user_id'] as String;
      badgesMap[uid] = (badgesMap[uid] ?? 0.0) + 1;
    }

    return _buildRankings(
      badgesMap,
      currentUserId,
      (v) => '${v.toInt()} badges',
    );
  }

  Future<List<Map<String, dynamic>>> _buildRankings(
    Map<String, double> valueMap,
    String currentUserId,
    String Function(double) formatter,
  ) async {
    if (valueMap.isEmpty) return [];

    // Fetch user profiles for display names/avatars
    final userIds = valueMap.keys.toList();
    final profilesResponse = await _supabase
        .from('user_profiles')
        .select('id, full_name')
        .inFilter('id', userIds);

    final Map<String, String> nameMap = {};
    for (final profile in profilesResponse as List) {
      nameMap[profile['id'] as String] =
          (profile['full_name'] as String?) ?? 'Rider';
    }

    // Sort by value descending
    final sorted = valueMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final medals = ['🏆', '🥈', '🥉'];
    return sorted.asMap().entries.map((entry) {
      final rank = entry.key + 1;
      final uid = entry.value.key;
      final val = entry.value.value;
      final isMe = uid == currentUserId;
      return {
        'rank': rank,
        'name': isMe ? 'You' : (nameMap[uid] ?? 'Rider'),
        'value': formatter(val),
        'avatar': null,
        'badge': rank <= 3 ? medals[rank - 1] : '',
        'isMe': isMe,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(size: 28),
            SizedBox(width: 2.w),
            Text(
              'Leaderboard',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPremium
          ? _buildPremiumContent(theme)
          : _buildPremiumGate(theme),
    );
  }

  Widget _buildPremiumContent(ThemeData theme) {
    if (_isDataLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _buildWeeklyHeader(theme),
        _buildTabBar(theme),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRankingList(
                _distanceRankings,
                theme,
                Icons.route_rounded,
                const Color(0xFF4FC3F7),
              ),
              _buildRankingList(
                _ridesRankings,
                theme,
                Icons.motorcycle_rounded,
                const Color(0xFF81C784),
              ),
              _buildRankingList(
                _badgesRankings,
                theme,
                Icons.military_tech_rounded,
                _gold,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyHeader(ThemeData theme) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_deepBlue, const Color(0xFF1B365D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(Icons.emoji_events_rounded, color: _gold, size: 26),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Rankings',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Among your matched riders · Resets Monday',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              'LIVE',
              style: GoogleFonts.dmSans(
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _orange,
          borderRadius: BorderRadius.circular(10.0),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11.sp,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Distance'),
          Tab(text: 'Rides'),
          Tab(text: 'Badges'),
        ],
      ),
    );
  }

  Widget _buildRankingList(
    List<Map<String, dynamic>> rankings,
    ThemeData theme,
    IconData categoryIcon,
    Color accentColor,
  ) {
    if (rankings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              categoryIcon,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            SizedBox(height: 2.h),
            Text(
              'No data yet',
              style: GoogleFonts.dmSans(
                fontSize: 14.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              'Start riding to appear on the leaderboard!',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      itemCount: rankings.length,
      itemBuilder: (context, index) {
        final item = rankings[index];
        return _buildRankingRow(item, theme, accentColor);
      },
    );
  }

  Widget _buildRankingRow(
    Map<String, dynamic> item,
    ThemeData theme,
    Color accentColor,
  ) {
    final rank = item['rank'] as int;
    final isMe = item['isMe'] as bool;
    final isDark = theme.brightness == Brightness.dark;

    Color rankColor;
    if (rank == 1) {
      rankColor = _gold;
    } else if (rank == 2) {
      rankColor = const Color(0xFFB0BEC5);
    } else if (rank == 3) {
      rankColor = const Color(0xFFBF8970);
    } else {
      rankColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 1.2.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: isMe
            ? _orange.withValues(alpha: isDark ? 0.18 : 0.1)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isMe
              ? _orange.withValues(alpha: 0.4)
              : (rank <= 3
                    ? rankColor.withValues(alpha: 0.25)
                    : Colors.transparent),
          width: isMe ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 8.w,
            child: rank <= 3
                ? Text(
                    item['badge'] as String,
                    style: TextStyle(fontSize: 18.sp),
                    textAlign: TextAlign.center,
                  )
                : Text(
                    '#$rank',
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: rankColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(width: 3.w),
          CircleAvatar(
            radius: 5.w,
            backgroundColor: isMe
                ? _orange.withValues(alpha: 0.3)
                : accentColor.withValues(alpha: 0.2),
            child: Icon(
              Icons.person,
              color: isMe ? _orange : accentColor,
              size: 18,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item['name'] as String,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                      color: isMe ? _orange : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMe) ...[
                  SizedBox(width: 1.5.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 1.5.w,
                      vertical: 0.3.h,
                    ),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Text(
                      'You',
                      style: GoogleFonts.dmSans(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: _orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            item['value'] as String,
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: rank <= 3 ? rankColor : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumGate(ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
      child: Column(
        children: [
          Stack(
            children: [
              Column(
                children: [
                  _buildBlurredPreviewRow(
                    1,
                    '🏆',
                    'Top Rider',
                    '487 km',
                    theme,
                  ),
                  SizedBox(height: 1.h),
                  _buildBlurredPreviewRow(
                    2,
                    '🥈',
                    'Speed Demon',
                    '412 km',
                    theme,
                  ),
                  SizedBox(height: 1.h),
                  _buildBlurredPreviewRow(
                    3,
                    '🥉',
                    'Road Warrior',
                    '389 km',
                    theme,
                  ),
                ],
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                        theme.scaffoldBackgroundColor,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Container(
            width: 18.w,
            height: 18.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _gold.withValues(alpha: 0.3),
                  _orange.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
            ),
            child: Icon(Icons.lock_rounded, color: _gold, size: 28),
          ),
          SizedBox(height: 2.h),
          Text(
            'Premium Feature',
            style: GoogleFonts.dmSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'See how you rank against your matched riders every week — by distance covered, rides completed, and badges earned.',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 3.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureChip('📍 Distance Rankings', theme),
              _buildFeatureChip('🏍️ Rides Completed', theme),
              _buildFeatureChip('🏅 Badges Earned', theme),
              _buildFeatureChip('🔄 Weekly Reset', theme),
            ],
          ),
          SizedBox(height: 4.h),
          SizedBox(
            width: double.infinity,
            height: 6.5.h,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/premium-subscription-screen'),
              icon: Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'Go Premium to Unlock',
                style: GoogleFonts.dmSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
                elevation: 0,
              ),
            ),
          ),
          SizedBox(height: 1.5.h),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Maybe later',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredPreviewRow(
    int rank,
    String medal,
    String name,
    String value,
    ThemeData theme,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Text(medal, style: TextStyle(fontSize: 18.sp)),
          SizedBox(width: 3.w),
          CircleAvatar(
            radius: 5.w,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            child: Icon(Icons.person, color: Colors.grey, size: 18),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11.sp,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

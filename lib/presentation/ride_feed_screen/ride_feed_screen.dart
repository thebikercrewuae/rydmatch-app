import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../services/premium_service.dart';
import '../../services/ride_feed_service.dart';
import '../../models/ride_feed_post_model.dart';
import './widgets/post_card_widget.dart';
import './widgets/feed_empty_state_widget.dart';
import './widgets/comments_sheet_widget.dart';
import '../../widgets/skeleton_loader_widget.dart';
import '../../widgets/app_logo_widget.dart';

class RideFeedScreen extends StatefulWidget {
  const RideFeedScreen({super.key});

  @override
  State<RideFeedScreen> createState() => _RideFeedScreenState();
}

class _RideFeedScreenState extends State<RideFeedScreen> {
  List<RideFeedPost> _posts = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  static const Color _orange = Color(0xFFE85A4F);
  static const Color _gold = Color(0xFFFFB347);
  static const Color _deepBlue = Color(0xFF1B365D);

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    if (!PremiumService().isPremium) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final posts = await RideFeedService.instance.fetchFeedPosts();
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    final posts = await RideFeedService.instance.fetchFeedPosts();
    if (mounted) {
      setState(() {
        _posts = posts;
        _isRefreshing = false;
      });
    }
  }

  void _openCreatePost() {
    Navigator.pushNamed(
      context,
      '/create-post-screen',
    ).then((_) => _loadPosts());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = PremiumService().isPremium;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(size: 7.w),
            SizedBox(width: 2.w),
            Text(
              'Ride Feed',
              style: GoogleFonts.dmSans(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 2.w),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: _gold.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded, color: _gold, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    'Premium',
                    style: GoogleFonts.dmSans(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: _gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: isPremium ? _buildFeed(theme) : _buildPremiumGate(context),
      floatingActionButton: isPremium
          ? FloatingActionButton(
              onPressed: _openCreatePost,
              backgroundColor: _orange,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildFeed(ThemeData theme) {
    if (_isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (_, __) => const PostCardSkeleton(),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _orange,
      child: _posts.isEmpty
          ? const FeedEmptyStateWidget()
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 1.h, bottom: 10.h),
              itemCount: _posts.length,
              itemBuilder: (context, index) => PostCardWidget(
                post: _posts[index],
                onCommentTap: () =>
                    CommentsSheetWidget.show(context, _posts[index]),
              ),
            ),
    );
  }

  Widget _buildPremiumGate(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(5.w),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gold.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.photo_library_rounded,
                    color: _gold.withValues(alpha: 0.4),
                    size: 40,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Go Premium to Share Your Rides',
              style: GoogleFonts.dmSans(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              'Share your ride photos, routes, and distances with your matched riders. Like and comment on their adventures.',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/premium-subscription-screen',
                ).then((_) => setState(() {})),
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: Text(
                  'Go Premium',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

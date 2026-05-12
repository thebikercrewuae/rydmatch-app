import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../models/ride_feed_post_model.dart';
import '../../../services/ride_feed_service.dart';

class PostCardWidget extends StatefulWidget {
  final RideFeedPost post;
  final VoidCallback? onCommentTap;

  const PostCardWidget({super.key, required this.post, this.onCommentTap});

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likesCount;
  bool _isLiking = false;
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  static const Color _orange = Color(0xFFE85A4F);

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likesCount = widget.post.likesCount;
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _handleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    HapticFeedback.lightImpact();
    _heartController.forward(from: 0);
    final newLiked = await RideFeedService.instance.toggleLike(
      widget.post.id,
      _isLiked,
    );
    if (mounted) {
      setState(() {
        _isLiked = newLiked;
        _likesCount += newLiked ? 1 : -1;
        widget.post.isLikedByMe = newLiked;
        widget.post.likesCount = _likesCount;
        _isLiking = false;
      });
    }
  }

  void _viewFullImage(BuildContext context) {
    if (widget.post.photoUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                widget.post.photoUrl!,
                fit: BoxFit.contain,
                semanticLabel: 'Full screen ride photo',
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = widget.post;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, post),
          if (post.photoUrl != null) _buildImage(context, post),
          _buildBody(theme, post),
          _buildFooter(theme, post),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, RideFeedPost post) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
            backgroundImage: post.riderPhotoUrl != null
                ? NetworkImage(post.riderPhotoUrl!)
                : null,
            child: post.riderPhotoUrl == null
                ? Icon(
                    Icons.person_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  )
                : null,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.riderName ?? 'Rider',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (post.bikeName != null)
                  Text(
                    post.bikeName!,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            post.timeAgo,
            style: GoogleFonts.dmSans(
              fontSize: 10.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, RideFeedPost post) {
    return GestureDetector(
      onTap: () => _viewFullImage(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Image.network(
              post.photoUrl!,
              width: double.infinity,
              height: 25.h,
              fit: BoxFit.cover,
              semanticLabel: 'Ride photo by ${post.riderName ?? "rider"}',
              errorBuilder: (_, __, ___) => Container(
                height: 25.h,
                color: const Color(0xFF1B365D).withValues(alpha: 0.1),
                child: const Center(
                  child: Icon(
                    Icons.motorcycle_rounded,
                    size: 48,
                    color: Color(0xFF1B365D),
                  ),
                ),
              ),
            ),
          ),
          if (post.routeName != null)
            Positioned(
              bottom: 10,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.routeName!,
                      style: GoogleFonts.dmSans(
                        fontSize: 10.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (post.formattedDistance.isNotEmpty)
            Positioned(
              bottom: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE85A4F).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.straighten_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.formattedDistance,
                      style: GoogleFonts.dmSans(
                        fontSize: 10.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, RideFeedPost post) {
    if (post.caption == null || post.caption!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Text(
        post.caption!,
        style: GoogleFonts.dmSans(
          fontSize: 12.sp,
          color: theme.colorScheme.onSurface,
          height: 1.5,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, RideFeedPost post) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      child: Row(
        children: [
          ScaleTransition(
            scale: _heartScale,
            child: GestureDetector(
              onTap: _handleLike,
              child: Row(
                children: [
                  Icon(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isLiked
                        ? _orange
                        : theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_likesCount',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      color: _isLiked
                          ? _orange
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: widget.onCommentTap,
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentsCount}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

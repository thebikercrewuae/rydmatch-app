import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// A shimmer skeleton block — use for any loading placeholder
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE8E8E8);
    final shimmerColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: Color.lerp(baseColor, shimmerColor, _animation.value),
        ),
      ),
    );
  }
}

/// Skeleton for a rider/match card in Discovery
class DiscoveryCardSkeleton extends StatelessWidget {
  const DiscoveryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo area
          Expanded(
            flex: 7,
            child: SkeletonBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 20.0,
            ),
          ),
          // Info area
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 35.w, height: 2.2.h),
                      SizedBox(width: 2.w),
                      SkeletonBox(width: 10.w, height: 2.2.h),
                    ],
                  ),
                  SkeletonBox(width: 50.w, height: 1.6.h),
                  Row(
                    children: [
                      SkeletonBox(width: 18.w, height: 3.h, borderRadius: 20.0),
                      SizedBox(width: 2.w),
                      SkeletonBox(width: 18.w, height: 3.h, borderRadius: 20.0),
                      SizedBox(width: 2.w),
                      SkeletonBox(width: 18.w, height: 3.h, borderRadius: 20.0),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a match list item
class MatchCardSkeleton extends StatelessWidget {
  const MatchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0.5.h),
      child: Row(
        children: [
          SkeletonBox(width: 14.w, height: 14.w, borderRadius: 40.0),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 28.w, height: 1.8.h),
                    SkeletonBox(width: 12.w, height: 1.4.h),
                  ],
                ),
                SizedBox(height: 0.8.h),
                SkeletonBox(width: 55.w, height: 1.4.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a chat message bubble
class ChatBubbleSkeleton extends StatelessWidget {
  final bool isSender;

  const ChatBubbleSkeleton({super.key, this.isSender = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.6.h),
      child: Row(
        mainAxisAlignment: isSender
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSender) ...[
            SkeletonBox(width: 8.w, height: 8.w, borderRadius: 20.0),
            SizedBox(width: 2.w),
          ],
          SkeletonBox(
            width: isSender ? 55.w : 60.w,
            height: isSender ? 5.h : 7.h,
            borderRadius: 16.0,
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a bike card in Garage
class BikeCardSkeleton extends StatelessWidget {
  const BikeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SkeletonBox(width: 22.w, height: 22.w, borderRadius: 12.0),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 40.w, height: 2.h),
                SizedBox(height: 1.h),
                SkeletonBox(width: 28.w, height: 1.6.h),
                SizedBox(height: 1.h),
                Row(
                  children: [
                    SkeletonBox(width: 16.w, height: 2.8.h, borderRadius: 20.0),
                    SizedBox(width: 2.w),
                    SkeletonBox(width: 16.w, height: 2.8.h, borderRadius: 20.0),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a ride feed post card
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name + bike/route line
          Row(
            children: [
              SkeletonBox(width: 10.w, height: 10.w, borderRadius: 40.0),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 32.w, height: 1.8.h),
                    SizedBox(height: 0.6.h),
                    SkeletonBox(width: 48.w, height: 1.4.h),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          // Large image placeholder
          SkeletonBox(width: double.infinity, height: 22.h, borderRadius: 12.0),
          SizedBox(height: 1.2.h),
          // Caption line
          SkeletonBox(width: 70.w, height: 1.6.h),
          SizedBox(height: 0.8.h),
          // Stats line
          SkeletonBox(width: 45.w, height: 1.4.h),
        ],
      ),
    );
  }
}

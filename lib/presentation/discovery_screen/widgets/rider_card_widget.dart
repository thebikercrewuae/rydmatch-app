import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/pioneer_member_badge.dart';
import '../../../widgets/verified_badge_widget.dart';
import '../../block_user_confirmation_screen/block_user_confirmation_screen.dart';
import '../../report_user_screen/report_user_screen.dart';

class RiderCardWidget extends StatefulWidget {
  final Map<String, dynamic> rider;
  final double swipePercent;
  final VoidCallback? onBlocked;
  final VoidCallback? onTap;

  const RiderCardWidget({
    super.key,
    required this.rider,
    required this.swipePercent,
    this.onBlocked,
    this.onTap,
  });

  @override
  State<RiderCardWidget> createState() => _RiderCardWidgetState();
}

class _RiderCardWidgetState extends State<RiderCardWidget>
    with SingleTickerProviderStateMixin {
  final bool _showDetails = false;

  late AnimationController _badgeGlowController;
  late Animation<double> _badgeGlowAnimation;

  @override
  void initState() {
    super.initState();
    _badgeGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _badgeGlowAnimation = Tween<double>(begin: 6.0, end: 16.0).animate(
      CurvedAnimation(parent: _badgeGlowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _badgeGlowController.dispose();
    super.dispose();
  }

  void _showLongPressMenu(BuildContext context) {
    final rider = widget.rider;
    final riderId = rider['id']?.toString() ?? 'unknown';
    final riderName = rider['name'] as String? ?? 'Rider';
    final riderImage = rider['photo'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        padding: EdgeInsets.symmetric(vertical: 1.5.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10.w,
              height: 4,
              margin: EdgeInsets.only(bottom: 1.h),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: Color(0xFFE85A4F),
              ),
              title: Text(
                'Report $riderName',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                ReportUserScreen.show(
                  context,
                  reportedUserId: riderId,
                  reportedUserName: riderName,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Color(0xFFE85A4F)),
              title: Text(
                'Block $riderName',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE85A4F),
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final blocked = await BlockUserConfirmationScreen.show(
                  context,
                  blockedUserId: riderId,
                  blockedUserName: riderName,
                  blockedUserImage: riderImage,
                );
                if (blocked) widget.onBlocked?.call();
              },
            ),
            SizedBox(height: 1.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    final swipe = widget.swipePercent;
    final compatibility = rider["compatibility"] as int? ?? 0;
    final rideMode = rider["rideMode"] as String? ?? 'motorcycle';

    final Color badgeAccent = compatibility >= 85
        ? const Color(0xFFFF6B00)
        : const Color(0xFF1E90FF);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: () => _showLongPressMenu(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CustomImageWidget(
                  imageUrl: rider["photo"] as String,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: rider["semanticLabel"] as String,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.0),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.35, 0.55, 0.75, 1.0],
              ),
            ),
          ),
          if (swipe > 0.1)
            Positioned(
              top: 4.h,
              left: 4.w,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF00E676),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                    color: const Color(0xFF00E676).withValues(alpha: 0.12),
                  ),
                  child: Text(
                    "MATCH",
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF00E676),
                      fontWeight: FontWeight.w900,
                      fontSize: 16.sp,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          if (swipe < -0.1)
            Positioned(
              top: 4.h,
              right: 4.w,
              child: Transform.rotate(
                angle: 0.3,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF5252),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                    color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                  ),
                  child: Text(
                    "PASS",
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFFF5252),
                      fontWeight: FontWeight.w900,
                      fontSize: 16.sp,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 2.h,
            right: 4.w,
            child: AnimatedBuilder(
              animation: _badgeGlowAnimation,
              builder: (context, child) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 0.9.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: badgeAccent.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: badgeAccent.withValues(alpha: 0.35),
                        blurRadius: _badgeGlowAnimation.value,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: badgeAccent, size: 15),
                      SizedBox(width: 1.w),
                      Text(
                        "$compatibility% match",
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 2.h,
            left: 4.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.6.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.more_horiz, color: Colors.white60, size: 13),
                  SizedBox(width: 1.w),
                  const Text(
                    'Hold to report',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 3.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          "${rider["name"]}, ${rider["age"]}",
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (rider["isVerified"] == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: VerifiedBadgeWidget(size: 22),
                        ),
                      if (rider["isPioneer"] == true &&
                          rider["pioneerNumber"] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: PioneerMemberBadge(
                            number: rider["pioneerNumber"] as int,
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 0.6.h),
                  Row(
                    children: [
                      Icon(
                        rideMode == 'bicycle'
                            ? Icons.directions_bike_rounded
                            : Icons.two_wheeler_rounded,
                        color: Colors.white.withValues(alpha: 0.75),
                        size: 14,
                      ),
                      SizedBox(width: 1.5.w),
                      Expanded(
                        child: Text(
                          rider["bikeName"] as String,
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Colors.white.withValues(alpha: 0.65),
                        size: 13,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        rider["distance"] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        Icons.speed_rounded,
                        color: Colors.white.withValues(alpha: 0.65),
                        size: 13,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        rider["skillLevel"] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.2.h),
                  Wrap(
                    spacing: 1.8.w,
                    runSpacing: 0.6.h,
                    children: (rider["tags"] as List).take(4).map((tag) {
                      final tagStr = tag as String;
                      final bool isSkill =
                          tagStr.toLowerCase().contains('intermediate') ||
                          tagStr.toLowerCase().contains('beginner') ||
                          tagStr.toLowerCase().contains('advanced') ||
                          tagStr.toLowerCase().contains('expert');
                      final Color chipColor = isSkill
                          ? const Color(0xFF1E90FF).withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.14);
                      final Color chipBorder = isSkill
                          ? const Color(0xFF1E90FF).withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.3);
                      final Color chipText = isSkill
                          ? const Color(0xFF7EC8FF)
                          : Colors.white.withValues(alpha: 0.9);

                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.8.w,
                          vertical: 0.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(30.0),
                          border: Border.all(color: chipBorder, width: 1.0),
                        ),
                        child: Text(
                          tagStr,
                          style: GoogleFonts.dmSans(
                            color: chipText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 1.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 0.8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 1.w),
                        const Text(
                          'Tap for profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showDetails) ...[
                    SizedBox(height: 1.h),
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow(
                            context,
                            'route',
                            "Routes: ${rider["preferredRoutes"]}",
                          ),
                          SizedBox(height: 0.5.h),
                          _detailRow(
                            context,
                            'style',
                            "Style: ${rider["rideStyle"]}",
                          ),
                          SizedBox(height: 0.5.h),
                          _detailRow(
                            context,
                            'schedule',
                            "Available: ${rider["availability"]}",
                          ),
                          SizedBox(height: 0.5.h),
                          _detailRow(
                            context,
                            'category',
                            "Vehicle Type: ${rider["bikeType"]}",
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String icon, String text) {
    return Row(
      children: [
        Icon(AppIcons.help, color: Colors.white70, size: 13),
        SizedBox(width: 2.w),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

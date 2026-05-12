import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../report_user_screen/report_user_screen.dart';
import '../../block_user_confirmation_screen/block_user_confirmation_screen.dart';
import '../../../widgets/app_logo_widget.dart';

class ChatHeaderWidget extends StatelessWidget {
  final String riderName;
  final String riderImage;
  final bool isOnline;
  final String bikeModel;
  final VoidCallback onBackTap;
  final VoidCallback onProfileTap;
  final String? riderId;
  final VoidCallback? onUserBlocked;

  const ChatHeaderWidget({
    super.key,
    required this.riderName,
    required this.riderImage,
    required this.isOnline,
    required this.bikeModel,
    required this.onBackTap,
    required this.onProfileTap,
    this.riderId,
    this.onUserBlocked,
  });

  void _showMenu(BuildContext context) {
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
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                ReportUserScreen.show(
                  context,
                  reportedUserId: riderId ?? 'unknown',
                  reportedUserName: riderName,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Color(0xFFE85A4F)),
              title: Text(
                'Block $riderName',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE85A4F),
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final blocked = await BlockUserConfirmationScreen.show(
                  context,
                  blockedUserId: riderId ?? 'unknown',
                  blockedUserName: riderName,
                  blockedUserImage: riderImage,
                );
                if (blocked) onUserBlocked?.call();
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x4D0D1B2A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            icon: Icon(Icons.arrow_back_ios_new, size: 20),
            color: Colors.white,
          ),
          // Logo
          AppLogoMark(size: 6.w),
          GestureDetector(
            onTap: onProfileTap,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 5.5.w,
                  backgroundImage: NetworkImage(riderImage),
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 3.w,
                      height: 3.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1B365D),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 2.5.w),
          Expanded(
            child: GestureDetector(
              onTap: onProfileTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    riderName,
                    style: GoogleFonts.dmSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isOnline ? 'Online · $bikeModel' : bikeModel,
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5.sp,
                      color: isOnline
                          ? const Color(0xFF4CAF50)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showMenu(context),
            icon: const Icon(Icons.more_vert, size: 22),
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

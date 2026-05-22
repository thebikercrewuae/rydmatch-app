import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/haptic_service.dart';
import './widgets/block_consequence_item_widget.dart';

class BlockUserConfirmationScreen extends StatefulWidget {
  final String blockedUserId;
  final String blockedUserName;
  final String? blockedUserImage;

  const BlockUserConfirmationScreen({
    super.key,
    required this.blockedUserId,
    required this.blockedUserName,
    this.blockedUserImage,
  });

  static Future<bool> show(
    BuildContext context, {
    required String blockedUserId,
    required String blockedUserName,
    String? blockedUserImage,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => BlockUserConfirmationScreen(
        blockedUserId: blockedUserId,
        blockedUserName: blockedUserName,
        blockedUserImage: blockedUserImage,
      ),
    );
    return result ?? false;
  }

  @override
  State<BlockUserConfirmationScreen> createState() =>
      _BlockUserConfirmationScreenState();
}

class _BlockUserConfirmationScreenState
    extends State<BlockUserConfirmationScreen> {
  bool _isBlocking = false;

  static const Color _navyColor = Color(0xFF1B365D);
  static const Color _orangeColor = Color(0xFFE85A4F);

  Future<void> _blockUser() async {
    HapticService.instance.medium();
    setState(() => _isBlocking = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await supabase.from('user_blocks').insert({
          'blocker_id': currentUser.id,
          'blocked_id': widget.blockedUserId,
        });
      }
    } catch (_) {
      // Proceed even if Supabase not configured
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.all(5.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatar + title
            if (widget.blockedUserImage != null)
              CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage(widget.blockedUserImage!),
                backgroundColor: theme.colorScheme.outline.withValues(
                  alpha: 0.1,
                ),
              )
            else
              CircleAvatar(
                radius: 32,
                backgroundColor: _orangeColor.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: _orangeColor, size: 32),
              ),
            SizedBox(height: 1.5.h),
            Text(
              'Block ${widget.blockedUserName}?',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: _navyColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            // Consequences
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: _navyColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: _navyColor.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  BlockConsequenceItemWidget(
                    text: 'They won\'t see your profile in Discovery',
                  ),
                  BlockConsequenceItemWidget(
                    text: 'All matches will be removed',
                  ),
                  BlockConsequenceItemWidget(
                    text: 'Chat history will be deleted',
                  ),
                  BlockConsequenceItemWidget(text: 'They cannot contact you'),
                ],
              ),
            ),
            SizedBox(height: 1.5.h),
            // Warning note
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: _navyColor.withValues(alpha: 0.6),
                ),
                SizedBox(width: 1.5.w),
                Expanded(
                  child: Text(
                    'You can unblock them later in Settings.',
                    style: GoogleFonts.dmSans(
                      fontSize: 10.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.5.h),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isBlocking
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      side: BorderSide(
                        color: _navyColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: _navyColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isBlocking ? null : _blockUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orangeColor,
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    child: _isBlocking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Block User',
                            style: GoogleFonts.dmSans(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

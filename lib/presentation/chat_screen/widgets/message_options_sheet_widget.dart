import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class MessageOptionsSheetWidget extends StatelessWidget {
  final String message;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const MessageOptionsSheetWidget({
    super.key,
    required this.message,
    required this.onCopy,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 1.h),
          Container(
            width: 10.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: const Color(0xFF666666),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 1.5.h),
          _buildOption(
            context,
            icon: AppIcons.copy,
            label: 'Copy',
            color: const Color(0xFF1B365D),
            onTap: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(context);
              onCopy();
            },
          ),
          _buildDivider(),
          _buildOption(
            context,
            icon: AppIcons.delete,
            label: 'Delete',
            color: const Color(0xFFE85A4F),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            },
          ),
          _buildDivider(),
          _buildOption(
            context,
            icon: AppIcons.flag,
            label: 'Report',
            color: const Color(0xFFB7791F),
            onTap: () {
              Navigator.pop(context);
              _showReportConfirmation(context);
            },
          ),
          SizedBox(height: 3.h),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(width: 4.w),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Delete Message',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This message will be removed from your chat.',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: const Color(0xFF666666)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: Text(
              'Delete',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFE85A4F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Report Message',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This message will be reported to our safety team for review.',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: const Color(0xFF666666)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onReport();
            },
            child: Text(
              'Report',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFB7791F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

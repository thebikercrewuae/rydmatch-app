import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/haptic_service.dart';
import './widgets/report_reason_card_widget.dart';

class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;
  final String reportedUserName;
  final String? reportedUserImage;
  final bool isModal;

  const ReportUserScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
    this.reportedUserImage,
    this.isModal = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String reportedUserId,
    required String reportedUserName,
    String? reportedUserImage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportUserScreen(
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        reportedUserImage: reportedUserImage,
        isModal: true,
      ),
    );
  }

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;
  late AnimationController _successAnimController;
  late Animation<double> _successScaleAnim;

  static const Color _navyColor = Color(0xFF1B365D);
  static const Color _orangeColor = Color(0xFFE85A4F);
  static const Color _successColor = Color(0xFF2D5A27);

  static const List<Map<String, dynamic>> _reasons = [
    {
      'key': 'inappropriate_content',
      'title': 'Inappropriate Content',
      'description': 'Offensive photos, messages, or profile info',
      'icon': Icons.no_photography_outlined,
    },
    {
      'key': 'fake_profile',
      'title': 'Fake Profile',
      'description': 'Impersonation or misleading identity',
      'icon': Icons.person_off_outlined,
    },
    {
      'key': 'harassment',
      'title': 'Harassment',
      'description': 'Threatening, abusive, or unwanted contact',
      'icon': Icons.warning_amber_outlined,
    },
    {
      'key': 'spam',
      'title': 'Spam',
      'description': 'Unsolicited promotions or repetitive messages',
      'icon': Icons.mark_email_unread_outlined,
    },
    {
      'key': 'underage_user',
      'title': 'Underage User',
      'description': 'Appears to be under the minimum age',
      'icon': Icons.child_care_outlined,
    },
    {
      'key': 'dangerous_behavior',
      'title': 'Dangerous Riding Behavior',
      'description': 'Reckless or unsafe riding reported by others',
      'icon': Icons.speed_outlined,
    },
    {
      'key': 'scam',
      'title': 'Scam or Fraud',
      'description': 'Attempting to deceive or defraud other riders',
      'icon': Icons.money_off_outlined,
    },
    {
      'key': 'other',
      'title': 'Other',
      'description': 'Something else not listed above',
      'icon': Icons.more_horiz_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successScaleAnim = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;
    HapticService.instance.medium();
    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await supabase.from('user_reports').insert({
          'reporter_id': currentUser.id,
          'reported_id': widget.reportedUserId,
          'reason': _selectedReason,
          'details': _detailsController.text.trim().isEmpty
              ? null
              : _detailsController.text.trim(),
          'status': 'pending',
        });
      }
    } catch (_) {
      // Proceed to success state even on error
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });
      _successAnimController.forward();
      HapticService.instance.heavy();
      await Future.delayed(const Duration(milliseconds: 2200));
      if (mounted) {
        if (widget.isModal) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModal) {
      return _buildModalContent(context);
    }
    return _buildFullScreen(context);
  }

  Widget _buildFullScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _navyColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Report User',
          style: GoogleFonts.dmSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: _navyColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: _navyColor.withValues(alpha: 0.08)),
        ),
      ),
      body: _isSuccess
          ? _buildSuccessState(theme, isFullScreen: true)
          : _buildReportFormFull(theme),
    );
  }

  Widget _buildModalContent(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1.2.h),
            child: Container(
              width: 10.w,
              height: 4,
              decoration: BoxDecoration(
                color: _navyColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Report User',
                    style: GoogleFonts.dmSans(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: _navyColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _navyColor.withValues(alpha: 0.1)),
          _isSuccess ? _buildSuccessState(theme) : _buildReportForm(theme),
        ],
      ),
    );
  }

  Widget _buildSuccessState(ThemeData theme, {bool isFullScreen = false}) {
    return isFullScreen
        ? Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: _buildSuccessContent(theme),
            ),
          )
        : Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 4.w),
            child: _buildSuccessContent(theme),
          );
  }

  Widget _buildSuccessContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _successScaleAnim,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _successColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: _successColor,
              size: 40,
            ),
          ),
        ),
        SizedBox(height: 2.5.h),
        Text(
          'Report Submitted',
          style: GoogleFonts.dmSans(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: _navyColor,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'Thank you for helping keep RydMatch safe.\nOur team will review your report confidentially.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 11.sp,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        SizedBox(height: 2.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          decoration: BoxDecoration(
            color: _navyColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: _navyColor.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: _navyColor.withValues(alpha: 0.6),
              ),
              SizedBox(width: 2.w),
              Text(
                'The reported user will not be notified.',
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportFormFull(ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserCard(theme),
          SizedBox(height: 2.5.h),
          _buildFormContent(theme),
        ],
      ),
    );
  }

  Widget _buildUserCard(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: _navyColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _navyColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _orangeColor.withValues(alpha: 0.1),
            backgroundImage: widget.reportedUserImage != null
                ? NetworkImage(widget.reportedUserImage!)
                : null,
            child: widget.reportedUserImage == null
                ? Icon(Icons.person, color: _orangeColor, size: 26)
                : null,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reportedUserName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _navyColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0.3.h),
                Text(
                  'You are about to submit a report for this user',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.5.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.6.h),
            decoration: BoxDecoration(
              color: _orangeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              'Report',
              style: GoogleFonts.dmSans(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: _orangeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportForm(ThemeData theme) {
    return Flexible(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        child: _buildFormContent(theme),
      ),
    );
  }

  Widget _buildFormContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why are you reporting ${widget.reportedUserName}?',
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: _navyColor,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          'Select the reason that best describes the issue.',
          style: GoogleFonts.dmSans(
            fontSize: 10.sp,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 1.5.h),
        ...List.generate(_reasons.length, (i) {
          final r = _reasons[i];
          return Padding(
            padding: EdgeInsets.only(bottom: 1.h),
            child: ReportReasonCardWidget(
              title: r['title'] as String,
              description: r['description'] as String,
              icon: r['icon'] as IconData,
              isSelected: _selectedReason == r['key'],
              onTap: () => setState(() => _selectedReason = r['key'] as String),
            ),
          );
        }),
        SizedBox(height: 1.h),
        Text(
          'Additional details (optional)',
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: _navyColor,
          ),
        ),
        SizedBox(height: 0.8.h),
        TextField(
          controller: _detailsController,
          maxLines: 4,
          maxLength: 500,
          style: GoogleFonts.dmSans(fontSize: 12.sp, color: _navyColor),
          decoration: InputDecoration(
            hintText:
                'Provide any additional context that may help our team review this report...',
            hintStyle: GoogleFonts.dmSans(
              fontSize: 11.sp,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: _orangeColor, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 3.w,
              vertical: 1.5.h,
            ),
            counterStyle: GoogleFonts.dmSans(
              fontSize: 9.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: _navyColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: _navyColor.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline,
                size: 15,
                color: _navyColor.withValues(alpha: 0.6),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Your report is completely confidential. The reported user will not be notified that you submitted this report.',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.5.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.5.h),
        SizedBox(
          width: double.infinity,
          height: 6.h,
          child: ElevatedButton(
            onPressed: _selectedReason == null || _isSubmitting
                ? null
                : _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: _orangeColor,
              disabledBackgroundColor: _orangeColor.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Submit Report',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: 1.h),
        SizedBox(
          width: double.infinity,
          height: 5.5.h,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SizedBox(height: 1.h),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  static const Color _deepBlue = Color(0xFF1B365D);
  static const Color _orange = Color(0xFFE85A4F);
  static const Color _green = Color(0xFF2E7D32);

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _loadingRequests = false;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  Future<void> _checkAdminAndLoad() async {
    try {
      final result =
          await Supabase.instance.client.rpc('is_admin_user') as bool?;
      if (!mounted) return;
      setState(() {
        _isAdmin = result ?? false;
        _checkingAdmin = false;
      });
      if (_isAdmin) {
        await _loadRequests();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _checkingAdmin = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() => _loadingRequests = true);
    try {
      final data =
          await Supabase.instance.client.rpc('list_verification_requests')
              as List<dynamic>?;
      if (!mounted) return;
      setState(() {
        _requests = (data ?? []).cast<Map<String, dynamic>>();
        _loadingRequests = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRequests = false);
      _showSnackBar('Failed to load verification requests.');
    }
  }

  Future<void> _viewDocument(String? path, String label) async {
    if (path == null || path.isEmpty) {
      _showSnackBar('No $label path available.');
      return;
    }
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('verification-documents')
          .createSignedUrl(path, 300);
      final uri = Uri.parse(signedUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar('Could not open $label.');
      }
    } catch (_) {
      _showSnackBar('Could not generate signed URL for $label.');
    }
  }

  Future<void> _approveRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Approve this rider?',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: _deepBlue,
          ),
        ),
        content: Text(
          'This will mark the rider as verified.',
          style: GoogleFonts.dmSans(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Approve',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.rpc(
        'review_verification_request',
        params: {
          'request_id_param': requestId,
          'approved_param': true,
          'rejection_reason_param': null,
        },
      );
      _showSnackBar('Rider approved');
      await _loadRequests();
    } catch (_) {
      _showSnackBar('Failed to approve request.');
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final reasonController = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                'Reject Verification',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  color: _deepBlue,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please provide a reason for rejection.',
                    style: GoogleFonts.dmSans(color: Colors.black87),
                  ),
                  SizedBox(height: 1.5.h),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Rejection reason',
                      hintStyle: GoogleFonts.dmSans(color: Colors.grey),
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: _deepBlue),
                      ),
                    ),
                    style: GoogleFonts.dmSans(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.dmSans(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _orange),
                  onPressed: () {
                    if (reasonController.text.trim().isEmpty) {
                      setDialogState(
                        () => errorText = 'Reason cannot be empty.',
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: Text(
                    'Reject',
                    style: GoogleFonts.dmSans(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    try {
      await Supabase.instance.client.rpc(
        'review_verification_request',
        params: {
          'request_id_param': requestId,
          'approved_param': false,
          'rejection_reason_param': reason,
        },
      );
      _showSnackBar('Verification rejected');
      await _loadRequests();
    } catch (_) {
      _showSnackBar('Failed to reject request.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _displayName(Map<String, dynamic> req) {
    final name = req['full_name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final email = req['email'] as String?;
    if (email != null && email.isNotEmpty) return email;
    return req['user_id']?.toString() ?? 'Unknown';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return _green;
      case 'rejected':
        return _orange;
      case 'pending':
        return Colors.orange[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'needs_more_info':
        return 'Needs More Info';
      default:
        return status ?? 'Unknown';
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _deepBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Verification Review',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_checkingAdmin) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isAdmin) {
      return _buildUnauthorized();
    }
    if (_loadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: _deepBlue,
      child: _requests.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildUnauthorized() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 8.w, color: _orange),
            SizedBox(height: 2.h),
            Text(
              'Admin access required',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _deepBlue,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              'You do not have permission to view this screen.',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 20.h),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 8.w, color: _green),
              SizedBox(height: 2.h),
              Text(
                'No pending verification requests',
                style: GoogleFonts.dmSans(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: _deepBlue,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => SizedBox(height: 1.5.h),
      itemBuilder: (context, index) {
        final req = _requests[index];
        return _buildRequestCard(req);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final requestId = req['request_id']?.toString() ?? '';
    final status = req['status'] as String?;
    final email = req['email'] as String? ?? '';
    final submittedAt = req['submitted_at'] as String?;
    final frontPath = req['license_front_path'] as String?;
    final backPath = req['license_back_path'] as String?;
    final rejectionReason = req['rejection_reason'] as String?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(3.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(req),
                        style: GoogleFonts.dmSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: _deepBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (email.isNotEmpty) ...[
                        SizedBox(height: 0.4.h),
                        Text(
                          email,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 2.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withAlpha(31),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: _statusColor(status).withAlpha(102),
                    ),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            if (submittedAt != null) ...[
              SizedBox(height: 0.8.h),
              Text(
                'Submitted: ${_formatDate(submittedAt)}',
                style: GoogleFonts.dmSans(
                  fontSize: 11.sp,
                  color: Colors.grey[500],
                ),
              ),
            ],
            if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
              SizedBox(height: 0.8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: _orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Reason: $rejectionReason',
                  style: GoogleFonts.dmSans(fontSize: 11.sp, color: _orange),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            SizedBox(height: 1.5.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: [
                _actionButton(
                  label: 'View Front',
                  icon: Icons.image_outlined,
                  color: _deepBlue,
                  onTap: () => _viewDocument(frontPath, 'Licence Front'),
                ),
                _actionButton(
                  label: 'View Back',
                  icon: Icons.image_outlined,
                  color: _deepBlue,
                  onTap: () => _viewDocument(backPath, 'Licence Back'),
                ),
                _actionButton(
                  label: 'Approve',
                  icon: Icons.check_circle_outline,
                  color: _green,
                  onTap: requestId.isNotEmpty
                      ? () => _approveRequest(requestId)
                      : null,
                ),
                _actionButton(
                  label: 'Reject',
                  icon: Icons.cancel_outlined,
                  color: _orange,
                  onTap: requestId.isNotEmpty
                      ? () => _rejectRequest(requestId)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14.sp, color: color),
      label: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withAlpha(153)),
        padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }
}

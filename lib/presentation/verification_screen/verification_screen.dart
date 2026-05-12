import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _VerificationStatus {
  notSubmitted,
  pending,
  approved,
  rejected,
  needsMoreInfo,
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const Color _appBarColor = Color(0xFF1B365D);
  static const Color _primaryColor = Color(0xFF1B365D);

  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
Future<ImageSource?> _showImageSourceSheet() {
  final theme = Theme.of(context);

  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20.0),
        ),
      ),
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 3.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11.w,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(height: 1.5.h),
          Text(
            'Add licence photo',
            style: GoogleFonts.dmSans(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: Text(
              'Take Photo',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(
              'Choose from Library',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

  _VerificationStatus _status = _VerificationStatus.notSubmitted;
  bool _loadingStatus = true;
  bool _submitting = false;

  XFile? _frontImage;
  XFile? _backImage;
  bool _consentAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() {
          _status = _VerificationStatus.notSubmitted;
          _loadingStatus = false;
        });
        return;
      }

      // Query user_profiles for is_verified and verification_status
      final profileRow = await _client
          .from('user_profiles')
          .select('is_verified, verification_status')
          .eq('id', user.id)
          .maybeSingle();

      if (profileRow != null && profileRow['is_verified'] == true) {
        setState(() {
          _status = _VerificationStatus.approved;
          _loadingStatus = false;
        });
        return;
      }

      // Query latest verification_requests row
      final requestRow = await _client
          .from('verification_requests')
          .select('status')
          .eq('user_id', user.id)
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      _VerificationStatus resolved = _VerificationStatus.notSubmitted;

      if (requestRow != null) {
        final rawStatus = requestRow['status'] as String? ?? '';
        resolved = _parseStatus(rawStatus);
      } else if (profileRow != null) {
        final rawStatus = profileRow['verification_status'] as String? ?? '';
        if (rawStatus.isNotEmpty) {
          resolved = _parseStatus(rawStatus);
        }
      }

      setState(() {
        _status = resolved;
        _loadingStatus = false;
      });
    } catch (_) {
      setState(() {
        _status = _VerificationStatus.notSubmitted;
        _loadingStatus = false;
      });
    }
  }

  _VerificationStatus _parseStatus(String raw) {
    switch (raw) {
      case 'pending':
        return _VerificationStatus.pending;
      case 'approved':
        return _VerificationStatus.approved;
      case 'rejected':
        return _VerificationStatus.rejected;
      case 'needs_more_info':
        return _VerificationStatus.needsMoreInfo;
      default:
        return _VerificationStatus.notSubmitted;
    }
  }

  bool get _canUpload =>
      _status == _VerificationStatus.notSubmitted ||
      _status == _VerificationStatus.rejected ||
      _status == _VerificationStatus.needsMoreInfo;

  bool get _submitEnabled =>
      _frontImage != null &&
      _backImage != null &&
      _consentAccepted &&
      !_submitting;

  Future<void> _pickImage({required bool isFront}) async {
  final source = await _showImageSourceSheet();

  if (source == null) return;

  final picked = await _picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1800,
  );

  if (picked == null || !mounted) return;

  setState(() {
    if (isFront) {
      _frontImage = picked;
    } else {
      _backImage = picked;
    }
  });
}

  String _contentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<String?> _uploadFile(XFile file, String side) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${user.id}/license_${side}_$timestamp.$ext';
    final contentType = _contentTypeForExtension(ext);

    await _client.storage
        .from('verification-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return path;
  }

  Future<void> _submit() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _showSnackBar('You must be signed in to submit verification.');
      return;
    }
    if (_frontImage == null || _backImage == null) return;

    setState(() => _submitting = true);

    try {
      final frontPath = await _uploadFile(_frontImage!, 'front');
      if (frontPath == null) throw Exception('Front upload failed');

      final backPath = await _uploadFile(_backImage!, 'back');
      if (backPath == null) throw Exception('Back upload failed');

      await _client.rpc(
        'submit_verification_request',
        params: {
          'license_front_path': frontPath,
          'license_back_path': backPath,
        },
      );

      setState(() {
        _status = _VerificationStatus.pending;
        _frontImage = null;
        _backImage = null;
        _consentAccepted = false;
        _submitting = false;
      });

      _showSnackBar('Verification submitted for review.');
    } catch (_) {
      setState(() => _submitting = false);
      _showSnackBar('Could not submit verification. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans(fontSize: 13.sp)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Status helpers ───────────────────────────────────────────────────────

  String get _statusTitle {
    switch (_status) {
      case _VerificationStatus.notSubmitted:
        return 'Verify Your Rider Licence';
      case _VerificationStatus.pending:
        return 'Under Review';
      case _VerificationStatus.approved:
        return 'Verified Rider';
      case _VerificationStatus.rejected:
        return 'Verification Rejected';
      case _VerificationStatus.needsMoreInfo:
        return 'More Info Needed';
    }
  }

  String get _statusMessage {
    switch (_status) {
      case _VerificationStatus.notSubmitted:
        return 'Upload your driver licence (front and back) to get verified as a rider on RydMatch.';
      case _VerificationStatus.pending:
        return 'Your documents have been submitted and are being reviewed by our team. This usually takes 1-2 business days.';
      case _VerificationStatus.approved:
        return 'Your rider licence has been verified. You now have a verified badge on your profile.';
      case _VerificationStatus.rejected:
        return 'Your verification was rejected. Please re-upload clear, valid licence images and resubmit.';
      case _VerificationStatus.needsMoreInfo:
        return 'Our team needs additional information. Please re-upload your documents and resubmit.';
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case _VerificationStatus.notSubmitted:
        return Icons.badge_outlined;
      case _VerificationStatus.pending:
        return Icons.hourglass_top_rounded;
      case _VerificationStatus.approved:
        return Icons.verified_rounded;
      case _VerificationStatus.rejected:
        return Icons.cancel_outlined;
      case _VerificationStatus.needsMoreInfo:
        return Icons.info_outline_rounded;
    }
  }

  Color get _statusColor {
    switch (_status) {
      case _VerificationStatus.notSubmitted:
        return _primaryColor;
      case _VerificationStatus.pending:
        return const Color(0xFFB7791F);
      case _VerificationStatus.approved:
        return const Color(0xFF2D5A27);
      case _VerificationStatus.rejected:
        return const Color(0xFFC5282F);
      case _VerificationStatus.needsMoreInfo:
        return const Color(0xFFB7791F);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: _appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Rider Verification',
          style: GoogleFonts.dmSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusCard(),
          SizedBox(height: 2.h),
          _buildPrivacyNotice(),
          if (_canUpload) ...[
            SizedBox(height: 2.h),
            _buildDocumentPickerCard(
              label: 'Licence Front',
              hint: 'Tap to select front of your driver licence',
              image: _frontImage,
              onTap: () => _pickImage(isFront: true),
            ),
            SizedBox(height: 1.5.h),
            _buildDocumentPickerCard(
              label: 'Licence Back',
              hint: 'Tap to select back of your driver licence',
              image: _backImage,
              onTap: () => _pickImage(isFront: false),
            ),
            SizedBox(height: 2.h),
            _buildConsentCheckbox(),
            SizedBox(height: 2.h),
            _buildSubmitButton(),
            SizedBox(height: 2.h),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: _statusColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 22.sp),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  _statusMessage,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    color: const Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FB),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: const Color(0xFF1B365D).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: _primaryColor, size: 16.sp),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              'Your licence images are uploaded to a private Supabase bucket. '
              'They are not public profile photos and are only intended for admin review using signed URLs.',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: _primaryColor,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPickerCard({
    required String label,
    required String hint,
    required XFile? image,
    required VoidCallback onTap,
  }) {
    final bool hasImage = image != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 14.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: hasImage
                ? _primaryColor.withValues(alpha: 0.6)
                : const Color(0xFFE0E0E0),
            width: hasImage ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 14.h,
              height: 14.h,
              decoration: BoxDecoration(
                color: hasImage
                    ? _primaryColor.withValues(alpha: 0.08)
                    : const Color(0xFFF5F5F5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  bottomLeft: Radius.circular(12.0),
                ),
              ),
              child: hasImage
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: _primaryColor,
                      size: 20.sp,
                    )
                  : Icon(
                      Icons.add_photo_alternate_outlined,
                      color: const Color(0xFF9E9E9E),
                      size: 20.sp,
                    ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 0.4.h),
                  Text(
                    hasImage ? image.name : hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      color: hasImage ? _primaryColor : const Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 3.w),
              child: Icon(
                hasImage ? Icons.edit_outlined : Icons.chevron_right_rounded,
                color: const Color(0xFF9E9E9E),
                size: 16.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _consentAccepted = !_consentAccepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _consentAccepted,
            onChanged: (val) => setState(() => _consentAccepted = val ?? false),
            activeColor: _primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(width: 1.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1.2.h),
              child: Text(
                'I consent to RydMatch storing these documents privately for manual verification.',
                style: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  color: const Color(0xFF1A1A1A),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 6.h,
      child: ElevatedButton(
        onPressed: _submitEnabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          disabledBackgroundColor: const Color(0xFFBDBDBD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          elevation: 2,
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'Submit for Review',
                style: GoogleFonts.dmSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

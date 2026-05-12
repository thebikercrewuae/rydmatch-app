import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/custom_icon_widget.dart';
import '../../../widgets/verified_badge_widget.dart';

class ProfileHeaderWidget extends StatelessWidget {
  final String? riderPhotoPath;
  final String riderName;
  final String riderBio;
  final bool isVerified;

  const ProfileHeaderWidget({
    super.key,
    this.riderPhotoPath,
    required this.riderName,
    required this.riderBio,
    this.isVerified = false,
  });

  bool get _isNetworkUrl =>
      riderPhotoPath != null &&
      (riderPhotoPath!.startsWith('http://') ||
          riderPhotoPath!.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                border: Border.all(color: theme.colorScheme.primary, width: 3),
              ),
              child: ClipOval(child: _buildPhotoWidget(theme)),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                riderName.isNotEmpty ? riderName : 'Rider Profile',
                style: GoogleFonts.dmSans(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified) ...[
              SizedBox(width: 1.5.w),
              const VerifiedBadgeWidget(size: 22),
            ],
          ],
        ),
        if (riderBio.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Text(
            riderBio,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoWidget(ThemeData theme) {
    if (riderPhotoPath == null || riderPhotoPath!.isEmpty) {
      return _buildPlaceholder(theme);
    }

    // Network URL (Supabase Storage or any http/https URL)
    if (_isNetworkUrl) {
      return Image.network(
        riderPhotoPath!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
      );
    }

    // Local file path (mobile only)
    if (!kIsWeb) {
      return Image.file(
        File(riderPhotoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
      );
    }

    return _buildPlaceholder(theme);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: CustomIconWidget(
          iconName: 'person',
          color: theme.colorScheme.primary,
          size: 48,
        ),
      ),
    );
  }
}

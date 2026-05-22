import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../services/haptic_service.dart';
import '../../../widgets/app_icons.dart';

class BikeCardWidget extends StatelessWidget {
  final Map<String, dynamic> bike;
  final VoidCallback onTap;
  final VoidCallback onSetPrimary;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const BikeCardWidget({
    super.key,
    required this.bike,
    required this.onTap,
    required this.onSetPrimary,
    required this.onDuplicate,
    required this.onDelete,
  });

  void _showQuickActions(BuildContext context) {
    HapticService.instance.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickActionsSheet(
        bike: bike,
        onSetPrimary: onSetPrimary,
        onDuplicate: onDuplicate,
        onDelete: onDelete,
      ),
    );
  }

  Widget _buildThumbnail(String? photoPath, double width, double height) {
    if (photoPath == null || photoPath.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: Icon(AppIcons.motorcycle, color: Colors.grey.shade400, size: 32),
      );
    }
    final isNetwork =
        photoPath.startsWith('http://') || photoPath.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        photoPath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(
            AppIcons.motorcycle,
            color: Colors.grey.shade400,
            size: 32,
          ),
        ),
      );
    } else if (kIsWeb) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: Icon(AppIcons.motorcycle, color: Colors.grey.shade400, size: 32),
      );
    } else {
      return Image.file(
        File(photoPath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(
            AppIcons.motorcycle,
            color: Colors.grey.shade400,
            size: 32,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = bike['isPrimary'] as bool? ?? false;
    final photoPath = bike['photo'] as String?;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showQuickActions(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: isPrimary
              ? Border.all(color: const Color(0xFF1B365D), width: 2)
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                bottomLeft: Radius.circular(16.0),
              ),
              child: _buildThumbnail(photoPath, 28.w, 12.h),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${bike['year']} ${bike['make']}',
                            style: GoogleFonts.manrope(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B365D),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: GoogleFonts.manrope(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 0.4.h),
                    Text(
                      bike['model'] as String? ?? '',
                      style: GoogleFonts.manrope(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 0.8.h),
                    Row(
                      children: [
                        Icon(
                          AppIcons.build,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${(bike['mods'] as List?)?.length ?? 0} modifications',
                            style: GoogleFonts.manrope(
                              fontSize: 10.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 2.w),
              child: Icon(
                AppIcons.edit,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsSheet extends StatelessWidget {
  final Map<String, dynamic> bike;
  final VoidCallback onSetPrimary;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _QuickActionsSheet({
    required this.bike,
    required this.onSetPrimary,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          Text(
            '${bike['year']} ${bike['make']} ${bike['model']}',
            style: GoogleFonts.manrope(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.5.h),
          _ActionTile(
            icon: AppIcons.help,
            label: 'Set as Primary',
            color: const Color(0xFF1B365D),
            onTap: () {
              Navigator.pop(context);
              onSetPrimary();
            },
          ),
          _ActionTile(
            icon: AppIcons.copy,
            label: 'Duplicate',
            color: theme.colorScheme.onSurface,
            onTap: () {
              Navigator.pop(context);
              onDuplicate();
            },
          ),
          _ActionTile(
            icon: AppIcons.delete,
            label: 'Delete',
            color: const Color(0xFFE85A4F),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    );
  }
}

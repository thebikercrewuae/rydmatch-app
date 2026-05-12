import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class TrustBadgesWidget extends StatelessWidget {
  final double averageRating;
  final int totalRatings;
  final List<String> safetyTags;

  const TrustBadgesWidget({
    super.key,
    required this.averageRating,
    required this.totalRatings,
    required this.safetyTags,
  });

  List<Map<String, dynamic>> get _earnedBadges {
    final badges = <Map<String, dynamic>>[];
    final tagCounts = <String, int>{};
    for (final tag in safetyTags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }

    if (averageRating >= 4.5 && totalRatings >= 3) {
      badges.add({
        'label': 'Top Rider',
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFFFF8C00),
      });
    }
    if ((tagCounts['Rode safely'] ?? 0) >= 3) {
      badges.add({
        'label': 'Safe Rider',
        'icon': Icons.verified_user_rounded,
        'color': const Color(0xFF2D5A27),
      });
    }
    if ((tagCounts['Respected pace'] ?? 0) >= 3) {
      badges.add({
        'label': 'Reliable',
        'icon': Icons.thumb_up_rounded,
        'color': const Color(0xFF1B365D),
      });
    }
    if ((tagCounts['Followed route'] ?? 0) >= 3) {
      badges.add({
        'label': 'Great Navigator',
        'icon': Icons.explore_rounded,
        'color': const Color(0xFF4A7CC7),
      });
    }
    if ((tagCounts['Good communicator'] ?? 0) >= 3) {
      badges.add({
        'label': 'Communicator',
        'icon': Icons.chat_bubble_rounded,
        'color': const Color(0xFF6B4C9A),
      });
    }
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (totalRatings == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star_rounded, size: 18, color: const Color(0xFFFF8C00)),
            SizedBox(width: 1.w),
            Text(
              averageRating.toStringAsFixed(1),
              style: GoogleFonts.dmSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(width: 1.w),
            Text(
              '($totalRatings ${totalRatings == 1 ? 'review' : 'reviews'})',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (_earnedBadges.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 0.8.h,
            children: _earnedBadges.map((badge) {
              final color = badge['color'] as Color;
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 2.5.w,
                  vertical: 0.5.h,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badge['icon'] as IconData, size: 12, color: color),
                    SizedBox(width: 1.w),
                    Text(
                      badge['label'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

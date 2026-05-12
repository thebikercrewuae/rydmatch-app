import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../models/badge_model.dart';
import './badge_card_widget.dart';
import './badge_detail_modal_widget.dart';

class BadgeCategorySectionWidget extends StatefulWidget {
  final BadgeCategory category;
  final List<BadgeModel> badges;

  const BadgeCategorySectionWidget({
    super.key,
    required this.category,
    required this.badges,
  });

  @override
  State<BadgeCategorySectionWidget> createState() =>
      _BadgeCategorySectionWidgetState();
}

class _BadgeCategorySectionWidgetState
    extends State<BadgeCategorySectionWidget> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earnedCount = widget.badges.where((b) => b.isEarned).length;
    final total = widget.badges.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 1.h),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(
                    BadgeModel.categoryIcon(widget.category),
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(width: 2.5.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BadgeModel.categoryLabel(widget.category),
                        style: GoogleFonts.dmSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '$earnedCount / $total earned',
                        style: GoogleFonts.dmSans(
                          fontSize: 9.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: widget.badges.length,
            itemBuilder: (context, index) {
              final badge = widget.badges[index];
              return BadgeCardWidget(
                badge: badge,
                onTap: () => BadgeDetailModalWidget.show(context, badge),
              );
            },
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
        SizedBox(height: 2.h),
      ],
    );
  }
}

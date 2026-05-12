import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class CategoryRatingsWidget extends StatefulWidget {
  final Map<String, int> categoryRatings;
  final ValueChanged<Map<String, int>> onChanged;

  const CategoryRatingsWidget({
    super.key,
    required this.categoryRatings,
    required this.onChanged,
  });

  @override
  State<CategoryRatingsWidget> createState() => _CategoryRatingsWidgetState();
}

class _CategoryRatingsWidgetState extends State<CategoryRatingsWidget> {
  bool _expanded = false;

  static const List<Map<String, dynamic>> _categories = [
    {
      'key': 'punctuality',
      'label': 'Punctuality',
      'icon': Icons.access_time_rounded,
    },
    {'key': 'safety', 'label': 'Safety', 'icon': Icons.shield_outlined},
    {'key': 'navigation', 'label': 'Navigation', 'icon': Icons.map_outlined},
    {
      'key': 'friendliness',
      'label': 'Friendliness',
      'icon': Icons.handshake_outlined,
    },
  ];

  void _updateRating(String key, int stars) {
    final updated = Map<String, int>.from(widget.categoryRatings)
      ..[key] = stars;
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16.0),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'Category Ratings (Optional)',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
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
            firstChild: Padding(
              padding: EdgeInsets.only(left: 4.w, right: 4.w, bottom: 1.5.h),
              child: Column(
                children: _categories.map((cat) {
                  final key = cat['key'] as String;
                  final label = cat['label'] as String;
                  final icon = cat['icon'] as IconData;
                  final rating = widget.categoryRatings[key] ?? 0;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 1.h),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 2.w),
                        SizedBox(
                          width: 22.w,
                          child: Text(
                            label,
                            style: GoogleFonts.dmSans(
                              fontSize: 12.sp,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: List.generate(4, (i) {
                              final filled = i < rating;
                              return GestureDetector(
                                onTap: () => _updateRating(key, i + 1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Icon(
                                    filled
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 22,
                                    color: filled
                                        ? const Color(0xFFFF8C00)
                                        : theme.colorScheme.outline,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../widgets/app_icons.dart';

class MatchCategoryModalWidget extends StatelessWidget {
  final String riderName;
  final Function(String) onCategorySelected;

  const MatchCategoryModalWidget({
    super.key,
    required this.riderName,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = [
      {
        "label": "Ride",
        "icon": "two_wheeler",
        "color": const Color(0xFF1B365D),
        "desc": "General riding together",
      },
      {
        "label": "Coffee Ride",
        "icon": "local_cafe",
        "color": const Color(0xFF6D4C41),
        "desc": "Casual coffee meetup ride",
      },
      {
        "label": "Track Day",
        "icon": "flag",
        "color": const Color(0xFFE85A4F),
        "desc": "Track day session together",
      },
      {
        "label": "Touring Partner",
        "icon": "explore",
        "color": const Color(0xFF2D5A27),
        "desc": "Long distance touring",
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            "How do you want to ride with $riderName?",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2.h),
          ...categories.map((cat) {
            return Padding(
              padding: EdgeInsets.only(bottom: 1.5.h),
              child: InkWell(
                onTap: () => onCategorySelected(cat["label"] as String),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 1.8.h,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outline),
                    color: (cat["color"] as Color).withValues(alpha: 0.06),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 11.w,
                        height: 11.w,
                        decoration: BoxDecoration(
                          color: (cat["color"] as Color).withValues(
                            alpha: 0.15,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            AppIcons.help,
                            color: cat["color"] as Color,
                            size: 22,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat["label"] as String,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              cat["desc"] as String,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        AppIcons.help,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          SizedBox(height: 1.h),
        ],
      ),
    );
  }
}

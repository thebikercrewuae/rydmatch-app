import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../widgets/app_icons.dart';

class SwipeActionButtonsWidget extends StatelessWidget {
  final VoidCallback onDislike;
  final VoidCallback onLike;
  final VoidCallback onSuperLike;

  const SwipeActionButtonsWidget({
    super.key,
    required this.onDislike,
    required this.onLike,
    required this.onSuperLike,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          onTap: onDislike,
          icon: AppIcons.close,
          color: theme.colorScheme.secondary,
          size: 14.w,
          iconSize: 28,
        ),
        SizedBox(width: 4.w),
        _buildActionButton(
          onTap: onSuperLike,
          icon: AppIcons.bolt,
          color: const Color(0xFFB7791F),
          size: 11.w,
          iconSize: 22,
        ),
        SizedBox(width: 4.w),
        _buildActionButton(
          onTap: onLike,
          icon: AppIcons.favorite,
          color: theme.colorScheme.tertiary,
          size: 14.w,
          iconSize: 28,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Center(
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}

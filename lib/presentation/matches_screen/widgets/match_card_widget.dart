import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class MatchCardWidget extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMessage;
  final VoidCallback onUnmatch;
  final VoidCallback onBlock;
  final VoidCallback? onReport;

  const MatchCardWidget({
    super.key,
    required this.match,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onMessage,
    required this.onUnmatch,
    required this.onBlock,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = match['unreadCount'] as int;
    final isOnline = match['isOnline'] as bool;

    return Slidable(
      key: ValueKey(match['id']),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.80,
        children: [
          SlidableAction(
            onPressed: (_) => onMessage(),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.message,
            label: 'Message',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          SlidableAction(
            onPressed: (_) => onUnmatch(),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: Icons.person_remove,
            label: 'Unmatch',
          ),
          SlidableAction(
            onPressed: (_) => onReport?.call(),
            backgroundColor: const Color(0xFFB7791F),
            foregroundColor: Colors.white,
            icon: Icons.flag_outlined,
            label: 'Report',
          ),
          SlidableAction(
            onPressed: (_) => onBlock(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.block,
            label: 'Block',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: Row(
              children: [
                isMultiSelectMode
                    ? Padding(
                        padding: EdgeInsets.only(right: 2.w),
                        child: CustomIconWidget(
                          iconName: isSelected
                              ? 'check_circle'
                              : 'radio_button_unchecked',
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                      )
                    : const SizedBox.shrink(),
                _buildAvatar(theme, isOnline),
                SizedBox(width: 3.w),
                Expanded(child: _buildInfo(theme, unreadCount)),
                _buildTrailing(theme, unreadCount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, bool isOnline) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: CustomImageWidget(
            imageUrl: match['image'] as String,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            semanticLabel: match['semanticLabel'] as String,
          ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfo(ThemeData theme, int unreadCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                '${match['name']}, ${match['age']}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: unreadCount > 0
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(width: 1.w),
            _buildCategoryChip(theme),
          ],
        ),
        SizedBox(height: 0.4.h),
        Text(
          match['bikeType'] as String,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        SizedBox(height: 0.4.h),
        Text(
          match['lastMessage'] as String,
          style: theme.textTheme.bodySmall?.copyWith(
            color: unreadCount > 0
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildCategoryChip(ThemeData theme) {
    final Map<String, Color> categoryColors = {
      'Ride': Colors.blue,
      'Coffee': Colors.brown,
      'Track Day': Colors.red,
      'Touring': Colors.green,
    };
    final color =
        categoryColors[match['category']] ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(
            iconName: match['categoryIcon'] as String,
            color: color,
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            match['category'] as String,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailing(ThemeData theme, int unreadCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(match['timestamp'] as String, style: theme.textTheme.labelSmall),
        SizedBox(height: 0.5.h),
        unreadCount > 0
            ? Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}

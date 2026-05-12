import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class WaypointListWidget extends StatelessWidget {
  final List<String> waypoints;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final Function(int oldIndex, int newIndex) onReorder;

  const WaypointListWidget({
    super.key,
    required this.waypoints,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Waypoints (${waypoints.length}/5)',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (waypoints.length < 5)
              TextButton.icon(
                onPressed: onAdd,
                icon: Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Add Stop',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.5.h,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        if (waypoints.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 1.h),
            child: Text(
              'Tap "Add Stop" to add intermediate waypoints',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: waypoints.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              return _WaypointItem(
                key: ValueKey('wp_$index'),
                index: index,
                label: waypoints[index],
                onRemove: () => onRemove(index),
              );
            },
          ),
      ],
    );
  }
}

class _WaypointItem extends StatelessWidget {
  final int index;
  final String label;
  final VoidCallback onRemove;

  const _WaypointItem({
    super.key,
    required this.index,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 0.8.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF1B365D),
              borderRadius: BorderRadius.circular(11.0),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: theme.colorScheme.error),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Icon(
            Icons.drag_handle,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class RouteSelectorWidget extends StatelessWidget {
  final List<String> routes;
  final String? selectedRoute;
  final ValueChanged<String?> onChanged;

  const RouteSelectorWidget({
    super.key,
    required this.routes,
    this.selectedRoute,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ['No Route', ...routes];
    return DropdownButtonFormField<String>(
      initialValue: selectedRoute ?? 'No Route',
      decoration: InputDecoration(
        prefixIcon: Icon(
          Icons.route_rounded,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      style: GoogleFonts.dmSans(
        fontSize: 13.sp,
        color: theme.colorScheme.onSurface,
      ),
      items: items
          .map(
            (r) => DropdownMenuItem(
              value: r,
              child: Text(r, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (val) => onChanged(val == 'No Route' ? null : val),
    );
  }
}

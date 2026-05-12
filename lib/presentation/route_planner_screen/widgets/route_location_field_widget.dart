import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class RouteLocationFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final Color dotColor;
  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSearch;
  final bool isLoading;

  const RouteLocationFieldWidget({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.dotColor,
    this.onUseCurrentLocation,
    this.onChanged,
    this.onSearch,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSearch?.call(),
            textInputAction: TextInputAction.search,
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              labelStyle: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onSearch != null)
                          IconButton(
                            icon: Icon(
                              Icons.search,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            onPressed: onSearch,
                            tooltip: 'Search location',
                          ),
                        if (onUseCurrentLocation != null)
                          IconButton(
                            icon: Icon(
                              Icons.my_location,
                              color: theme.colorScheme.primary,
                              size: 18,
                            ),
                            onPressed: onUseCurrentLocation,
                            tooltip: 'Use current location',
                          ),
                      ],
                    ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 3.w,
                vertical: 1.2.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
        ),
      ],
    );
  }
}

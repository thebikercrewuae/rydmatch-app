import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class UnitSystemWidget extends StatefulWidget {
  final bool isMetric;
  final ValueChanged<bool> onChanged;

  const UnitSystemWidget({
    super.key,
    required this.isMetric,
    required this.onChanged,
  });

  @override
  State<UnitSystemWidget> createState() => _UnitSystemWidgetState();
}

class _UnitSystemWidgetState extends State<UnitSystemWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: primary.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Icon(AppIcons.straighten, color: primary, size: 20),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit System',
                        style: GoogleFonts.dmSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        'Choose how distances and weights are displayed',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          color: onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Container(
              decoration: BoxDecoration(
                color: outline.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.0),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  _UnitOption(
                    label: 'Metric',
                    sublabel: 'km · kg · cc',
                    icon: AppIcons.speed,
                    isSelected: widget.isMetric,
                    primary: primary,
                    onTap: () => widget.onChanged(true),
                  ),
                  _UnitOption(
                    label: 'Imperial',
                    sublabel: 'miles · lbs · cu in',
                    icon: AppIcons.flag,
                    isSelected: !widget.isMetric,
                    primary: primary,
                    onTap: () => widget.onChanged(false),
                  ),
                ],
              ),
            ),
            SizedBox(height: 1.5.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.help,
                  size: 14,
                  color: primary.withValues(alpha: 0.7),
                ),
                SizedBox(width: 1.w),
                Text(
                  'Currently using: ${widget.isMetric ? 'Metric (km, kg, cc)' : 'Imperial (miles, lbs, cu in)'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    color: primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isSelected;
  final Color primary;
  final VoidCallback onTap;

  const _UnitOption({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.isSelected,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                sublabel,
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class FavouriteRoute {
  final String name;
  final String distance;
  final int rideCount;
  final String scenery;

  const FavouriteRoute({
    required this.name,
    required this.distance,
    required this.rideCount,
    required this.scenery,
  });
}

class FavouriteRoutesWidget extends StatelessWidget {
  final List<FavouriteRoute> routes;

  const FavouriteRoutesWidget({super.key, required this.routes});

  static const Color _primary = Color(0xFF1B365D);
  static const Color _gold = Color(0xFFFFB347);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(AppIcons.route, color: _gold, size: 16),
              ),
              SizedBox(width: 2.w),
              Text(
                'Favourite Routes',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          ...routes.asMap().entries.map((entry) {
            final i = entry.key;
            final route = entry.value;
            final maxCount = routes
                .map((r) => r.rideCount)
                .reduce((a, b) => a > b ? a : b);
            final progress = maxCount > 0 ? route.rideCount / maxCount : 0.0;
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < routes.length - 1 ? 1.5.h : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? _gold.withValues(alpha: 0.2)
                              : _primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: i == 0 ? _gold : _primary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.name,
                              style: GoogleFonts.dmSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${route.distance} · ${route.scenery}',
                              style: GoogleFonts.dmSans(
                                fontSize: 9.sp,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${route.rideCount}x',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: theme.colorScheme.outline.withValues(
                        alpha: 0.15,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        i == 0 ? _gold : _primary.withValues(alpha: 0.7),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

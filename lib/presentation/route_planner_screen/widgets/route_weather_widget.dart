import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../services/weather_service.dart';

class RouteWeatherWidget extends StatefulWidget {
  final String? locationName;

  const RouteWeatherWidget({super.key, this.locationName});

  @override
  State<RouteWeatherWidget> createState() => _RouteWeatherWidgetState();
}

class _RouteWeatherWidgetState extends State<RouteWeatherWidget> {
  final WeatherService _weatherService = WeatherService();

  WeatherData? _weatherData;
  bool _isLoading = false;
  bool _hasError = false;
  String? _lastFetchedLocation;

  @override
  void initState() {
    super.initState();
    if (widget.locationName != null && widget.locationName!.isNotEmpty) {
      _fetchWeather(widget.locationName!);
    }
  }

  @override
  void didUpdateWidget(RouteWeatherWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locationName != oldWidget.locationName &&
        widget.locationName != null &&
        widget.locationName!.isNotEmpty &&
        widget.locationName != _lastFetchedLocation) {
      _fetchWeather(widget.locationName!);
    }
  }

  Future<void> _fetchWeather(String location) async {
    if (location.isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final data = await _weatherService.fetchWeatherForLocation(location);
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoading = false;
        _hasError = data == null;
        _lastFetchedLocation = location;
      });
    }
  }

  Color _conditionColor(RideCondition condition) {
    switch (condition) {
      case RideCondition.good:
        return const Color(0xFF2D5A27);
      case RideCondition.caution:
        return const Color(0xFFF57C00);
      case RideCondition.poor:
        return const Color(0xFFD32F2F);
    }
  }

  String _conditionLabel(RideCondition condition) {
    switch (condition) {
      case RideCondition.good:
        return 'Good';
      case RideCondition.caution:
        return 'Caution';
      case RideCondition.poor:
        return 'Poor';
    }
  }

  IconData _conditionIcon(RideCondition condition) {
    switch (condition) {
      case RideCondition.good:
        return Icons.check_circle_outline;
      case RideCondition.caution:
        return Icons.warning_amber_outlined;
      case RideCondition.poor:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.locationName == null || widget.locationName!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: 1.5.w),
                Text(
                  'Weather Conditions',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else if (_weatherData != null)
                  GestureDetector(
                    onTap: () => _fetchWeather(widget.locationName!),
                    child: Icon(
                      Icons.refresh,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),

          if (_isLoading) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Row(
                children: [
                  SizedBox(width: 2.w),
                  Text(
                    'Fetching weather data...',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_hasError) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'Unable to fetch weather for this location',
                      style: GoogleFonts.dmSans(
                        fontSize: 10.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_weatherData != null) ...[
            _buildWeatherContent(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherContent(ThemeData theme) {
    final w = _weatherData!;
    final conditionColor = _conditionColor(w.rideCondition);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main weather row
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Emoji + temp
              Text(w.iconEmoji, style: const TextStyle(fontSize: 32)),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${w.temperature.round()}°C',
                          style: GoogleFonts.dmSans(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(width: 1.5.w),
                        Text(
                          'Feels ${w.feelsLike.round()}°C',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      w.description,
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (w.locationName.isNotEmpty)
                      Text(
                        w.locationName,
                        style: GoogleFonts.dmSans(
                          fontSize: 9.sp,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              // Ride condition badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: conditionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: conditionColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _conditionIcon(w.rideCondition),
                      size: 14,
                      color: conditionColor,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      _conditionLabel(w.rideCondition),
                      style: GoogleFonts.dmSans(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: conditionColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Stats row: wind + precipitation
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0),
          child: Row(
            children: [
              _StatChip(
                icon: Icons.air,
                label: '${w.windSpeedKmh.round()} km/h',
                sublabel: 'Wind',
                theme: theme,
              ),
              SizedBox(width: 2.w),
              _StatChip(
                icon: Icons.water_drop_outlined,
                label: '${w.precipitationMm.toStringAsFixed(1)} mm',
                sublabel: 'Precip.',
                theme: theme,
              ),
            ],
          ),
        ),

        // Warnings
        if (w.warnings.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 1.2.h, 4.w, 0),
            child: Column(
              children: w.warnings
                  .map((warning) => _WarningRow(warning: warning, theme: theme))
                  .toList(),
            ),
          ),
        ],

        SizedBox(height: 1.5.h),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final ThemeData theme;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.7.h),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest ??
            theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          SizedBox(width: 1.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                sublabel,
                style: GoogleFonts.dmSans(
                  fontSize: 8.sp,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final WeatherWarning warning;
  final ThemeData theme;

  const _WarningRow({required this.warning, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.6.h),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: warning.warningColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 2.w),
          Text(warning.icon, style: const TextStyle(fontSize: 12)),
          SizedBox(width: 1.5.w),
          Expanded(
            child: Text(
              warning.message,
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                color: warning.warningColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

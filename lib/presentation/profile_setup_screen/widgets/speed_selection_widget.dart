import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class SpeedSelectionWidget extends StatelessWidget {
  final double ridingSpeed; // always in mph
  final bool isMetric;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onUnitChanged;
  final String rideMode;

  const SpeedSelectionWidget({
    super.key,
    required this.ridingSpeed,
    required this.isMetric,
    required this.onSpeedChanged,
    required this.onUnitChanged,
    this.rideMode = 'motorcycle',
  });

  bool get _isBicycle => rideMode == 'bicycle';

  double get _minSpeed => _isBicycle ? 5 : 20;
  double get _maxSpeed => _isBicycle ? 35 : 120;
  int get _divisions => _isBicycle ? 30 : 20;
  double get _effectiveSpeed =>
      ridingSpeed.clamp(_minSpeed, _maxSpeed).toDouble();

  // Convert mph to km/h for display
  double get _displaySpeed =>
      isMetric ? (_effectiveSpeed * 1.60934) : _effectiveSpeed;

  String get _unitLabel => isMetric ? 'km/h avg' : 'mph avg';

  String get _speedLabel {
    if (_isBicycle) {
      if (_effectiveSpeed <= 10) return 'Easy Spin';
      if (_effectiveSpeed <= 15) return 'Social Pace';
      if (_effectiveSpeed <= 22) return 'Steady Ride';
      if (_effectiveSpeed <= 28) return 'Fast Group';
      return 'Race Pace';
    }

    // Labels based on mph value
    if (ridingSpeed <= 40) return 'Casual Cruiser';
    if (ridingSpeed <= 65) return 'Relaxed Rider';
    if (ridingSpeed <= 85) return 'Spirited Rider';
    if (ridingSpeed <= 100) return 'Fast & Focused';
    return 'Track Pace';
  }

  Color _speedColor(ThemeData theme) {
    if (_isBicycle) {
      if (_effectiveSpeed <= 10) return theme.colorScheme.tertiary;
      if (_effectiveSpeed <= 22) return theme.colorScheme.primary;
      if (_effectiveSpeed <= 28) return const Color(0xFFB7791F);
      return theme.colorScheme.secondary;
    }

    if (ridingSpeed <= 40) return theme.colorScheme.tertiary;
    if (ridingSpeed <= 65) return theme.colorScheme.primary;
    if (ridingSpeed <= 85) return const Color(0xFFB7791F);
    return theme.colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How fast do you typically ride?',
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: 1.h),
          Text(
            'This helps us match you with riders who share your pace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 2.h),
          // Unit toggle
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UnitToggleButton(
                    label: 'mph',
                    isSelected: !isMetric,
                    onTap: () => onUnitChanged(false),
                    theme: theme,
                  ),
                  _UnitToggleButton(
                    label: 'km/h',
                    isSelected: isMetric,
                    onTap: () => onUnitChanged(true),
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 3.h),
          Center(
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _speedColor(theme).withValues(alpha: 0.1),
                border: Border.all(color: _speedColor(theme), width: 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_displaySpeed.round()}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: _speedColor(theme),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _unitLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: _speedColor(theme).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _speedLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _speedColor(theme),
                ),
              ),
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMetric
                    ? '${(_minSpeed * 1.60934).round()} km/h'
                    : '${_minSpeed.round()} mph',
                style: theme.textTheme.labelSmall,
              ),
              Text(
                isMetric
                    ? '${(_maxSpeed * 1.60934).round()} km/h'
                    : '${_maxSpeed.round()} mph',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _speedColor(theme),
              thumbColor: _speedColor(theme),
              overlayColor: _speedColor(theme).withValues(alpha: 0.15),
              inactiveTrackColor: theme.colorScheme.outline,
            ),
            child: Slider(
              value: _effectiveSpeed,
              min: _minSpeed,
              max: _maxSpeed,
              divisions: _divisions,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                onSpeedChanged(val);
              },
            ),
          ),
          SizedBox(height: 3.h),
          _buildSpeedLegend(theme),
        ],
      ),
    );
  }

  Widget _buildSpeedLegend(ThemeData theme) {
    if (_isBicycle) {
      final items = isMetric
          ? [
              {'label': 'Easy', 'range': '8-16 km/h', 'icon': 'directions_bike'},
              {'label': 'Social', 'range': '17-24 km/h', 'icon': 'groups'},
              {'label': 'Steady', 'range': '25-35 km/h', 'icon': 'speed'},
              {'label': 'Fast', 'range': '36-56 km/h', 'icon': 'flash_on'},
            ]
          : [
              {'label': 'Easy', 'range': '5-10 mph', 'icon': 'directions_bike'},
              {'label': 'Social', 'range': '11-15 mph', 'icon': 'groups'},
              {'label': 'Steady', 'range': '16-22 mph', 'icon': 'speed'},
              {'label': 'Fast', 'range': '23-35 mph', 'icon': 'flash_on'},
            ];
      return Column(
        children: items.map((item) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 0.5.h),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: item['icon'] as String,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                SizedBox(width: 3.w),
                Text(item['label'] as String, style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(item['range'] as String, style: theme.textTheme.bodySmall),
              ],
            ),
          );
        }).toList(),
      );
    }

    final items = isMetric
        ? [
            {
              'label': 'Casual',
              'range': '32-64 km/h',
              'icon': 'directions_bike',
            },
            {'label': 'Relaxed', 'range': '65-104 km/h', 'icon': 'motorcycle'},
            {'label': 'Spirited', 'range': '105-136 km/h', 'icon': 'speed'},
            {'label': 'Fast', 'range': '137-193 km/h', 'icon': 'flash_on'},
          ]
        : [
            {
              'label': 'Casual',
              'range': '20-40 mph',
              'icon': 'directions_bike',
            },
            {'label': 'Relaxed', 'range': '41-65 mph', 'icon': 'motorcycle'},
            {'label': 'Spirited', 'range': '66-85 mph', 'icon': 'speed'},
            {'label': 'Fast', 'range': '86-120 mph', 'icon': 'flash_on'},
          ];
    return Column(
      children: items.map((item) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 0.5.h),
          child: Row(
            children: [
              CustomIconWidget(
                iconName: item['icon'] as String,
                color: theme.colorScheme.onSurfaceVariant,
                size: 18,
              ),
              SizedBox(width: 3.w),
              Text(item['label'] as String, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(item['range'] as String, style: theme.textTheme.bodySmall),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _UnitToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _UnitToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

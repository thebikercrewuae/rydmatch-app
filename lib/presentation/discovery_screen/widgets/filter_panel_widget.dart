import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../widgets/app_icons.dart';

const double _defaultSearchRadius = 500;

class FilterState {
  final double distance;
  final String rideCommunity;
  final String skillLevel;
  final String bikeType;
  final List<String> ridingStyles;
  final bool onlineOnly;

  const FilterState({
    this.distance = _defaultSearchRadius,
    this.rideCommunity = 'All',
    this.skillLevel = 'All',
    this.bikeType = 'All',
    this.ridingStyles = const ['All'],
    this.onlineOnly = false,
  });

  FilterState copyWith({
    double? distance,
    String? rideCommunity,
    String? skillLevel,
    String? bikeType,
    List<String>? ridingStyles,
    bool? onlineOnly,
  }) {
    return FilterState(
      distance: distance ?? this.distance,
      rideCommunity: rideCommunity ?? this.rideCommunity,
      skillLevel: skillLevel ?? this.skillLevel,
      bikeType: bikeType ?? this.bikeType,
      ridingStyles: ridingStyles ?? this.ridingStyles,
      onlineOnly: onlineOnly ?? this.onlineOnly,
    );
  }

  bool get isDefault =>
      distance == _defaultSearchRadius &&
      rideCommunity == 'All' &&
      skillLevel == 'All' &&
      bikeType == 'All' &&
      ridingStyles.length == 1 &&
      ridingStyles.first == 'All' &&
      !onlineOnly;

  int get activeCount {
    int count = 0;
    if (distance != _defaultSearchRadius) count++;
    if (rideCommunity != 'All') count++;
    if (skillLevel != 'All') count++;
    if (bikeType != 'All') count++;
    if (!(ridingStyles.length == 1 && ridingStyles.first == 'All')) count++;
    if (onlineOnly) count++;
    return count;
  }
}

class FilterPanelWidget extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(FilterState) onApply;
  final FilterState initialState;

  const FilterPanelWidget({
    super.key,
    required this.onClose,
    required this.onApply,
    this.initialState = const FilterState(),
  });

  @override
  State<FilterPanelWidget> createState() => _FilterPanelWidgetState();
}

class _FilterPanelWidgetState extends State<FilterPanelWidget> {
  late double _distance;
  late String _selectedRideCommunity;
  late String _selectedSkill;
  late String _selectedBikeType;
  late List<String> _selectedRidingStyles;
  late bool _onlineOnly;
  bool _isMetric = true;

  final List<String> _skillLevels = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];
  final List<String> _rideCommunities = ['All', 'motorcycle', 'bicycle'];
  final List<String> _motorcycleTypes = [
    'All',
    'sport',
    'naked',
    'cruiser',
    'adventure',
    'touring',
    'scrambler',
    'dirt',
    'scooter',
  ];
  final List<String> _bicycleTypes = [
    'All',
    'road_bicycle',
    'gravel_bicycle',
    'mountain_bicycle',
    'hybrid_bicycle',
    'e_bike',
    'touring_bicycle',
    'bmx',
    'folding_bicycle',
  ];
  final List<String> _ridingStyles = [
    'All',
    'Social',
    'Fitness',
    'Touring',
    'Sport',
    'Off-road',
    'Commuting',
    'Track / Training',
    'Casual',
  ];

  @override
  void initState() {
    super.initState();
    _distance = widget.initialState.distance;
    _selectedRideCommunity = widget.initialState.rideCommunity;
    _selectedSkill = widget.initialState.skillLevel;
    _selectedBikeType = widget.initialState.bikeType;
    _selectedRidingStyles = List.from(widget.initialState.ridingStyles);
    _onlineOnly = widget.initialState.onlineOnly;
    _loadUnitPreference();
  }

  Future<void> _loadUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsMetric = prefs.getBool('unit_system_metric');
    final legacyMetric = prefs.getBool('isMetric');
    final profileUnit = prefs.getString('profile_speed_unit');

    if (mounted) {
      setState(() {
        _isMetric =
            settingsMetric ?? legacyMetric ?? (profileUnit != 'imperial');
      });
    }
  }

  void _toggleMultiSelect(List<String> list, String value) {
    setState(() {
      if (value == 'All') {
        list
          ..clear()
          ..add('All');
      } else {
        list.remove('All');
        if (list.contains(value)) {
          list.remove(value);
          if (list.isEmpty) list.add('All');
        } else {
          list.add(value);
        }
      }
    });
  }

  List<String> get _vehicleTypeOptions {
    if (_selectedRideCommunity == 'motorcycle') return _motorcycleTypes;
    if (_selectedRideCommunity == 'bicycle') return _bicycleTypes;

    return [
      'All',
      ..._motorcycleTypes.where((type) => type != 'All'),
      ..._bicycleTypes.where((type) => type != 'All'),
    ];
  }

  String _labelForOption(String value) {
    switch (value) {
      case 'motorcycle':
        return 'Motorcycle';
      case 'bicycle':
        return 'Bicycle';
      case 'sport':
        return 'Sport';
      case 'naked':
        return 'Naked';
      case 'cruiser':
        return 'Cruiser';
      case 'adventure':
        return 'Adventure';
      case 'touring':
        return 'Touring';
      case 'scrambler':
        return 'Scrambler';
      case 'dirt':
        return 'Dirt / Enduro';
      case 'scooter':
        return 'Scooter';
      case 'road_bicycle':
        return 'Road';
      case 'gravel_bicycle':
        return 'Gravel';
      case 'mountain_bicycle':
        return 'Mountain';
      case 'hybrid_bicycle':
        return 'Hybrid';
      case 'e_bike':
        return 'E-Bike';
      case 'touring_bicycle':
        return 'Cycle Touring';
      case 'bmx':
        return 'BMX';
      case 'folding_bicycle':
        return 'Folding';
      default:
        return value;
    }
  }

  void _resetAll() {
    setState(() {
      _distance = _defaultSearchRadius;
      _selectedRideCommunity = 'All';
      _selectedSkill = 'All';
      _selectedBikeType = 'All';
      _selectedRidingStyles = ['All'];
      _onlineOnly = false;
    });
  }

  void _applyFilters() {
    widget.onApply(
      FilterState(
        distance: _distance,
        rideCommunity: _selectedRideCommunity,
        skillLevel: _selectedSkill,
        bikeType: _selectedBikeType,
        ridingStyles: List.from(_selectedRidingStyles),
        onlineOnly: _onlineOnly,
      ),
    );
    widget.onClose();
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.5.h),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildChipRow({
    required ThemeData theme,
    required List<String> options,
    required List<String> selected,
    required Color activeColor,
    required void Function(String) onTap,
    String Function(String)? labelBuilder,
  }) {
    return SizedBox(
      height: 5.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => SizedBox(width: 2.w),
        itemBuilder: (_, i) {
          final isSelected = selected.contains(options[i]);
          return GestureDetector(
            onTap: () => onTap(options[i]),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? activeColor : theme.colorScheme.outline,
                ),
              ),
              child: Text(
                labelBuilder?.call(options[i]) ?? options[i],
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Filters',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _resetAll,
                      child: Text(
                        'Reset All',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Icon(
                        AppIcons.close,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 1.h),

            // Distance
            Text(
              'Distance: ${_distance.round()} ${_isMetric ? 'km' : 'miles'}',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: _distance,
              min: 5,
              max: _defaultSearchRadius,
              divisions: 99,
              onChanged: (v) => setState(() => _distance = v),
            ),
            SizedBox(height: 0.5.h),

            // Ride Community
            _buildSectionLabel(theme, 'Ride Community'),
            _buildChipRow(
              theme: theme,
              options: _rideCommunities,
              selected: [_selectedRideCommunity],
              activeColor: theme.colorScheme.primary,
              labelBuilder: _labelForOption,
              onTap: (v) => setState(() {
                _selectedRideCommunity = v;
                _selectedBikeType = 'All';
              }),
            ),
            SizedBox(height: 1.h),

            // Skill Level
            _buildSectionLabel(theme, 'Skill Level'),
            _buildChipRow(
              theme: theme,
              options: _skillLevels,
              selected: [_selectedSkill],
              activeColor: theme.colorScheme.primary,
              onTap: (v) => setState(() => _selectedSkill = v),
            ),
            SizedBox(height: 1.h),

            // Vehicle Type
            _buildSectionLabel(theme, 'Vehicle Type'),
            _buildChipRow(
              theme: theme,
              options: _vehicleTypeOptions,
              selected: [_selectedBikeType],
              activeColor: theme.colorScheme.secondary,
              labelBuilder: _labelForOption,
              onTap: (v) => setState(() => _selectedBikeType = v),
            ),
            SizedBox(height: 1.h),

            // Riding Style
            _buildSectionLabel(theme, 'Riding Style'),
            _buildChipRow(
              theme: theme,
              options: _ridingStyles,
              selected: _selectedRidingStyles,
              activeColor: theme.colorScheme.tertiary,
              onTap: (v) => _toggleMultiSelect(_selectedRidingStyles, v),
            ),
            SizedBox(height: 1.h),

            // Online Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Show Online Only',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: _onlineOnly,
                  onChanged: (v) => setState(() => _onlineOnly = v),
                  activeThumbColor: theme.colorScheme.primary,
                ),
              ],
            ),
            SizedBox(height: 1.h),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

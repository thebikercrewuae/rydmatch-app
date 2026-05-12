import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../widgets/app_icons.dart';

class FilterState {
  final double distance;
  final String skillLevel;
  final String bikeType;
  final List<String> bikeBrands;
  final RangeValues engineSize;
  final List<String> ridingStyles;
  final bool onlineOnly;

  const FilterState({
    this.distance = 500,
    this.skillLevel = 'All',
    this.bikeType = 'All',
    this.bikeBrands = const ['All'],
    this.engineSize = const RangeValues(125, 2000),
    this.ridingStyles = const ['All'],
    this.onlineOnly = false,
  });

  FilterState copyWith({
    double? distance,
    String? skillLevel,
    String? bikeType,
    List<String>? bikeBrands,
    RangeValues? engineSize,
    List<String>? ridingStyles,
    bool? onlineOnly,
  }) {
    return FilterState(
      distance: distance ?? this.distance,
      skillLevel: skillLevel ?? this.skillLevel,
      bikeType: bikeType ?? this.bikeType,
      bikeBrands: bikeBrands ?? this.bikeBrands,
      engineSize: engineSize ?? this.engineSize,
      ridingStyles: ridingStyles ?? this.ridingStyles,
      onlineOnly: onlineOnly ?? this.onlineOnly,
    );
  }

  bool get isDefault =>
      distance == 500 &&
      skillLevel == 'All' &&
      bikeType == 'All' &&
      bikeBrands.length == 1 &&
      bikeBrands.first == 'All' &&
      engineSize.start == 125 &&
      engineSize.end == 2000 &&
      ridingStyles.length == 1 &&
      ridingStyles.first == 'All' &&
      !onlineOnly;

  int get activeCount {
    int count = 0;
    if (distance != 500) count++;
    if (skillLevel != 'All') count++;
    if (bikeType != 'All') count++;
    if (!(bikeBrands.length == 1 && bikeBrands.first == 'All')) count++;
    if (engineSize.start != 125 || engineSize.end != 2000) count++;
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
  late String _selectedSkill;
  late String _selectedBikeType;
  late List<String> _selectedBikeBrands;
  late RangeValues _engineSize;
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
  final List<String> _bikeTypes = [
    'All',
    'Sport',
    'Cruiser',
    'Adventure',
    'Naked',
    'Touring',
  ];
  final List<String> _bikeBrands = [
    'All',
    'Ducati',
    'BMW',
    'Honda',
    'Kawasaki',
    'Yamaha',
    'Suzuki',
    'Harley-Davidson',
    'KTM',
    'Triumph',
    'Royal Enfield',
    'Other',
  ];
  final List<String> _ridingStyles = [
    'All',
    'Touring',
    'Sport',
    'Off-Road',
    'Commuting',
    'Track Day',
    'Casual',
  ];

  @override
  void initState() {
    super.initState();
    _distance = widget.initialState.distance;
    _selectedSkill = widget.initialState.skillLevel;
    _selectedBikeType = widget.initialState.bikeType;
    _selectedBikeBrands = List.from(widget.initialState.bikeBrands);
    _engineSize = widget.initialState.engineSize;
    _selectedRidingStyles = List.from(widget.initialState.ridingStyles);
    _onlineOnly = widget.initialState.onlineOnly;
    _loadUnitPreference();
  }

  Future<void> _loadUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isMetric = prefs.getBool('unit_system_metric') ?? true;
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

  void _resetAll() {
    setState(() {
      _distance = 500;
      _selectedSkill = 'All';
      _selectedBikeType = 'All';
      _selectedBikeBrands = ['All'];
      _engineSize = const RangeValues(125, 2000);
      _selectedRidingStyles = ['All'];
      _onlineOnly = false;
    });
  }

  void _applyFilters() {
    widget.onApply(
      FilterState(
        distance: _distance,
        skillLevel: _selectedSkill,
        bikeType: _selectedBikeType,
        bikeBrands: List.from(_selectedBikeBrands),
        engineSize: _engineSize,
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
                options[i],
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
    final engineStart = _engineSize.start.round();
    final engineEnd = _engineSize.end.round();
    final engineEndLabel = engineEnd >= 2000 ? '2000cc+' : '${engineEnd}cc';

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
              max: 100,
              divisions: 19,
              onChanged: (v) => setState(() => _distance = v),
            ),
            SizedBox(height: 0.5.h),

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

            // Bike Type
            _buildSectionLabel(theme, 'Bike Type'),
            _buildChipRow(
              theme: theme,
              options: _bikeTypes,
              selected: [_selectedBikeType],
              activeColor: theme.colorScheme.secondary,
              onTap: (v) => setState(() => _selectedBikeType = v),
            ),
            SizedBox(height: 1.h),

            // Bike Brand
            _buildSectionLabel(theme, 'Bike Brand'),
            _buildChipRow(
              theme: theme,
              options: _bikeBrands,
              selected: _selectedBikeBrands,
              activeColor: theme.colorScheme.primary,
              onTap: (v) => _toggleMultiSelect(_selectedBikeBrands, v),
            ),
            SizedBox(height: 1.h),

            // Engine Size
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Engine Size',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${engineStart}cc – $engineEndLabel',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            RangeSlider(
              values: _engineSize,
              min: 125,
              max: 2000,
              divisions: 38,
              onChanged: (v) => setState(() => _engineSize = v),
            ),
            SizedBox(height: 0.5.h),

            // Riding Style
            _buildSectionLabel(theme, 'Riding Style'),
            _buildChipRow(
              theme: theme,
              options: _ridingStyles,
              selected: _selectedRidingStyles,
              activeColor:
                  theme.colorScheme.tertiary ?? theme.colorScheme.primary,
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

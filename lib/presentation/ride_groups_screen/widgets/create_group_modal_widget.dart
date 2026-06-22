import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';

import '../../../models/ride_group_model.dart';
import '../../../services/profile_service.dart';
import '../../../services/swipe_service.dart';

class CreateGroupModalWidget extends StatefulWidget {
  final Function(RideGroup, Set<String>) onCreate;

  final String? prefillRoute;
  final DateTime? prefillDate;
  final double? prefillDistanceKm;
  final String? prefillRouteType;
  final List<String>? prefillWaypoints;
  final List<LatLng>? prefillRoutePolylinePoints;

  const CreateGroupModalWidget({
    super.key,
    required this.onCreate,
    this.prefillRoute,
    this.prefillDate,
    this.prefillDistanceKm,
    this.prefillRouteType,
    this.prefillWaypoints,
    this.prefillRoutePolylinePoints,
  });

  @override
  State<CreateGroupModalWidget> createState() => _CreateGroupModalWidgetState();
}

class _CreateGroupModalWidgetState extends State<CreateGroupModalWidget> {
  static const int _maxGroupSize = 15;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _routeController = TextEditingController();

  int _groupSize = 4;
  String _rideCommunity = 'motorcycle';
  String _rideType = 'Scenic';
  String _difficulty = 'Moderate';
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  List<Map<String, dynamic>> _matchedRiders = [];
  final Set<String> _selectedInvitees = {};
  bool _loadingRiders = false;

  final List<String> _motorcycleRideTypes = [
    'Scenic',
    'Sport',
    'Adventure',
    'Touring',
    'Track Day',
  ];

  final List<String> _bicycleRideTypes = [
    'Social',
    'Fitness',
    'Road',
    'Gravel',
    'MTB',
  ];

  final List<String> _difficulties = ['Easy', 'Moderate', 'Hard'];

  List<String> get _rideTypes =>
      _rideCommunity == 'bicycle' ? _bicycleRideTypes : _motorcycleRideTypes;

  String get _communityLabel =>
      _rideCommunity == 'bicycle' ? 'Bicycle' : 'Motorcycle';

  String get _vehicleLabel => _rideCommunity == 'bicycle' ? 'cycle' : 'bike';

  @override
  void initState() {
    super.initState();

    _selectedDate =
        widget.prefillDate ?? DateTime.now().add(const Duration(days: 3));

    _selectedTime = TimeOfDay(
      hour: widget.prefillDate?.hour ?? 9,
      minute: widget.prefillDate?.minute ?? 0,
    );

    if (widget.prefillRoute != null && widget.prefillRoute!.isNotEmpty) {
      _routeController.text = widget.prefillRoute!;
    }

    if (widget.prefillRouteType != null) {
      final typeMap = {
        'fastest': 'Sport',
        'scenic': 'Scenic',
        'avoid_motorways': 'Adventure',
      };

      _rideType = typeMap[widget.prefillRouteType] ?? 'Scenic';
    }

    _loadRideCommunity();
    _loadMatchedRiders();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchedRiders() async {
    if (!mounted) return;

    setState(() => _loadingRiders = true);

    try {
      final community = _rideCommunity;
      final matches = await SwipeService.instance.getInviteableMatches();

      final riders = matches
          .where((match) {
            final rideMode = match['ride_mode'] as String? ?? 'motorcycle';
            return rideMode == community;
          })
          .map<Map<String, dynamic>>((match) {
            final bikeTypes = match['bike_types'];

            String bikeModel = '';
            if (bikeTypes is List && bikeTypes.isNotEmpty) {
              bikeModel = bikeTypes.first.toString();
            } else if (bikeTypes is String && bikeTypes.isNotEmpty) {
              bikeModel = bikeTypes;
            }

            final email = match['email'] as String?;
            final fallbackName = email != null && email.isNotEmpty
                ? email.split('@').first
                : 'Rider';

            return {
              'userId': match['id'] as String,
              'name': match['full_name'] as String? ?? fallbackName,
              'image': match['avatar_url'] as String? ?? '',
              'bikeModel': bikeModel,
              'rideMode': match['ride_mode'] as String? ?? 'motorcycle',
            };
          })
          .toList();

      if (!mounted) return;
      if (community != _rideCommunity) return;

      setState(() {
        _matchedRiders = riders;
        _loadingRiders = false;
      });
    } catch (e, stack) {
      debugPrint('CreateGroupModal: _loadMatchedRiders error: $e\n$stack');

      if (!mounted) return;

      setState(() {
        _matchedRiders = [];
        _loadingRiders = false;
      });
    }
  }

  Future<void> _loadRideCommunity() async {
    try {
      final profile = await ProfileService.loadProfile();
      final rideMode = profile['rideMode'] as String? ?? 'motorcycle';
      if (!mounted || rideMode != 'bicycle') return;

      setState(() {
        _rideCommunity = 'bicycle';
        _rideType = 'Social';
      });
      _loadMatchedRiders();
    } catch (e) {
      debugPrint('CreateGroupModal: _loadRideCommunity error: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _setRideCommunity(String community) {
    if (_rideCommunity == community) return;

    setState(() {
      _rideCommunity = community;
      _rideType = community == 'bicycle' ? 'Social' : 'Scenic';
      _selectedInvitees.clear();
    });
    _loadMatchedRiders();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final group = RideGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      route: _routeController.text.trim(),
      date: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
      maxRiders: _groupSize,
      memberCount: 1,
      leaderName: 'You',
      rideCommunity: _rideCommunity,
      rideType: _rideType,
      difficulty: _difficulty,
      duration: '${2 + _groupSize ~/ 2}h',
      routeImageUrl: _rideCommunity == 'bicycle'
          ? 'https://images.pexels.com/photos/163491/bike-mountain-mountain-biking-trail-163491.jpeg'
          : 'https://images.pexels.com/photos/1119796/pexels-photo-1119796.jpeg',
      routePolyline: widget.prefillRoutePolylinePoints ?? const [],
      routeWaypoints: widget.prefillWaypoints ?? const [],
    );

    widget.onCreate(group, Set<String>.from(_selectedInvitees));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isFromRoutePlanner = widget.prefillRoute != null;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.only(
        left: 5.w,
        right: 5.w,
        top: 2.h,
        bottom:
            mediaQuery.viewInsets.bottom + mediaQuery.viewPadding.bottom + 3.h,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 10.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create Group Ride',
                      style: GoogleFonts.dmSans(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isFromRoutePlanner)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B365D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.route_rounded,
                            size: 12,
                            color: Color(0xFF1B365D),
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            'From Route Planner',
                            style: GoogleFonts.dmSans(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1B365D),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 2.h),
              _buildLabel('Ride Community'),
              Row(
                children: [
                  Expanded(
                    child: _communityOption(
                      theme,
                      value: 'motorcycle',
                      label: 'Motorcycle',
                      icon: Icons.motorcycle_rounded,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: _communityOption(
                      theme,
                      value: 'bicycle',
                      label: 'Bicycle',
                      icon: Icons.directions_bike_rounded,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.5.h),
              _buildLabel('Ride Name'),
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.dmSans(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: _rideCommunity == 'bicycle'
                      ? 'e.g. Friday Creek Loop'
                      : 'e.g. Sunday Mountain Run',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a ride name'
                    : null,
              ),
              SizedBox(height: 1.5.h),
              _buildLabel('Route / Destination'),
              TextFormField(
                controller: _routeController,
                style: GoogleFonts.dmSans(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: _rideCommunity == 'bicycle'
                      ? 'e.g. Al Qudra Cycle Track'
                      : 'e.g. Pacific Coast Highway',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: const Icon(Icons.route_rounded, size: 18),
                  suffixIcon: isFromRoutePlanner
                      ? Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.green[600],
                        )
                      : null,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a route'
                    : null,
              ),
              if (isFromRoutePlanner &&
                  widget.prefillDistanceKm != null &&
                  widget.prefillDistanceKm! > 0) ...[
                SizedBox(height: 0.8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B365D).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: const Color(0xFF1B365D).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.straighten_rounded,
                        size: 14,
                        color: Color(0xFF1B365D),
                      ),
                      SizedBox(width: 1.5.w),
                      Text(
                        '${widget.prefillDistanceKm!.toStringAsFixed(1)} km',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1B365D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 1.5.h),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Date'),
                        GestureDetector(
                          onTap: _pickDate,
                          child: _dateTimeBox(
                            theme,
                            Icons.calendar_today_rounded,
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Time'),
                        GestureDetector(
                          onTap: _pickTime,
                          child: _dateTimeBox(
                            theme,
                            Icons.access_time_rounded,
                            _selectedTime.format(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.5.h),
              _buildLabel('Group Size (max $_maxGroupSize riders)'),
              Wrap(
                spacing: 2.w,
                runSpacing: 1.h,
                children: List.generate(_maxGroupSize - 1, (index) {
                  final size = index + 2;
                  final selected = _groupSize == size;

                  return GestureDetector(
                    onTap: () => setState(() => _groupSize = size),
                    child: Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Center(
                        child: Text(
                          '$size',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 1.5.h),
              _buildLabel('$_communityLabel Ride Type'),
              Wrap(
                spacing: 2.w,
                runSpacing: 1.h,
                children: _rideTypes.map((type) {
                  final selected = _rideType == type;

                  return GestureDetector(
                    onTap: () => setState(() => _rideType = type),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 0.8.h,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Text(
                        type,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 1.5.h),
              _buildLabel('Difficulty'),
              Row(
                children: _difficulties.map((difficulty) {
                  final selected = _difficulty == difficulty;

                  Color color;
                  switch (difficulty) {
                    case 'Easy':
                      color = const Color(0xFF4CAF50);
                      break;
                    case 'Hard':
                      color = const Color(0xFFE85A4F);
                      break;
                    default:
                      color = const Color(0xFFFF9800);
                  }

                  return Padding(
                    padding: EdgeInsets.only(right: 2.w),
                    child: GestureDetector(
                      onTap: () => setState(() => _difficulty = difficulty),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 0.8.h,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.15)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20.0),
                          border: selected ? Border.all(color: color) : null,
                        ),
                        child: Text(
                          difficulty,
                          style: GoogleFonts.dmSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? color
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Invite Riders',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (_selectedInvitees.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.3.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE85A4F),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        '${_selectedInvitees.length} selected',
                        style: GoogleFonts.dmSans(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 1.h),
              _buildInviteRidersSection(theme),
              SizedBox(height: 3.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Text(
                    _selectedInvitees.isNotEmpty
                        ? 'Create & Invite ${_selectedInvitees.length} Rider${_selectedInvitees.length > 1 ? 's' : ''}'
                        : 'Create Ride',
                    style: GoogleFonts.dmSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTimeBox(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _communityOption(
    ThemeData theme, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _rideCommunity == value;

    return GestureDetector(
      onTap: () => _setRideCommunity(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.4.h),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : theme.colorScheme.onSurface,
            ),
            SizedBox(width: 2.w),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteRidersSection(ThemeData theme) {
    if (_loadingRiders) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 1.5.h),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (_matchedRiders.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 3.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          children: [
            Icon(Icons.people_outline, size: 18, color: Colors.grey[500]),
            SizedBox(width: 2.w),
            Text(
              'No ${_communityLabel.toLowerCase()} riders available to invite',
              style: GoogleFonts.dmSans(
                fontSize: 11.sp,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _matchedRiders.take(6).map((rider) {
        final userId = rider['userId'] as String;
        final isSelected = _selectedInvitees.contains(userId);
        final imageUrl = rider['image'] as String? ?? '';
        final bikeModel = rider['bikeModel'] as String? ?? '';

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedInvitees.remove(userId);
              } else {
                _selectedInvitees.add(userId);
              }
            });
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 0.8.h),
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1B365D).withValues(alpha: 0.08)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
              borderRadius: BorderRadius.circular(10.0),
              border: isSelected
                  ? Border.all(
                      color: const Color(0xFF1B365D).withValues(alpha: 0.4),
                    )
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : null,
                  child: imageUrl.isEmpty
                      ? Icon(Icons.person, size: 18, color: Colors.grey[500])
                      : null,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider['name'] as String? ?? 'Rider',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (bikeModel.isNotEmpty)
                        Text(
                          '$_vehicleLabel: $bikeModel',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1B365D)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1B365D)
                          : Colors.grey[400]!,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.8.h),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

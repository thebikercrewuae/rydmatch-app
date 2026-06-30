import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './widgets/bike_card_widget.dart';
import './widgets/bike_detail_sheet_widget.dart';
import './widgets/add_edit_bike_modal_widget.dart';
import './widgets/garage_empty_state_widget.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/toast_widget.dart';
import '../../widgets/skeleton_loader_widget.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import 'package:image_picker/image_picker.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  bool _isLoading = true;

  final List<Map<String, dynamic>> _bikes = [];

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  List<String> _normalizeMods(dynamic rawMods) {
    if (rawMods is List) {
      return rawMods
          .map((mod) => mod.toString().trim())
          .where((mod) => mod.isNotEmpty)
          .toList();
    }

    if (rawMods is String && rawMods.trim().isNotEmpty) {
      return rawMods
          .split(',')
          .map((mod) => mod.trim())
          .where((mod) => mod.isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  @override
  void initState() {
    super.initState();
    _loadBikes();
  }

  Future<void> _loadBikes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final uid = _userId;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final data = await _supabase
          .from('garage_bikes')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _bikes.clear();
          for (final row in data as List<dynamic>) {
            final r = Map<String, dynamic>.from(row as Map);
            final photoUrl = r['photo_url'] as String?;
            _bikes.add({
              'id': r['id']?.toString() ?? '',
              'make': r['make'] ?? '',
              'model': r['model'] ?? '',
              'year': r['year']?.toString() ?? '',
              'color': r['color'] ?? '',
              'engineSize': r['engine_size'] ?? '',
              'mileage': r['mileage'] ?? '',
              'bikeType': r['bike_type'] ?? '',
              'notes': r['notes'] ?? '',
              'isPrimary': r['is_primary'] ?? false,
              'photo': photoUrl,
              'photos': photoUrl != null && photoUrl.isNotEmpty
                  ? [
                      {'url': photoUrl, 'label': 'Motorcycle photo'},
                    ]
                  : [],
              'mods': _normalizeMods(r['mods']),
            });
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    await _loadBikes();
  }

  Future<void> _saveBike(Map<String, dynamic> bike) async {
    final uid = _userId;
    if (uid == null) return;

    // If this is the first bike, make it primary
    final isPrimary = bike['isPrimary'] == true || _bikes.isEmpty;

    // Upload photo if a new XFile was provided
    String? photoUrl = bike['photo'] as String?;
    final photoFile = bike['photoFile'] as XFile?;

    if (photoFile != null) {
      photoUrl = await ProfileService.uploadPhoto(photoFile, 'bikes');
      if (photoUrl == null || photoUrl.isEmpty) {
        throw Exception(
          ProfileService.lastUploadError ?? 'Motorcycle photo upload failed.',
        );
      }
    }

    await _supabase.from('garage_bikes').insert({
      'user_id': uid,
      'make': bike['make'] ?? '',
      'model': bike['model'] ?? '',
      'year': int.tryParse(bike['year']?.toString() ?? ''),
      'color': bike['color'] ?? '',
      'engine_size': bike['engineSize'] ?? '',
      'mileage': bike['mileage'] ?? '',
      'bike_type': bike['bikeType'] ?? '',
      'notes': bike['notes'] ?? '',
      'mods': _normalizeMods(bike['mods']),
      'is_primary': isPrimary,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
  }

  Future<void> _updateBike(String id, Map<String, dynamic> bike) async {
    final uid = _userId;
    if (uid == null) return;

    final photoFile = bike['photoFile'] as XFile?;

    String? photoUrl = bike['photo'] as String?;

    if (photoFile != null) {
      photoUrl = await ProfileService.uploadPhoto(photoFile, 'bikes');
      if (photoUrl == null || photoUrl.isEmpty) {
        throw Exception(
          ProfileService.lastUploadError ?? 'Motorcycle photo upload failed.',
        );
      }
    }

    final updateData = <String, dynamic>{
      'make': bike['make'] ?? '',
      'model': bike['model'] ?? '',
      'year': int.tryParse(bike['year']?.toString() ?? ''),
      'color': bike['color'] ?? '',
      'engine_size': bike['engineSize'] ?? '',
      'mileage': bike['mileage'] ?? '',
      'bike_type': bike['bikeType'] ?? '',
      'notes': bike['notes'] ?? '',
      'mods': _normalizeMods(bike['mods']),
      'photo_url': photoUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase
        .from('garage_bikes')
        .update(updateData)
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<void> _deleteBikeFromDb(String id) async {
    final uid = _userId;
    if (uid == null) return;
    await _supabase
        .from('garage_bikes')
        .delete()
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<void> _setPrimaryInDb(String id) async {
    final uid = _userId;
    if (uid == null) return;
    // Clear all primary flags for this user
    await _supabase
        .from('garage_bikes')
        .update({'is_primary': false})
        .eq('user_id', uid);
    // Set the selected bike as primary
    await _supabase
        .from('garage_bikes')
        .update({'is_primary': true})
        .eq('id', id)
        .eq('user_id', uid);
  }

  void _openBikeDetail(Map<String, dynamic> bike) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BikeDetailSheetWidget(
        bike: bike,
        onEdit: () {
          Navigator.pop(context);
          _openEditBike(bike);
        },
      ),
    );
  }

  void _openEditBike(Map<String, dynamic> bike) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditBikeModalWidget(
        existingBike: bike,
        onSave: (updated) async {
          try {
            await _updateBike(bike['id'] as String, updated);
            await _loadBikes();
            if (mounted) {
              AppToast.show(context, message: 'Bike updated successfully');
            }
          } catch (_) {
            if (mounted) {
              AppToast.show(context, message: 'Failed to update bike');
            }
          }
        },
      ),
    );
  }

  void _openAddBike() {
    HapticService.instance.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditBikeModalWidget(
        onSave: (newBike) async {
          try {
            await _saveBike(newBike);
            await _loadBikes();
            if (mounted) {
              AppToast.show(context, message: 'Bike added to your garage 🏍️');
            }
          } catch (_) {
            if (mounted) AppToast.show(context, message: 'Failed to add bike');
          }
        },
      ),
    );
  }

  void _setPrimary(String id) async {
    try {
      await _setPrimaryInDb(id);
      await _loadBikes();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, message: 'Failed to update primary bike');
      }
    }
  }

  void _duplicateBike(Map<String, dynamic> bike) async {
    try {
      await _saveBike({
        ...bike,
        'isPrimary': false,
        'make': '${bike['make']} (Copy)',
      });
      await _loadBikes();
    } catch (_) {
      if (mounted) AppToast.show(context, message: 'Failed to duplicate bike');
    }
  }

  void _deleteBike(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Delete Bike',
          style: GoogleFonts.manrope(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove this bike from your garage?',
          style: GoogleFonts.manrope(
            fontSize: 11.sp,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _deleteBikeFromDb(id);
                await _loadBikes();
              } catch (_) {
                if (mounted) {
                  AppToast.show(context, message: 'Failed to delete bike');
                }
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE85A4F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(size: 7.w),
            SizedBox(width: 2.w),
            Text(
              'My Garage',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 3.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_bikes.length} ${_bikes.length == 1 ? 'bike' : 'bikes'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(width: 2.w),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed('/settings-screen'),
                  child: const Icon(
                    AppIcons.settings,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildGarageSkeleton()
          : _bikes.isEmpty
          ? GarageEmptyStateWidget(onAddBike: _openAddBike)
          : RefreshIndicator(
              onRefresh: _onRefresh,
              color: const Color(0xFF1B365D),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 1.h),
                itemCount: _bikes.length,
                itemBuilder: (_, i) {
                  final bike = _bikes[i];
                  return BikeCardWidget(
                    bike: bike,
                    onTap: () => _openBikeDetail(bike),
                    onSetPrimary: () => _setPrimary(bike['id'] as String),
                    onDuplicate: () => _duplicateBike(bike),
                    onDelete: () => _deleteBike(bike['id'] as String),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddBike,
        backgroundColor: const Color(0xFFE85A4F),
        foregroundColor: Colors.white,
        elevation: 4,
        child: Icon(AppIcons.add, size: 28),
      ),
    );
  }

  Widget _buildGarageSkeleton() {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        BikeCardSkeleton(),
        BikeCardSkeleton(),
        BikeCardSkeleton(),
      ],
    );
  }
}

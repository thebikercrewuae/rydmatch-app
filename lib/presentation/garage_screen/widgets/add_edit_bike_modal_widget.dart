import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../widgets/app_icons.dart';

class AddEditBikeModalWidget extends StatefulWidget {
  final Map<String, dynamic>? existingBike;
  final Function(Map<String, dynamic>) onSave;

  const AddEditBikeModalWidget({
    super.key,
    this.existingBike,
    required this.onSave,
  });

  @override
  State<AddEditBikeModalWidget> createState() => _AddEditBikeModalWidgetState();
}

class _AddEditBikeModalWidgetState extends State<AddEditBikeModalWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _modsController;
  final List<String> _uploadedPhotos = [];
  // Track newly picked XFile photos (not yet uploaded)
  XFile? _newPhotoFile;

  @override
  void initState() {
    super.initState();
    final bike = widget.existingBike;
    _makeController = TextEditingController(
      text: bike?['make'] as String? ?? '',
    );
    _modelController = TextEditingController(
      text: bike?['model'] as String? ?? '',
    );
    _yearController = TextEditingController(
      text: bike?['year'] != null ? bike!['year'].toString() : '',
    );

    // Fix: mods comes back from JSON as List<dynamic>, not List<String>
    final rawMods = bike?['mods'];
    List<String> mods = [];
    if (rawMods != null && rawMods is List) {
      mods = rawMods.map((e) => e.toString()).toList();
    }
    _modsController = TextEditingController(text: mods.join(', '));

    // Fix: photos comes back from JSON as List<dynamic> with dynamic maps
    final rawPhotos = bike?['photos'];
    if (rawPhotos != null && rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p is Map) {
          final url = p['url']?.toString() ?? '';
          if (url.isNotEmpty) _uploadedPhotos.add(url);
        } else if (p is String && p.isNotEmpty) {
          _uploadedPhotos.add(p);
        }
      }
    }
    // Also check the single 'photo' field as fallback
    if (_uploadedPhotos.isEmpty && bike?['photo'] != null) {
      final singlePhoto = bike!['photo'].toString();
      if (singlePhoto.isNotEmpty) _uploadedPhotos.add(singlePhoto);
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _modsController.dispose();
    super.dispose();
  }

  void _showPhotoSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
          ),
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              Text(
                'Add Photo',
                style: GoogleFonts.manrope(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 1.h),
              ListTile(
                leading: Icon(AppIcons.camera, color: const Color(0xFF1B365D)),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.manrope(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 78,
                      maxWidth: 1600,
                      maxHeight: 1600,
                    );
                    if (image != null) {
                      setState(() {
                        _newPhotoFile = image;
                        _uploadedPhotos.add(image.path);
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not open camera. Please try again.',
                            style: GoogleFonts.manrope(fontSize: 11.sp),
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              ListTile(
                leading: Icon(AppIcons.help, color: const Color(0xFF1B365D)),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.manrope(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 78,
                      maxWidth: 1600,
                      maxHeight: 1600,
                    );
                    if (image != null) {
                      setState(() {
                        _newPhotoFile = image;
                        _uploadedPhotos.add(image.path);
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not open gallery. Please try again.',
                            style: GoogleFonts.manrope(fontSize: 11.sp),
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final modsText = _modsController.text.trim();
      final mods = modsText.isEmpty
          ? <String>[]
          : modsText
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();

      // Only include existing network URLs in photos list (not local paths)
      final existingNetworkPhotos = _uploadedPhotos
          .where((p) => p.startsWith('http://') || p.startsWith('https://'))
          .toList();

      final photos = existingNetworkPhotos
          .map((url) => {'url': url, 'label': 'Motorcycle photo'})
          .toList();

      widget.onSave({
        'make': _makeController.text.trim(),
        'model': _modelController.text.trim(),
        'year': int.tryParse(_yearController.text.trim()) ?? 2024,
        'mods': mods,
        'photos': photos,
        'photo': existingNetworkPhotos.isNotEmpty
            ? existingNetworkPhotos.first
            : null,
        'isPrimary': widget.existingBike?['isPrimary'] ?? false,
        // Pass the new XFile so garage_screen can upload it
        'photoFile': _newPhotoFile,
      });
      Navigator.pop(context);
    }
  }

  Widget _buildPhotoThumbnail(String path) {
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    if (isNetwork) {
      return Image.network(path, fit: BoxFit.cover);
    } else if (kIsWeb) {
      return Image.network(path, fit: BoxFit.cover);
    } else {
      return Image.file(File(path), fit: BoxFit.cover);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existingBike != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Bike' : 'Add New Bike',
                      style: GoogleFonts.manrope(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(AppIcons.close),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 1.h),
                        _SectionLabel(label: 'Make'),
                        SizedBox(height: 0.8.h),
                        TextFormField(
                          controller: _makeController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Ducati, Honda, BMW',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          style: GoogleFonts.manrope(fontSize: 12.sp),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                        SizedBox(height: 1.5.h),
                        _SectionLabel(label: 'Model'),
                        SizedBox(height: 0.8.h),
                        TextFormField(
                          controller: _modelController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Panigale V4, CBR600RR',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          style: GoogleFonts.manrope(fontSize: 12.sp),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                        SizedBox(height: 1.5.h),
                        _SectionLabel(label: 'Year'),
                        SizedBox(height: 0.8.h),
                        TextFormField(
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: 'e.g. 2023',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          style: GoogleFonts.manrope(fontSize: 12.sp),
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return 'Required';
                            final y = int.tryParse(v!.trim());
                            if (y == null || y < 1900 || y > 2030) {
                              return 'Enter a valid year';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 1.5.h),
                        _SectionLabel(label: 'Modifications'),
                        SizedBox(height: 0.5.h),
                        Text(
                          'Separate multiple mods with commas',
                          style: GoogleFonts.manrope(
                            fontSize: 10.sp,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 0.8.h),
                        TextFormField(
                          controller: _modsController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Akrapovic exhaust, Ohlins suspension, Quick shifter',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          style: GoogleFonts.manrope(fontSize: 12.sp),
                        ),
                        SizedBox(height: 2.h),
                        _SectionLabel(label: 'Photos'),
                        SizedBox(height: 1.h),
                        SizedBox(
                          height: 12.h,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              GestureDetector(
                                onTap: _showPhotoSourceDialog,
                                child: Container(
                                  width: 20.w,
                                  height: 12.h,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(
                                      color: theme.dividerColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        AppIcons.add,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        size: 28,
                                      ),
                                      SizedBox(height: 0.4.h),
                                      Text(
                                        'Add',
                                        style: GoogleFonts.manrope(
                                          fontSize: 9.sp,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ..._uploadedPhotos.asMap().entries.map((entry) {
                                return Stack(
                                  children: [
                                    Container(
                                      width: 20.w,
                                      height: 12.h,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          10.0,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: _buildPhotoThumbnail(entry.value),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 14,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                          () => _uploadedPhotos.removeAt(
                                            entry.key,
                                          ),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFE85A4F),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            AppIcons.close,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        SizedBox(height: 3.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B365D),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: Text(
                              isEdit ? 'Save Changes' : 'Add Bike',
                              style: GoogleFonts.manrope(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 3.h),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

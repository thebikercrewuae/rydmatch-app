import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;
import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/custom_image_widget.dart';

class PhotoUploadWidget extends StatefulWidget {
  final XFile? riderPhoto;
  final String? existingRiderPhotoUrl;
  final List<String> existingBikePhotoUrls;
  final List<XFile> bikePhotos;
  final ValueChanged<XFile?> onRiderPhotoChanged;
  final ValueChanged<List<String>> onExistingBikePhotoUrlsChanged;
  final ValueChanged<List<XFile>> onBikePhotosChanged;

  static const int maxBikePhotos = 6;

  const PhotoUploadWidget({
    super.key,
    required this.riderPhoto,
    this.existingRiderPhotoUrl,
    this.existingBikePhotoUrls = const [],
    required this.bikePhotos,
    required this.onRiderPhotoChanged,
    required this.onExistingBikePhotoUrlsChanged,
    required this.onBikePhotosChanged,
  });

  @override
  State<PhotoUploadWidget> createState() => _PhotoUploadWidgetState();
}

class _PhotoUploadWidgetState extends State<PhotoUploadWidget> {
  int? _draggingIndex;
  int? _hoverIndex;

  /// Returns true if there's any photo to display (new XFile or existing URL)
  bool get _hasRiderPhoto =>
      widget.riderPhoto != null ||
      (widget.existingRiderPhotoUrl != null &&
          widget.existingRiderPhotoUrl!.isNotEmpty);

  int get _totalBikePhotoCount =>
      widget.existingBikePhotoUrls.length + widget.bikePhotos.length;

  Future<void> _pickRiderPhoto(BuildContext context) async {
    final picker = ImagePicker();
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 2.h),
                Text('Upload Rider Photo', style: theme.textTheme.titleMedium),
                SizedBox(height: 2.h),
                ListTile(
                  leading: Icon(
                    AppIcons.camera,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _captureRiderFromCamera(picker);
                  },
                ),
                ListTile(
                  leading: Icon(
                    AppIcons.help,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickRiderFromGallery(picker);
                  },
                ),
                SizedBox(height: 1.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBikePhotos(BuildContext context) async {
    final picker = ImagePicker();
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 2.h),
                Text('Add Bike Photo', style: theme.textTheme.titleMedium),
                SizedBox(height: 2.h),
                ListTile(
                  leading: Icon(
                    AppIcons.camera,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _captureBikeFromCamera(picker);
                  },
                ),
                ListTile(
                  leading: Icon(
                    AppIcons.help,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickBikeFromGallery(picker);
                  },
                ),
                SizedBox(height: 1.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _captureRiderFromCamera(ImagePicker picker) async {
    try {
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) return;
      }
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        final adjustedPhoto = await _adjustRiderPhoto(photo);
        if (adjustedPhoto != null) widget.onRiderPhotoChanged(adjustedPhoto);
      }
    } catch (_) {
      // Silent fail
    }
  }

  Future<void> _pickRiderFromGallery(ImagePicker picker) async {
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (photo != null) {
        final adjustedPhoto = await _adjustRiderPhoto(photo);
        if (adjustedPhoto != null) widget.onRiderPhotoChanged(adjustedPhoto);
      }
    } catch (_) {
      // Silent fail
    }
  }

  Future<XFile?> _adjustRiderPhoto(XFile photo) async {
    if (!mounted) return null;

    return Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RiderPhotoAdjustScreen(photo: photo),
      ),
    );
  }

  Future<void> _captureBikeFromCamera(ImagePicker picker) async {
    try {
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) return;
      }
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        widget.onBikePhotosChanged([...widget.bikePhotos, photo]);
      }
    } catch (_) {
      // Silent fail
    }
  }

  Future<void> _pickBikeFromGallery(ImagePicker picker) async {
    try {
      final List<XFile> photos = await ImagePicker().pickMultiImage(
        imageQuality: 85,
      );
      if (photos.isNotEmpty) {
        final remaining =
            PhotoUploadWidget.maxBikePhotos - widget.bikePhotos.length;
        final toAdd = photos.take(remaining).toList();
        widget.onBikePhotosChanged([...widget.bikePhotos, ...toAdd]);
      }
    } catch (_) {
      // Silent fail
    }
  }

  void _removeBikePhoto(int index) {
    final updated = List<XFile>.from(widget.bikePhotos);
    updated.removeAt(index);
    widget.onBikePhotosChanged(updated);
  }

  void _removeExistingBikePhoto(int index) {
    final updated = List<String>.from(widget.existingBikePhotoUrls);
    updated.removeAt(index);
    widget.onExistingBikePhotoUrlsChanged(updated);
  }

  void _reorderBikePhotos(int oldIndex, int newIndex) {
    final updated = List<XFile>.from(widget.bikePhotos);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    widget.onBikePhotosChanged(updated);
  }

  /// Builds the rider photo image widget — handles new XFile, existing URL, or placeholder
  Widget _buildRiderPhotoImage() {
    // New photo picked — show from XFile
    if (widget.riderPhoto != null) {
      if (kIsWeb) {
        return CustomImageWidget(
          imageUrl: widget.riderPhoto!.path,
          width: 55.w,
          height: 35.h,
          fit: BoxFit.cover,
          semanticLabel: 'Rider profile photo uploaded by user',
        );
      } else {
        return Image.file(
          File(widget.riderPhoto!.path),
          fit: BoxFit.cover,
          width: 55.w,
          height: 35.h,
          semanticLabel: 'Rider profile photo',
        );
      }
    }

    // No new photo but existing URL from Supabase
    if (widget.existingRiderPhotoUrl != null &&
        widget.existingRiderPhotoUrl!.isNotEmpty) {
      return CustomImageWidget(
        imageUrl: widget.existingRiderPhotoUrl!,
        width: 55.w,
        height: 35.h,
        fit: BoxFit.cover,
        semanticLabel: 'Rider profile photo from profile',
      );
    }

    // Should not reach here if _hasRiderPhoto is checked
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add your photos', style: theme.textTheme.headlineSmall),
          SizedBox(height: 1.h),
          Text(
            'A great photo increases your match rate by 3x!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 3.h),
          // Rider Photo
          _buildRiderPhotoCard(context: context, theme: theme),
          SizedBox(height: 2.h),
          // Bike Photos Section
          _buildBikePhotosSection(context: context, theme: theme),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(AppIcons.help, color: theme.colorScheme.primary, size: 20),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'Photos are only visible to matched riders. You can add more photos later from your profile.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderPhotoCard({
    required BuildContext context,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: () => _pickRiderPhoto(context),
      child: Center(
        child: Container(
          width: 55.w,
          height: 35.h,
          decoration: BoxDecoration(
            color: _hasRiderPhoto
                ? Colors.transparent
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasRiderPhoto
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: _hasRiderPhoto ? 2 : 1,
            ),
          ),
          child: _hasRiderPhoto
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildRiderPhotoImage(),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => widget.onRiderPhotoChanged(null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              AppIcons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 0.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.edit,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                'Change',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 15.w,
                      height: 15.w,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          AppIcons.person,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    Text(
                      'Rider Photo',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        'Show your face — riders want to know who they\'re riding with',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.help,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          'Tap to add photo',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBikePhotosSection({
    required BuildContext context,
    required ThemeData theme,
  }) {
    final canAddMore = _totalBikePhotoCount < PhotoUploadWidget.maxBikePhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bike Photos',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '$_totalBikePhotoCount/${PhotoUploadWidget.maxBikePhotos}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: 0.5.h),
        Text(
          'Show off your ride — add up to ${PhotoUploadWidget.maxBikePhotos} bike photos',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 0.5.h),
        if (widget.bikePhotos.length > 1)
          Text(
            'Long-press and drag to reorder',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        SizedBox(height: 1.5.h),
        _buildDraggableGrid(
          context: context,
          theme: theme,
          canAddMore: canAddMore,
        ),
      ],
    );
  }

  Widget _buildDraggableGrid({
    required BuildContext context,
    required ThemeData theme,
    required bool canAddMore,
  }) {
    final existingCount = widget.existingBikePhotoUrls.length;
    final itemCount = _totalBikePhotoCount + (canAddMore ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.w,
        mainAxisSpacing: 2.w,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        if (index == _totalBikePhotoCount && canAddMore) {
          return GestureDetector(
            onTap: () => _pickBikePhotos(context),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Icon(
                AppIcons.camera,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ),
          );
        }

        if (index < existingCount) {
          return _buildExistingBikePhotoTile(
            widget.existingBikePhotoUrls[index],
            index,
          );
        }

        final newPhotoIndex = index - existingCount;
        final photo = widget.bikePhotos[newPhotoIndex];

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? CustomImageWidget(imageUrl: photo.path, fit: BoxFit.cover)
                  : Image.file(File(photo.path), fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeBikePhoto(newPhotoIndex),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AppIcons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExistingBikePhotoTile(String url, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomImageWidget(
            imageUrl: url,
            fit: BoxFit.cover,
            semanticLabel: 'Existing bike photo',
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeExistingBikePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _RiderPhotoAdjustScreen extends StatefulWidget {
  final XFile photo;

  const _RiderPhotoAdjustScreen({required this.photo});

  @override
  State<_RiderPhotoAdjustScreen> createState() =>
      _RiderPhotoAdjustScreenState();
}

class _RiderPhotoAdjustScreenState extends State<_RiderPhotoAdjustScreen> {
  final GlobalKey _previewKey = GlobalKey();
  final TransformationController _controller = TransformationController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAdjustedPhoto() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(widget.photo);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final Uint8List? bytes = byteData?.buffer.asUint8List();

      if (bytes == null || bytes.isEmpty) {
        if (mounted) Navigator.of(context).pop(widget.photo);
        return;
      }

      if (kIsWeb) {
        if (mounted) {
          Navigator.of(context).pop(
            XFile.fromData(
              bytes,
              name: 'rider-profile-photo.png',
              mimeType: 'image/png',
            ),
          );
        }
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${Directory.systemTemp.path}/'
          'rydmatch_profile_$timestamp.png';
      final file = await File(filePath).writeAsBytes(bytes, flush: true);

      if (mounted) Navigator.of(context).pop(XFile(file.path));
    } catch (_) {
      if (mounted) Navigator.of(context).pop(widget.photo);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetAdjustment() {
    _controller.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewSize = MediaQuery.of(context).size.width * 0.86;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust Profile Photo'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAdjustedPhoto,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Use Photo'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: RepaintBoundary(
                key: _previewKey,
                child: ClipOval(
                  child: Container(
                    width: previewSize,
                    height: previewSize,
                    color: theme.colorScheme.surface,
                    child: InteractiveViewer(
                      transformationController: _controller,
                      minScale: 1,
                      maxScale: 4,
                      boundaryMargin: EdgeInsets.zero,
                      child: SizedBox(
                        width: previewSize,
                        height: previewSize,
                        child: kIsWeb
                            ? Image.network(
                                widget.photo.path,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const ColoredBox(color: Colors.black),
                              )
                            : Image.file(
                                File(widget.photo.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Pinch to zoom and drag to position',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _resetAdjustment,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

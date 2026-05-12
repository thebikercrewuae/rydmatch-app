import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/custom_image_widget.dart';
import '../../../widgets/app_icons.dart';

class BikeDetailSheetWidget extends StatefulWidget {
  final Map<String, dynamic> bike;
  final VoidCallback onEdit;

  const BikeDetailSheetWidget({
    super.key,
    required this.bike,
    required this.onEdit,
  });

  @override
  State<BikeDetailSheetWidget> createState() => _BikeDetailSheetWidgetState();
}

class _BikeDetailSheetWidgetState extends State<BikeDetailSheetWidget> {
  int _currentPhotoIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fix: JSON decoding returns List<dynamic> with dynamic maps, not typed lists
    final rawPhotos = widget.bike['photos'];
    final List<Map<String, String>> photos = [];
    if (rawPhotos != null && rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p is Map) {
          photos.add({
            'url': p['url']?.toString() ?? '',
            'label': p['label']?.toString() ?? 'Motorcycle photo',
          });
        }
      }
    }
    // Fallback to single 'photo' field if photos list is empty
    if (photos.isEmpty && widget.bike['photo'] != null) {
      final singlePhoto = widget.bike['photo'].toString();
      if (singlePhoto.isNotEmpty) {
        photos.add({'url': singlePhoto, 'label': 'Motorcycle photo'});
      }
    }

    final rawMods = widget.bike['mods'];
    final List<String> mods = rawMods is List
        ? rawMods.map((e) => e.toString()).toList()
        : [];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Gallery
                      if (photos.isNotEmpty)
                        Stack(
                          children: [
                            SizedBox(
                              height: 28.h,
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: photos.length,
                                onPageChanged: (i) =>
                                    setState(() => _currentPhotoIndex = i),
                                itemBuilder: (_, i) {
                                  return InteractiveViewer(
                                    child: CustomImageWidget(
                                      imageUrl: photos[i]['url'],
                                      width: double.infinity,
                                      height: 28.h,
                                      fit: BoxFit.cover,
                                      semanticLabel: photos[i]['label'],
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (photos.length > 1)
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    photos.length,
                                    (i) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      width: _currentPhotoIndex == i ? 20 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _currentPhotoIndex == i
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          4.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        Container(
                          height: 22.h,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              AppIcons.motorcycle,
                              size: 60,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),

                      // Header row
                      Padding(
                        padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.bike['year']} ${widget.bike['make']}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    widget.bike['model'] as String? ?? '',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.bike['isPrimary'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B365D),
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                child: Text(
                                  'PRIMARY',
                                  style: GoogleFonts.manrope(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            SizedBox(width: 2.w),
                            GestureDetector(
                              onTap: widget.onEdit,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1B365D,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Icon(
                                  AppIcons.edit,
                                  color: const Color(0xFF1B365D),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Specs section
                      Padding(
                        padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
                        child: Text(
                          'Specifications',
                          style: GoogleFonts.manrope(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 1.h,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: theme.dividerColor,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              _SpecRow(
                                label: 'Make',
                                value: widget.bike['make'] as String? ?? '',
                              ),
                              Divider(
                                height: 1,
                                color: theme.dividerColor,
                                indent: 16,
                                endIndent: 16,
                              ),
                              _SpecRow(
                                label: 'Model',
                                value: widget.bike['model'] as String? ?? '',
                              ),
                              Divider(
                                height: 1,
                                color: theme.dividerColor,
                                indent: 16,
                                endIndent: 16,
                              ),
                              _SpecRow(
                                label: 'Year',
                                value: widget.bike['year'].toString(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Modifications
                      if (mods.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0),
                          child: Text(
                            'Modifications',
                            style: GoogleFonts.manrope(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 1.h,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: mods
                                .map((mod) => _ModChip(label: mod))
                                .toList(),
                          ),
                        ),
                      ],
                      SizedBox(height: 3.h),
                    ],
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

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModChip extends StatelessWidget {
  final String label;

  const _ModChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B365D).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: const Color(0xFF1B365D).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1B365D),
        ),
      ),
    );
  }
}

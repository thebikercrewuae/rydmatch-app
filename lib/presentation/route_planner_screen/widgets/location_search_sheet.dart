import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../services/places_autocomplete_service.dart';

/// The place a rider picked from the search sheet.
class LocationSearchResult {
  const LocationSearchResult({
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String address;
  final double lat;
  final double lng;
}

/// A Google-Maps-style location search sheet: type a place name or address,
/// see matching options, and pick the right one. Returns the selected
/// place's address + coordinates, or null if the rider dismisses it.
class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({
    super.key,
    this.initialQuery = '',
    this.biasLat,
    this.biasLng,
  });

  final String initialQuery;
  final double? biasLat;
  final double? biasLng;

  static Future<LocationSearchResult?> show(
    BuildContext context, {
    String initialQuery = '',
    double? biasLat,
    double? biasLng,
  }) {
    return showModalBottomSheet<LocationSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSearchSheet(
        initialQuery: initialQuery,
        biasLat: biasLat,
        biasLng: biasLng,
      ),
    );
  }

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<PlacePrediction> _predictions = const [];
  bool _loadingPredictions = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      _fetchPredictions(widget.initialQuery);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: _controller.text.length,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPredictions(String input) async {
    setState(() => _loadingPredictions = true);
    final results = await PlacesAutocompleteService.instance.getSuggestions(
      input,
      biasLat: widget.biasLat,
      biasLng: widget.biasLng,
    );
    if (mounted) {
      setState(() {
        _predictions = results;
        _loadingPredictions = false;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _predictions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchPredictions(query);
    });
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    setState(() => _resolving = true);
    final details = await PlacesAutocompleteService.instance.getDetails(
      prediction.placeId,
    );
    if (!mounted) return;
    if (details == null) {
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not get that location. Try another option.',
            style: GoogleFonts.dmSans(fontSize: 12.sp),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      LocationSearchResult(
        address: details.formattedAddress.isNotEmpty
            ? details.formattedAddress
            : prediction.description,
        lat: details.lat,
        lng: details.lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        height: 80.h,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 1.h),
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.colorScheme.primary, size: 22),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'Search location',
                      style: GoogleFonts.dmSans(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.dmSans(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: 'Type a place name or address',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: theme.colorScheme.primary, size: 20),
                  suffixIcon: _loadingPredictions
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 1.h),
            Expanded(
              child: _resolving
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : _predictions.isEmpty && !_loadingPredictions
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Text(
                              _controller.text.trim().isEmpty
                                  ? 'Type a place name or address to see options.'
                                  : 'No matching places found. Try a different search.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 12.sp,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _predictions.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: theme.colorScheme.outline.withValues(alpha: 0.15),
                          ),
                          itemBuilder: (context, index) {
                            final p = _predictions[index];
                            return ListTile(
                              leading: Icon(
                                Icons.location_on_outlined,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                              title: Text(
                                p.mainText.isNotEmpty ? p.mainText : p.description,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: p.secondaryText.isNotEmpty
                                  ? Text(
                                      p.secondaryText,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11.sp,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () => _selectPrediction(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
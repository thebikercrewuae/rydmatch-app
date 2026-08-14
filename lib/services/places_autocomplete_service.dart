import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A single autocomplete prediction returned by the Google Places API.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText = '',
    this.secondaryText = '',
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
}

/// Resolved coordinates + formatted address for a selected place.
class PlaceDetails {
  const PlaceDetails({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
  });

  final double lat;
  final double lng;
  final String formattedAddress;
}

/// Wraps the Google Places Autocomplete + Place Details endpoints so the
/// route planner can offer Google-Maps-style "type, see options, pick one"
/// location search instead of a single silent geocode result.
class PlacesAutocompleteService {
  PlacesAutocompleteService._();
  static final PlacesAutocompleteService instance = PlacesAutocompleteService._();

  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  /// Returns place predictions worldwide. Optional location bias narrows
  /// results to the area near the ride start point when available.
  Future<List<PlacePrediction>> getSuggestions(
    String input, {
    double? biasLat,
    double? biasLng,
    double radiusMeters = 50000,
  }) async {
    final query = input.trim();
    if (query.isEmpty) return const [];
    try {
      final params = <String, dynamic>{
        'input': query,
        'key': _apiKey,
      };
      if (biasLat != null && biasLng != null) {
        params['location'] = '$biasLat,$biasLng';
        params['radius'] = radiusMeters.toString();
      }
      final res = await Dio().get(_autocompleteUrl, queryParameters: params);
      final data = res.data;
      if (data is! Map || data['status'] != 'OK' || data['predictions'] == null) {
        return const [];
      }
      final list = (data['predictions'] as List).whereType<Map>().toList();
      return list.map((p) {
        final structured = p['structured_formatting'] as Map?;
        return PlacePrediction(
          placeId: p['place_id'] as String,
          description: p['description'] as String,
          mainText: structured?['main_text'] as String? ?? '',
          secondaryText: structured?['secondary_text'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('PlacesAutocomplete suggestions failed: $e');
      return const [];
    }
  }

  Future<PlaceDetails?> getDetails(String placeId) async {
    try {
      final params = <String, dynamic>{
        'place_id': placeId,
        'key': _apiKey,
        'fields': 'geometry,formatted_address',
      };
      final res = await Dio().get(_detailsUrl, queryParameters: params);
      final data = res.data;
      if (data is! Map || data['status'] != 'OK' || data['result'] == null) {
        return null;
      }
      final result = data['result'] as Map;
      final loc = result['geometry']?['location'] as Map?;
      if (loc == null) return null;
      return PlaceDetails(
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
        formattedAddress: result['formatted_address'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('PlacesAutocomplete details failed: $e');
      return null;
    }
  }
}
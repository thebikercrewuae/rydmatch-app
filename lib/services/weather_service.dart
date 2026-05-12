import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

enum RideCondition { good, caution, poor }

class WeatherWarning {
  final String message;
  final String icon;
  final Color warningColor;

  const WeatherWarning({
    required this.message,
    required this.icon,
    required this.warningColor,
  });
}

class WeatherData {
  final double temperature;
  final double feelsLike;
  final double windSpeedKmh;
  final double precipitationMm;
  final int weatherCode;
  final String description;
  final String iconEmoji;
  final RideCondition rideCondition;
  final List<WeatherWarning> warnings;
  final String locationName;

  const WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.windSpeedKmh,
    required this.precipitationMm,
    required this.weatherCode,
    required this.description,
    required this.iconEmoji,
    required this.rideCondition,
    required this.warnings,
    required this.locationName,
  });
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 10)),
  );

  /// Geocode a location name to lat/lng using Open-Meteo geocoding API
  Future<Map<String, dynamic>?> geocodeLocation(String locationName) async {
    if (locationName.isEmpty) return null;

    // Check if it's already coordinates (lat, lng)
    final coordRegex = RegExp(r'^(-?\d+\.?\d*),\s*(-?\d+\.?\d*)$');
    final match = coordRegex.firstMatch(locationName.trim());
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) {
        return {'lat': lat, 'lng': lng, 'name': locationName};
      }
    }

    try {
      final response = await _dio.get(
        'https://geocoding-api.open-meteo.com/v1/search',
        queryParameters: {
          'name': locationName,
          'count': 1,
          'language': 'en',
          'format': 'json',
        },
      );

      final data = response.data;
      if (data['results'] != null && (data['results'] as List).isNotEmpty) {
        final result = data['results'][0];
        return {
          'lat': result['latitude'] as double,
          'lng': result['longitude'] as double,
          'name': result['name'] as String,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Fetch weather for given lat/lng from Open-Meteo
  Future<WeatherData?> fetchWeather(
    double lat,
    double lng,
    String locationName,
  ) async {
    try {
      final response = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'current': [
            'temperature_2m',
            'apparent_temperature',
            'weather_code',
            'wind_speed_10m',
            'precipitation',
          ].join(','),
          'timezone': 'auto',
          'forecast_days': 1,
        },
      );

      final current = response.data['current'];
      final temp = (current['temperature_2m'] as num).toDouble();
      final feelsLike = (current['apparent_temperature'] as num).toDouble();
      final windSpeed = (current['wind_speed_10m'] as num).toDouble();
      final precipitation = (current['precipitation'] as num).toDouble();
      final weatherCode = (current['weather_code'] as num).toInt();

      final description = _weatherDescription(weatherCode);
      final emoji = _weatherEmoji(weatherCode);
      final warnings = _buildWarnings(
        temp,
        feelsLike,
        windSpeed,
        precipitation,
        weatherCode,
      );
      final condition = _rideCondition(
        temp,
        feelsLike,
        windSpeed,
        precipitation,
        weatherCode,
      );

      return WeatherData(
        temperature: temp,
        feelsLike: feelsLike,
        windSpeedKmh: windSpeed,
        precipitationMm: precipitation,
        weatherCode: weatherCode,
        description: description,
        iconEmoji: emoji,
        rideCondition: condition,
        warnings: warnings,
        locationName: locationName,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch weather for a location name (geocodes first)
  Future<WeatherData?> fetchWeatherForLocation(String locationName) async {
    final coords = await geocodeLocation(locationName);
    if (coords == null) return null;
    return fetchWeather(
      coords['lat'] as double,
      coords['lng'] as double,
      coords['name'] as String? ?? locationName,
    );
  }

  String _weatherDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 56 && code <= 57) return 'Freezing drizzle';
    if (code >= 61 && code <= 65) return 'Rain';
    if (code >= 66 && code <= 67) return 'Freezing rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code == 95) return 'Thunderstorm';
    if (code >= 96 && code <= 99) return 'Thunderstorm with hail';
    return 'Unknown';
  }

  String _weatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 2) return '🌤️';
    if (code == 3) return '☁️';
    if (code <= 48) return '🌫️';
    if (code <= 57) return '🌦️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌧️';
    if (code <= 86) return '🌨️';
    return '⛈️';
  }

  List<WeatherWarning> _buildWarnings(
    double temp,
    double feelsLike,
    double windSpeed,
    double precipitation,
    int code,
  ) {
    final warnings = <WeatherWarning>[];

    if (feelsLike <= 0) {
      warnings.add(
        const WeatherWarning(
          message: 'Risk of ice on road surfaces',
          icon: '🧊',
          warningColor: Color(0xFF1565C0),
        ),
      );
    } else if (feelsLike <= 5) {
      warnings.add(
        const WeatherWarning(
          message: 'Very cold — dress in layers',
          icon: '🥶',
          warningColor: Color(0xFF1976D2),
        ),
      );
    } else if (temp <= 10) {
      warnings.add(
        const WeatherWarning(
          message: 'Cold conditions — wear warm gear',
          icon: '🌡️',
          warningColor: Color(0xFF0288D1),
        ),
      );
    }

    if (temp >= 38) {
      warnings.add(
        const WeatherWarning(
          message: 'Extreme heat — stay hydrated',
          icon: '🔥',
          warningColor: Color(0xFFD32F2F),
        ),
      );
    } else if (temp >= 32) {
      warnings.add(
        const WeatherWarning(
          message: 'High heat — take breaks & hydrate',
          icon: '☀️',
          warningColor: Color(0xFFF57C00),
        ),
      );
    }

    if (windSpeed >= 60) {
      warnings.add(
        const WeatherWarning(
          message: 'Dangerous wind speeds',
          icon: '💨',
          warningColor: Color(0xFFD32F2F),
        ),
      );
    } else if (windSpeed >= 40) {
      warnings.add(
        const WeatherWarning(
          message: 'Strong winds — ride with caution',
          icon: '💨',
          warningColor: Color(0xFFF57C00),
        ),
      );
    }

    if (precipitation >= 5) {
      warnings.add(
        const WeatherWarning(
          message: 'Heavy rain — reduced visibility',
          icon: '🌧️',
          warningColor: Color(0xFF1565C0),
        ),
      );
    } else if (precipitation > 0) {
      warnings.add(
        const WeatherWarning(
          message: 'Wet roads — reduce speed',
          icon: '🌦️',
          warningColor: Color(0xFF0288D1),
        ),
      );
    }

    if (code >= 45 && code <= 48) {
      warnings.add(
        const WeatherWarning(
          message: 'Foggy — use lights & slow down',
          icon: '🌫️',
          warningColor: Color(0xFF455A64),
        ),
      );
    }

    if (code >= 71 && code <= 77) {
      warnings.add(
        const WeatherWarning(
          message: 'Snow — roads may be slippery',
          icon: '❄️',
          warningColor: Color(0xFF1565C0),
        ),
      );
    }

    if (code >= 95) {
      warnings.add(
        const WeatherWarning(
          message: 'Thunderstorm — avoid riding',
          icon: '⛈️',
          warningColor: Color(0xFFD32F2F),
        ),
      );
    }

    return warnings;
  }

  RideCondition _rideCondition(
    double temp,
    double feelsLike,
    double windSpeed,
    double precipitation,
    int code,
  ) {
    if (code >= 95) return RideCondition.poor;
    if (code >= 71 && code <= 77) return RideCondition.poor;
    if (feelsLike <= 0) return RideCondition.poor;
    if (windSpeed >= 60) return RideCondition.poor;
    if (temp >= 38) return RideCondition.poor;
    if (precipitation >= 5) return RideCondition.poor;

    if (code >= 45 && code <= 48) return RideCondition.caution;
    if (code >= 51 && code <= 67) return RideCondition.caution;
    if (code >= 80 && code <= 86) return RideCondition.caution;
    if (feelsLike <= 5) return RideCondition.caution;
    if (windSpeed >= 40) return RideCondition.caution;
    if (temp >= 32) return RideCondition.caution;
    if (precipitation > 0) return RideCondition.caution;
    if (temp <= 10) return RideCondition.caution;

    return RideCondition.good;
  }
}

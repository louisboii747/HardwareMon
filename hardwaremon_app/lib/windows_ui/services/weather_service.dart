import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherSnapshot {
  final String location;
  final double temperature;
  final double apparentTemperature;
  final double windSpeed;
  final int weatherCode;

  const WeatherSnapshot({
    required this.location,
    required this.temperature,
    required this.apparentTemperature,
    required this.windSpeed,
    required this.weatherCode,
  });

  String get condition => switch (weatherCode) {
    0 => 'Clear sky',
    1 || 2 => 'Partly cloudy',
    3 => 'Overcast',
    45 || 48 => 'Fog',
    51 || 53 || 55 || 56 || 57 => 'Drizzle',
    61 || 63 || 65 || 66 || 67 => 'Rain',
    71 || 73 || 75 || 77 => 'Snow',
    80 || 81 || 82 => 'Rain showers',
    85 || 86 => 'Snow showers',
    95 || 96 || 99 => 'Thunderstorm',
    _ => 'Current conditions',
  };
}

class WeatherService {
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  Future<WeatherSnapshot> fetchCurrent(String query) async {
    final location = query.trim();
    if (location.length < 2) {
      throw const FormatException('Enter a city or postcode in Settings.');
    }

    final geocodingResponse = await _client
        .get(
          Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
            'name': location,
            'count': '1',
            'language': 'en',
            'format': 'json',
          }),
        )
        .timeout(const Duration(seconds: 6));
    if (geocodingResponse.statusCode != 200) {
      throw StateError('Location lookup failed');
    }

    final geocoding = jsonDecode(geocodingResponse.body);
    final results = geocoding is Map ? geocoding['results'] : null;
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw const FormatException('Location not found.');
    }
    final match = Map<String, dynamic>.from(results.first as Map);
    final latitude = (match['latitude'] as num?)?.toDouble();
    final longitude = (match['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('Location coordinates unavailable.');
    }

    final weatherResponse = await _client
        .get(
          Uri.https('api.open-meteo.com', '/v1/forecast', {
            'latitude': '$latitude',
            'longitude': '$longitude',
            'current':
                'temperature_2m,apparent_temperature,weather_code,wind_speed_10m',
            'timezone': 'auto',
          }),
        )
        .timeout(const Duration(seconds: 6));
    if (weatherResponse.statusCode != 200) {
      throw StateError('Weather lookup failed');
    }

    final weather = Map<String, dynamic>.from(
      jsonDecode(weatherResponse.body) as Map,
    );
    final current = Map<String, dynamic>.from(
      weather['current'] as Map? ?? const {},
    );
    final displayName = [
      match['name']?.toString(),
      match['admin1']?.toString(),
    ].whereType<String>().where((part) => part.isNotEmpty).toSet().join(', ');

    return WeatherSnapshot(
      location: displayName.isEmpty ? location : displayName,
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      apparentTemperature:
          (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.round() ?? -1,
    );
  }

  void dispose() => _client.close();
}

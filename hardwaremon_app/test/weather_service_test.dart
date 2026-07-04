import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_gui/windows_ui/services/weather_service.dart';

void main() {
  test('weather service resolves a location and current conditions', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'geocoding-api.open-meteo.com') {
        expect(request.url.queryParameters['name'], 'Manchester');
        return http.Response(
          '{"results":[{"name":"Manchester","admin1":"England","latitude":53.48,"longitude":-2.24}]}',
          200,
        );
      }
      expect(request.url.host, 'api.open-meteo.com');
      expect(request.url.queryParameters['latitude'], '53.48');
      return http.Response(
        '{"current":{"temperature_2m":17.4,"apparent_temperature":16.2,"weather_code":2,"wind_speed_10m":11.8}}',
        200,
      );
    });
    final service = WeatherService(client: client);

    final snapshot = await service.fetchCurrent('Manchester');

    expect(snapshot.location, 'Manchester, England');
    expect(snapshot.temperature, 17.4);
    expect(snapshot.condition, 'Partly cloudy');
    service.dispose();
  });

  test('weather service requires an explicit location', () async {
    final service = WeatherService(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(() => service.fetchCurrent(''), throwsFormatException);
    service.dispose();
  });
}

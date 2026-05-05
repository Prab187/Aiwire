import 'dart:convert';
import 'package:http/http.dart' as http;

import 'location_service_stub.dart'
    if (dart.library.js_interop) 'location_service_web.dart';

class LocationResult {
  final double lat;
  final double lng;
  final String city;
  final String country;
  final String countryCode;
  final String displayName;

  const LocationResult({
    required this.lat,
    required this.lng,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.displayName,
  });
}

class LocationService {
  static Future<LocationResult> getCurrentLocation() async {
    final coords = await nativeGetCoords();
    return _reverseGeocode(coords.lat, coords.lng);
  }

  static Future<LocationResult> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'AIWire/1.0 (web; location lookup)',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final city = (address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            address['state'] ??
            'Unknown City') as String;
        final country = (address['country'] ?? 'Unknown Country') as String;
        final rawCode = ((address['country_code'] as String?) ?? '').toLowerCase();
        return LocationResult(
          lat: lat,
          lng: lng,
          city: city,
          country: country,
          countryCode: _toAdzunaCode(rawCode),
          displayName: '$city, $country',
        );
      }
    } catch (_) {}

    return LocationResult(
      lat: lat,
      lng: lng,
      city: 'Your Location',
      country: 'Unknown',
      countryCode: '',
      displayName: '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}',
    );
  }

  static String _toAdzunaCode(String iso) {
    const supported = {
      'us', 'gb', 'au', 'ca', 'de', 'fr', 'in', 'nl', 'sg', 'br',
      'za', 'pl', 'es', 'it', 'at', 'be', 'ch', 'nz', 'mx',
    };
    return supported.contains(iso) ? iso : '';
  }

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = _sin2(dLat / 2) +
        _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin2(dLng / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  static double _rad(double deg) => deg * 3.141592653589793 / 180;
  static double _sin2(double x) => _sin(x) * _sin(x);
  static double _sin(double x) => x - x * x * x / 6 + x * x * x * x * x / 120;
  static double _cos(double x) => 1 - x * x / 2 + x * x * x * x / 24;
  static double _asin(double x) => x + x * x * x / 6;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 20; i++) {
      g = (g + x / g) / 2;
    }
    return g;
  }
}

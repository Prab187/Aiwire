import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final double lat;
  final double lng;
  final String city;
  final String country;
  final String countryCode; // 2-letter lowercase e.g. 'us', 'gb'
  final String displayName; // e.g. "San Francisco, United States"

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
  /// Request permission and return current position.
  /// Throws descriptive strings on denial or error.
  static Future<LocationResult> getCurrentLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them in Settings.');
    }

    // Check / request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable it in Settings → Privacy → Location Services.');
    }

    // Get position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // Reverse geocode via Nominatim (OpenStreetMap — free, no key)
    return _reverseGeocode(position.latitude, position.longitude);
  }

  static Future<LocationResult> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'AIWire/1.0 (Flutter; location lookup)',
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
        final rawCode = ((address['country_code'] as String?) ?? 'us').toLowerCase();
        // Map to Adzuna-compatible code
        final countryCode = _toAdzunaCode(rawCode);

        return LocationResult(
          lat: lat,
          lng: lng,
          city: city,
          country: country,
          countryCode: countryCode,
          displayName: '$city, $country',
        );
      }
    } catch (_) {}

    // Fallback: return coords without city name — don't assume 'us'
    return LocationResult(
      lat: lat,
      lng: lng,
      city: 'Your Location',
      country: 'Unknown',
      countryCode: '',
      displayName: '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}',
    );
  }

  /// Map ISO 3166-1 alpha-2 to Adzuna country codes
  static String _toAdzunaCode(String iso) {
    const supported = {
      'us', 'gb', 'au', 'ca', 'de', 'fr', 'in', 'nl', 'sg', 'br',
      'za', 'pl', 'es', 'it', 'at', 'be', 'ch', 'nz', 'mx',
    };
    return supported.contains(iso) ? iso : '';
  }

  /// Rough km distance between two lat/lng points (Haversine)
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
    for (int i = 0; i < 20; i++) { g = (g + x / g) / 2; }
    return g;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
    if (kIsWeb) {
      throw Exception('Location requires browser permission. Please allow location access and retry.');
    }

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
        throw Exception('Location permission denied. Please allow location access in Settings.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Enable it in Settings > Privacy > Location.');
    }

    // Get position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // Reverse geocode using OpenStreetMap Nominatim (free, no key needed)
    return _reverseGeocode(position.latitude, position.longitude);
  }

  static Future<LocationResult> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'AIWire/1.0 (Flutter app)',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final city = address['city'] as String?
            ?? address['town'] as String?
            ?? address['village'] as String?
            ?? address['county'] as String?
            ?? '';
        final country = address['country'] as String? ?? '';
        final countryCode = (address['country_code'] as String? ?? 'us').toLowerCase();
        final displayName = city.isNotEmpty
            ? '$city, $country'
            : country.isNotEmpty ? country : 'Your location';

        return LocationResult(
          lat: lat,
          lng: lng,
          city: city,
          country: country,
          countryCode: countryCode,
          displayName: displayName,
        );
      }
    } catch (e) {
      debugPrint('AIWire: reverse geocode failed — $e');
    }

    // Fallback: return coords without city name
    return LocationResult(
      lat: lat,
      lng: lng,
      city: '',
      country: '',
      countryCode: 'us',
      displayName: '${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)}',
    );
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
    for (int i = 0; i < 20; i++) { g = (g + x / g) / 2; }
    return g;
  }
}

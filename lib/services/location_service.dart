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
    throw Exception('Location is not available on this platform.');
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

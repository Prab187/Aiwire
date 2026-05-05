/// Stub used on non-web platforms. The web implementation in
/// location_service_web.dart calls navigator.geolocation directly.
/// Native (iOS/Android) builds normally use the geolocator package, but
/// it isn't currently in pubspec — so on non-web we throw so the UI
/// shows its existing "location unavailable" state.

class _Coords {
  final double lat;
  final double lng;
  const _Coords(this.lat, this.lng);
}

Future<_Coords> nativeGetCoords() {
  throw Exception('Location is not available on this platform.');
}

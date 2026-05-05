import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class _Coords {
  final double lat;
  final double lng;
  const _Coords(this.lat, this.lng);
}

/// Browser geolocation via navigator.geolocation.getCurrentPosition.
/// Throws a descriptive Exception on denial / unsupported / timeout.
Future<_Coords> nativeGetCoords() {
  final completer = Completer<_Coords>();
  final geolocation = web.window.navigator.geolocation;

  void success(web.GeolocationPosition pos) {
    final c = pos.coords;
    if (!completer.isCompleted) {
      completer.complete(_Coords(c.latitude, c.longitude));
    }
  }

  void error(web.GeolocationPositionError err) {
    if (completer.isCompleted) return;
    String msg;
    switch (err.code) {
      case 1:
        msg = 'Location permission denied. Allow location access in your '
            'browser settings to use this feature.';
        break;
      case 2:
        msg = 'Location unavailable. Check that location services are on.';
        break;
      case 3:
        msg = 'Location request timed out. Please try again.';
        break;
      default:
        msg = 'Could not get your location.';
    }
    completer.completeError(Exception(msg));
  }

  final options = web.PositionOptions(
    enableHighAccuracy: false,
    timeout: 15000,
    maximumAge: 60000,
  );

  geolocation.getCurrentPosition(
    success.toJS,
    error.toJS,
    options,
  );

  return completer.future;
}

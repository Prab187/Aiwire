import 'package:flutter/foundation.dart' show kIsWeb;

/// Wraps a URL with a CORS proxy on web builds so browser fetches to
/// third-party APIs that don't send CORS headers still succeed.
/// On mobile/desktop the original URL is returned untouched.
String corsWrapped(String url) {
  if (kIsWeb) return 'https://corsproxy.io/?url=${Uri.encodeComponent(url)}';
  return url;
}

/// Convenience: parse a URL with the CORS proxy applied on web.
Uri corsUri(String url) => Uri.parse(corsWrapped(url));

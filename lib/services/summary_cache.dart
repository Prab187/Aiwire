import 'dart:collection';

class SummaryCache {
  static final Map<String, String> _cache = LinkedHashMap();
  static final Map<String, Future<String>> _inFlight = {};
  static const int _maxSize = 50;

  static bool has(String url) => _cache.containsKey(url);

  static String? get(String url) => _cache[url];

  static void set(String url, String summary) {
    if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = summary;
  }

  static Future<String>? getInFlight(String url) => _inFlight[url];

  static void setInFlight(String url, Future<String> future) {
    _inFlight[url] = future;
    future.then((_) {
      _inFlight.remove(url);
    }).catchError((dynamic _) {
      _inFlight.remove(url);
      return '';
    });
  }
}

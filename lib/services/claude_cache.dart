import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple TTL-based JSON cache backed by SharedPreferences.
/// Used to avoid re-hitting Claude for deterministic content
/// (resume analysis, career recommendations, etc.).
class ClaudeCache {
  /// Read a cached value. Returns null if missing or expired.
  static Future<String?> get(String namespace, String key, {Duration? ttl}) async {
    final prefs = await SharedPreferences.getInstance();
    final full = '_cc_${namespace}_$key';
    final raw = prefs.getString(full);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      final ts = (m['ts'] as num?)?.toInt() ?? 0;
      final value = m['v'] as String?;
      if (value == null || value.isEmpty) return null;
      if (ttl != null) {
        final age = DateTime.now().millisecondsSinceEpoch - ts;
        if (age > ttl.inMilliseconds) return null; // expired
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Write a value into the cache.
  static Future<void> set(String namespace, String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final full = '_cc_${namespace}_$key';
    await prefs.setString(full, json.encode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'v': value,
    }));
  }

  /// Build a stable cache key from an arbitrary list of components.
  static String keyFrom(List<Object?> parts) {
    final joined = parts.map((p) => p?.toString() ?? '').join('|');
    // Simple FNV-1a-ish hash
    var h = 2166136261;
    for (final c in joined.codeUnits) {
      h = (h ^ c) & 0xffffffff;
      h = (h * 16777619) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

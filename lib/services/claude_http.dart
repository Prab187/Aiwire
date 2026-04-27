import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralized Claude HTTP helper with:
/// - Fresh http.Client per request (avoids iOS socket reuse bugs)
/// - Retry on transient network errors ("bad file descriptor", socket errors)
/// - Exponential backoff between attempts
/// - Clean disposal to prevent connection pool exhaustion
class ClaudeHttp {
  /// Tracks global Claude API throttle state — if a rate limit was hit,
  /// subsequent calls wait until this time before firing. Prevents burning
  /// more TPM when we know we're already over the limit.
  static DateTime? _throttleUntil;

  /// POST to Claude's /v1/messages with automatic retry on transient errors.
  /// Returns the raw http.Response so callers handle status codes themselves.
  ///
  /// Rate-limit aware: if Anthropic returns 429, respects the `retry-after`
  /// header and waits that many seconds before retrying. Also sets a global
  /// throttle so parallel calls don't keep hammering the API.
  static Future<http.Response> post({
    required String apiKey,
    required Map<String, dynamic> body,
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 60),
    int maxAttempts = 3,
  }) async {
    // Pre-flight: if we're in a known throttle window, wait it out first.
    final now = DateTime.now();
    if (_throttleUntil != null && _throttleUntil!.isAfter(now)) {
      final waitMs = _throttleUntil!.difference(now).inMilliseconds;
      // Cap the pre-wait at 10s so user doesn't stare at a spinner forever.
      if (waitMs > 10000) {
        throw Exception('Too many AI requests in a short time. This resets in '
            '~${(_throttleUntil!.difference(now).inSeconds)} seconds — please wait.');
      }
      await Future.delayed(Duration(milliseconds: waitMs + 100));
    }

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final client = http.Client();
      try {
        final response = await client.post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            ...?extraHeaders,
          },
          body: json.encode(body),
        ).timeout(timeout);

        // Handle 429 rate limit — respect retry-after header
        if (response.statusCode == 429) {
          final retryAfter = _parseRetryAfterSeconds(response.headers);
          // Record global throttle so parallel callers don't pile on.
          _throttleUntil = DateTime.now()
              .add(Duration(seconds: retryAfter.clamp(1, 120)));
          if (attempt < maxAttempts && retryAfter <= 15) {
            // Short rate limit — wait it out and retry inside this call.
            await Future.delayed(Duration(seconds: retryAfter + 1));
            continue;
          }
          // Long rate limit or exhausted retries — let caller surface it.
          return response;
        }

        // Clear throttle on any successful (or non-429) response
        if (response.statusCode >= 200 && response.statusCode < 500) {
          _throttleUntil = null;
        }
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
        // Only retry on transient socket/network errors
        if (!_isTransient(e)) rethrow;
      } finally {
        client.close();
      }
      if (attempt < maxAttempts) {
        // Exponential backoff: 500ms, 1500ms
        await Future.delayed(Duration(milliseconds: 500 * attempt * attempt));
      }
    }
    throw Exception(friendlyNetworkError(lastError));
  }

  /// Parse `retry-after` header (Anthropic returns integer seconds).
  /// Defaults to 30s if missing/invalid.
  static int _parseRetryAfterSeconds(Map<String, String> headers) {
    final raw = headers['retry-after'] ?? headers['Retry-After'];
    if (raw == null) return 30;
    final n = int.tryParse(raw.trim());
    if (n != null) return n;
    // Could be an HTTP-date format — punt with a sane default.
    return 30;
  }

  static bool _isTransient(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('bad file descriptor')
        || msg.contains('connection closed')
        || msg.contains('connection reset')
        || msg.contains('broken pipe')
        || msg.contains('socketexception')
        || msg.contains('timed out')
        || msg.contains('handshake');
  }

  /// Convert cryptic Dart network errors into user-readable messages.
  static String friendlyNetworkError(Object? e) {
    if (e == null) return 'Network unavailable. Please try again.';
    final msg = e.toString().toLowerCase();
    if (msg.contains('bad file descriptor')
        || msg.contains('socketexception')
        || msg.contains('connection closed')
        || msg.contains('connection reset')) {
      return 'Network connection dropped. Please check your internet and try again.';
    }
    if (msg.contains('timed out')) {
      return 'Request timed out. The AI service is slow right now — please try again.';
    }
    if (msg.contains('handshake') || msg.contains('ssl')) {
      return 'Secure connection failed. Check your network and try again.';
    }
    if (msg.contains('no address')) {
      return 'Cannot reach AI service. Check your internet connection.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}

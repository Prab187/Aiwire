import 'dart:convert';

/// Parses an Anthropic API non-200 response into a human-readable message.
///
/// Anthropic returns errors as:
/// `{"type":"error","error":{"type":"invalid_request_error","message":"..."}}`
///
/// Returns a string like "400 invalid_request_error: model not found" or
/// just "400" if the body can't be parsed.
String claudeError(int statusCode, String body) {
  try {
    final data = json.decode(body);
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        final type = err['type']?.toString() ?? '';
        final message = err['message']?.toString() ?? '';
        if (message.isNotEmpty) {
          return type.isNotEmpty
              ? '$statusCode $type: $message'
              : '$statusCode: $message';
        }
      }
    }
  } catch (_) {}
  // Fallback — body first 200 chars so we can at least see what came back
  final snippet = body.length > 200 ? '${body.substring(0, 200)}…' : body;
  return snippet.isEmpty ? '$statusCode' : '$statusCode: $snippet';
}

/// Detects whether a Claude error message indicates the user has hit
/// their monthly spend limit or run out of credits. When true, the UI
/// should show a friendly "quota reached" message with a link to the
/// Anthropic billing page instead of raw error text.
bool isUsageLimitError(String errorMessage) {
  final m = errorMessage.toLowerCase();
  return m.contains('usage limit')
      || m.contains('spend limit')
      || m.contains('credit balance')
      || m.contains('credit_balance_too_low')
      || m.contains('quota')
      || m.contains('monthly limit')
      || m.contains('rate_limit_error')
      || m.contains('insufficient_quota');
}

/// Friendly replacement message for usage-limit errors.
const String kUsageLimitMessage =
    'Monthly AI quota reached. Please add credits at console.anthropic.com or try again tomorrow.';

/// Returns the friendly message if this looks like a quota error,
/// otherwise returns the original error text unchanged.
String friendlyError(String raw) {
  if (isUsageLimitError(raw)) return kUsageLimitMessage;
  return raw;
}

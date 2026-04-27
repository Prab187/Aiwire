import 'dart:convert';

/// Parses an Anthropic API non-200 response into a human-readable message.
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
  final snippet = body.length > 200 ? '${body.substring(0, 200)}...' : body;
  return snippet.isEmpty ? '$statusCode' : '$statusCode: $snippet';
}

/// Detects whether a Claude error indicates a usage/quota limit.
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

/// Returns a friendly message for quota errors, otherwise the original text.
String friendlyError(String raw) {
  if (isUsageLimitError(raw)) {
    return 'Monthly AI quota reached. Please add credits at console.anthropic.com or try again tomorrow.';
  }
  return raw;
}

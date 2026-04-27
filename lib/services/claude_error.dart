import 'dart:convert';

/// Parses an Anthropic API non-200 response into a human-readable message.
///
/// Anthropic returns errors as:
/// `{"type":"error","error":{"type":"invalid_request_error","message":"..."}}`
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

/// True if the error is a **per-minute rate limit** (TPM/RPM). These clear
/// automatically after ~60 seconds — the user doesn't need to add credits.
bool isRateLimitError(String errorMessage) {
  final m = errorMessage.toLowerCase();
  // Anthropic uses "rate_limit_error" type + messages mentioning tpm/rpm
  return m.contains('rate_limit_error')
      || m.contains('rate limit')
      || m.contains('tokens per min')
      || m.contains('per-minute')
      || m.contains('429')
      || (m.contains('too many requests'))
      || m.contains('tpm')
      || m.contains('rpm');
}

/// True if the error is a **hard balance/spend-cap** issue. Only this case
/// actually requires the user to go add credits.
bool isCreditExhaustionError(String errorMessage) {
  final m = errorMessage.toLowerCase();
  // Don't false-positive on rate limits
  if (isRateLimitError(m) && !m.contains('credit') && !m.contains('balance')
      && !m.contains('spend limit')) {
    return false;
  }
  return m.contains('credit balance')
      || m.contains('credit_balance_too_low')
      || m.contains('insufficient_quota')
      || m.contains('spend limit')
      || m.contains('monthly limit')
      || m.contains('quota exceeded')
      || m.contains('usage limit');
}

/// Legacy helper — kept for back-compat with older callers.
bool isUsageLimitError(String errorMessage) =>
    isRateLimitError(errorMessage) || isCreditExhaustionError(errorMessage);

/// Converts any Anthropic error into a user-actionable message.
/// Critically, distinguishes **wait 60 seconds** from **add money**.
String friendlyError(String raw) {
  if (isCreditExhaustionError(raw)) {
    return 'AI credits exhausted. Please add credits at console.anthropic.com → Settings → Plans & Billing, then try again.';
  }
  if (isRateLimitError(raw)) {
    return 'Too many AI requests in a short time. This resets in ~60 seconds — please wait a moment and try again.';
  }
  return raw;
}

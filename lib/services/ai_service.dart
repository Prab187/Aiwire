import 'dart:convert';
import 'package:http/http.dart' as http;
import 'claude_error.dart';
import 'summary_cache.dart';

class AIService {
  static Future<String> summarizeArticle({
    required String title,
    String? description,
    String? content,
    String? url,
  }) async {
    // Return instantly if cached
    if (url != null && SummaryCache.has(url)) {
      return SummaryCache.get(url)!;
    }

    // If already fetching, wait for same request
    if (url != null && SummaryCache.getInFlight(url) != null) {
      return SummaryCache.getInFlight(url)!;
    }

    final future = _fetch(title: title, description: description, content: content, url: url);

    if (url != null) SummaryCache.setInFlight(url, future);

    return future;
  }

  static Future<String> _fetch({
    required String title,
    String? description,
    String? content,
    String? url,
  }) async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');
    final context = description ?? content ?? '';
    final prompt = '''Summarize this AI news article in exactly 4 concise bullet points. Each bullet starts with "• " and is a single short sentence. Cover: the core news, who's involved, the key insight, and why it matters. No preamble, no headers, no closing remark — just 4 bullets.

Title: $title

$context''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: json.encode({
        'model': 'claude-haiku-4-5',
        'max_tokens': 300,
        'messages': [{'role': 'user', 'content': prompt}],
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final contentList = data['content'] as List?;
      if (contentList == null || contentList.isEmpty) {
        throw Exception('Empty response from AI');
      }
      final summary = (contentList[0]['text'] as String?) ?? '';
      if (summary.isEmpty) throw Exception('Empty summary');
      if (url != null) SummaryCache.set(url, summary);
      return summary;
    } else {
      throw Exception('Article summary failed — ${claudeError(response.statusCode, response.body)}');
    }
  }

  // Prefetch disabled to save Claude API credits. Summaries are now
  // generated on-demand only when the user taps an article.
  // The old behavior fired 8 parallel calls every time the home feed
  // loaded, costing ~$0.015 per app open for summaries most users
  // never read. Leaving the method as a no-op so existing callers
  // don't need to change.
  static void prefetch(List<dynamic> articles) {
    // Intentionally no-op. See comment above.
  }
}

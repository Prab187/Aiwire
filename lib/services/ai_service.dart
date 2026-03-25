import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    final apiKey = dotenv.env['ANTHROPIC_API_KEY'];
    final context = description ?? content ?? '';
    final prompt = 'Write a 4-5 sentence summary of this AI news article. Weave in the key insight naturally — no bullet points, no headers, just flowing editorial prose.\n\nTitle: $title\n\n$context';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey!,
        'anthropic-version': '2023-06-01',
      },
      body: json.encode({
        'model': 'claude-3-5-haiku-20241022',
        'max_tokens': 300,
        'messages': [{'role': 'user', 'content': prompt}],
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final summary = data['content'][0]['text'] as String;
      if (url != null) SummaryCache.set(url, summary);
      return summary;
    } else {
      throw Exception('Failed: ${response.statusCode}');
    }
  }

  // Pre-fetch top N articles silently in background
  static void prefetch(List<dynamic> articles) {
    final top = articles.take(8).toList();
    for (final article in top) {
      final url = article.url as String;
      if (!SummaryCache.has(url)) {
        summarizeArticle(
          title: article.title,
          description: article.description,
          content: article.content,
          url: url,
        ).catchError((_) => '');
      }
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/article.dart';

class NewsService {
  static const List<String> _relevantKeywords = [
    'artificial intelligence', 'AI', 'LLM', 'machine learning',
    'deep learning', 'ChatGPT', 'GPT', 'Gemini', 'Claude',
    'OpenAI', 'Anthropic', 'Google AI', 'Meta AI',
    'neural network', 'generative AI', 'large language model',
    'robotics', 'automation', 'tech startup', 'innovation'
  ];

  static const List<String> _blockedSources = [
    'removed', 'unknown', '[removed]'
  ];

  // Detect non-English characters (Chinese, Japanese, Korean, Arabic, etc.)
  static bool _isEnglish(String text) {
    final nonEnglishPattern = RegExp(
      r'[\u4e00-\u9fff\u3400-\u4dbf\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af\u0600-\u06ff]'
    );
    return !nonEnglishPattern.hasMatch(text);
  }

  static Future<List<Article>> fetchAINews() async {
    final apiKey = dotenv.env['NEWS_API_KEY'];
    final url = Uri.parse(
      'https://newsapi.org/v2/everything?q=artificial+intelligence+AI+LLM&sortBy=publishedAt&language=en&pageSize=50&apiKey=$apiKey'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      List<Article> articles = (data['articles'] as List)
          .where((a) =>
              a['title'] != null &&
              a['title'] != '[Removed]' &&
              a['urlToImage'] != null &&
              a['description'] != null &&
              a['description'].length > 50 &&
              _isEnglish(a['title'].toString()) &&
              _isEnglish(a['description'].toString()) &&
              !_blockedSources.any((b) =>
                  a['source']['name'].toString().toLowerCase().contains(b)))
          .map((a) => Article.fromJson(a))
          .toList();

      articles = _filterAndScore(articles);

      return articles;
    } else {
      throw Exception('Failed to fetch news: ${response.statusCode}');
    }
  }

  static List<Article> _filterAndScore(List<Article> articles) {
    Map<Article, double> scores = {};

    for (var article in articles) {
      double score = 0;

      final titleLower = article.title.toLowerCase();
      final descLower = article.description?.toLowerCase() ?? '';

      // Keyword relevance score
      for (var keyword in _relevantKeywords) {
        if (titleLower.contains(keyword.toLowerCase())) score += 3;
        if (descLower.contains(keyword.toLowerCase())) score += 1;
      }

      // Has image = more engaging
      if (article.urlToImage != null) score += 2;

      // Good description length
      if ((article.description?.length ?? 0) > 100) score += 2;

      // Recency score — parse String to DateTime
      if (article.publishedAt != null) {
        try {
          final published = DateTime.parse(article.publishedAt!);
          final age = DateTime.now().difference(published).inHours;
          if (age < 6) score += 5;
          else if (age < 12) score += 3;
          else if (age < 24) score += 2;
          else if (age < 48) score += 1;
        } catch (_) {
          // ignore parse errors
        }
      }

      scores[article] = score;
    }

    // Filter low scores
    articles = articles.where((a) => (scores[a] ?? 0) >= 5).toList();

    // Sort by score
    articles.sort((a, b) =>
        (scores[b] ?? 0).compareTo(scores[a] ?? 0));

    // Top 15 only
    return articles.take(15).toList();
  }
}

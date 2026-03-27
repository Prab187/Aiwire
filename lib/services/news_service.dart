import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/article.dart';

class NewsService {
  static const List<String> _relevantKeywords = [
    'artificial intelligence', 'AI', 'LLM', 'machine learning',
    'deep learning', 'ChatGPT', 'GPT', 'Gemini', 'Claude',
    'OpenAI', 'Anthropic', 'Google AI', 'Meta AI',
    'neural network', 'generative AI', 'large language model',
    'robotics', 'automation', 'tech startup', 'innovation'
  ];

  // Curated AI-focused RSS feeds only — quality over quantity
  static const List<Map<String, String>> _rssFeeds = [
    // ── Tier 1: Pure AI news ──────────────────────────────────
    {'url': 'https://techcrunch.com/category/artificial-intelligence/feed/', 'source': 'TechCrunch AI'},
    {'url': 'https://venturebeat.com/category/ai/feed/', 'source': 'VentureBeat AI'},
    {'url': 'https://artificialintelligence-news.com/feed/', 'source': 'AI News'},
    {'url': 'https://www.marktechpost.com/feed/', 'source': 'MarkTechPost'},
    {'url': 'https://syncedreview.com/feed/', 'source': 'Synced Review'},
    {'url': 'https://www.aitrends.com/feed/', 'source': 'AI Trends'},
    {'url': 'https://techxplore.com/rss-feed/machine-learning-ai-news/', 'source': 'TechXplore AI'},
    // ── Tier 2: Top labs & research ──────────────────────────
    {'url': 'https://openai.com/blog/rss.xml', 'source': 'OpenAI'},
    {'url': 'https://www.deepmind.com/blog/rss.xml', 'source': 'DeepMind'},
    {'url': 'https://huggingface.co/blog/feed.xml', 'source': 'HuggingFace'},
    {'url': 'https://hai.stanford.edu/news/rss.xml', 'source': 'Stanford HAI'},
    {'url': 'https://bair.berkeley.edu/blog/feed.xml', 'source': 'Berkeley AI'},
    {'url': 'https://thegradient.pub/rss/', 'source': 'The Gradient'},
    // ── Tier 3: Trusted tech with AI coverage ─────────────────
    {'url': 'https://www.technologyreview.com/feed/', 'source': 'MIT Tech Review'},
    {'url': 'https://www.wired.com/feed/tag/artificial-intelligence/rss', 'source': 'Wired'},
    {'url': 'https://feeds.arstechnica.com/arstechnica/technology-lab', 'source': 'Ars Technica'},
    {'url': 'https://www.theverge.com/rss/index.xml', 'source': 'The Verge'},
    {'url': 'https://www.zdnet.com/topic/artificial-intelligence/rss.xml', 'source': 'ZDNet'},
    {'url': 'https://news.crunchbase.com/feed/', 'source': 'Crunchbase'},
  ];

  static bool _isEnglish(String text) {
    final nonEnglishPattern = RegExp(
      r'[\u4e00-\u9fff\u3400-\u4dbf\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af\u0600-\u06ff]'
    );
    return !nonEnglishPattern.hasMatch(text);
  }

  static Future<List<Article>> fetchAINews() async {
    List<Article> allArticles = [];

    // Fetch in batches of 5 to avoid memory spikes from 19 concurrent connections
    const batchSize = 5;
    for (int i = 0; i < _rssFeeds.length; i += batchSize) {
      final batch = _rssFeeds.skip(i).take(batchSize);
      final futures = batch.map((feed) => _fetchRssFeed(feed['url']!, feed['source']!));
      final results = await Future.wait(futures, eagerError: false);
      for (final articles in results) {
        allArticles.addAll(articles);
      }
    }

    // Fallback to NewsAPI if RSS yields nothing
    if (allArticles.isEmpty) {
      try {
        final newsApiArticles = await _fetchNewsApi();
        allArticles.addAll(newsApiArticles);
      } catch (_) {}
    }

    // Deduplicate by URL
    final seen = <String>{};
    allArticles = allArticles.where((a) => seen.add(a.url)).toList();

    return _filterAndScore(allArticles);
  }

  static Future<List<Article>> _fetchRssFeed(String feedUrl, String sourceName) async {
    try {
      final response = await http.get(
        Uri.parse(feedUrl),
        headers: {'User-Agent': 'AIWire/1.0 (Flutter RSS Reader)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      // Parse XML off the main thread to avoid blocking the UI
      final maps = await compute(_parseRssBody, {'body': response.body, 'source': sourceName});
      return maps.map((m) => Article(
        title: m['title'] as String,
        description: m['description'] as String?,
        urlToImage: m['urlToImage'] as String?,
        url: m['url'] as String,
        publishedAt: m['publishedAt'] as String?,
        source: m['source'] as String?,
        content: m['content'] as String?,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  // Top-level-style static method so it can run in a compute() isolate.
  // Must only use primitive types in args and return value.
  static List<Map<String, dynamic>> _parseRssBody(Map<String, String> args) {
    final body = args['body']!;
    final sourceName = args['source']!;
    try {
      final document = XmlDocument.parse(body);
      final items = document.findAllElements('item');
      final entries = items.isEmpty ? document.findAllElements('entry') : items;

      final List<Map<String, dynamic>> results = [];
      for (final item in entries) {
        final title = _getText(item, ['title']);
        final url = _getUrl(item) ?? '';
        final description = _stripHtml(
          _getText(item, ['encoded', 'content', 'description', 'summary']) ?? '');
        final publishedAt = _parseDate(
          _getText(item, ['pubDate', 'published', 'updated']));
        final imageUrl = _extractImage(item, body);

        if (title == null || title.isEmpty || url.isEmpty) continue;
        if (!_isEnglish(title)) continue;

        results.add({
          'title': title,
          'description': description.isNotEmpty ? description : null,
          'urlToImage': imageUrl,
          'url': url,
          'publishedAt': publishedAt,
          'source': sourceName,
          'content': description.isNotEmpty ? description : null,
        });
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Article>> _fetchNewsApi() async {
    const apiKey = String.fromEnvironment('NEWS_API_KEY');
    if (apiKey.isEmpty) return [];

    final url = Uri.parse(
      'https://newsapi.org/v2/everything?q=artificial+intelligence+AI+LLM&sortBy=publishedAt&language=en&pageSize=50&apiKey=$apiKey'
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['articles'] as List)
          .where((a) =>
              a['title'] != null &&
              a['title'] != '[Removed]' &&
              a['urlToImage'] != null &&
              a['description'] != null &&
              a['description'].length > 50 &&
              _isEnglish(a['title'].toString()))
          .map((a) => Article.fromJson(a))
          .toList();
    }
    return [];
  }

  // ── XML helpers ──────────────────────────────────────────────

  static String? _getText(XmlElement item, List<String> tags) {
    for (final tag in tags) {
      try {
        // Search by local name to handle namespaces like content:encoded
        final el = item.childElements
            .where((e) => e.name.local == tag || e.name.qualified == tag)
            .firstOrNull;
        if (el != null) {
          // Atom <link href="..."/>
          final href = el.getAttribute('href');
          if (href != null && href.isNotEmpty) return href;
          final text = el.innerText.trim();
          if (text.isNotEmpty) return text;
        }
      } catch (_) {}
    }
    return null;
  }

  static String? _getUrl(XmlElement item) {
    // Try <link> element — RSS 2.0 has text, Atom has href attribute
    for (final el in item.childElements) {
      if (el.name.local == 'link') {
        final href = el.getAttribute('href');
        if (href != null && href.isNotEmpty) return href;
        final text = el.innerText.trim();
        if (text.isNotEmpty && text.startsWith('http')) return text;
      }
    }
    // Fallback to <guid>
    final guid = item.childElements
        .where((e) => e.name.local == 'guid')
        .firstOrNull?.innerText.trim();
    if (guid != null && guid.startsWith('http')) return guid;
    return null;
  }

  static String? _extractImage(XmlElement item, String rawXml) {
    // 1. media:content or media:thumbnail (with namespace)
    for (final el in item.childElements) {
      final name = el.name.local;
      if (name == 'content' || name == 'thumbnail') {
        final url = el.getAttribute('url');
        if (url != null && url.isNotEmpty && _isImageUrl(url)) return url;
      }
      if (name == 'enclosure') {
        final url = el.getAttribute('url');
        final type = el.getAttribute('type') ?? '';
        if (url != null && url.isNotEmpty && type.startsWith('image')) return url;
      }
    }

    // 2. img src inside description / content:encoded HTML
    for (final tag in ['description', 'encoded', 'summary', 'content']) {
      final el = item.childElements.where((e) => e.name.local == tag).firstOrNull;
      if (el != null) {
        final html = el.innerText;
        final imgMatch = RegExp(r"""<img[^>]+src=["']([^"']+)["']""").firstMatch(html);
        if (imgMatch != null) {
          final url = imgMatch.group(1);
          if (url != null && _isImageUrl(url)) return url;
        }
      }
    }

    return null;
  }

  static bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('http') &&
        (lower.contains('.jpg') || lower.contains('.jpeg') ||
         lower.contains('.png') || lower.contains('.webp') ||
         lower.contains('.gif') || lower.contains('image'));
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static String? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    // 1. ISO 8601 — try directly
    try {
      return DateTime.parse(raw.trim()).toIso8601String();
    } catch (_) {}

    // 2. RFC 822 — e.g. "Mon, 25 Mar 2026 10:30:00 +0000"
    try {
      final parts = raw.trim().split(RegExp(r'[\s,]+'));
      // parts: [Mon, 25, Mar, 2026, 10:30:00, +0000]
      // or without weekday: [25, Mar, 2026, 10:30:00, +0000]
      int day = 0, month = 0, year = 0;
      int hour = 0, minute = 0, second = 0;

      for (int i = 0; i < parts.length; i++) {
        final p = parts[i];
        final monthNum = _months[p.toLowerCase().substring(0, p.length.clamp(0, 3))];
        if (monthNum != null) {
          month = monthNum;
          if (i > 0) day = int.tryParse(parts[i - 1]) ?? 0;
          if (i + 1 < parts.length) year = int.tryParse(parts[i + 1]) ?? 0;
          if (i + 2 < parts.length && parts[i + 2].contains(':')) {
            final timeParts = parts[i + 2].split(':');
            hour   = int.tryParse(timeParts[0]) ?? 0;
            minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
            second = int.tryParse(timeParts.length > 2 ? timeParts[2] : '0') ?? 0;
          }
          break;
        }
      }

      if (day > 0 && month > 0 && year > 0) {
        return DateTime.utc(year, month, day, hour, minute, second).toIso8601String();
      }
    } catch (_) {}

    // 3. Give up — return null so article still shows without a timestamp
    return null;
  }

  // ── Scoring ──────────────────────────────────────────────────

  static List<Article> _filterAndScore(List<Article> articles) {
    Map<Article, double> scores = {};

    for (var article in articles) {
      double score = 0;
      final titleLower = article.title.toLowerCase();
      final descLower = article.description?.toLowerCase() ?? '';

      for (var keyword in _relevantKeywords) {
        if (titleLower.contains(keyword.toLowerCase())) score += 3;
        if (descLower.contains(keyword.toLowerCase())) score += 1;
      }

      if (article.urlToImage != null) score += 2;
      if ((article.description?.length ?? 0) > 100) score += 2;

      if (article.publishedAt != null) {
        try {
          final published = DateTime.parse(article.publishedAt!);
          final age = DateTime.now().difference(published).inHours;
          if (age < 6) score += 5;
          else if (age < 12) score += 3;
          else if (age < 24) score += 2;
          else if (age < 48) score += 1;
        } catch (_) {}
      }

      scores[article] = score;
    }

    // Sources are already AI-focused — just sort by score, show all
    articles.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return articles.take(30).toList();
  }
}

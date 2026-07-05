import '../config/secrets.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
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
    {'url': 'https://www.marktechpost.com/feed/', 'source': 'MarkTechPost'},
    {'url': 'https://thegradient.pub/rss/', 'source': 'The Gradient'},
    // ── Tier 2: Top AI labs ───────────────────────────────────
    {'url': 'https://openai.com/blog/rss.xml', 'source': 'OpenAI'},
    {'url': 'https://www.deepmind.com/blog/rss.xml', 'source': 'DeepMind'},
    {'url': 'https://huggingface.co/blog/feed.xml', 'source': 'HuggingFace'},
    {'url': 'https://www.anthropic.com/news/rss', 'source': 'Anthropic'},
    {'url': 'https://ai.googleblog.com/feeds/posts/default', 'source': 'Google AI'},
    {'url': 'https://engineering.fb.com/category/ml-applications/feed/', 'source': 'Meta AI'},
    // ── Tier 3: Top newsletters ───────────────────────────────
    {'url': 'https://www.deeplearning.ai/the-batch/feed/', 'source': 'The Batch'},
    {'url': 'https://jack-clark.net/feed/', 'source': 'Import AI'},
    // ── Tier 4: Trusted tech with AI coverage ─────────────────
    {'url': 'https://www.technologyreview.com/feed/', 'source': 'MIT Tech Review'},
    {'url': 'https://www.wired.com/feed/tag/artificial-intelligence/rss', 'source': 'Wired'},
    {'url': 'https://feeds.arstechnica.com/arstechnica/technology-lab', 'source': 'Ars Technica'},
    {'url': 'https://www.theverge.com/rss/index.xml', 'source': 'The Verge'},
  ];

  // Fallback images for sources that don't provide images in their RSS
  static const Map<String, String> _sourceFallbackImages = {
    'OpenAI':         'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/OpenAI_Logo.svg/320px-OpenAI_Logo.svg.png',
    'Anthropic':      'https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Anthropic_logo.svg/320px-Anthropic_logo.svg.png',
    'DeepMind':       'https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/DeepMind_new_logo.svg/320px-DeepMind_new_logo.svg.png',
    'Google AI':      'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Google_2015_logo.svg/320px-Google_2015_logo.svg.png',
    'Meta AI':        'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Meta_Platforms_Inc._logo.svg/320px-Meta_Platforms_Inc._logo.svg.png',
    'Import AI':      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/240px-Python-logo-notext.svg.png',
    'The Batch':      'https://www.deeplearning.ai/wp-content/uploads/2021/02/the-batch-logo.png',
    'Stanford HAI':   'https://hai.stanford.edu/sites/default/files/2020-01/HAI_Homepage_Hero.jpg',
    'HuggingFace':    'https://huggingface.co/front/assets/huggingface_logo.svg',
    'The Gradient':   'https://thegradient.pub/content/images/2019/10/gradient_og.png',
    'TechCrunch AI':  'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b9/TechCrunch_logo.svg/320px-TechCrunch_logo.svg.png',
    'VentureBeat AI': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/VentureBeat_logo.svg/320px-VentureBeat_logo.svg.png',
    'MarkTechPost':   'https://www.marktechpost.com/wp-content/uploads/2022/09/cropped-New-Logo-192x192.png',
    'MIT Tech Review':'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1f/MIT_Technology_Review_modern_logo.svg/320px-MIT_Technology_Review_modern_logo.svg.png',
    'Wired':          'https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/Wired_logo.svg/320px-Wired_logo.svg.png',
    'Ars Technica':   'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Ars_Technica_logo_%282016%29.svg/320px-Ars_Technica_logo_%282016%29.svg.png',
    'The Verge':      'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/The_Verge_logo.svg/320px-The_Verge_logo.svg.png',
  };

  static bool _isEnglish(String text) {
    final nonEnglishPattern = RegExp(
      r'[\u4e00-\u9fff\u3400-\u4dbf\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af\u0600-\u06ff]'
    );
    return !nonEnglishPattern.hasMatch(text);
  }

  static Future<List<Article>> fetchAINews() async {
    List<Article> allArticles = [];

    // Fetch from all RSS feeds in parallel
    final futures = _rssFeeds.map((feed) => _fetchRssFeed(feed['url']!, feed['source']!));
    final results = await Future.wait(futures, eagerError: false);
    for (final articles in results) {
      allArticles.addAll(articles);
    }

    // Fallback to NewsAPI if RSS yields nothing
    if (allArticles.isEmpty) {
      try {
        final newsApiArticles = await _fetchNewsApi();
        allArticles.addAll(newsApiArticles);
      } catch (e) { debugPrint("AIWire: $e"); }
    }

    // Deduplicate by URL
    final seen = <String>{};
    allArticles = allArticles.where((a) => seen.add(a.url)).toList();

    return _filterAndScore(allArticles);
  }

  static String _proxiedUrl(String url) {
    if (kIsWeb) return 'https://corsproxy.io/?url=${Uri.encodeComponent(url)}';
    return url;
  }

  static Future<List<Article>> _fetchRssFeed(String feedUrl, String sourceName) async {
    try {
      final requestUrl = _proxiedUrl(feedUrl);
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: kIsWeb ? {} : {'User-Agent': 'AIWire/1.0 (Flutter RSS Reader)'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      final entries = items.isEmpty ? document.findAllElements('entry') : items;

      List<Article> articles = [];

      for (final item in entries) {
        final title = _getText(item, ['title']);
        final url = _getUrl(item) ?? '';
        final description = _stripHtml(
          _getText(item, ['encoded', 'content', 'description', 'summary']) ?? '');
        final publishedAt = _parseDate(
          _getText(item, ['pubDate', 'published', 'updated']));
        final imageUrl = _extractImage(item, response.body);

        if (title == null || title.isEmpty || url.isEmpty) continue;
        if (!_isEnglish(title)) continue;

        articles.add(Article(
          title: title,
          description: description.isNotEmpty ? description : null,
          urlToImage: imageUrl ?? _sourceFallbackImages[sourceName],
          url: url,
          publishedAt: publishedAt,
          source: sourceName,
          content: description,
        ));
      }

      return articles;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Article>> _fetchNewsApi() async {
    const apiKey = Secrets.newsApiKey;
    if (apiKey.isEmpty) return [];

    const newsApiUrl = 'https://newsapi.org/v2/everything?q=artificial+intelligence+AI+LLM&sortBy=publishedAt&language=en&pageSize=50&apiKey=$apiKey';
    final url = Uri.parse(_proxiedUrl(newsApiUrl));

    final response = await http.get(url).timeout(const Duration(seconds: 15));

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
      } catch (e) { debugPrint("AIWire: $e"); }
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
    var s = html;
    // Strip CDATA wrappers
    s = s.replaceAll(RegExp(r'<!\[CDATA\['), '').replaceAll(']]>', '');
    // Remove all HTML tags
    s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    // Named entities
    const named = {
      '&amp;'  : '&',  '&lt;'   : '<',  '&gt;'   : '>',
      '&quot;' : '"',  '&apos;' : "'",  '&#39;'  : "'",
      '&nbsp;' : ' ',
      // Smart quotes & typographic chars
      '&#8216;': '\u2018', '&#8217;': '\u2019',
      '&#8220;': '\u201C', '&#8221;': '\u201D',
      '&#8230;': '\u2026', '&#8211;': '\u2013',
      '&#8212;': '\u2014', '&#160;' : ' ',
    };
    named.forEach((entity, char) { s = s.replaceAll(entity, char); });
    // Remaining numeric entities &#NNNN;
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : '';
    });
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static String? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.trim();

    // 1. ISO 8601 — try directly
    try {
      return DateTime.parse(raw.trim()).toIso8601String();
    } catch (e) { debugPrint("AIWire: $e"); }

    // 2. RFC 822 — "Mon, 25 Mar 2026 10:30:00 +0000" or "...GMT"
    try {
      // Normalise timezone: GMT/UTC → +0000
      s = s.replaceAll(RegExp(r'\bGMT\b'), '+0000')
           .replaceAll(RegExp(r'\bUTC\b'), '+0000');
      final parts = s.split(RegExp(r'[\s,]+'));
      int day = 0, month = 0, year = 0;
      int hour = 0, minute = 0, second = 0;
      for (int i = 0; i < parts.length; i++) {
        final p = parts[i];
        final key = p.toLowerCase();
        final monthNum = _months[key.length >= 3 ? key.substring(0, 3) : key];
        if (monthNum != null) {
          month = monthNum;
          if (i > 0) day = int.tryParse(parts[i - 1]) ?? 0;
          if (i + 1 < parts.length) year = int.tryParse(parts[i + 1]) ?? 0;
          if (i + 2 < parts.length && parts[i + 2].contains(':')) {
            final t = parts[i + 2].split(':');
            hour   = int.tryParse(t[0]) ?? 0;
            minute = int.tryParse(t.length > 1 ? t[1] : '0') ?? 0;
            second = int.tryParse(t.length > 2 ? t[2] : '0') ?? 0;
          }
          break;
        }
      }
      if (day > 0 && month > 0 && year > 0) {
        return DateTime.utc(year, month, day, hour, minute, second)
            .toIso8601String();
      }
    } catch (e) { debugPrint("AIWire: $e"); }

    // 3. Fallback — return now so article always has a timestamp
    return DateTime.now().toIso8601String();
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
        } catch (e) { debugPrint("AIWire: $e"); }
      }

      scores[article] = score;
    }

    // Sources are already AI-focused — just sort by score, show all
    articles.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return articles.take(50).toList();
  }
}

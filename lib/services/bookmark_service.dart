import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import 'user_activity_context.dart';

class BookmarkService {
  static const _key = 'bookmarked_articles';

  static Future<List<Article>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final List<Article> result = [];
    for (final s in raw) {
      try {
        result.add(Article.fromJson(json.decode(s)));
      } catch (_) {
        // skip corrupted entries
      }
    }
    return result;
  }

  static Future<void> save(Article article) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final map = {
      'title': article.title,
      'description': article.description,
      'urlToImage': article.urlToImage,
      'url': article.url,
      'publishedAt': article.publishedAt,
      'source': {'name': article.source},
      'content': article.content,
    };
    final isDuplicate = raw.any((s) {
      try { return json.decode(s)['url'] == article.url; }
      catch (_) { return false; }
    });
    if (!isDuplicate) {
      raw.add(json.encode(map));
      await prefs.setStringList(_key, raw);
      // Feed into user activity context for LLM personalization
      await UserActivityContext.recordBookmark(article.title);
    }
  }

  static Future<void> remove(Article article) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      try { return json.decode(s)['url'] == article.url; }
      catch (_) { return false; }
    });
    await prefs.setStringList(_key, raw);
  }

  static Future<bool> isBookmarked(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.any((s) {
      try { return json.decode(s)['url'] == url; }
      catch (_) { return false; }
    });
  }
}

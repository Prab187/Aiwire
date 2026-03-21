import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';

class BookmarkService {
  static const _key = 'bookmarked_articles';

  static Future<List<Article>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => Article.fromJson(json.decode(s))).toList();
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
    if (!raw.any((s) => json.decode(s)['url'] == article.url)) {
      raw.add(json.encode(map));
      await prefs.setStringList(_key, raw);
    }
  }

  static Future<void> remove(Article article) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) => json.decode(s)['url'] == article.url);
    await prefs.setStringList(_key, raw);
  }

  static Future<bool> isBookmarked(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.any((s) => json.decode(s)['url'] == url);
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';

class HistoryService {
  static const _key = 'reading_history';

  static Future<void> add(Article article) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final map = json.encode({
      'title': article.title,
      'description': article.description,
      'urlToImage': article.urlToImage,
      'url': article.url,
      'publishedAt': article.publishedAt,
      'source': {'name': article.source},
      'content': article.content,
    });
    raw.removeWhere((s) => json.decode(s)['url'] == article.url);
    raw.insert(0, map);
    if (raw.length > 50) raw.removeLast();
    await prefs.setStringList(_key, raw);
  }

  static Future<List<Article>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => Article.fromJson(json.decode(s))).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

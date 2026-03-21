import 'package:shared_preferences/shared_preferences.dart';

class LikesService {
  static Future<bool> isLiked(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final liked = prefs.getStringList('liked_articles') ?? [];
    return liked.contains(url);
  }

  static Future<bool> toggle(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final liked = prefs.getStringList('liked_articles') ?? [];
    if (liked.contains(url)) {
      liked.remove(url);
      await prefs.setStringList('liked_articles', liked);
      return false;
    } else {
      liked.add(url);
      await prefs.setStringList('liked_articles', liked);
      return true;
    }
  }

  static Future<int> getCount(String url) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('likes_count_$url') ?? (url.length % 47 + 12);
  }

  static Future<void> incrementCount(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('likes_count_$url') ?? (url.length % 47 + 12);
    await prefs.setInt('likes_count_$url', count + 1);
  }
}

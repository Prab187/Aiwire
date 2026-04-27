import 'package:shared_preferences/shared_preferences.dart';
import '../models/star_story.dart';

class StarStoryService {
  static const _key = 'star_stories_v1';
  static const _maxStories = 50;

  static Future<List<StarStory>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final List<StarStory> result = [];
    for (final s in raw) {
      try {
        result.add(StarStory.decode(s));
      } catch (_) {}
    }
    return result;
  }

  static Future<void> save(StarStory story) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    // Deduplicate by id
    raw.removeWhere((s) {
      try { return StarStory.decode(s).id == story.id; }
      catch (_) { return false; }
    });

    raw.insert(0, story.encode());

    // Cap at max
    while (raw.length > _maxStories) {
      raw.removeLast();
    }
    await prefs.setStringList(_key, raw);
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      try { return StarStory.decode(s).id == id; }
      catch (_) { return false; }
    });
    await prefs.setStringList(_key, raw);
  }

  /// Find stories relevant to a job description using keyword overlap
  static Future<List<StarStory>> findRelevant(String jobContext, {int limit = 3}) async {
    final stories = await all();
    if (stories.isEmpty) return [];

    final contextWords = _extractWords(jobContext);
    final scored = stories.map((story) {
      final storyWords = {..._extractWords(story.question), ..._extractWords(story.answer), ...story.tags.map((t) => t.toLowerCase())};
      final overlap = contextWords.intersection(storyWords).length;
      return (story: story, score: overlap);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.where((s) => s.score > 0).take(limit).map((s) => s.story).toList();
  }

  static Set<String> _extractWords(String text) {
    const stopWords = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at',
      'to', 'for', 'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were',
      'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did',
      'will', 'would', 'could', 'should', 'may', 'might', 'can', 'this',
      'that', 'these', 'those', 'i', 'you', 'we', 'they', 'me', 'my', 'your',
      'our', 'their', 'it', 'its', 'how', 'what', 'when', 'where', 'why',
      'about', 'into', 'through', 'during', 'before', 'after', 'above'};

    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s+#]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toSet();
  }

  /// Extract tags from a question + answer for future matching
  static List<String> extractTags(String question, String answer) {
    const relevantTerms = {
      'leadership', 'conflict', 'teamwork', 'challenge', 'failure', 'success',
      'communication', 'deadline', 'pressure', 'initiative', 'problem',
      'innovation', 'collaboration', 'mentoring', 'feedback', 'decision',
      'python', 'java', 'ml', 'ai', 'data', 'cloud', 'aws', 'gcp', 'azure',
      'tensorflow', 'pytorch', 'deep', 'learning', 'nlp', 'llm', 'system',
      'design', 'architecture', 'scale', 'performance', 'optimization',
      'algorithm', 'database', 'api', 'microservices', 'kubernetes', 'docker',
    };

    final words = _extractWords('$question $answer');
    return words.intersection(relevantTerms).toList()..sort();
  }
}

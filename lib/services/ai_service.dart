import 'dart:convert';
import '../models/resume_profile.dart';
import 'claude_error.dart';
import 'claude_http.dart';
import 'summary_cache.dart';

class AIService {
  /// Summarize an article.
  ///
  /// Personalization is OPT-IN. By default (no `personalizeFor`), the summary
  /// is GENERIC — the same for every user — which is what you want on the
  /// main news feed / Discover screen.
  ///
  /// Pass `personalizeFor` when the article is being shown in a context tied
  /// to a specific resume (e.g. inside the Resume Scan results tab). The
  /// fourth bullet will then be tailored to that resume's profile.
  static Future<String> summarizeArticle({
    required String title,
    String? description,
    String? content,
    String? url,
    ResumeProfile? personalizeFor,
  }) async {
    final bool isPersonalized = personalizeFor != null
        && personalizeFor.skills.isNotEmpty
        && personalizeFor.jobTitle.isNotEmpty;

    // Cache key distinguishes generic vs personalized. Generic cache is
    // shared across ALL users. Personalized cache is unique per user profile.
    final cacheSuffix = isPersonalized
        ? 'p_${personalizeFor.jobTitle}_${personalizeFor.experienceLevel}_${personalizeFor.country}_${personalizeFor.skills.take(3).join("_")}'
        : 'generic';
    final cacheKey = url != null ? '${url}__$cacheSuffix' : null;

    // Return instantly if cached
    if (cacheKey != null && SummaryCache.has(cacheKey)) {
      return SummaryCache.get(cacheKey)!;
    }

    // Coalesce in-flight requests for the same key
    if (cacheKey != null && SummaryCache.getInFlight(cacheKey) != null) {
      return SummaryCache.getInFlight(cacheKey)!;
    }

    final future = _fetch(
      title: title, description: description, content: content,
      cacheKey: cacheKey, personalizeFor: isPersonalized ? personalizeFor : null);

    if (cacheKey != null) SummaryCache.setInFlight(cacheKey, future);
    return future;
  }

  static Future<String> _fetch({
    required String title,
    String? description,
    String? content,
    String? cacheKey,
    ResumeProfile? personalizeFor,
  }) async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');
    final context = description ?? content ?? '';

    final isPersonalized = personalizeFor != null;

    final personalBlock = isPersonalized
        ? '''
READER PROFILE (tailor the last bullet to this SPECIFIC person):
- Name: ${personalizeFor.name ?? 'the reader'}
- Role: ${personalizeFor.jobTitle}
- Level: ${personalizeFor.experienceLevel}
- Top skills: ${personalizeFor.skills.take(4).join(", ")}
- Country: ${personalizeFor.country}

'''
        : '';

    final lastBulletSpec = isPersonalized
        ? 'Bullet 4 (personalized for ${personalizeFor.name ?? "this reader"}): "For you as a ${personalizeFor.jobTitle}" — explain ONE concrete implication for THIS specific reader\'s day-to-day work, skill learning path, or job market in ${personalizeFor.country}. Be specific: name a tool, skill, or company.'
        : 'Bullet 4: Why this matters for AI/ML practitioners in general. Keep it broadly applicable — do NOT tailor to any specific person.';

    final prompt = '''Summarize this AI news article in exactly 4 concise bullets. Each starts with "• " and is one sentence.

$personalBlock
Bullet 1: The core news in plain language (what happened).
Bullet 2: Who's involved (companies, people, products) + one number or specific detail.
Bullet 3: The key insight or technical takeaway most readers will miss.
$lastBulletSpec

Rules:
- No preamble, no headers, no closing remark.
- No hype words ("revolutionary", "groundbreaking").
- If the article lacks technical depth, say so rather than invent.
- Exactly 4 bullets. Each under 25 words.

⚠️ HONESTY GUARD:
- Only state facts present in the Title + description above. Do NOT extrapolate from your training data.
- If a bullet would require info not in the article, write "Article doesn't specify" for that bullet instead.
- Numbers: only cite if explicitly in the source. No inventing stats.

Title: $title

$context''';

    final response = await ClaudeHttp.post(
      apiKey: apiKey,
      timeout: const Duration(seconds: 30),
      body: {
        'model': 'claude-haiku-4-5',
        'max_tokens': 400,
        'messages': [{'role': 'user', 'content': prompt}],
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final contentList = data['content'] as List?;
      if (contentList == null || contentList.isEmpty) {
        throw Exception('Empty response from AI');
      }
      final summary = (contentList[0]['text'] as String?) ?? '';
      if (summary.isEmpty) throw Exception('Empty summary');
      if (cacheKey != null) SummaryCache.set(cacheKey, summary);
      return summary;
    } else {
      throw Exception('Article summary failed — ${claudeError(response.statusCode, response.body)}');
    }
  }

  /// Prefetch disabled to save Claude credits. Left as no-op for callers.
  static void prefetch(List<dynamic> articles) {}
}

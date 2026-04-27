import 'package:shared_preferences/shared_preferences.dart';

/// Aggregates everything we know about the user to pass as context to Claude.
/// This gives the LLM "memory" across sessions by loading their resume profile,
/// bookmarked articles, saved jobs, recent searches, and interview history.
///
/// Returns a compact string block suitable for injecting into any prompt.
class UserActivityContext {
  /// Build a full context block. Caller decides whether to include it
  /// based on prompt budget. Typically 200-400 tokens.
  static Future<String> buildPromptContext({
    bool includeBookmarks = true,
    bool includeSavedJobs = true,
    bool includeSearches = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final buf = StringBuffer();

      // ── Profile (from resume) ────────────────────────────────────────
      final jobTitle = prefs.getString('user_job_title');
      if (jobTitle != null && jobTitle.isNotEmpty) {
        final level = prefs.getString('user_level') ?? 'Mid';
        final country = prefs.getString('user_country') ?? '';
        final skills = prefs.getStringList('user_skills') ?? const [];
        buf.writeln('USER PROFILE:');
        buf.writeln('- Role: $jobTitle ($level)');
        if (country.isNotEmpty) buf.writeln('- Country: $country');
        if (skills.isNotEmpty) {
          buf.writeln('- Top skills: ${skills.take(6).join(", ")}');
        }
      }

      // ── Recent bookmarks (what articles they care about) ──────────────
      if (includeBookmarks) {
        final titles = prefs.getStringList('bookmark_titles') ?? const [];
        if (titles.isNotEmpty) {
          buf.writeln('\nRECENTLY BOOKMARKED ARTICLES (signals their interests):');
          for (final t in titles.take(5)) {
            buf.writeln('- $t');
          }
        }
      }

      // ── Saved jobs (what they\'re targeting) ──────────────────────────
      if (includeSavedJobs) {
        final savedJobs = prefs.getStringList('saved_job_titles') ?? const [];
        if (savedJobs.isNotEmpty) {
          buf.writeln('\nSAVED JOBS (signals their target roles):');
          for (final j in savedJobs.take(5)) {
            buf.writeln('- $j');
          }
        }
      }

      // ── Recent searches (current focus) ──────────────────────────────
      if (includeSearches) {
        final searches = prefs.getStringList('recent_searches') ?? const [];
        if (searches.isNotEmpty) {
          buf.writeln('\nRECENT SEARCHES (what they\'re exploring right now):');
          for (final s in searches.take(5)) {
            buf.writeln('- $s');
          }
        }
      }

      // ── Interview history ────────────────────────────────────────────
      final avgScore = prefs.getInt('interview_avg_score');
      final weakArea = prefs.getString('interview_weak_area');
      if (avgScore != null) {
        buf.writeln('\nINTERVIEW HISTORY:');
        buf.writeln('- Avg score across past mocks: $avgScore/10');
        if (weakArea != null && weakArea.isNotEmpty) {
          buf.writeln('- Weakest rubric area: $weakArea');
        }
      }

      final result = buf.toString().trim();
      return result.isEmpty ? '' : '$result\n';
    } catch (_) {
      return '';
    }
  }

  // ── Writers used by various screens to populate context ──────────────

  /// Called when user bookmarks an article
  static Future<void> recordBookmark(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final titles = List<String>.from(prefs.getStringList('bookmark_titles') ?? []);
    titles.remove(title); // Move to front if already present
    titles.insert(0, title);
    if (titles.length > 20) titles.removeRange(20, titles.length);
    await prefs.setStringList('bookmark_titles', titles);
  }

  /// Called when user saves a job
  static Future<void> recordSavedJob(String jobTitle, String company) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = '$jobTitle @ $company';
    final list = List<String>.from(prefs.getStringList('saved_job_titles') ?? []);
    list.remove(entry);
    list.insert(0, entry);
    if (list.length > 20) list.removeRange(20, list.length);
    await prefs.setStringList('saved_job_titles', list);
  }

  /// Called when user searches (jobs, articles, anything)
  static Future<void> recordSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(prefs.getStringList('recent_searches') ?? []);
    list.remove(query);
    list.insert(0, query);
    if (list.length > 10) list.removeRange(10, list.length);
    await prefs.setStringList('recent_searches', list);
  }

  /// Called after a mock interview completes — stores avg + weak rubric area
  static Future<void> recordInterviewResult({
    required int avgScore10,
    required String weakestArea,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('interview_avg_score', avgScore10);
    await prefs.setString('interview_weak_area', weakestArea);
  }
}

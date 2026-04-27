import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'claude_cache.dart';
import 'claude_error.dart';
import 'claude_http.dart';
import 'user_activity_context.dart';
import '../models/resume_profile.dart';

class CompanyResearchService {
  /// Fetch recent news about a company via NewsAPI (last 30 days, top 5 hits).
  /// Returns a concise text block to feed Claude as grounding context.
  static Future<String> _fetchRecentNews(String company) async {
    const apiKey = String.fromEnvironment('NEWS_API_KEY');
    if (apiKey.isEmpty) return '';
    try {
      final fromDate = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String()
          .split('T').first;
      final url = Uri.parse(
        'https://newsapi.org/v2/everything'
        '?q=${Uri.encodeComponent('"$company"')}'
        '&from=$fromDate'
        '&sortBy=publishedAt'
        '&language=en'
        '&pageSize=5'
        '&apiKey=$apiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return '';
      final data = json.decode(response.body);
      final articles = (data['articles'] as List?) ?? [];
      if (articles.isEmpty) return '';
      final lines = <String>[];
      for (final a in articles.take(5)) {
        final date = (a['publishedAt'] as String? ?? '').split('T').first;
        final title = (a['title'] as String? ?? '').trim();
        final source = (a['source']?['name'] as String? ?? '').trim();
        if (title.isEmpty) continue;
        lines.add('- [$date] $title (${source.isEmpty ? "news" : source})');
      }
      if (lines.isEmpty) return '';
      return lines.join('\n');
    } catch (_) {
      return '';
    }
  }

  static Future<String> research({
    required String company,
    required String jobTitle,
    required ResumeProfile profile,
  }) async {
    final cacheKey = ClaudeCache.keyFrom(['v2', company, jobTitle]);
    final cached = await ClaudeCache.get('company_research', cacheKey,
        ttl: const Duration(days: 7)); // shorter cache since news changes
    if (cached != null) return cached;

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('API key not configured');

    // Pull real news BEFORE calling Claude so it has current grounding
    final recentNews = await _fetchRecentNews(company);
    final today = DateTime.now().toIso8601String().split('T').first;

    // User activity context — gives Claude memory of what user cares about
    final activityCtx = await UserActivityContext.buildPromptContext(
      includeSearches: true, includeBookmarks: true, includeSavedJobs: true);

    final newsBlock = recentNews.isNotEmpty
        ? '''

RECENT NEWS (last 30 days, fetched $today — USE THIS for "Recent Moves" section, cite it):
$recentNews
'''
        : '''

NO RECENT NEWS API DATA AVAILABLE.
In the "Recent Moves" section, explicitly note: "Unable to fetch live news. Visit ${_guessCompanyDomain(company)}/news or search '$company' on LinkedIn for latest updates."
''';

    final prompt = '''You are an expert career strategist briefing a candidate. Use ONLY verifiable information — prefer the RECENT NEWS block below over your training data (which is from early 2025).

COMPANY: $company
TARGET ROLE: $jobTitle
CANDIDATE: ${profile.jobTitle} with ${profile.yearsOfExperience} years experience in ${profile.skills.take(5).join(', ')}
COUNTRY: ${profile.country}
TODAY'S DATE: $today

${activityCtx.isNotEmpty ? "\nADDITIONAL USER CONTEXT (use to make positioning advice more specific):\n$activityCtx\n" : ""}
$newsBlock
Use these EXACT section headers on their own line (no asterisks, no markdown). Each has 3-4 bullets starting with "• ". Be specific and honest. If you don't know something current, say so — don't guess.

AI STRATEGY
• [Their known AI/ML focus areas. If from training data only, say "As of early 2025:"]
• [Products or services with AI/ML]
• [Where $jobTitle role fits]

RECENT MOVES
• [Cite SPECIFIC news headlines from the RECENT NEWS block above with dates. If no news available, say "Check [Company website]/news for latest". Never invent moves.]
• [Funding, hires, launches — ONLY if in news block or widely known]
• [Market direction based on news]

ENGINEERING CULTURE
• [Known tech stack — if uncertain, say "typical for companies of this size/stage"]
• [Team structure patterns for this type of company]
• [Glassdoor-style cultural signals if known]

KEY CHALLENGES
• [Technical/business problems this role addresses at $company]
• [Competitive pressures facing them]
• [Why they're hiring for $jobTitle specifically]

COMPETITORS
• [Top 3 direct competitors with one-line differentiation each]
• [How $company differentiates]
• [Market position: leader / challenger / niche]

HOW TO POSITION YOURSELF
• [ONE specific talking point that connects ${profile.name ?? 'the candidate'}'s experience (${profile.skills.take(3).join(', ')}) to $company's current needs — reference the news if relevant]
• [Most impressive skill/project from profile to lead with]
• [2 smart questions to ask that show deep research — must reference the recent news or a known challenge]
• [One red flag to watch for and what to ask to surface it]

IMPORTANT:
- Do NOT invent facts, funding rounds, or product launches that aren't in the RECENT NEWS block.
- Be clear about what's grounded in 2026 news vs. 2025 training data.''';

    final response = await ClaudeHttp.post(
      apiKey: apiKey,
      timeout: const Duration(seconds: 60),
      body: {
        'model': 'claude-haiku-4-5',
        'max_tokens': 1400,
        'messages': [{'role': 'user', 'content': prompt}],
      },
    );

    if (response.statusCode != 200) {
      throw Exception(claudeError(response.statusCode, response.body));
    }

    final data = json.decode(response.body);
    final contentList = data['content'] as List?;
    if (contentList == null || contentList.isEmpty) {
      throw Exception('Empty response from AI');
    }
    final text = (contentList[0]['text'] as String? ?? '').trim();
    await ClaudeCache.set('company_research', cacheKey, text);
    return text;
  }

  /// Best-guess company domain for a "see their website" fallback
  static String _guessCompanyDomain(String company) {
    final slug = company
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return '$slug.com';
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'claude_cache.dart';
import 'claude_error.dart';
import '../models/resume_profile.dart';

class CompanyResearchService {
  static Future<String> research({
    required String company,
    required String jobTitle,
    required ResumeProfile profile,
  }) async {
    final cacheKey = ClaudeCache.keyFrom([company, jobTitle]);
    final cached = await ClaudeCache.get('company_research', cacheKey,
        ttl: const Duration(days: 14));
    if (cached != null) return cached;

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('API key not configured');

    final prompt = '''You are an expert career strategist. Generate a company research brief for a candidate preparing to apply.

COMPANY: $company
TARGET ROLE: $jobTitle
CANDIDATE: ${profile.jobTitle} with ${profile.yearsOfExperience} years experience in ${profile.skills.take(5).join(', ')}
COUNTRY: ${profile.country}

Use these EXACT section headers. Each section should have 3-4 bullet points starting with "•". Be specific and actionable.

AI STRATEGY
• [Their AI/ML initiatives, products, and technical direction]
• [Key AI investments or acquisitions]
• [Where this role fits in their AI roadmap]

RECENT MOVES
• [Latest funding, product launches, or major announcements]
• [Key hires or leadership changes]
• [Market expansion or pivots]

ENGINEERING CULTURE
• [Tech stack and tools they use]
• [Team structure and collaboration style]
• [Growth opportunities and learning culture]

KEY CHALLENGES
• [Technical challenges this role would address]
• [Business challenges or competitive pressures]
• [Talent gaps they're trying to fill]

COMPETITORS
• [Top 3 direct competitors]
• [How this company differentiates]
• [Market position strength]

HOW TO POSITION YOURSELF
• [Specific talking points for ${profile.name ?? 'the candidate'} applying to $jobTitle]
• [Skills from their profile to emphasize: ${profile.skills.take(3).join(', ')}]
• [Questions to ask in the interview that show research]
• [Red flags to watch for]

Be concise and specific to $company. No generic advice.''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: json.encode({
        'model': 'claude-haiku-4-5',
        'max_tokens': 1200,
        'messages': [{'role': 'user', 'content': prompt}],
      }),
    ).timeout(const Duration(seconds: 45));

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
}

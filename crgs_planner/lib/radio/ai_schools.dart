import 'news_item.dart';

/// AI products to listen out for: display name -> pattern.
final _tools = <String, RegExp>{
  'ChatGPT': RegExp(r'chat\s?gpt', caseSensitive: false),
  'Copilot': RegExp(r'\bcopilot\b', caseSensitive: false),
  'Gemini': RegExp(r'\bgemini\b', caseSensitive: false),
  'Claude': RegExp(r'\bclaude\b'),
  'Khanmigo': RegExp(r'khanmigo', caseSensitive: false),
  'Aila': RegExp(r'\baila\b'),
  'MagicSchool': RegExp(r'magic\s?school', caseSensitive: false),
  'Teachermatic': RegExp(r'teachermatic', caseSensitive: false),
  'Century Tech': RegExp(r'century\s+tech', caseSensitive: false),
  'Grammarly': RegExp(r'grammarly', caseSensitive: false),
  'Perplexity': RegExp(r'perplexity', caseSensitive: false),
  'DeepSeek': RegExp(r'deepseek', caseSensitive: false),
  'Meta AI': RegExp(r'\bmeta ai\b', caseSensitive: false),
  'Kahoot AI': RegExp(r'kahoot', caseSensitive: false),
  'Quizlet': RegExp(r'quizlet', caseSensitive: false),
};
final _generic = <String, RegExp>{
  'AI tutor': RegExp(r'\bAI[- ]tutor', caseSensitive: false),
  'AI chatbot': RegExp(r'\bchatbot', caseSensitive: false),
  'AI marking': RegExp(r'\bAI[- ]marking|\bmarking tool', caseSensitive: false),
};

/// Up to three AI products or kinds of AI named in [text].
List<String> aiToolsIn(String text) {
  final found = <String>[
    for (final e in _tools.entries)
      if (e.value.hasMatch(text)) e.key,
  ];
  if (found.isEmpty) {
    for (final e in _generic.entries) {
      if (e.value.hasMatch(text)) found.add(e.key);
    }
  }
  return found.take(3).toList();
}

final _word = r"[A-Z][A-Za-z0-9'’.&-]*";
final _schoolRe = RegExp(
  "((?:$_word|of|the|and)(?:\\s+(?:$_word|of|the|and)){0,6}"
  "\\s+(?:Grammar School|High School|Primary School|Secondary School|Junior School|Infant School|Preparatory School|Sixth Form College|Sixth Form|Academy|School|College))",
);
const _leading = {
  'the', 'a', 'an', 'at', 'in', 'on', 'of', 'to', 'for', 'from', 'by', 'with', 'how', 'why', 'what', 'when', 'where', 'as',
  'pupils', 'students', 'teachers', 'staff', 'parents', 'new', 'first', 'every', 'all', 'uk', 'british', 'english', 'ai', 'and', 'but', 'after', 'inside',
};
const _genericSchool = {
  'school', 'schools', 'high', 'primary', 'secondary', 'junior', 'infant', 'preparatory', 'grammar', 'sixth', 'form', 'college', 'academy',
  'the', 'of', 'and', 'state', 'private', 'independent', 'local', 'every', 'many', 'some', 'uk', 'english', 'british', 'ai',
};

/// A school named in [text], like "Colchester Royal Grammar School", or null.
String? schoolIn(String text) {
  for (final m in _schoolRe.allMatches(text)) {
    final words = m.group(1)!.split(RegExp(r'\s+'));
    while (words.isNotEmpty && _leading.contains(words.first.toLowerCase())) {
      words.removeAt(0);
    }
    if (words.length < 2) continue;
    final distinctive = words.where((w) => !_genericSchool.contains(w.toLowerCase())).toList();
    if (distinctive.isEmpty) continue;
    return words.join(' ');
  }
  return null;
}

final _aiRe = RegExp(r'\bAI\b|\bA\.I\.|artificial intelligence|chat\s?gpt|copilot|gemini|chatbot|generative|machine learning|khanmigo', caseSensitive: false);
final _aiUpper = RegExp(r'\bAI\b');
final _schoolish = RegExp(r'\b(schools?|academy|academies|pupils?|students?|teachers?|classrooms?|college|sixth form|GCSE|A-levels?|lessons?|homework)\b', caseSensitive: false);

/// True for stories about AI in schools.
bool isAiSchoolStory(NewsItem it) {
  final t = '${it.title} ${it.summary}';
  final ai = _aiUpper.hasMatch(t) || _aiRe.hasMatch(t) || aiToolsIn(t).isNotEmpty;
  return ai && _schoolish.hasMatch(t);
}

final _blocked = RegExp(
  r'\b(sex\w*|porn\w*|nude\w*|naked|rape\w*|murder\w*|kill(?:ed|ing|er)?|suicid\w*|self-harm|terror\w*|shooting|shot dead|stabb\w*|abus\w*|paedophil\w*|pedophil\w*|groom(?:ing|ed)|deepfake\w*|explicit|drugs?|gun|guns|knife|dead|death|died)\b',
  caseSensitive: false,
);

/// Drops stories with words that are not right to read out to a school-age audience.
bool isSafeForStudents(NewsItem it) => !_blocked.hasMatch('${it.title} ${it.summary}');

/// Only reputable news and education sources are used.
const trustedDomains = <String, String>{
  'bbc.co.uk': 'BBC News',
  'bbc.com': 'BBC News',
  'theguardian.com': 'The Guardian',
  'schoolsweek.co.uk': 'Schools Week',
  'tes.com': 'Tes',
  'independent.co.uk': 'The Independent',
  'telegraph.co.uk': 'The Telegraph',
  'thetimes.co.uk': 'The Times',
  'news.sky.com': 'Sky News',
  'itv.com': 'ITV News',
  'reuters.com': 'Reuters',
  'apnews.com': 'AP News',
  'theconversation.com': 'The Conversation',
  'edtechmagazine.com': 'EdTech Magazine',
  'eschoolnews.com': 'eSchool News',
  'edweek.org': 'Education Week',
  'chalkbeat.org': 'Chalkbeat',
  'k12dive.com': 'K-12 Dive',
  'schoolsimprovement.net': 'Schools Improvement',
  'gazette-news.co.uk': 'Colchester Gazette',
  'essexlive.news': 'Essex Live',
};

/// Friendly name for a trusted [domain], or null if it is not trusted.
String? trustedSourceName(String domain) {
  var d = domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (trustedDomains.containsKey(d)) return trustedDomains[d];
  if (d.endsWith('.gov.uk')) return 'GOV.UK';
  if (d.endsWith('.ac.uk')) return 'University news';
  for (final e in trustedDomains.entries) {
    if (d.endsWith('.${e.key}')) return e.value;
  }
  return null;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// Keeps one copy of each story (same headline, any source).
List<NewsItem> dedupe(List<NewsItem> items) {
  final seen = <String>{};
  final out = <NewsItem>[];
  for (final it in items) {
    final key = _norm(it.title);
    final short = key.length > 60 ? key.substring(0, 60) : key;
    if (seen.add(short)) out.add(it);
  }
  return out;
}

bool mentionsSchool(NewsItem it, String mySchool) {
  final s = _norm(mySchool);
  if (s.isEmpty) return false;
  return _norm('${it.title} ${it.summary}').contains(s);
}

/// Safe AI-in-schools stories, one copy each, your school first, then stories
/// that name a school and an AI product, then the newest.
List<NewsItem> rankStories(List<NewsItem> items, {String mySchool = '', DateTime? now, int limit = 30}) {
  final n = now ?? DateTime.now();
  final good = dedupe(items.where((i) => isAiSchoolStory(i) && isSafeForStudents(i)).toList());
  double score(NewsItem i) {
    var s = 0.0;
    if (mentionsSchool(i, mySchool)) s += 100;
    if (i.hasSchoolAndAi) {
      s += 20;
    } else if (i.school != null) {
      s += 8;
    } else if (i.aiTools.isNotEmpty) {
      s += 4;
    }
    if (i.published != null) {
      final days = n.difference(i.published!).inHours / 24;
      s += (10 - days).clamp(0, 10);
    }
    return s;
  }

  final ranked = [...good]..sort((a, b) => score(b).compareTo(score(a)));
  return ranked.take(limit).toList();
}

/// "School -> AI product" pairs, one row per pair, for the "who got what" board.
List<({String school, String tool, NewsItem story})> schoolAiPairs(List<NewsItem> items) {
  final seen = <String>{};
  final out = <({String school, String tool, NewsItem story})>[];
  for (final it in items) {
    if (!it.hasSchoolAndAi) continue;
    for (final t in it.aiTools) {
      if (seen.add('${_norm(it.school!)}|$t')) out.add((school: it.school!, tool: t, story: it));
    }
  }
  return out;
}

import 'ai_schools.dart';

/// One news story about AI in schools.
class NewsItem {
  NewsItem({required this.title, required this.url, required this.source, this.published, this.summary = ''})
      : aiTools = aiToolsIn('$title $summary'),
        school = schoolIn(title) ?? schoolIn(summary);

  final String title;
  final String url;

  /// Friendly source name, e.g. "BBC News".
  final String source;
  final DateTime? published;
  final String summary;

  /// AI products spotted in the story, e.g. ChatGPT or Khanmigo.
  final List<String> aiTools;

  /// A school named in the story, if one was spotted. Spotting is automatic and can be wrong.
  final String? school;

  bool get hasSchoolAndAi => school != null && aiTools.isNotEmpty;

  Map<String, dynamic> toJson() => {
        't': title,
        'u': url,
        's': source,
        'p': published?.toUtc().toIso8601String(),
        'd': summary,
      };

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        title: j['t'] as String,
        url: j['u'] as String,
        source: j['s'] as String,
        published: j['p'] == null ? null : DateTime.tryParse(j['p'] as String),
        summary: j['d'] as String? ?? '',
      );
}

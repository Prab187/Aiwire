import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'ai_schools.dart';
import 'news_item.dart';

/// Where the radio gets its stories. Swappable so tests need no internet.
abstract class NewsRepository {
  /// Stories for everyone, ranked, with [mySchool]'s stories first.
  Future<List<NewsItem>> fetch({required String mySchool, required bool ukOnly});

  /// Extra stories that name [mySchool]. Slower, so asked for after [fetch].
  Future<List<NewsItem>> fetchMine({required String mySchool});
}

/// Free sources, no keys or accounts:
///  - GDELT DOC 2.0 API (news search across the world's outlets)
///  - Schools Week RSS feed
///  - BBC News Education RSS feed
class LiveNewsRepository implements NewsRepository {
  LiveNewsRepository({http.Client? client, this.timeout = const Duration(seconds: 12)}) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;

  static const _headers = {'User-Agent': 'CRGSStudentPlanner/1.0 (student app; unofficial)'};

  Uri gdeltUri(String query) => Uri.https('api.gdeltproject.org', '/api/v2/doc/doc', {
        'query': query,
        'mode': 'artlist',
        'maxrecords': '75',
        'format': 'json',
        'timespan': '14d',
        'sort': 'datedesc',
      });

  String generalQuery({required bool ukOnly}) =>
      '("artificial intelligence" OR ChatGPT OR Copilot OR "AI tutor" OR chatbot OR Khanmigo) (school OR academy OR pupils OR teachers) sourcelang:english${ukOnly ? ' sourcecountry:UK' : ''}';

  String schoolQuery(String school) => '"$school" ("artificial intelligence" OR AI OR ChatGPT OR Copilot OR chatbot)';

  Future<String?> _get(Uri uri) async {
    try {
      final r = await _client.get(uri, headers: _headers).timeout(timeout);
      if (r.statusCode != 200) return null;
      return utf8.decode(r.bodyBytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<NewsItem>> fetch({required String mySchool, required bool ukOnly}) async {
    final results = await Future.wait([
      _get(gdeltUri(generalQuery(ukOnly: ukOnly))).then((b) => b == null ? null : parseGdelt(b)),
      _get(Uri.parse('https://schoolsweek.co.uk/feed/')).then((b) => b == null ? null : parseRss(b, 'Schools Week')),
      _get(Uri.parse('https://feeds.bbci.co.uk/news/education/rss.xml')).then((b) => b == null ? null : parseRss(b, 'BBC News')),
    ]);
    if (results.every((r) => r == null)) {
      throw const NewsUnavailable('Could not reach the news sources.');
    }
    final all = [for (final r in results) ...?r];
    return rankStories(all, mySchool: mySchool);
  }

  @override
  Future<List<NewsItem>> fetchMine({required String mySchool}) async {
    if (mySchool.trim().isEmpty) return [];
    final body = await _get(gdeltUri(schoolQuery(mySchool.trim())));
    return body == null ? [] : parseGdelt(body);
  }
}

class NewsUnavailable implements Exception {
  const NewsUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

String decodeEntities(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&#8217;', '’')
    .replaceAll('&#8216;', '‘')
    .replaceAll('&#8220;', '“')
    .replaceAll('&#8221;', '”')
    .replaceAll('&#8211;', '–')
    .replaceAll('&nbsp;', ' ');

String stripHtml(String s) => decodeEntities(s.replaceAll(RegExp(r'<[^>]*>'), ' ')).replaceAll(RegExp(r'\s+'), ' ').trim();

/// GDELT "20261022T093000Z" -> UTC time.
DateTime? parseGdeltDate(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z?$').firstMatch(s.trim());
  if (m == null) return null;
  final v = List.generate(6, (i) => int.parse(m.group(i + 1)!));
  return DateTime.utc(v[0], v[1], v[2], v[3], v[4], v[5]);
}

const _months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};

/// RSS date like "Fri, 23 Oct 2026 14:00:00 +0100" or "... GMT" -> UTC time.
DateTime? parseRssDate(String? s) {
  if (s == null) return null;
  final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4})?').firstMatch(s);
  if (m == null) return null;
  final mon = _months[m.group(2)!.toLowerCase()];
  if (mon == null) return null;
  var t = DateTime.utc(int.parse(m.group(3)!), mon, int.parse(m.group(1)!), int.parse(m.group(4)!), int.parse(m.group(5)!), int.parse(m.group(6) ?? '0'));
  final off = m.group(7);
  if (off != null) {
    final sign = off.startsWith('-') ? -1 : 1;
    t = t.subtract(Duration(hours: sign * int.parse(off.substring(1, 3)), minutes: sign * int.parse(off.substring(3, 5))));
  }
  return t;
}

/// Reads a GDELT DOC API "artlist" JSON reply. Returns only trusted sources. Bad replies give [].
List<NewsItem> parseGdelt(String body) {
  try {
    final j = jsonDecode(body);
    if (j is! Map || j['articles'] is! List) return [];
    final out = <NewsItem>[];
    for (final a in (j['articles'] as List)) {
      if (a is! Map) continue;
      final url = a['url'] as String?;
      final title = a['title'] as String?;
      final domain = a['domain'] as String?;
      if (url == null || title == null || domain == null || !url.startsWith('http')) continue;
      final source = trustedSourceName(domain);
      if (source == null) continue;
      final t = stripHtml(title);
      if (t.isEmpty) continue;
      out.add(NewsItem(title: t, url: url, source: source, published: parseGdeltDate(a['seendate'] as String?)));
    }
    return out;
  } catch (_) {
    return [];
  }
}

/// Reads an RSS 2.0 feed. Bad feeds give [].
List<NewsItem> parseRss(String body, String sourceName) {
  try {
    final doc = XmlDocument.parse(body);
    final out = <NewsItem>[];
    for (final item in doc.findAllElements('item')) {
      String? text(String name) => item.findElements(name).firstOrNull?.innerText.trim();
      final title = text('title'), link = text('link');
      if (title == null || link == null || !link.startsWith('http')) continue;
      var summary = stripHtml(text('description') ?? '');
      if (summary.length > 240) summary = '${summary.substring(0, 237).trimRight()}…';
      out.add(NewsItem(title: stripHtml(title), url: link, source: sourceName, published: parseRssDate(text('pubDate')), summary: summary));
    }
    return out;
  } catch (_) {
    return [];
  }
}

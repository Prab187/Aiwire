import 'package:crgs_planner/radio/ai_schools.dart';
import 'package:crgs_planner/radio/news_item.dart';
import 'package:crgs_planner/radio/news_sources.dart';
import 'package:crgs_planner/radio/radio_script.dart';
import 'package:flutter_test/flutter_test.dart';

NewsItem story(String title, {String source = 'BBC News', DateTime? at, String summary = ''}) =>
    NewsItem(title: title, url: 'https://example.org/${title.hashCode}', source: source, published: at, summary: summary);

const gdeltFixture = '''
{"articles":[
 {"url":"https://www.bbc.co.uk/news/crgs-chatgpt","url_mobile":"","title":"Colchester Royal Grammar School trials ChatGPT for homework feedback","seendate":"20261020T093000Z","socialimage":"","domain":"bbc.co.uk","language":"English","sourcecountry":"United Kingdom"},
 {"url":"https://schoolsweek.co.uk/st-marys-khanmigo/","title":"St Mary&#39;s Academy rolls out Khanmigo AI tutor to Year 9","seendate":"20261022T120000Z","domain":"schoolsweek.co.uk","language":"English","sourcecountry":"United Kingdom"},
 {"url":"https://www.theguardian.com/education/chatgpt-bans","title":"Why schools are banning ChatGPT in homework","seendate":"20261021T080000Z","domain":"www.theguardian.com","language":"English"},
 {"url":"https://www.theguardian.com/education/crgs-copy","title":"Colchester Royal Grammar School trials ChatGPT for homework feedback","seendate":"20261020T100000Z","domain":"theguardian.com","language":"English"},
 {"url":"https://www.bbc.co.uk/news/deepfakes","title":"Pupils fooled by deepfake nude images made with AI","seendate":"20261022T080000Z","domain":"bbc.co.uk","language":"English"},
 {"url":"https://www.bbc.co.uk/sport/football","title":"Colchester United win again at home","seendate":"20261022T081000Z","domain":"bbc.co.uk","language":"English"},
 {"url":"https://random-blog.example/oakfield","title":"Oakfield High School is using Copilot to cut marking","seendate":"20261022T081000Z","domain":"random-blog.example","language":"English"},
 {"url":"ftp://bad.example/x","title":"Bad link","seendate":"x","domain":"bbc.co.uk"}
]}
''';

const rssFixture = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Schools Week</title>
<item><title>Ark Academy &amp; Microsoft trial Copilot in lessons</title><link>https://schoolsweek.co.uk/ark-copilot/</link>
<pubDate>Thu, 22 Oct 2026 09:30:00 +0100</pubDate>
<description><![CDATA[<p>Pupils at the Ark trust will use <b>Microsoft Copilot</b> &#8211; the AI assistant &#8211; in lessons.</p>]]></description></item>
<item><title>Exam board confirms GCSE dates</title><link>https://schoolsweek.co.uk/gcse-dates/</link><pubDate>Wed, 21 Oct 2026 10:00:00 GMT</pubDate><description>Dates for summer.</description></item>
<item><title>No link here</title></item>
</channel></rss>''';

void main() {
  group('AI tools and schools in headlines', () {
    test('finds AI products', () {
      expect(aiToolsIn('Pupils try ChatGPT and Microsoft Copilot'), ['ChatGPT', 'Copilot']);
      expect(aiToolsIn('Khanmigo comes to the classroom'), ['Khanmigo']);
      expect(aiToolsIn('A new AI tutor for maths'), ['AI tutor']);
      expect(aiToolsIn('Football results'), isEmpty);
    });

    test('finds a school by name and ignores generic mentions', () {
      expect(schoolIn('Colchester Royal Grammar School trials ChatGPT'), 'Colchester Royal Grammar School');
      expect(schoolIn("Pupils at St Mary's Academy get Khanmigo"), "St Mary's Academy");
      expect(schoolIn('How Oakfield High School is using Copilot'), 'Oakfield High School');
      expect(schoolIn('Ark Academy & Microsoft trial Copilot'), 'Ark Academy');
      expect(schoolIn('Why schools are banning ChatGPT'), isNull);
      expect(schoolIn('Government backs AI in schools'), isNull);
      expect(schoolIn('Secondary School pupils use AI'), isNull);
      expect(schoolIn('The Primary School is closing'), isNull);
    });

    test('is it an AI in schools story', () {
      expect(isAiSchoolStory(story('Government backs AI in schools')), isTrue);
      expect(isAiSchoolStory(story('Teachers try ChatGPT for lesson plans')), isTrue);
      expect(isAiSchoolStory(story('Colchester United win again')), isFalse);
      expect(isAiSchoolStory(story('AI stocks rally on Wall Street')), isFalse);
    });

    test('keeps unsuitable stories out', () {
      expect(isSafeForStudents(story('Pupils fooled by deepfake nude images made with AI')), isFalse);
      expect(isSafeForStudents(story('Teacher killed in school incident')), isFalse);
      expect(isSafeForStudents(story('Teachers use AI to plan lessons')), isTrue);
      expect(isSafeForStudents(story('Fine headline', summary: 'It involves drugs.')), isFalse);
    });

    test('only trusted sources', () {
      expect(trustedSourceName('www.bbc.co.uk'), 'BBC News');
      expect(trustedSourceName('news.bbc.co.uk'), 'BBC News');
      expect(trustedSourceName('colchester.gov.uk'), 'GOV.UK');
      expect(trustedSourceName('random-blog.example'), isNull);
      expect(trustedSourceName('notbbc.co.uk'), isNull);
    });
  });

  group('Reading the feeds', () {
    test('GDELT: trusted sources only, entities decoded, bad rows skipped', () {
      final items = parseGdelt(gdeltFixture);
      expect(items.length, 6); // blog and ftp rows dropped
      final khan = items.firstWhere((i) => i.title.contains('Khanmigo'));
      expect(khan.title, "St Mary's Academy rolls out Khanmigo AI tutor to Year 9");
      expect(khan.source, 'Schools Week');
      expect(khan.published, DateTime.utc(2026, 10, 22, 12));
      expect(khan.school, "St Mary's Academy");
      expect(khan.aiTools, ['Khanmigo']);
      expect(items.any((i) => i.source == 'The Guardian'), isTrue);
    });

    test('GDELT: junk replies give an empty list, not a crash', () {
      expect(parseGdelt(''), isEmpty);
      expect(parseGdelt('Please limit requests to one every 5 seconds.'), isEmpty);
      expect(parseGdelt('{"articles":"nope"}'), isEmpty);
      expect(parseGdelt('{}'), isEmpty);
    });

    test('RSS: title, link, clean summary and date with time zone', () {
      final items = parseRss(rssFixture, 'Schools Week');
      expect(items.length, 2);
      final ark = items.first;
      expect(ark.title, 'Ark Academy & Microsoft trial Copilot in lessons');
      expect(ark.url, 'https://schoolsweek.co.uk/ark-copilot/');
      expect(ark.summary, 'Pupils at the Ark trust will use Microsoft Copilot – the AI assistant – in lessons.');
      expect(ark.published, DateTime.utc(2026, 10, 22, 8, 30));
      expect(ark.school, 'Ark Academy');
      expect(ark.aiTools, ['Copilot']);
      expect(items[1].published, DateTime.utc(2026, 10, 21, 10));
      expect(parseRss('not xml at all', 'x'), isEmpty);
    });

    test('dates', () {
      expect(parseGdeltDate('20261022T093000Z'), DateTime.utc(2026, 10, 22, 9, 30));
      expect(parseGdeltDate('nonsense'), isNull);
      expect(parseRssDate('Fri, 23 Oct 2026 14:00:00 -0500'), DateTime.utc(2026, 10, 23, 19));
      expect(parseRssDate(null), isNull);
    });
  });

  group('Ranking', () {
    final now = DateTime.utc(2026, 10, 23, 12);
    final all = [...parseGdelt(gdeltFixture), ...parseRss(rssFixture, 'Schools Week')];

    test('safe AI-in-schools stories only, one copy each', () {
      final r = rankStories(all, now: now);
      final titles = r.map((i) => i.title).toList();
      expect(titles.where((t) => t.startsWith('Colchester Royal Grammar School trials')).length, 1);
      expect(titles.any((t) => t.contains('deepfake')), isFalse);
      expect(titles.any((t) => t.contains('Colchester United')), isFalse);
      expect(titles.any((t) => t.contains('GCSE dates')), isFalse);
    });

    test('your school goes first, then school + AI stories, then the rest', () {
      final r = rankStories(all, mySchool: 'Colchester Royal Grammar School', now: now);
      expect(r.first.title, startsWith('Colchester Royal Grammar School'));
      expect(r.last.title, 'Why schools are banning ChatGPT in homework');
    });

    test('who got which AI board', () {
      final pairs = schoolAiPairs(rankStories(all, now: now));
      final names = pairs.map((p) => '${p.school} -> ${p.tool}').toSet();
      expect(names, containsAll(['Colchester Royal Grammar School -> ChatGPT', "St Mary's Academy -> Khanmigo", 'Ark Academy -> Copilot']));
      expect(pairs.length, names.length);
    });

    test('limit', () {
      final many = [for (var i = 0; i < 50; i++) story('Pupils at School Number$i use ChatGPT in class $i')];
      expect(rankStories(many, limit: 30).length, 30);
    });
  });

  group('Radio script', () {
    test('story reads school, AI, headline, source and age', () {
      final it = story("St Mary's Academy rolls out Khanmigo AI tutor", source: 'Schools Week', at: DateTime.utc(2026, 10, 22, 9));
      final s = storyScript(it, 0, 5, now: DateTime.utc(2026, 10, 23, 9));
      expect(s, "Story 1 of 5. St Mary's Academy, and Khanmigo. St Mary's Academy rolls out Khanmigo AI tutor. From Schools Week yesterday.");
    });

    test('no school: skips that line and does not read web addresses', () {
      final it = story('Why schools are banning ChatGPT.', source: 'The Guardian', summary: 'A short summary.');
      final s = storyScript(it, 2, 3, now: DateTime.utc(2026, 10, 23));
      expect(s, 'Story 3 of 3. Why schools are banning ChatGPT. From The Guardian. A short summary.');
      expect(s.contains('http'), isFalse);
    });

    test('intro counts stories', () {
      expect(introScript(1), contains('1 story'));
      expect(introScript(7), contains('7 stories'));
    });
  });
}

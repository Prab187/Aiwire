import 'dart:async';

import 'package:crgs_planner/radio/news_item.dart';
import 'package:crgs_planner/radio/news_sources.dart';
import 'package:crgs_planner/radio/speaker.dart';

/// A voice that records what it was asked to say. With [auto] it finishes straight
/// away; otherwise call [finish] to end the current line.
class FakeSpeaker implements Speaker {
  FakeSpeaker({this.auto = true});
  final bool auto;
  final spoken = <String>[];
  double rate = 1.0;
  int stops = 0;
  Completer<void>? _c;

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    if (auto) return Future.value();
    _c = Completer<void>();
    return _c!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = _c;
    _c = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  void finish() {
    final c = _c;
    _c = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> setRate(double multiplier) async => rate = multiplier;
}

class FakeRepo implements NewsRepository {
  FakeRepo(this.items, {this.mine = const [], this.fail = false});
  List<NewsItem> items;
  List<NewsItem> mine;
  bool fail;
  int fetches = 0;
  int mineFetches = 0;

  @override
  Future<List<NewsItem>> fetch({required String mySchool, required bool ukOnly}) async {
    fetches++;
    if (fail) throw const NewsUnavailable('offline');
    return items;
  }

  @override
  Future<List<NewsItem>> fetchMine({required String mySchool}) async {
    mineFetches++;
    return mine;
  }
}

List<NewsItem> sampleStories() => [
      NewsItem(
        title: "St Mary's Academy rolls out Khanmigo AI tutor to Year 9",
        url: 'https://schoolsweek.co.uk/st-marys-khanmigo/',
        source: 'Schools Week',
        published: DateTime.utc(2026, 10, 21, 12),
      ),
      NewsItem(
        title: 'Why schools are banning ChatGPT in homework',
        url: 'https://www.theguardian.com/education/chatgpt-homework',
        source: 'The Guardian',
        published: DateTime.utc(2026, 10, 20, 8),
      ),
      NewsItem(
        title: 'Oakfield High School is using Copilot to cut marking time',
        url: 'https://www.bbc.co.uk/news/oakfield-copilot',
        source: 'BBC News',
        published: DateTime.utc(2026, 10, 19, 8),
        summary: 'Teachers say AI marking saves hours each week.',
      ),
    ];

class NewsItemFactory {
  static NewsItem make(String title, String source) =>
      NewsItem(title: title, url: 'https://example.org/${title.hashCode}', source: source, published: DateTime.utc(2026, 10, 22));
}

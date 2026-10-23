import 'dart:convert';

import 'package:crgs_planner/models.dart';
import 'package:crgs_planner/radio/radio_controller.dart';
import 'package:crgs_planner/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

AppStore newStore() => AppStore(AppData.example(DateTime(2026, 10, 21)));
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('play loads stories, reads the intro, every story, then signs off', () async {
    final speaker = FakeSpeaker();
    final repo = FakeRepo(sampleStories());
    final r = RadioController(repo: repo, speaker: speaker, store: newStore(), clock: () => DateTime.utc(2026, 10, 22, 12));
    await r.play();
    expect(repo.fetches, 1);
    expect(speaker.spoken.length, 5); // intro + 3 stories + outro
    expect(speaker.spoken.first, contains("You're tuned in to CRGS Connect Radio. 3 stories"));
    expect(speaker.spoken[1], startsWith('Story 1 of 3.'));
    expect(speaker.spoken[1], contains("St Mary's Academy, and Khanmigo."));
    expect(speaker.spoken[3], contains('Oakfield High School, and Copilot.'));
    expect(speaker.spoken[3], contains('Teachers say AI marking saves hours each week.'));
    expect(speaker.spoken.last, contains("That's the latest"));
    expect(r.state, RadioState.idle);
    expect(r.index, 0);
    r.dispose();
  });

  test('pause stops the voice and resume carries on from the same story without the intro', () async {
    final speaker = FakeSpeaker(auto: false);
    final r = RadioController(repo: FakeRepo(sampleStories()), speaker: speaker, store: newStore());
    final playing = r.play();
    await settle();
    await settle();
    expect(r.state, RadioState.playing);
    expect(speaker.spoken.length, 1); // intro
    speaker.finish();
    await settle();
    await settle();
    expect(speaker.spoken.length, 2);
    expect(speaker.spoken.last, startsWith('Story 1 of 3.'));
    await r.pause();
    await playing;
    expect(r.state, RadioState.paused);
    final before = speaker.spoken.length;
    unawaitedPlay(r);
    await settle();
    await settle();
    expect(r.state, RadioState.playing);
    expect(speaker.spoken.length, before + 1);
    expect(speaker.spoken.last, startsWith('Story 1 of 3.')); // same story again, no intro
    await r.stop();
    r.dispose();
  });

  test('next, previous and picking a story', () async {
    final speaker = FakeSpeaker();
    final r = RadioController(repo: FakeRepo(sampleStories()), speaker: speaker, store: newStore());
    await r.load();
    expect(r.index, 0);
    await r.next();
    expect(r.index, 1);
    await r.next();
    await r.next();
    expect(r.index, 2); // stops at the last story
    await r.previous();
    expect(r.index, 1);
    expect(speaker.spoken, isEmpty); // skipping while stopped does not speak
    await r.playAt(2);
    expect(speaker.spoken.first, startsWith('Story 3 of 3.')); // straight to the story, no intro
    r.dispose();
  });

  test('no connection and nothing saved shows a friendly error and can retry', () async {
    final repo = FakeRepo([], fail: true);
    final r = RadioController(repo: repo, speaker: FakeSpeaker(), store: newStore());
    await r.load();
    expect(r.state, RadioState.error);
    expect(r.message, contains("Couldn't load stories"));
    repo.fail = false;
    repo.items = sampleStories();
    await r.load(force: true);
    expect(r.state, RadioState.idle);
    expect(r.items.length, 3);
    expect(r.message, isNull);
    r.dispose();
  });

  test('no connection but saved stories: plays the saved ones', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final good = RadioController(repo: FakeRepo(sampleStories()), speaker: FakeSpeaker(), store: newStore(), prefs: prefs);
    await good.load();
    expect(prefs.getString('radio_cache_v1'), isNotNull);
    good.dispose();

    final offline = RadioController(repo: FakeRepo([], fail: true), speaker: FakeSpeaker(), store: newStore(), prefs: prefs);
    await offline.load();
    expect(offline.items.length, 3);
    expect(offline.fromCache, isTrue);
    expect(offline.state, RadioState.idle);
    expect(offline.message, contains('saved stories'));
    offline.dispose();
  });

  test('stories about your school are merged in after the main load', () async {
    final extra = [
      NewsItemFactory.make('Colchester Royal Grammar School pilots Gemini for revision', 'BBC News'),
    ];
    final repo = FakeRepo(sampleStories(), mine: extra);
    final r = RadioController(repo: repo, speaker: FakeSpeaker(), store: newStore());
    await r.load();
    await settle();
    await settle();
    expect(repo.mineFetches, 1);
    expect(r.items.first.title, startsWith('Colchester Royal Grammar School'));
    r.dispose();
  });

  test('speed and settings are saved', () async {
    final store = newStore();
    final speaker = FakeSpeaker();
    final repo = FakeRepo(sampleStories());
    final r = RadioController(repo: repo, speaker: speaker, store: store);
    await r.load();
    await r.setRate(1.2);
    expect(store.data.radioRate, 1.2);
    expect(speaker.rate, 1.2);
    await r.setScope('world');
    expect(store.data.radioScope, 'world');
    expect(repo.fetches, 2);
    await r.setScope('world');
    expect(repo.fetches, 2); // no change, no refetch
    await r.setSchool('  Oakfield High School ');
    expect(store.data.radioSchool, 'Oakfield High School');
    expect(repo.fetches, 3);
    final back = AppData.fromJson(jsonDecode(jsonEncode(store.data.toJson())) as Map<String, dynamic>);
    expect(back.radioSchool, 'Oakfield High School');
    expect(back.radioScope, 'world');
    expect(back.radioRate, 1.2);
    r.dispose();
  });

  test('older saved data without radio settings still loads', () {
    final d = AppData.fromJson({'name': 'A'});
    expect(d.radioSchool, 'Colchester Royal Grammar School');
    expect(d.radioScope, 'uk');
    expect(d.radioRate, 1.0);
  });
}

void unawaitedPlay(RadioController r) {
  r.play();
}

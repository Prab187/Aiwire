import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store.dart';
import 'ai_schools.dart';
import 'news_item.dart';
import 'news_sources.dart';
import 'radio_script.dart';
import 'speaker.dart';

enum RadioState { idle, loading, playing, paused, error }

/// The radio: gets the stories, reads them out one after another, and lets the
/// listener pause, skip and change speed.
class RadioController extends ChangeNotifier {
  RadioController({required this.repo, required this.speaker, required this.store, this.prefs, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final NewsRepository repo;
  final Speaker speaker;
  final AppStore store;
  final SharedPreferences? prefs;
  final DateTime Function() _clock;

  static const _cacheKey = 'radio_cache_v1';

  List<NewsItem> items = const [];
  int index = 0;
  RadioState state = RadioState.idle;
  String? message;
  DateTime? updated;
  bool fromCache = false;
  bool _loadedOnce = false;

  int _gen = 0; // changes whenever playback is stopped or restarted
  bool _introDone = false;
  bool _disposed = false;

  String get mySchool => store.data.radioSchool;
  bool get ukOnly => store.data.radioScope == 'uk';
  double get rate => store.data.radioRate;
  bool get playing => state == RadioState.playing;
  NewsItem? get current => items.isEmpty ? null : items[index.clamp(0, items.length - 1)];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _loadCache() {
    if (items.isNotEmpty || prefs == null) return;
    try {
      final raw = prefs!.getString(_cacheKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      items = (j['items'] as List).map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      updated = DateTime.tryParse(j['at'] as String? ?? '');
      fromCache = items.isNotEmpty;
    } catch (_) {
      items = const [];
    }
  }

  void _saveCache() {
    prefs?.setString(_cacheKey, jsonEncode({'at': _clock().toUtc().toIso8601String(), 'items': items.map((i) => i.toJson()).toList()}));
  }

  /// Gets stories. The first call shows saved stories straight away, then fresh ones.
  Future<void> load({bool force = false}) async {
    if (state == RadioState.loading) return;
    if (_loadedOnce && !force) return;
    _loadedOnce = true;
    if (playing) await stop();
    _loadCache();
    state = RadioState.loading;
    message = null;
    _notify();
    try {
      final fresh = await repo.fetch(mySchool: mySchool, ukOnly: ukOnly);
      if (_disposed) return;
      items = fresh;
      index = 0;
      _introDone = false;
      fromCache = false;
      updated = _clock();
      state = RadioState.idle;
      message = fresh.isEmpty ? 'No new AI in schools stories right now. Check back soon.' : null;
      _saveCache();
      _notify();
      unawaited(_mergeMine());
    } catch (_) {
      if (_disposed) return;
      state = items.isEmpty ? RadioState.error : RadioState.idle;
      message = items.isEmpty ? "Couldn't load stories. Check your connection and try again." : "Couldn't refresh, so these are saved stories.";
      _notify();
    }
  }

  Future<void> _mergeMine() async {
    if (mySchool.trim().isEmpty) return;
    try {
      final mine = await repo.fetchMine(mySchool: mySchool);
      if (_disposed || mine.isEmpty || state != RadioState.idle) return;
      items = rankStories([...items, ...mine], mySchool: mySchool);
      index = 0;
      _introDone = false;
      _saveCache();
      _notify();
    } catch (_) {
      // The main stories are already showing.
    }
  }

  Future<void> play() async {
    if (!_loadedOnce) await load();
    if (items.isEmpty) return;
    await speaker.setRate(rate);
    final gen = ++_gen;
    state = RadioState.playing;
    _notify();
    await _run(gen);
  }

  Future<void> _run(int gen) async {
    if (!_introDone && index == 0) {
      _introDone = true;
      await speaker.speak(introScript(items.length));
      if (gen != _gen) return;
    }
    while (gen == _gen && index < items.length) {
      await speaker.speak(storyScript(items[index], index, items.length, now: _clock()));
      if (gen != _gen) return;
      if (index >= items.length - 1) break;
      index++;
      _notify();
    }
    if (gen != _gen) return;
    await speaker.speak(outroScript);
    if (gen != _gen) return;
    state = RadioState.idle;
    index = 0;
    _introDone = false;
    _notify();
  }

  Future<void> pause() async {
    _gen++;
    await speaker.stop();
    if (state == RadioState.playing) state = RadioState.paused;
    _notify();
  }

  Future<void> stop() async {
    _gen++;
    await speaker.stop();
    state = RadioState.idle;
    _notify();
  }

  Future<void> toggle() => playing ? pause() : play();

  Future<void> _jumpTo(int i) async {
    if (items.isEmpty) return;
    final was = playing;
    _gen++;
    await speaker.stop();
    index = i.clamp(0, items.length - 1);
    _introDone = true;
    state = was ? RadioState.paused : state;
    _notify();
    if (was) await play();
  }

  Future<void> next() => _jumpTo(index + 1);
  Future<void> previous() => _jumpTo(index - 1);

  /// Starts playing from story [i].
  Future<void> playAt(int i) async {
    if (items.isEmpty) return;
    _gen++;
    await speaker.stop();
    index = i.clamp(0, items.length - 1);
    _introDone = true;
    state = RadioState.paused;
    await play();
  }

  Future<void> setRate(double r) async {
    store.update((d) => d.radioRate = r, clearsExample: false);
    await speaker.setRate(r);
    if (playing) await _jumpTo(index);
  }

  Future<void> setSchool(String school) async {
    store.update((d) => d.radioSchool = school.trim(), clearsExample: false);
    await load(force: true);
  }

  Future<void> setScope(String scope) async {
    if (store.data.radioScope == scope) return;
    store.update((d) => d.radioScope = scope, clearsExample: false);
    await load(force: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _gen++;
    speaker.stop();
    super.dispose();
  }
}

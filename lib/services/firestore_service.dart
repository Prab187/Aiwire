import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/article.dart';
import '../models/job.dart';
import '../models/event.dart';
import 'news_service.dart';
import 'job_service.dart';
import 'events_service.dart';

/// Central Firestore cache layer.
/// - Reads from Firestore first (fast, shared across all users)
/// - Falls back to direct API fetch if Firestore is empty
/// - Refreshes Firestore in background when cache is stale
class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // Cache TTLs
  static const _newsTtl    = Duration(minutes: 30);
  static const _jobsTtl    = Duration(hours: 2);
  static const _eventsTtl  = Duration(hours: 12);

  // ── Meta helpers ────────────────────────────────────────────────────────

  static Future<DateTime?> _lastUpdated(String collection) async {
    try {
      final doc = await _db.collection('_meta').doc(collection).get();
      if (!doc.exists) return null;
      final ts = doc.data()?['updatedAt'];
      if (ts is Timestamp) return ts.toDate();
    } catch (_) {}
    return null;
  }

  static Future<void> _setUpdated(String collection) async {
    await _db.collection('_meta').doc(collection).set({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static bool _isStale(DateTime? last, Duration ttl) {
    if (last == null) return true;
    return DateTime.now().difference(last) > ttl;
  }

  // ── News ────────────────────────────────────────────────────────────────

  static Future<List<Article>> fetchArticles() async {
    try {
      final snap = await _db.collection('articles')
          .orderBy('score', descending: true)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 6));

      if (snap.docs.isNotEmpty) {
        // Return cached data immediately
        final articles = snap.docs.map((d) => Article.fromJson(d.data())).toList();
        // Refresh in background if stale
        _refreshNewsIfStale();
        return articles;
      }
    } catch (_) {}

    // Firestore empty or error — fetch directly and cache
    return _fetchAndCacheNews();
  }

  static Future<void> _refreshNewsIfStale() async {
    final last = await _lastUpdated('articles');
    if (_isStale(last, _newsTtl)) await _fetchAndCacheNews();
  }

  static Future<List<Article>> _fetchAndCacheNews() async {
    final articles = await NewsService.fetchAINews();
    // Cache in background — don't block returning results
    if (articles.isNotEmpty) {
      _cacheArticles(articles).catchError((_) {});
    }
    return articles;
  }

  static Future<void> _cacheArticles(List<Article> articles) async {
    final batch = _db.batch();
    final old = await _db.collection('articles').limit(100).get()
        .timeout(const Duration(seconds: 6));
    for (final doc in old.docs) { batch.delete(doc.reference); }
    for (int i = 0; i < articles.length; i++) {
      final a = articles[i];
      final ref = _db.collection('articles').doc(
        Uri.encodeComponent(a.url).substring(0, 20).replaceAll('%', '_') + '_$i',
      );
      batch.set(ref, {
        ...a.toJson(),
        'score': articles.length - i,
        'cachedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _setUpdated('articles');
  }

  // ── Jobs ────────────────────────────────────────────────────────────────

  static Future<List<Job>> fetchJobs({
    String? query, String? type, String? level,
    String countryCode = '', String city = '', String country = '',
  }) async {
    // For searches, always go direct (Firestore only caches default feed)
    if (query != null && query.isNotEmpty) {
      return JobService.fetchJobs(
        query: query, type: type, level: level,
        countryCode: countryCode, city: city, country: country,
      );
    }

    try {
      var q = _db.collection('jobs').orderBy('featured', descending: true).limit(50);
      final snap = await q.get().timeout(const Duration(seconds: 6));

      if (snap.docs.isNotEmpty) {
        var jobs = snap.docs.map((d) => Job.fromJson(d.data())).toList();
        if (type != null && type != 'All') jobs = jobs.where((j) => j.type == type).toList();
        if (level != null && level != 'All') jobs = jobs.where((j) => j.level == level).toList();
        _refreshJobsIfStale();
        return jobs;
      }
    } catch (_) {}

    return _fetchAndCacheJobs();
  }

  static Future<void> _refreshJobsIfStale() async {
    final last = await _lastUpdated('jobs');
    if (_isStale(last, _jobsTtl)) await _fetchAndCacheJobs();
  }

  static Future<List<Job>> _fetchAndCacheJobs() async {
    final jobs = await JobService.fetchJobs();
    if (jobs.isNotEmpty) {
      _cacheJobs(jobs).catchError((_) {});
    }
    return jobs;
  }

  static Future<void> _cacheJobs(List<Job> jobs) async {
    final batch = _db.batch();
    final old = await _db.collection('jobs').limit(100).get()
        .timeout(const Duration(seconds: 6));
    for (final doc in old.docs) { batch.delete(doc.reference); }
    for (int i = 0; i < jobs.length; i++) {
      final j = jobs[i];
      final ref = _db.collection('jobs').doc('job_$i');
      batch.set(ref, {
        ...j.toJson(),
        'cachedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _setUpdated('jobs');
  }

  // ── Events ──────────────────────────────────────────────────────────────

  static Future<List<AIEvent>> fetchEvents({String? type, String? format}) async {
    try {
      final snap = await _db.collection('events')
          .orderBy('date')
          .limit(60)
          .get()
          .timeout(const Duration(seconds: 6));

      if (snap.docs.isNotEmpty) {
        var events = snap.docs.map((d) => AIEvent.fromJson(d.data())).toList();
        events = events.where((e) => e.isUpcoming).toList();
        if (type != null && type != 'All') events = events.where((e) => e.type == type).toList();
        if (format != null && format != 'All') events = events.where((e) => e.format == format).toList();
        _refreshEventsIfStale();
        return events;
      }
    } catch (_) {}

    return _fetchAndCacheEvents(type: type, format: format);
  }

  static Future<void> _refreshEventsIfStale() async {
    final last = await _lastUpdated('events');
    if (_isStale(last, _eventsTtl)) await _fetchAndCacheEvents();
  }

  static Future<List<AIEvent>> _fetchAndCacheEvents({String? type, String? format}) async {
    final events = await EventsService.fetchEvents(type: type, format: format);
    if (events.isNotEmpty) {
      _cacheEvents(events).catchError((_) {});
    }
    return events;
  }

  static Future<void> _cacheEvents(List<AIEvent> events) async {
    final batch = _db.batch();
    final old = await _db.collection('events').limit(100).get()
        .timeout(const Duration(seconds: 6));
    for (final doc in old.docs) { batch.delete(doc.reference); }
    for (int i = 0; i < events.length; i++) {
      final e = events[i];
      final ref = _db.collection('events').doc('event_$i');
      batch.set(ref, {
        ...e.toJson(),
        'cachedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _setUpdated('events');
  }

  // ── Called on app start — refreshes stale collections in background ─────

  static Future<void> refreshIfStale() async {
    await Future.wait([
      _refreshNewsIfStale().catchError((_) {}),
      _refreshJobsIfStale().catchError((_) {}),
      _refreshEventsIfStale().catchError((_) {}),
    ]);
  }
}

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/resume_profile.dart';
import 'claude_cache.dart';
import 'cors_proxy.dart';
import 'claude_error.dart';
import 'claude_http.dart';

class YouTubeVideo {
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final String? duration;
  final String? viewCount;
  final int rawViewCount;
  final String? description;

  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    this.duration,
    this.viewCount,
    this.rawViewCount = 0,
    this.description,
  });

  String get watchUrl => 'https://www.youtube.com/watch?v=$id';
}

class YouTubeService {
  // Broad trending AI queries to get popular results
  static const _queries = [
    'AI news',
    'artificial intelligence',
    'ChatGPT',
    'OpenAI',
    'machine learning',
    'AI update',
  ];

  /// Minimum views to be considered "trending"
  static const _minViews = 10000;

  static Future<List<YouTubeVideo>> fetchTrendingAI({int maxResults = 5}) async {
    // 1. Try official YouTube Data API first (fast, reliable, no bot detection)
    try {
      final apiResults = await _fetchViaYouTubeDataApi(_queries, maxResults)
          .timeout(const Duration(seconds: 10));
      if (apiResults.isNotEmpty) {
        debugPrint('AIWire YouTube: Data API returned ${apiResults.length} videos');
        return apiResults;
      }
    } catch (e) {
      debugPrint('AIWire YouTube Data API: $e');
    }

    // 2. Fall back to scraping via youtube_explode_dart
    try {
      final scraped = await _fetchTrendingAIInternal(maxResults: maxResults)
          .timeout(const Duration(seconds: 15));
      if (scraped.isNotEmpty) return scraped;
    } catch (e) {
      debugPrint('AIWire YouTube scraper: $e');
    }

    // 3. Last resort: curated fallback
    debugPrint('AIWire YouTube: all sources failed, using curated fallback');
    return _curatedFallbackVideos.take(maxResults).toList();
  }

  /// Query YouTube Data API v3 — the OFFICIAL, reliable way to search YouTube.
  /// Free tier: 10,000 units/day. Each search = 100 units, so ~100 searches/day.
  /// Needs YOUTUBE_API_KEY in .env.
  static Future<List<YouTubeVideo>> _fetchViaYouTubeDataApi(
      List<String> queries, int maxResults) async {
    const apiKey = String.fromEnvironment('YOUTUBE_API_KEY');
    if (apiKey.isEmpty) return [];

    final candidates = <YouTubeVideo>[];
    final seen = <String>{};

    // Use first 2 queries only — saves quota
    final queriesToUse = queries.take(2).toList();

    for (final query in queriesToUse) {
      try {
        // Search: returns video IDs, published dates, basic metadata
        // Cost: 100 units per call. 15-day window ordered by viewCount.
        final searchUrl = corsUri(
          'https://www.googleapis.com/youtube/v3/search'
          '?part=snippet'
          '&q=${Uri.encodeComponent(query)}'
          '&type=video'
          '&order=viewCount'
          '&publishedAfter=${_daysAgoIso(15)}'
          '&maxResults=15'
          '&relevanceLanguage=en'
          '&key=$apiKey',
        );
        final searchResp = await http.get(searchUrl)
            .timeout(const Duration(seconds: 8));
        if (searchResp.statusCode != 200) continue;
        final searchData = json.decode(searchResp.body);
        final items = (searchData['items'] as List?) ?? [];
        if (items.isEmpty) continue;

        // Collect video IDs to fetch stats in one batch
        final videoIds = <String>[];
        final meta = <String, Map<String, dynamic>>{};
        for (final item in items) {
          final id = item['id']?['videoId'] as String?;
          if (id == null || seen.contains(id)) continue;
          seen.add(id);
          videoIds.add(id);
          meta[id] = item['snippet'] as Map<String, dynamic>? ?? {};
        }
        if (videoIds.isEmpty) continue;

        // Fetch statistics + duration in one batched call (cost: 1 unit)
        final detailsUrl = corsUri(
          'https://www.googleapis.com/youtube/v3/videos'
          '?part=statistics,contentDetails'
          '&id=${videoIds.join(",")}'
          '&key=$apiKey',
        );
        final detailsResp = await http.get(detailsUrl)
            .timeout(const Duration(seconds: 8));
        if (detailsResp.statusCode != 200) continue;
        final detailsData = json.decode(detailsResp.body);
        final detailItems = (detailsData['items'] as List?) ?? [];

        for (final d in detailItems) {
          final id = d['id'] as String?;
          if (id == null) continue;
          final stats = d['statistics'] as Map<String, dynamic>? ?? {};
          final views = int.tryParse(stats['viewCount']?.toString() ?? '0') ?? 0;
          if (views < _minViews) continue;
          final content = d['contentDetails'] as Map<String, dynamic>? ?? {};
          final snippet = meta[id] ?? {};
          final thumbs = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
          final thumb = (thumbs['high']?['url'] ?? thumbs['medium']?['url']
              ?? thumbs['default']?['url']) as String? ?? '';

          candidates.add(YouTubeVideo(
            id: id,
            title: (snippet['title'] as String? ?? '').trim(),
            channelName: (snippet['channelTitle'] as String? ?? '').trim(),
            thumbnailUrl: thumb,
            duration: _parseIsoDuration(content['duration'] as String? ?? ''),
            viewCount: _formatViews(views),
            rawViewCount: views,
            description: snippet['description'] as String?,
          ));
        }
      } catch (e) {
        debugPrint('AIWire YouTube API query "$query": $e');
      }
      if (candidates.length >= maxResults * 2) break;
    }

    candidates.sort((a, b) => b.rawViewCount.compareTo(a.rawViewCount));
    return candidates.take(maxResults).toList();
  }

  static String _daysAgoIso(int days) =>
      DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();

  /// Convert ISO 8601 duration (PT15M33S) to display format (15:33)
  static String? _parseIsoDuration(String iso) {
    if (iso.isEmpty) return null;
    final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (match == null) return null;
    final h = int.tryParse(match.group(1) ?? '0') ?? 0;
    final m = int.tryParse(match.group(2) ?? '0') ?? 0;
    final s = int.tryParse(match.group(3) ?? '0') ?? 0;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static Future<List<YouTubeVideo>> _fetchTrendingAIInternal({int maxResults = 5}) async {
    final yt = YoutubeExplode();
    try {
      // Try last week first, then fall back to last month
      var candidates = await _searchWithFilter(yt, UploadDateFilter.lastWeek);

      if (candidates.isEmpty) {
        debugPrint('AIWire: No videos from last week, trying last month');
        candidates = await _searchWithFilter(yt, UploadDateFilter.lastMonth);
      }

      // Sort by highest views first
      candidates.sort((a, b) => b.rawViewCount.compareTo(a.rawViewCount));

      final results = candidates.take(maxResults).toList();

      // If live search returned nothing, use curated evergreen videos
      if (results.isEmpty) {
        debugPrint('AIWire: Using curated fallback videos');
        return _curatedFallbackVideos.take(maxResults).toList();
      }

      return results;
    } finally {
      yt.close();
    }
  }

  /// Searches YouTube with the given upload date filter and returns candidates.
  static Future<List<YouTubeVideo>> _searchWithFilter(
    YoutubeExplode yt, SearchFilter filter,
  ) async {
    final candidates = <YouTubeVideo>[];
    final seen = <String>{};

    for (final query in _queries) {
      try {
        final results = await yt.search.search(query, filter: filter);

        for (final v in results.take(10)) {
          if (seen.contains(v.id.value)) continue;
          seen.add(v.id.value);

          final views = v.engagement.viewCount;
          if (views < _minViews) continue;
          if (v.isLive) continue;

          final thumbUrl = v.thumbnails.highResUrl.isNotEmpty
              ? v.thumbnails.highResUrl
              : v.thumbnails.standardResUrl;

          String? duration;
          if (v.duration != null) {
            final d = v.duration!;
            if (d.inHours > 0) {
              duration = '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
            } else {
              duration = '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
            }
          }

          candidates.add(YouTubeVideo(
            id: v.id.value,
            title: v.title,
            channelName: v.author,
            thumbnailUrl: thumbUrl,
            duration: duration,
            viewCount: _formatViews(views),
            rawViewCount: views,
            description: v.description,
          ));
        }
      } catch (e) { debugPrint("AIWire: $e"); }
    }

    return candidates;
  }

  /// Curated evergreen AI videos — shown when live YouTube search fails.
  /// These are popular, high-quality videos that stay relevant.
  static const _curatedFallbackVideos = [
    YouTubeVideo(
      id: 'aircAruvnKk',
      title: 'But what is a neural network? | Deep learning, chapter 1',
      channelName: '3Blue1Brown',
      thumbnailUrl: 'https://i.ytimg.com/vi/aircAruvnKk/hqdefault.jpg',
      duration: '19:13',
      viewCount: '17M views',
      rawViewCount: 17000000,
    ),
    YouTubeVideo(
      id: 'zjkBMFhNj_g',
      title: 'How AI Could Empower Any Business | Andrew Ng | TED',
      channelName: 'TED',
      thumbnailUrl: 'https://i.ytimg.com/vi/zjkBMFhNj_g/hqdefault.jpg',
      duration: '11:48',
      viewCount: '3.3M views',
      rawViewCount: 3300000,
    ),
    YouTubeVideo(
      id: 'jGwO_UgTS7I',
      title: 'ChatGPT Explained Completely',
      channelName: 'Fireship',
      thumbnailUrl: 'https://i.ytimg.com/vi/jGwO_UgTS7I/hqdefault.jpg',
      duration: '5:31',
      viewCount: '5.2M views',
      rawViewCount: 5200000,
    ),
    YouTubeVideo(
      id: 'KYS1PaKBR44',
      title: 'What Is an AI Anyway? | Mustafa Suleyman | TED',
      channelName: 'TED',
      thumbnailUrl: 'https://i.ytimg.com/vi/KYS1PaKBR44/hqdefault.jpg',
      duration: '15:24',
      viewCount: '2.1M views',
      rawViewCount: 2100000,
    ),
    YouTubeVideo(
      id: 'WXuK6gekU1Y',
      title: 'How Large Language Models Work',
      channelName: '3Blue1Brown',
      thumbnailUrl: 'https://i.ytimg.com/vi/WXuK6gekU1Y/hqdefault.jpg',
      duration: '21:38',
      viewCount: '8.5M views',
      rawViewCount: 8500000,
    ),
  ];

  /// Fetches YouTube videos personalized to a user's profile.
  /// Builds queries from their top skills + job title, filters for
  /// high-view videos, and returns the best matches sorted by views.
  /// Metadata only — NO Claude calls at all, fast + free.
  static Future<List<YouTubeVideo>> fetchForProfile({
    required List<String> skills,
    required String jobTitle,
    String? country,
    int maxResults = 5,
  }) async {
    // Build personalized queries
    final queries = <String>[];
    if (jobTitle.isNotEmpty) queries.add('$jobTitle tutorial');
    for (final s in skills.take(2)) {
      if (s.isNotEmpty) queries.add('$s tutorial 2026');
    }
    if (queries.isEmpty) queries.addAll(['machine learning tutorial', 'AI tutorial']);

    // 1. Try official YouTube Data API
    try {
      final apiResults = await _fetchViaYouTubeDataApi(queries, maxResults)
          .timeout(const Duration(seconds: 10));
      if (apiResults.isNotEmpty) return apiResults;
    } catch (e) {
      debugPrint('AIWire YouTube Data API (profile): $e');
    }

    // 2. Fall back to scraper
    try {
      return await _fetchForProfileInternal(
        skills: skills, jobTitle: jobTitle, country: country, maxResults: maxResults,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('AIWire YouTube scraper (profile): $e');
    }

    // 3. Curated fallback
    return _curatedFallbackVideos.take(maxResults).toList();
  }

  static Future<List<YouTubeVideo>> _fetchForProfileInternal({
    required List<String> skills,
    required String jobTitle,
    String? country,
    int maxResults = 5,
  }) async {
    final yt = YoutubeExplode();
    try {
      // Build queries. Job title is best, then top 2 skills as "skill tutorial"
      // When country is known, bias 2 queries with country name
      final queries = <String>[];
      final hasCountry = country != null && country.isNotEmpty;
      if (jobTitle.isNotEmpty) {
        queries.add('$jobTitle tutorial');
        if (hasCountry) {
          queries.add('$jobTitle $country');
        } else {
          queries.add('$jobTitle explained');
        }
      }
      for (final s in skills.take(2)) {
        if (s.isNotEmpty) queries.add('$s tutorial');
      }
      if (queries.isEmpty) {
        queries.addAll(['AI tutorial', 'machine learning tutorial']);
      }

      final candidates = <YouTubeVideo>[];
      final seen = <String>{};

      for (final query in queries) {
        try {
          // Filter to videos uploaded in the last month
          final results = await yt.search.search(query,
            filter: UploadDateFilter.lastMonth);
          for (final v in results.take(8)) {
            if (seen.contains(v.id.value)) continue;
            seen.add(v.id.value);

            final views = v.engagement.viewCount;
            // Lower view threshold for personalized (more niche content)
            if (views < 5000) continue;
            if (v.isLive) continue;

            final thumbUrl = v.thumbnails.highResUrl.isNotEmpty
                ? v.thumbnails.highResUrl
                : v.thumbnails.standardResUrl;

            String? duration;
            if (v.duration != null) {
              final d = v.duration!;
              if (d.inHours > 0) {
                duration = '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
              } else {
                duration = '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
              }
            }

            candidates.add(YouTubeVideo(
              id: v.id.value,
              title: v.title,
              channelName: v.author,
              thumbnailUrl: thumbUrl,
              duration: duration,
              viewCount: _formatViews(views),
              rawViewCount: views,
              description: v.description,
            ));
          }
        } catch (e) { debugPrint("AIWire: $e"); }
        if (candidates.length >= maxResults * 2) break;
      }

      candidates.sort((a, b) => b.rawViewCount.compareTo(a.rawViewCount));
      return candidates.take(maxResults).toList();
    } finally {
      yt.close();
    }
  }

  static String _formatViews(int? views) {
    if (views == null || views == 0) return '';
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M views';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(0)}K views';
    return '$views views';
  }

  /// Fetch closed captions transcript from YouTube video.
  /// Tries English first, then auto-generated, then any available track.
  static Future<String> _fetchTranscript(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isEmpty) return '';

      // Prefer English, then auto-generated English, then first available
      ClosedCaptionTrackInfo? track;
      track = manifest.tracks.cast<ClosedCaptionTrackInfo?>().firstWhere(
        (t) => t!.language.code.startsWith('en') && !t.isAutoGenerated,
        orElse: () => null,
      );
      track ??= manifest.tracks.cast<ClosedCaptionTrackInfo?>().firstWhere(
        (t) => t!.language.code.startsWith('en'),
        orElse: () => null,
      );
      track ??= manifest.tracks.first;

      final captionTrack = await yt.videos.closedCaptions.get(track);
      final text = captionTrack.captions.map((c) => c.text).join(' ');
      return text;
    } catch (_) {
      return '';
    } finally {
      yt.close();
    }
  }

  /// Summarizes a YouTube video by fetching captions and asking Claude.
  /// Summarize a YouTube video.
  ///
  /// Personalization is OPT-IN — by default this returns a GENERIC summary
  /// that's the same for every user (suitable for the main "Trending in AI"
  /// screen). Personalization must be explicitly requested by passing
  /// `personalizeFor` with the profile to tailor for.
  ///
  /// Results are cached by video ID (+ profile hash when personalized) for
  /// 7 days — a popular video's summary doesn't change.
  static Future<String> summarizeVideo(
    YouTubeVideo video, {
    /// If non-null, tailors the last bullet to this profile. If null
    /// (the default), returns a GENERIC summary for all users.
    ResumeProfile? personalizeFor,
  }) async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');

    // Build an explicit context object — ONLY when the caller asks for it.
    final bool isPersonalized = personalizeFor != null
        && personalizeFor.skills.isNotEmpty
        && personalizeFor.jobTitle.isNotEmpty;

    // Cache key distinguishes generic vs personalized summaries.
    // Generic key = video ID alone → shared across users.
    // Personalized key = video ID + profile hash → unique per user.
    final cacheKey = isPersonalized
        ? ClaudeCache.keyFrom([
            video.id,
            'p', // "personalized" marker
            personalizeFor.jobTitle,
            personalizeFor.experienceLevel,
            personalizeFor.country,
            personalizeFor.skills.take(3).join('_'),
          ])
        : ClaudeCache.keyFrom([video.id, 'generic']);

    final cached = await ClaudeCache.get('yt_sum', cacheKey,
        ttl: const Duration(days: 7));
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    // Try to get transcript first, fall back to description
    String transcript = '';
    try {
      transcript = await _fetchTranscript(video.id);
    } catch (e) { debugPrint("AIWire: $e"); }

    String context;
    if (transcript.length > 100) {
      final trimmed = _sampleTranscript(transcript, 8000);
      context = 'Title: ${video.title}\nChannel: ${video.channelName}\nDuration: ${video.duration ?? "unknown"}\n\nTranscript:\n$trimmed';
    } else {
      final desc = video.description?.trim() ?? '';
      context = desc.isNotEmpty
          ? 'Title: ${video.title}\nDuration: ${video.duration ?? "unknown"}\n\nDescription: ${desc.length > 800 ? desc.substring(0, 800) : desc}'
          : 'Title: ${video.title}\nChannel: ${video.channelName}\nDuration: ${video.duration ?? "unknown"}';
    }

    final personalLine = isPersonalized
        ? '''
VIEWER PROFILE (tailor the final bullet to this SPECIFIC person, not a generic reader):
- Name: ${personalizeFor.name ?? 'User'}
- Role: ${personalizeFor.jobTitle}
- Level: ${personalizeFor.experienceLevel}
- Country: ${personalizeFor.country}
- Skills: ${personalizeFor.skills.take(4).join(", ")}
'''
        : '';

    final lastBullet = isPersonalized
        ? 'For ${personalizeFor.name ?? "you"} as a ${personalizeFor.jobTitle} in ${personalizeFor.country}: what to do AFTER watching — a concrete next action (tool to try, repo to clone, paper to read) that directly ties to their skills: ${personalizeFor.skills.take(3).join(", ")}'
        : 'Who should watch this video, and ONE concrete next step a typical AI/ML viewer could take';

    final prompt = '''Summarize this YouTube video. Return a structured summary with 5 parts — each on its own line, each one short.

$personalLine

FORMAT (exactly these 5 labelled lines — do NOT use markdown):

LEVEL: [Beginner | Intermediate | Advanced] · [time commitment — use the duration]
PREREQ: [What the viewer should already know, e.g. "Basic Python + neural nets" or "None — pure concept"]
• [Core topic in one sentence — what the video teaches]
• [Most important insight or technical takeaway most viewers will miss]
• [ONE specific tool, framework, dataset, or number the speaker mentions]
• [$lastBullet]

Rules:
- LEVEL line is required. Guess if unsure — "Beginner" = no code + concept, "Intermediate" = some ML background assumed, "Advanced" = research-level.
- PREREQ line is required — be specific (not "some ML knowledge" but "know what a transformer is").
- Bullets must be concrete: name tools, numbers, companies. No vague "various techniques".
- No preamble, no closing remark.
${isPersonalized ? '- The last bullet MUST reference ${personalizeFor.name ?? "the viewer"} by name (or "you") and ONE of their specific skills.' : '- The last bullet is generic — applicable to ALL viewers interested in AI/ML.'}

$context''';

    final response = await ClaudeHttp.post(
      apiKey: apiKey,
      timeout: const Duration(seconds: 45),
      body: {
        'model': 'claude-haiku-4-5',
        'max_tokens': 320,
        'messages': [{'role': 'user', 'content': prompt}],
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final contentList = data['content'] as List?;
      if (contentList == null || contentList.isEmpty) {
        throw Exception('Empty response from AI');
      }
      final text = (contentList[0]['text'] as String?) ?? 'Summary unavailable';
      if (text.trim().isNotEmpty) {
        await ClaudeCache.set('yt_sum', cacheKey, text);
      }
      return text;
    } else {
      throw Exception('Video summary failed — ${claudeError(response.statusCode, response.body)}');
    }
  }

  /// Samples a long transcript by taking the beginning, middle, and end
  /// so the summary reflects the whole video, not just the intro.
  static String _sampleTranscript(String full, int maxChars) {
    if (full.length <= maxChars) return full;
    final chunkSize = maxChars ~/ 3;
    final start = full.substring(0, chunkSize);
    final midPoint = full.length ~/ 2;
    final midStart = (midPoint - chunkSize ~/ 2).clamp(0, full.length - chunkSize);
    final middle = full.substring(midStart, midStart + chunkSize);
    final end = full.substring(full.length - chunkSize);
    return '$start\n\n[…middle of video…]\n\n$middle\n\n[…end of video…]\n\n$end';
  }

}

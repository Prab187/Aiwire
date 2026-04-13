import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'claude_cache.dart';
import 'claude_error.dart';

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
    try {
      return await _fetchTrendingAIInternal(maxResults: maxResults)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('AIWire YouTube: $e');
      return [];
    }
  }

  static Future<List<YouTubeVideo>> _fetchTrendingAIInternal({int maxResults = 5}) async {
    final yt = YoutubeExplode();
    try {
      final candidates = <YouTubeVideo>[];
      final seen = <String>{};

      for (final query in _queries) {
        try {
          // Search last week, sorted by view count
          final results = await yt.search.search(query,
            filter: UploadDateFilter.lastWeek);

          for (final v in results.take(10)) {
            if (seen.contains(v.id.value)) continue;
            seen.add(v.id.value);

            final views = v.engagement.viewCount;

            // Skip low-view videos
            if (views < _minViews) continue;

            // Skip live streams
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

      // Sort by highest views first
      candidates.sort((a, b) => b.rawViewCount.compareTo(a.rawViewCount));

      // Return top N
      return candidates.take(maxResults).toList();
    } finally {
      yt.close();
    }
  }

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
    try {
      return await _fetchForProfileInternal(
        skills: skills, jobTitle: jobTitle, country: country, maxResults: maxResults,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('AIWire YouTube: $e');
      return [];
    }
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
  /// Results are cached by video ID for 7 days — a popular video's summary
  /// doesn't change, so the second user to tap it (and all subsequent
  /// users for a week) gets the cached result for $0.
  static Future<String> summarizeVideo(YouTubeVideo video) async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');

    // Cache lookup — keyed on video ID alone (content doesn't change)
    final cacheKey = ClaudeCache.keyFrom([video.id]);
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
      // Use much more of the transcript (up to 8000 chars ≈ 2000 tokens)
      // so summaries cover the whole video, not just the intro. If the
      // transcript is longer, sample beginning + middle + end.
      final trimmed = _sampleTranscript(transcript, 8000);
      context = 'Title: ${video.title}\nChannel: ${video.channelName}\n\nTranscript:\n$trimmed';
    } else {
      // Fall back to description
      final desc = video.description?.trim() ?? '';
      context = desc.isNotEmpty
          ? 'Title: ${video.title}\n\nDescription: ${desc.length > 800 ? desc.substring(0, 800) : desc}'
          : 'Title: ${video.title}\nChannel: ${video.channelName}';
    }

    final prompt = '''Summarize this YouTube video in exactly 4 concise bullet points. Each bullet starts with "• " and is a single short sentence. Cover: what the video is about, the most important insight, a specific detail the speaker makes, and who this is useful for. No preamble, no headers, just 4 bullets.

$context''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: json.encode({
        'model': 'claude-haiku-4-5',
        'max_tokens': 320,
        'messages': [{'role': 'user', 'content': prompt}],
      }),
    ).timeout(const Duration(seconds: 30));

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

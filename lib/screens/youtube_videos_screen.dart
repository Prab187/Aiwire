import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/youtube_service.dart';

class YouTubeVideosScreen extends StatefulWidget {
  final AppTheme theme;
  const YouTubeVideosScreen({super.key, required this.theme});

  @override
  State<YouTubeVideosScreen> createState() => _YouTubeVideosScreenState();
}

class _YouTubeVideosScreenState extends State<YouTubeVideosScreen> {
  List<YouTubeVideo> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final videos = await YouTubeService.fetchTrendingAI(maxResults: 20);
      if (mounted) setState(() { _videos = videos; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openVideo(YouTubeVideo video) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VideoDetailSheet(theme: widget.theme, video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Trending on YouTube', style: GoogleFonts.sourceSerif4(
                      fontSize: 22, fontWeight: FontWeight.w700, color: t.primary)),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                child: Row(children: [
                  const SizedBox(width: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_circle_filled_rounded, color: Color(0xFFFF0000), size: 12),
                      const SizedBox(width: 4),
                      Text('AI/ML videos · AI summaries', style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFFFF0000), fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: Divider(height: 1, color: t.divider)),

            // Content
            if (_loading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _VideoShimmer(theme: t),
                  childCount: 8,
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.wifi_off_rounded, size: 48, color: t.muted.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('Could not load videos', style: GoogleFonts.sourceSerif4(
                      fontSize: 18, fontWeight: FontWeight.w600, color: t.primary)),
                    const SizedBox(height: 8),
                    Text('Check your connection and try again', style: GoogleFonts.inter(
                      fontSize: 13, color: t.muted), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _load,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: t.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Retry', style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: t.background)),
                      ),
                    ),
                  ]),
                )),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _VideoCard(
                    theme: t,
                    video: _videos[i],
                    onTap: () => _openVideo(_videos[i]),
                  ),
                  childCount: _videos.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Video Card ─────────────────────────────────────────────────────────────────
class _VideoCard extends StatelessWidget {
  final AppTheme theme;
  final YouTubeVideo video;
  final VoidCallback onTap;

  const _VideoCard({required this.theme, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.divider, width: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                width: 120,
                height: 68,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 120, height: 68,
                  color: t.surface,
                  child: Center(child: Icon(Icons.play_circle_outline_rounded,
                    color: t.muted.withValues(alpha: 0.4), size: 28)),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 120, height: 68,
                  color: t.surface,
                  child: Center(child: Icon(Icons.smart_display_outlined,
                    color: t.muted.withValues(alpha: 0.4), size: 28)),
                ),
              ),
            ),
            if (video.duration != null)
              Positioned(
                bottom: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(video.duration!, style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: t.primary, height: 1.35)),
            const SizedBox(height: 6),
            Text(video.channelName, style: GoogleFonts.inter(
              fontSize: 12, color: t.muted)),
            if (video.viewCount != null && video.viewCount!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(video.viewCount!, style: GoogleFonts.inter(
                fontSize: 11, color: t.muted.withValues(alpha: 0.7))),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 3),
                  Text('AI Summary', style: GoogleFonts.inter(
                    fontSize: 10, color: const Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ── Video Detail Sheet ─────────────────────────────────────────────────────────
class _VideoDetailSheet extends StatefulWidget {
  final AppTheme theme;
  final YouTubeVideo video;
  const _VideoDetailSheet({required this.theme, required this.video});

  @override
  State<_VideoDetailSheet> createState() => _VideoDetailSheetState();
}

class _VideoDetailSheetState extends State<_VideoDetailSheet> {
  String? _summary;
  bool _summaryLoading = true;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    try {
      final s = await YouTubeService.summarizeVideo(widget.video);
      if (mounted) setState(() { _summary = s; _summaryLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _summaryError = e.toString(); _summaryLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final v = widget.video;

    return Container(
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Center(child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: t.muted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        )),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: v.thumbnailUrl,
                  width: double.infinity,
                  height: 190,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 190, color: t.surface,
                    child: Center(child: Icon(Icons.smart_display_outlined,
                      color: t.muted.withValues(alpha: 0.4), size: 44)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 190, color: t.surface,
                    child: Center(child: Icon(Icons.smart_display_outlined,
                      color: t.muted.withValues(alpha: 0.4), size: 44)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(v.title, style: GoogleFonts.sourceSerif4(
                fontSize: 18, fontWeight: FontWeight.w700, color: t.primary, height: 1.35)),
              const SizedBox(height: 6),

              // Channel + views
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 14, color: t.muted),
                const SizedBox(width: 4),
                Expanded(child: Text(v.channelName, style: GoogleFonts.inter(
                  fontSize: 13, color: t.muted))),
                if (v.viewCount != null && v.viewCount!.isNotEmpty)
                  Text(v.viewCount!, style: GoogleFonts.inter(
                    fontSize: 12, color: t.muted.withValues(alpha: 0.7))),
              ]),
              const SizedBox(height: 20),

              // AI Summary section
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 10),
                Text('AI Summary', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
              ]),
              const SizedBox(height: 12),

              if (_summaryLoading)
                _SummaryShimmer(theme: t)
              else if (_summaryError != null)
                Text('Could not generate summary.', style: GoogleFonts.inter(
                  fontSize: 13, color: t.muted, fontStyle: FontStyle.italic))
              else if (_summary != null)
                Text(_summary!, style: GoogleFonts.inter(
                  fontSize: 14, color: t.primary, height: 1.65)),

              const SizedBox(height: 24),

              // Watch button
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(v.watchUrl);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text('Watch on YouTube', style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Shimmer ────────────────────────────────────────────────────────────────────
class _VideoShimmer extends StatelessWidget {
  final AppTheme theme;
  const _VideoShimmer({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: theme.surface,
      highlightColor: theme.divider,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 120, height: 68, decoration: BoxDecoration(
            color: theme.surface, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 13, color: theme.surface),
            const SizedBox(height: 6),
            Container(height: 13, width: 180, color: theme.surface),
            const SizedBox(height: 8),
            Container(height: 12, width: 100, color: theme.surface),
          ])),
        ]),
      ),
    );
  }
}

class _SummaryShimmer extends StatelessWidget {
  final AppTheme theme;
  const _SummaryShimmer({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: theme.surface,
      highlightColor: theme.divider,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 14, color: theme.surface),
        const SizedBox(height: 8),
        Container(height: 14, width: double.infinity, color: theme.surface),
        const SizedBox(height: 8),
        Container(height: 14, width: 200, color: theme.surface),
        const SizedBox(height: 12),
        Container(height: 14, color: theme.surface),
        const SizedBox(height: 8),
        Container(height: 14, width: double.infinity, color: theme.surface),
        const SizedBox(height: 8),
        Container(height: 14, width: 150, color: theme.surface),
        const SizedBox(height: 12),
        Container(height: 14, color: theme.surface),
        const SizedBox(height: 8),
        Container(height: 14, width: 220, color: theme.surface),
      ]),
    );
  }
}

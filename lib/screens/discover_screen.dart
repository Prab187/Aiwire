import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/youtube_service.dart';
import '../widgets/bullet_summary.dart';
import '../services/analytics_service.dart';
import 'job_board_screen.dart';
import 'events_hub_screen.dart';
import 'certification_screen.dart';
import 'forecast_screen.dart';
import 'investment_screen.dart';
import 'resume_scan_screen.dart';
import 'application_tracker_screen.dart';
import 'mock_interview_screen.dart';
import 'salary_calculator_screen.dart';

const _indigo = Color(0xFF6366F1);

class DiscoverScreen extends StatefulWidget {
  final AppTheme theme;
  const DiscoverScreen({super.key, required this.theme});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<YouTubeVideo> _videos = [];
  final Map<String, String> _summaries = {};
  final Map<String, bool> _summaryLoading = {};
  bool _videosLoading = true;
  bool _hasResume = false;
  String _userTitle = '';
  String _userLevel = '';

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _loadResumeState();
  }

  Future<void> _loadResumeState() async {
    final prefs = await SharedPreferences.getInstance();
    final skills = prefs.getStringList('user_skills') ?? [];
    if (mounted) setState(() {
      _hasResume = skills.isNotEmpty;
      _userTitle = prefs.getString('user_job_title') ?? '';
      _userLevel = prefs.getString('user_level') ?? '';
    });
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await YouTubeService.fetchTrendingAI(maxResults: 5);
      if (!mounted) return;
      setState(() { _videos = videos; _videosLoading = false; });
      for (final v in videos) { _fetchSummary(v); }
    } catch (_) {
      if (mounted) setState(() => _videosLoading = false);
    }
  }

  Future<void> _fetchSummary(YouTubeVideo video) async {
    setState(() => _summaryLoading[video.id] = true);
    try {
      final s = await YouTubeService.summarizeVideo(video);
      if (mounted) setState(() { _summaries[video.id] = s; _summaryLoading[video.id] = false; });
    } catch (_) {
      if (mounted) setState(() => _summaryLoading[video.id] = false);
    }
  }

  void _navTo(Widget screen, {String? feature}) {
    HapticFeedback.lightImpact();
    if (feature != null) AnalyticsService.featureTapped(feature: feature);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadResumeState())
        .catchError((e, st) {
          // Log instead of silently swallowing so debug builds can spot
          // breakage in the resume-state refresh after returning from a
          // pushed screen.
          debugPrint('AIWire: _loadResumeState() after pop failed — $e');
        });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: t.primary,
          backgroundColor: t.surface,
          onRefresh: () async {
            await _loadVideos();
            await _loadResumeState();
          },
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Text('AIWire', style: GoogleFonts.sourceSerif4(
                  fontSize: 30, fontWeight: FontWeight.w700,
                  color: t.primary, letterSpacing: -0.5)),
              )),

              // ── Hero: Career Plan ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                child: GestureDetector(
                  onTap: () => _navTo(ResumeScanScreen(theme: t), feature: 'career_plan'),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          _indigo.withValues(alpha: 0.14),
                          _indigo.withValues(alpha: 0.04),
                        ]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _indigo.withValues(alpha: 0.18))),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _indigo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.auto_awesome_rounded,
                          size: 22, color: _indigo),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasResume ? 'Your AI Career Plan' : 'Get Your AI Career Plan',
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: t.primary, letterSpacing: -0.3)),
                          const SizedBox(height: 3),
                          Text(
                            _hasResume && _userTitle.isNotEmpty
                              ? '$_userTitle · $_userLevel'
                              : 'AI career roadmap — upload resume or answer 3 questions',
                            style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                        ],
                      )),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: t.muted),
                    ]),
                  ),
                ),
              )),

              // ── Tools grid — clean list style ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.divider, width: 0.5)),
                  child: Column(children: [
                    _ListTile(theme: t, icon: Icons.work_outline_rounded,
                      label: 'AI Jobs', onTap: () => _navTo(JobBoardScreen(theme: t), feature: 'jobs')),
                    _divider(t),
                    _ListTile(theme: t, icon: Icons.psychology_rounded,
                      label: 'AI Interview Prep', onTap: () => _navTo(MockInterviewScreen(theme: t), feature: 'interview')),
                    _divider(t),
                    _ListTile(theme: t, icon: Icons.payments_outlined,
                      label: 'AI Salary Insights', onTap: () => _navTo(SalaryCalculatorScreen(theme: t), feature: 'salary')),
                    _divider(t),
                    _ListTile(theme: t, icon: Icons.event_outlined,
                      label: 'AI Events', onTap: () => _navTo(EventsHubScreen(theme: t), feature: 'events')),
                    _divider(t),
                    _ListTile(theme: t, icon: Icons.verified_outlined,
                      label: 'AI Certifications', onTap: () => _navTo(CertificationScreen(theme: t), feature: 'certifications')),
                    _divider(t),
                    _ListTile(theme: t, icon: Icons.business_center_outlined,
                      label: 'Job Tracker', onTap: () => _navTo(ApplicationTrackerScreen(theme: t), feature: 'tracker')),
                  ]),
                ),
              )),

              // ── Trending in AI (videos) ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
                child: Text('Trending in AI', style: GoogleFonts.sourceSerif4(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: t.primary, letterSpacing: -0.2)),
              )),

              if (_videosLoading)
                SliverToBoxAdapter(child: SizedBox(height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _VideoCardShimmer(theme: t)),
                ))
              else if (_videos.isEmpty)
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Text('Pull down to refresh videos',
                    style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                ))
              else
                SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => _VideoRow(
                    theme: t, video: _videos[i],
                    summary: _summaries[_videos[i].id],
                    loading: _summaryLoading[_videos[i].id] ?? true),
                  childCount: _videos.length,
                )),

              // ── More ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.divider, width: 0.5)),
                  child: Column(children: [
                    _ListTile(theme: t, icon: Icons.trending_up_rounded,
                      label: 'AI Job Forecast', onTap: () => _navTo(ForecastScreen(theme: t), feature: 'forecast')),
                    _divider(t),
                    _ListTile(theme: t, icon: Icons.show_chart_rounded,
                      label: 'AI Investment Tracker', onTap: () => _navTo(InvestmentScreen(theme: t), feature: 'investment')),
                  ]),
                ),
              )),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(AppTheme t) => Padding(
    padding: const EdgeInsets.only(left: 52),
    child: Divider(height: 1, color: t.divider),
  );
}

// ── iOS Settings-style list tile ────────────────────────────────────────────
class _ListTile extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ListTile({
    required this.theme, required this.icon,
    required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 20, color: t.secondary),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w500, color: t.primary))),
          Icon(Icons.chevron_right_rounded, size: 18, color: t.muted),
        ]),
      ),
    );
  }
}

// ── Video row (compact, minimal) ────────────────────────────────────────────
class _VideoRow extends StatelessWidget {
  final AppTheme theme;
  final YouTubeVideo video;
  final String? summary;
  final bool loading;

  const _VideoRow({
    required this.theme, required this.video,
    this.summary, this.loading = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.divider, width: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: video.thumbnailUrl, width: 96, height: 54, fit: BoxFit.cover,
                placeholder: (_, __) => Container(width: 96, height: 54, color: t.surface),
                errorWidget: (_, __, ___) => Container(width: 96, height: 54, color: t.surface))),
            if (video.duration != null)
              Positioned(bottom: 3, right: 3, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3)),
                child: Text(video.duration!, style: GoogleFonts.inter(
                  fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: t.primary, height: 1.3)),
              const SizedBox(height: 4),
              Text(
                [video.channelName, if (video.viewCount != null) video.viewCount!]
                  .join(' · '),
                style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
            ],
          )),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    HapticFeedback.lightImpact();
    final t = theme;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: DraggableScrollableSheet(
          expand: false, initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95,
          builder: (_, ctrl) => Column(children: [
            Center(child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: t.muted.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2)))),
            Expanded(child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: double.infinity, height: 190, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 190, color: t.surface),
                    errorWidget: (_, __, ___) => Container(height: 190, color: t.surface))),
                const SizedBox(height: 16),
                Text(video.title, style: GoogleFonts.sourceSerif4(
                  fontSize: 20, fontWeight: FontWeight.w700, color: t.primary, height: 1.3)),
                const SizedBox(height: 8),
                Text(
                  [video.channelName, if (video.viewCount != null) video.viewCount!]
                    .join(' · '),
                  style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        t.accent.withValues(alpha: 0.08),
                        t.surface,
                      ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.accent.withValues(alpha: 0.22), width: 0.8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7)),
                        child: Icon(Icons.auto_awesome_rounded, size: 13, color: t.accent)),
                      const SizedBox(width: 10),
                      Text('AI Summary', style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: t.primary, letterSpacing: 0.3)),
                    ]),
                    const SizedBox(height: 14),
                    if (loading)
                      _SummaryShimmer(theme: t)
                    else if (summary != null)
                      BulletSummary(text: summary!, theme: t, accent: t.accent, fontSize: 14)
                    else
                      Text('Summary unavailable', style: GoogleFonts.inter(
                        fontSize: 13, color: t.muted, fontStyle: FontStyle.italic)),
                  ]),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(video.watchUrl);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('Watch on YouTube', style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Shimmers ────────────────────────────────────────────────────────────────
class _VideoCardShimmer extends StatelessWidget {
  final AppTheme theme;
  const _VideoCardShimmer({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: theme.surface, highlightColor: theme.divider,
      child: Container(width: 260, padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 120, decoration: BoxDecoration(
            color: theme.surface, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 10),
          Container(height: 14, width: 180, color: theme.surface),
          const SizedBox(height: 6),
          Container(height: 12, width: 120, color: theme.surface),
        ])));
  }
}

class _SummaryShimmer extends StatelessWidget {
  final AppTheme theme;
  const _SummaryShimmer({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: theme.divider, highlightColor: theme.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 13, color: theme.surface),
        const SizedBox(height: 6),
        Container(height: 13, color: theme.surface),
        const SizedBox(height: 6),
        Container(height: 13, width: 180, color: theme.surface),
      ]));
  }
}

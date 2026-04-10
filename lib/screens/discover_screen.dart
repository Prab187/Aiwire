import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/youtube_service.dart';
import '../services/job_service.dart';
import '../services/career_progress_service.dart';
import '../services/application_tracker_service.dart';
import '../widgets/bullet_summary.dart';
import 'job_board_screen.dart';
import 'events_hub_screen.dart';
import 'certification_screen.dart';
import 'forecast_screen.dart';
import 'investment_screen.dart';
import 'resume_scan_screen.dart';
import 'application_tracker_screen.dart';
import 'mock_interview_screen.dart';
import 'salary_calculator_screen.dart';

// ── Minimal color system ────────────────────────────────────────────────────
// Action blue: things you do (Find Jobs, Mock Interview, Events)
const _actionBlue = Color(0xFF3B82F6);
// Growth green: things you build (Certifications, Salary, Job Tracker)
const _growthGreen = Color(0xFF10B981);
// Hero indigo: career plan identity (used only in the hero gradient)
const _heroIndigo = Color(0xFF6366F1);

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

  // Resume state
  bool _hasResume = false;
  String _userTitle = '';
  String _userLevel = '';

  // Career progress + tracker
  int _streak = 0;
  int _appCount = 0;

  // Skills heatmap
  List<({String skill, int count})> _trendingSkills = [];
  bool _trendingLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _loadResumeState();
    _loadProgress();
    _loadTrendingSkills();
  }

  Future<void> _loadResumeState() async {
    final prefs = await SharedPreferences.getInstance();
    final skills = prefs.getStringList('user_skills') ?? [];
    if (mounted) {
      setState(() {
        _hasResume = skills.isNotEmpty;
        _userTitle = prefs.getString('user_job_title') ?? '';
        _userLevel = prefs.getString('user_level') ?? '';
      });
    }
  }

  Future<void> _loadProgress() async {
    final streak = await CareerProgressService.currentStreak();
    final counts = await ApplicationTrackerService.counts();
    if (mounted) {
      setState(() {
        _streak = streak;
        _appCount = counts.values.fold<int>(0, (a, b) => a + b);
      });
    }
  }

  Future<void> _loadTrendingSkills() async {
    try {
      final jobs = await JobService.fetchJobs();
      final freq = <String, int>{};
      for (final j in jobs.take(40)) {
        for (final s in j.skills) {
          final key = s.trim();
          if (key.isEmpty) continue;
          freq[key] = (freq[key] ?? 0) + 1;
        }
      }
      final sorted = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (mounted) {
        setState(() {
          _trendingSkills = sorted.take(8).map((e) => (skill: e.key, count: e.value)).toList();
          _trendingLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _trendingLoading = false);
    }
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

  void _navTo(Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) { _loadResumeState(); _loadProgress(); });
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
            await _loadProgress();
            await _loadTrendingSkills();
          },
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Text('Discover', style: GoogleFonts.sourceSerif4(
                  fontSize: 32, fontWeight: FontWeight.w700,
                  color: t.primary, letterSpacing: -0.5)),
              )),

              // ── Hero Career Plan Card ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: GestureDetector(
                  onTap: () => _navTo(ResumeScanScreen(theme: t)),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          _heroIndigo.withValues(alpha: 0.16),
                          _actionBlue.withValues(alpha: 0.06),
                        ]),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _heroIndigo.withValues(alpha: 0.2))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: _heroIndigo.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.auto_awesome_rounded,
                            size: 22, color: _heroIndigo),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasResume
                                ? 'Your Career Plan'
                                : 'Get Your AI Career Plan',
                              style: GoogleFonts.sourceSerif4(
                                fontSize: 19, fontWeight: FontWeight.w700,
                                color: t.primary, letterSpacing: -0.3)),
                            const SizedBox(height: 3),
                            Text(
                              _hasResume && _userTitle.isNotEmpty
                                ? '$_userTitle · $_userLevel'
                                : 'Upload resume → 90-day plan in 30 seconds',
                              style: GoogleFonts.inter(
                                fontSize: 13, color: t.muted)),
                          ],
                        )),
                        Icon(Icons.arrow_forward_ios_rounded, size: 15, color: t.muted),
                      ]),
                      // Inline stats row (only when resume exists)
                      if (_hasResume) ...[
                        const SizedBox(height: 16),
                        Row(children: [
                          _HeroChip(
                            emoji: '🔥',
                            label: '$_streak day${_streak == 1 ? "" : "s"} streak',
                            theme: t),
                          const SizedBox(width: 8),
                          _HeroChip(
                            emoji: '📋',
                            label: '$_appCount tracked',
                            theme: t),
                        ]),
                      ],
                    ]),
                  ),
                ),
              )),

              // ── Unified 6-tile grid (no section header) ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _Tile(theme: t,
                      icon: Icons.work_outline_rounded,
                      color: _actionBlue,
                      label: 'Find Jobs',
                      onTap: () => _navTo(JobBoardScreen(theme: t)))),
                    const SizedBox(width: 10),
                    Expanded(child: _Tile(theme: t,
                      icon: Icons.psychology_rounded,
                      color: _actionBlue,
                      label: 'Mock Interview',
                      onTap: () => _navTo(MockInterviewScreen(theme: t)))),
                  ]),
                  Row(children: [
                    Expanded(child: _Tile(theme: t,
                      icon: Icons.payments_outlined,
                      color: _growthGreen,
                      label: 'Salary',
                      onTap: () => _navTo(SalaryCalculatorScreen(theme: t)))),
                    const SizedBox(width: 10),
                    Expanded(child: _Tile(theme: t,
                      icon: Icons.event_outlined,
                      color: _actionBlue,
                      label: 'Events',
                      onTap: () => _navTo(EventsHubScreen(theme: t)))),
                  ]),
                  Row(children: [
                    Expanded(child: _Tile(theme: t,
                      icon: Icons.verified_outlined,
                      color: _growthGreen,
                      label: 'Certifications',
                      onTap: () => _navTo(CertificationScreen(theme: t)))),
                    const SizedBox(width: 10),
                    Expanded(child: _Tile(theme: t,
                      icon: Icons.business_center_outlined,
                      color: _growthGreen,
                      label: 'Job Tracker',
                      onTap: () => _navTo(ApplicationTrackerScreen(theme: t)))),
                  ]),
                ]),
              )),

              // ── Trending skills ──
              _sectionHeader(t, 'Trending skills'),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _trendingLoading
                  ? SizedBox(height: 80, child: Center(child:
                    CircularProgressIndicator(color: t.primary, strokeWidth: 1.5)))
                  : _SkillsHeatmap(skills: _trendingSkills, theme: t),
              )),

              // ── Trending in AI (videos) ──
              _sectionHeader(t, 'Trending in AI'),
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
                  child: Column(children: [
                    Icon(Icons.smart_display_outlined, size: 40,
                      color: t.muted.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    Text('No trending videos this week', style: GoogleFonts.inter(
                      fontSize: 13, color: t.muted)),
                  ]),
                ))
              else
                SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => _VideoArticleCompact(
                    theme: t, video: _videos[i],
                    summary: _summaries[_videos[i].id],
                    loading: _summaryLoading[_videos[i].id] ?? true,
                    index: i + 1),
                  childCount: _videos.length,
                )),

              // ── Footer links (tertiary features) ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                child: Column(children: [
                  _FooterLink(theme: t,
                    label: 'AI Job Forecast',
                    onTap: () => _navTo(ForecastScreen(theme: t))),
                  _FooterLink(theme: t,
                    label: 'Investment Tracker',
                    onTap: () => _navTo(InvestmentScreen(theme: t))),
                ]),
              )),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(AppTheme t, String label) {
    return SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 6),
      child: Text(label, style: GoogleFonts.sourceSerif4(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: t.primary, letterSpacing: -0.2)),
    ));
  }
}

// ── Hero chip (streak / tracked) ─────────────────────────────────────────────
class _HeroChip extends StatelessWidget {
  final String emoji;
  final String label;
  final AppTheme theme;
  const _HeroChip({required this.emoji, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.divider)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: t.primary)),
      ]),
    );
  }
}

// ── Unified Tile (label only, no subtitle) ──────────────────────────────────
class _Tile extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _Tile({
    required this.theme, required this.icon, required this.color,
    required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: t.primary))),
        ]),
      ),
    );
  }
}

// ── Footer link (tertiary features) ──────────────────────────────────────────
class _FooterLink extends StatelessWidget {
  final AppTheme theme;
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.divider, width: 0.5))),
        child: Row(children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400, color: t.secondary))),
          Icon(Icons.chevron_right_rounded, size: 16, color: t.muted),
        ]),
      ),
    );
  }
}

// ── Skills Heatmap (simplified: no micro-counts) ────────────────────────────
class _SkillsHeatmap extends StatelessWidget {
  final List<({String skill, int count})> skills;
  final AppTheme theme;
  const _SkillsHeatmap({required this.skills, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (skills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('No data yet', style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
      );
    }
    final max = skills.first.count;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5)),
      child: Wrap(spacing: 6, runSpacing: 8, children: skills.map((s) {
        final intensity = max == 0 ? 0.5 : (s.count / max);
        final size = 11.5 + (intensity * 4); // 11.5 to 15.5pt
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: t.primary.withValues(alpha: 0.03 + (intensity * 0.08)),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: t.primary.withValues(alpha: 0.08 + (intensity * 0.15))),
          ),
          child: Text(s.skill, style: GoogleFonts.inter(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: t.primary.withValues(alpha: 0.55 + (intensity * 0.45)))),
        );
      }).toList()),
    );
  }
}

// ── Compact Video Article (unchanged) ───────────────────────────────────────
class _VideoArticleCompact extends StatelessWidget {
  final AppTheme theme;
  final YouTubeVideo video;
  final String? summary;
  final bool loading;
  final int index;

  const _VideoArticleCompact({
    required this.theme, required this.video,
    this.summary, this.loading = true, this.index = 1,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.divider, width: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 22, child: Text('$index', style: GoogleFonts.sourceSerif4(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: t.muted.withValues(alpha: 0.4)))),
          const SizedBox(width: 10),
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: video.thumbnailUrl, width: 100, height: 60, fit: BoxFit.cover,
                placeholder: (_, __) => Container(width: 100, height: 60, color: t.surface),
                errorWidget: (_, __, ___) => Container(width: 100, height: 60, color: t.surface,
                  child: Icon(Icons.smart_display_outlined,
                    color: t.muted.withValues(alpha: 0.3), size: 24)))),
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
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: t.primary, height: 1.3)),
              const SizedBox(height: 4),
              Row(children: [
                Flexible(child: Text(video.channelName, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: t.muted))),
                if (video.viewCount != null && video.viewCount!.isNotEmpty) ...[
                  Text('  ·  ', style: GoogleFonts.inter(
                    fontSize: 12, color: t.muted.withValues(alpha: 0.5))),
                  Text(video.viewCount!, style: GoogleFonts.inter(
                    fontSize: 12, color: t.muted)),
                ],
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.auto_awesome_rounded, size: 10, color: t.accent),
                const SizedBox(width: 4),
                Text(loading ? 'Summarizing...' : 'AI Summary',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
              ]),
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
                Row(children: [
                  Expanded(child: Text(video.channelName,
                    style: GoogleFonts.inter(fontSize: 13, color: t.muted))),
                  if (video.viewCount != null && video.viewCount!.isNotEmpty)
                    Text(video.viewCount!, style: GoogleFonts.inter(
                      fontSize: 12, color: t.muted.withValues(alpha: 0.7))),
                ]),
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
                    border: Border.all(
                      color: t.accent.withValues(alpha: 0.22), width: 0.8)),
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
                      _SummaryShimmerInline(theme: t)
                    else if (summary != null)
                      BulletSummary(
                        text: summary!,
                        theme: t,
                        accent: t.accent,
                        fontSize: 14)
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

class _SummaryShimmerInline extends StatelessWidget {
  final AppTheme theme;
  const _SummaryShimmerInline({required this.theme});

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

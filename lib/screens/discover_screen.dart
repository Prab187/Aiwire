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
import 'job_board_screen.dart';
import 'events_hub_screen.dart';
import 'certification_screen.dart';
import 'forecast_screen.dart';
import 'investment_screen.dart';
import 'resume_scan_screen.dart';
import 'application_tracker_screen.dart';
import 'mock_interview_screen.dart';
import 'salary_calculator_screen.dart';
import 'career_progress_screen.dart';

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
    if (mounted) setState(() {
      _hasResume = skills.isNotEmpty;
      _userTitle = prefs.getString('user_job_title') ?? '';
      _userLevel = prefs.getString('user_level') ?? '';
    });
  }

  Future<void> _loadProgress() async {
    final streak = await CareerProgressService.currentStreak();
    final counts = await ApplicationTrackerService.counts();
    if (mounted) setState(() {
      _streak = streak;
      _appCount = counts.values.fold<int>(0, (a, b) => a + b);
    });
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
      if (mounted) setState(() {
        _trendingSkills = sorted.take(8).map((e) => (skill: e.key, count: e.value)).toList();
        _trendingLoading = false;
      });
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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
          onRefresh: () async { await _loadVideos(); await _loadResumeState(); },
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(_greeting, style: GoogleFonts.inter(
                  fontSize: 14, color: t.muted, fontWeight: FontWeight.w500)),
              )),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text('Discover', style: GoogleFonts.sourceSerif4(
                  fontSize: 30, fontWeight: FontWeight.w700, color: t.primary)),
              )),

              // ── Hero: Career Plan CTA ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ResumeScanScreen(theme: t)))
                      .then((_) => _loadResumeState());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF6366F1).withValues(alpha: 0.15),
                          const Color(0xFF3B82F6).withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.auto_awesome_rounded,
                            size: 22, color: Color(0xFF6366F1)),
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
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: t.primary)),
                            const SizedBox(height: 2),
                            Text(
                              _hasResume
                                ? '$_userTitle · $_userLevel'
                                : 'Upload resume or answer 3 questions',
                              style: GoogleFonts.inter(
                                fontSize: 13, color: t.muted)),
                          ],
                        )),
                        Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: t.muted),
                      ]),
                      if (!_hasResume) ...[
                        const SizedBox(height: 14),
                        Row(children: [
                          _heroPill(t, Icons.upload_file_rounded, 'Upload CV'),
                          const SizedBox(width: 8),
                          _heroPill(t, Icons.bolt_rounded, '90-Day Plan'),
                          const SizedBox(width: 8),
                          _heroPill(t, Icons.work_outline_rounded, 'Job Match'),
                        ]),
                      ] else ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: t.accent),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              'Resume scanned · Tap to view recommendation & apply',
                              style: GoogleFonts.inter(
                                fontSize: 12, color: t.accent, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
              )),

              // ── Today's Brief progress strip ──
              if (_hasResume) SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(children: [
                  Expanded(child: _MiniStatCard(theme: t,
                    icon: Icons.local_fire_department_rounded,
                    label: 'Streak',
                    value: '$_streak day${_streak == 1 ? "" : "s"}',
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CareerProgressScreen(theme: t)))
                        .then((_) => _loadProgress());
                    })),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStatCard(theme: t,
                    icon: Icons.business_center_outlined,
                    label: 'Tracked',
                    value: '$_appCount job${_appCount == 1 ? "" : "s"}',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ApplicationTrackerScreen(theme: t)))
                        .then((_) => _loadProgress());
                    })),
                ]),
              )),

              // ── Career Tools (NEW row) ──
              _sectionHeader(t, 'Career Tools'),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _QuickAction(theme: t,
                      icon: Icons.psychology_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      label: 'Mock Interview',
                      subtitle: 'AI practice',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => MockInterviewScreen(theme: t)));
                      })),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(theme: t,
                      icon: Icons.payments_outlined,
                      iconColor: const Color(0xFF10B981),
                      label: 'Salary',
                      subtitle: 'Calculator + script',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SalaryCalculatorScreen(theme: t)));
                      })),
                  ]),
                  Row(children: [
                    Expanded(child: _QuickAction(theme: t,
                      icon: Icons.business_center_outlined,
                      iconColor: const Color(0xFF6366F1),
                      label: 'Job Tracker',
                      subtitle: 'Saved & applied',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ApplicationTrackerScreen(theme: t)))
                          .then((_) => _loadProgress());
                      })),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(theme: t,
                      icon: Icons.insights_rounded,
                      iconColor: const Color(0xFFEC4899),
                      label: 'Progress',
                      subtitle: 'Streak & growth',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CareerProgressScreen(theme: t)))
                          .then((_) => _loadProgress());
                      })),
                  ]),
                ]),
              )),

              // ── Discover ──
              _sectionHeader(t, 'Discover'),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _QuickAction(theme: t,
                      icon: Icons.work_outline_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      label: 'Find Jobs',
                      subtitle: 'AI/ML roles',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => JobBoardScreen(theme: t)));
                      })),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(theme: t,
                      icon: Icons.event_outlined,
                      iconColor: const Color(0xFFEC4899),
                      label: 'Events',
                      subtitle: 'Webinars & more',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => EventsHubScreen(theme: t)));
                      })),
                  ]),
                  Row(children: [
                    Expanded(child: _QuickAction(theme: t,
                      icon: Icons.verified_outlined,
                      iconColor: const Color(0xFF10B981),
                      label: 'Certifications',
                      subtitle: 'Courses & certs',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CertificationScreen(theme: t)));
                      })),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(theme: t,
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Forecast',
                      subtitle: 'Market trends',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ForecastScreen(theme: t)));
                      })),
                  ]),
                ]),
              )),

              // ── Trending Skills Heatmap ──
              _sectionHeader(t, 'Trending Skills'),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text('Most-requested AI/ML skills in current job postings',
                  style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
              )),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _trendingLoading
                  ? SizedBox(height: 80, child: Center(child:
                    CircularProgressIndicator(color: t.primary, strokeWidth: 1.5)))
                  : _SkillsHeatmap(skills: _trendingSkills, theme: t),
              )),

              // ── Market Intel ──
              _sectionHeader(t, 'Market Intel'),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FeatureRow(theme: t,
                  icon: Icons.show_chart_rounded,
                  iconBg: const Color(0xFF8B5CF6),
                  title: 'Investment Tracker',
                  subtitle: 'AI funding, sectors & capital flow',
                  badge: '\$97B+',
                  badgeColor: const Color(0xFF8B5CF6),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => InvestmentScreen(theme: t)));
                  },
                ),
              )),

              // ── Trending in AI ──
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
                child: Row(children: [
                  Expanded(child: Text('Trending in AI', style: GoogleFonts.sourceSerif4(
                    fontSize: 18, fontWeight: FontWeight.w700, color: t.primary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_circle_filled_rounded,
                        color: Color(0xFFFF0000), size: 11),
                      const SizedBox(width: 4),
                      Text('This week', style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFFFF0000),
                        fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              )),
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Text('Top AI/ML videos with AI-generated summaries',
                  style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
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

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroPill(AppTheme t, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.divider)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: t.secondary),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w500, color: t.secondary)),
      ]),
    );
  }

  Widget _sectionHeader(AppTheme t, String label) {
    return SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Text(label, style: GoogleFonts.sourceSerif4(
        fontSize: 18, fontWeight: FontWeight.w700, color: t.primary)),
    ));
  }
}

// ── Quick Action Card (2×2 grid) ────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.theme, required this.icon, required this.iconColor,
    required this.label, required this.onTap, this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: GoogleFonts.inter(
                  fontSize: 11, color: t.muted)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: t.muted, size: 16),
        ]),
      ),
    );
  }
}

// ── Feature Row ─────────────────────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _FeatureRow({
    required this.theme, required this.icon, required this.iconBg,
    required this.title, required this.subtitle, required this.onTap,
    this.badge, this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.divider, width: 0.5))),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconBg, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(title, style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? t.accent).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text(badge!, style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: badgeColor ?? t.accent)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: t.muted, size: 18),
        ]),
      ),
    );
  }
}

// ── Mini Stat Card (streak / tracked) ───────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _MiniStatCard({
    required this.theme, required this.icon, required this.label,
    required this.value, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(
              fontSize: 11, color: t.muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: t.primary)),
          ])),
        ]),
      ),
    );
  }
}

// ── Skills Heatmap ──────────────────────────────────────────────────────────
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
        final size = 11.0 + (intensity * 5); // 11 to 16pt
        final opacity = 0.4 + (intensity * 0.6); // 0.4 to 1.0
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.05 + (intensity * 0.15)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2 + (intensity * 0.3))),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(s.skill, style: GoogleFonts.inter(
              fontSize: size,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF59E0B).withValues(alpha: opacity))),
            const SizedBox(width: 4),
            Text('×${s.count}', style: GoogleFonts.inter(
              fontSize: 10, color: t.muted)),
          ]),
        );
      }).toList()),
    );
  }
}

// ── Compact Video Article ───────────────────────────────────────────────────
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
                Row(children: [
                  Container(padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.auto_awesome_rounded, size: 14, color: t.accent)),
                  const SizedBox(width: 10),
                  Text('AI Summary', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
                ]),
                const SizedBox(height: 12),
                if (loading)
                  _SummaryShimmerInline(theme: t)
                else if (summary != null)
                  Text(summary!, style: GoogleFonts.inter(
                    fontSize: 14, color: t.primary.withValues(alpha: 0.85), height: 1.6))
                else
                  Text('Summary unavailable', style: GoogleFonts.inter(
                    fontSize: 13, color: t.muted, fontStyle: FontStyle.italic)),
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

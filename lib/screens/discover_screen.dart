import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/job.dart';
import '../services/job_service.dart';
import '../theme/app_theme.dart';
import 'job_board_screen.dart';
import 'events_hub_screen.dart';
import 'certification_screen.dart';
import 'forecast_screen.dart';
import 'investment_screen.dart';
import 'resume_scan_screen.dart';
import 'nearby_jobs_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final AppTheme theme;
  const DiscoverScreen({super.key, required this.theme});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchCtrl = TextEditingController();
  List<Job> _hotJobs = [];
  bool _hotLoading = true;
  int _totalJobCount = 0;

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _fetchHotJobs();
  }

  Future<void> _fetchHotJobs() async {
    try {
      final jobs = await JobService.fetchJobs(
          query: 'machine learning engineer', type: 'All', level: 'All');
      if (mounted) {
        setState(() {
          _hotJobs = jobs.take(8).toList();
          _totalJobCount = jobs.length;
          _hotLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hotLoading = false);
    }
  }

  static const _quickSearches = [
    'ML Engineer',
    'Data Scientist',
    'LLM Engineer',
    'Remote Python',
    'AI Research',
    'MLOps',
    'NLP Engineer',
    'Prompt Engineer',
  ];

  void _search(String query) {
    if (query.trim().isEmpty) return;
    _searchCtrl.clear();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => JobBoardScreen(theme: t, initialQuery: query.trim())));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discover', style: GoogleFonts.sourceSerif4(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: t.primary)),
                          const SizedBox(height: 2),
                          Text('Your AI/ML career hub', style: GoogleFonts.inter(
                              fontSize: 13, color: t.muted)),
                        ],
                      ),
                    ),
                    // Live job count badge
                    if (!_hotLoading && _totalJobCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text('${_totalJobCount * 40}+ live',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF16A34A))),
                        ]),
                      ),
                  ],
                ),
              ),
            ),

            // ── Search bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.inter(fontSize: 15, color: t.primary),
                  decoration: InputDecoration(
                    hintText: 'Search AI/ML jobs, roles, skills...',
                    hintStyle: GoogleFonts.inter(fontSize: 15, color: t.muted),
                    prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 22),
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _searchCtrl,
                      builder: (_, v, __) => v.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () => _searchCtrl.clear(),
                              child: Icon(Icons.close_rounded,
                                  color: t.muted, size: 18))
                          : const SizedBox.shrink(),
                    ),
                    filled: true,
                    fillColor: t.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.divider)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.primary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                ),
              ),
            ),

            // ── Quick search chips ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _quickSearches.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final q = _quickSearches[i];
                      return GestureDetector(
                        onTap: () => _search(q),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: t.divider),
                          ),
                          child: Text(q,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: t.secondary)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── Hot Jobs live strip ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            size: 15, color: Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        Text('Hot Jobs',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: t.primary)),
                        const SizedBox(width: 6),
                        Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => JobBoardScreen(theme: t))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('View all',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: t.primary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 10, color: t.primary),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    child: _hotLoading
                        ? _buildHotJobsShimmer()
                        : _hotJobs.isEmpty
                            ? const SizedBox.shrink()
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: _hotJobs.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (_, i) =>
                                    _HotJobCard(job: _hotJobs[i], theme: t),
                              ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Section: Find Your Role ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: 'Find Your Role',
                icon: Icons.work_rounded,
                color: const Color(0xFF3B82F6),
                theme: t,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.near_me_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    iconBg: const Color(0xFFEFF6FF),
                    title: 'Jobs Near You',
                    subtitle: 'AI/ML roles in your city & region',
                    badge: 'GPS',
                    badgeColor: const Color(0xFF3B82F6),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => NearbyJobsScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.work_outline_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    iconBg: const Color(0xFFF5F3FF),
                    title: 'Job Board',
                    subtitle: 'Remote, hybrid & on-site AI/ML roles',
                    badge: 'Live',
                    badgeColor: const Color(0xFF22C55E),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => JobBoardScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.document_scanner_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    iconBg: const Color(0xFFFFFBEB),
                    title: 'Scan Resume',
                    subtitle: 'AI matches your CV to top roles',
                    badge: 'AI',
                    badgeColor: const Color(0xFFF59E0B),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => ResumeScanScreen(theme: t))),
                  ),
                ]),
              ),
            ),

            // ── Section: Grow Your Career ────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: 'Grow Your Career',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF10B981),
                theme: t,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.event_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFECFDF5),
                    title: 'Events Hub',
                    subtitle: 'Webinars, conferences & meetups',
                    badge: 'Live',
                    badgeColor: const Color(0xFF10B981),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => EventsHubScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.verified_outlined,
                    iconColor: const Color(0xFF0EA5E9),
                    iconBg: const Color(0xFFF0F9FF),
                    title: 'Certifications',
                    subtitle: 'Top courses from Google, AWS & more',
                    badge: 'Enroll',
                    badgeColor: const Color(0xFF0EA5E9),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => CertificationScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.insights_rounded,
                    iconColor: const Color(0xFFEC4899),
                    iconBg: const Color(0xFFFDF2F8),
                    title: 'AI Job Forecast',
                    subtitle: 'Market trends & demand by role',
                    badge: 'Q1 2026',
                    badgeColor: const Color(0xFFEC4899),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => ForecastScreen(theme: t))),
                  ),
                ]),
              ),
            ),

            // ── Section: Market Intel ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: 'Market Intel',
                icon: Icons.show_chart_rounded,
                color: const Color(0xFF6366F1),
                theme: t,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.show_chart_rounded,
                    iconColor: const Color(0xFF6366F1),
                    iconBg: const Color(0xFFEEF2FF),
                    title: 'AI Investment Tracker',
                    subtitle: 'Funding rounds, sectors & capital flow',
                    badge: '\$97.8B',
                    badgeColor: const Color(0xFF6366F1),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => InvestmentScreen(theme: t))),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotJobsShimmer() {
    return Shimmer.fromColors(
      baseColor: t.divider,
      highlightColor: t.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Container(
          width: 180,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final AppTheme theme;

  const _SectionHeader({
    required this.label, required this.icon,
    required this.color, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: t.muted,
            letterSpacing: 0.5)),
      ]),
    );
  }
}

// ── Hot job mini-card ──────────────────────────────────────────────────────────

class _HotJobCard extends StatelessWidget {
  final Job job;
  final AppTheme theme;
  const _HotJobCard({required this.job, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final hassalary = job.salaryRange.isNotEmpty &&
        job.salaryRange != 'Salary not listed';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => JobBoardScreen(theme: t, initialQuery: job.title))),
      child: Container(
        width: 185,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _logo(t),
              const SizedBox(width: 8),
              Expanded(child: Text(job.company,
                  style: GoogleFonts.inter(fontSize: 11, color: t.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 7),
            Text(job.title,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.primary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 10, color: t.muted),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                    job.location.isNotEmpty ? job.location : 'Remote',
                    style: GoogleFonts.inter(fontSize: 10, color: t.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            if (hassalary) ...[
              const SizedBox(height: 5),
              Text(job.salaryRange,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  Widget _logo(AppTheme t) {
    if (job.companyLogo?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CachedNetworkImage(
            imageUrl: job.companyLogo!,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _letterAvatar(t)),
      );
    }
    return _letterAvatar(t);
  }

  Widget _letterAvatar(AppTheme t) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
          color: t.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(7)),
      child: Center(
          child: Text(job.company.isNotEmpty ? job.company[0] : '?',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.primary))),
    );
  }
}

// ── Discover card ──────────────────────────────────────────────────────────────

class _DiscoverCard extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _DiscoverCard({
    required this.theme,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            // Coloured icon container
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.primary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Coloured badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: t.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  AppTheme get t => widget.theme;

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
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => JobBoardScreen(theme: t, initialQuery: query.trim())));
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
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text('Discover', style: GoogleFonts.sourceSerif4(
                  fontSize: 28, fontWeight: FontWeight.w600, color: t.primary)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                child: Text('AI/ML career, events & insights', style: GoogleFonts.inter(
                  fontSize: 14, color: t.muted)),
              ),
            ),

            // ── Search bar ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                            child: Icon(Icons.close_rounded, color: t.muted, size: 18))
                        : const SizedBox.shrink(),
                    ),
                    filled: true,
                    fillColor: t.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: t.divider),
                          ),
                          child: Text(q, style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w500, color: t.secondary)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
              child: Divider(height: 1, color: t.divider),
            )),

            // ── Feature cards ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.near_me_rounded,
                    title: 'Jobs Near You',
                    subtitle: 'AI/ML roles in your city & nearby',
                    meta: 'GPS',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => NearbyJobsScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.work_outline_rounded,
                    title: 'Job Board',
                    subtitle: 'Remote, hybrid & on-site AI/ML roles',
                    meta: 'Live',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => JobBoardScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.document_scanner_outlined,
                    title: 'Scan Resume',
                    subtitle: 'Upload CV · get matched jobs by country',
                    meta: 'AI',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ResumeScanScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.event_outlined,
                    title: 'Events Hub',
                    subtitle: 'Webinars, conferences & meetups',
                    meta: 'Live',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EventsHubScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.verified_outlined,
                    title: 'Certifications',
                    subtitle: 'Courses from top institutions',
                    meta: 'Enroll',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CertificationScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.trending_up_rounded,
                    title: 'AI Job Forecast',
                    subtitle: 'Job market trends & demand signals',
                    meta: 'Trends',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ForecastScreen(theme: t))),
                  ),
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.show_chart_rounded,
                    title: 'AI Investment Tracker',
                    subtitle: 'Funding, sectors & capital flow',
                    meta: '\$97.8B',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
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
}

class _DiscoverCard extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onTap;

  const _DiscoverCard({
    required this.theme, required this.icon, required this.title,
    required this.subtitle, required this.meta, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.divider, width: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: t.primary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(
                      fontSize: 13, color: t.muted)),
                  ],
                ),
              ),
              Text(meta, style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500, color: t.muted)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: t.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

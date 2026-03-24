import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'job_board_screen.dart';
import 'events_hub_screen.dart';
import 'certification_screen.dart';
import 'forecast_screen.dart';
import 'investment_screen.dart';

class DiscoverScreen extends StatelessWidget {
  final AppTheme theme;
  const DiscoverScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text('Discover', style: GoogleFonts.sourceSerif4(
                  fontSize: 28, fontWeight: FontWeight.w700, color: t.primary)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                child: Text('AI/ML career, events & insights', style: GoogleFonts.inter(
                  fontSize: 14, color: t.muted)),
              ),
            ),
            SliverToBoxAdapter(child: Divider(height: 1, color: t.divider)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DiscoverCard(
                    theme: t,
                    icon: Icons.work_outline_rounded,
                    title: 'Job Board',
                    subtitle: 'AI/ML openings worldwide',
                    meta: 'Global',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => JobBoardScreen(theme: t))),
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

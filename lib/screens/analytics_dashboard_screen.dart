import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/talent_pool_service.dart';
import '../services/job_service.dart';
import '../services/events_service.dart';
import '../services/certification_service.dart';

class AnalyticsDashboardScreen extends StatelessWidget {
  final AppTheme theme;
  const AnalyticsDashboardScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final stats = TalentPoolService.getPoolStats();
    final specializations = stats['specializations'] as Map<String, int>;
    final locations = stats['locationBreakdown'] as Map<String, int>;
    final experience = stats['experienceDistribution'] as Map<String, int>;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Analytics', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero metric
            _HeroCard(theme: t),
            const SizedBox(height: 16),

            // Platform overview
            Text('Platform Overview', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricCard(
                  theme: t, icon: Icons.work_outline_rounded,
                  value: '${JobService.totalJobs}', label: 'Active Jobs',
                  color: const Color(0xFF2196F3))),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(
                  theme: t, icon: Icons.event_outlined,
                  value: '${EventsService.totalEvents}', label: 'Upcoming Events',
                  color: const Color(0xFF9C27B0))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MetricCard(
                  theme: t, icon: Icons.verified_outlined,
                  value: '${CertificationService.totalCerts}', label: 'Certifications',
                  color: const Color(0xFFFF9800))),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(
                  theme: t, icon: Icons.people_outline_rounded,
                  value: '${TalentPoolService.totalProfiles}', label: 'Elite Profiles',
                  color: t.accent)),
              ],
            ),
            const SizedBox(height: 24),

            // Talent Pool Exclusivity
            Text('Talent Pool Exclusivity', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 12),
            _ExclusivityCard(theme: t, stats: stats),
            const SizedBox(height: 24),

            // Specialization breakdown
            Text('Specialization Breakdown', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 12),
            _BreakdownCard(theme: t, data: specializations, colors: _specColors),
            const SizedBox(height: 24),

            // Geographic distribution
            Text('Geographic Distribution', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 12),
            _BreakdownCard(theme: t, data: locations, colors: _geoColors),
            const SizedBox(height: 24),

            // Experience distribution
            Text('Experience Distribution', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 12),
            _BarChartCard(theme: t, data: experience),
            const SizedBox(height: 24),

            // Industry context
            Text('Industry Context', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 12),
            _InsightCard(theme: t, icon: Icons.trending_up_rounded,
              title: 'AI/ML Job Growth',
              value: '+42%', subtitle: 'Year-over-year increase in AI/ML job postings globally'),
            const SizedBox(height: 10),
            _InsightCard(theme: t, icon: Icons.attach_money_rounded,
              title: 'Average Senior AI Salary',
              value: '\$195K', subtitle: 'Median base compensation for senior AI/ML engineers in the US'),
            const SizedBox(height: 10),
            _InsightCard(theme: t, icon: Icons.school_rounded,
              title: 'Certification Demand',
              value: '+67%', subtitle: 'Increase in AI certification enrollments since 2024'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static const _specColors = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFFF9800),
    Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFF00BCD4),
    Color(0xFF795548), Color(0xFF607D8B), Color(0xFFFF5722), Color(0xFF3F51B5),
  ];

  static const _geoColors = [
    Color(0xFF1A8917), Color(0xFF2196F3), Color(0xFFFF9800),
    Color(0xFFE91E63), Color(0xFF9C27B0),
  ];
}

class _HeroCard extends StatelessWidget {
  final AppTheme theme;
  const _HeroCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.accent.withValues(alpha: 0.15), t.accent.withValues(alpha: 0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text('The Elite 0.33%', style: GoogleFonts.sourceSerif4(
            fontSize: 28, fontWeight: FontWeight.w600, color: t.accent)),
          const SizedBox(height: 8),
          Text(
            'Out of ~30 million IT professionals worldwide, only ~99,000 possess the specialized AI/ML expertise that defines this concentrated talent pool.',
            style: GoogleFonts.inter(fontSize: 13, color: t.secondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HeroStat(value: '30M', label: 'IT Workforce', theme: t),
              Container(width: 1, height: 30, color: t.divider),
              _HeroStat(value: '~99K', label: 'AI/ML Elite', theme: t),
              Container(width: 1, height: 30, color: t.divider),
              _HeroStat(value: '0.33%', label: 'Concentration', theme: t),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final AppTheme theme;

  const _HeroStat({required this.value, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w700, color: theme.primary)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: theme.muted)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricCard({required this.theme, required this.icon, required this.value,
    required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700, color: t.primary)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
        ],
      ),
    );
  }
}

class _ExclusivityCard extends StatelessWidget {
  final AppTheme theme;
  final Map<String, dynamic> stats;

  const _ExclusivityCard({required this.theme, required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final total = stats['totalITWorkforce'] as int;
    final elite = stats['elitePoolSize'] as int;
    final pct = stats['topPercentile'] as double;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual bar
          Text('Talent Concentration', style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Container(color: t.background),
                  FractionallySizedBox(
                    widthFactor: pct / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  // Since 0.33% is too thin, show a minimum visual
                  Positioned(
                    left: 0, top: 0, bottom: 0,
                    child: Container(
                      width: 12,
                      decoration: BoxDecoration(
                        color: t.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                color: t.accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('AI/ML Elite (~${_fmt(elite)})', style: GoogleFonts.inter(
                fontSize: 12, color: t.secondary)),
              const Spacer(),
              Container(width: 10, height: 10, decoration: BoxDecoration(
                color: t.background, borderRadius: BorderRadius.circular(2),
                border: Border.all(color: t.divider))),
              const SizedBox(width: 6),
              Text('Total IT (${_fmt(total)})', style: GoogleFonts.inter(
                fontSize: 12, color: t.muted)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: t.divider, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ExclusivityStat(label: 'Available Now', value: '${stats['availableNow']}', theme: t)),
              Expanded(child: _ExclusivityStat(label: 'Total Papers', value: '${stats['totalPublications']}', theme: t)),
              Expanded(child: _ExclusivityStat(label: 'Total Patents', value: '${stats['totalPatents']}', theme: t)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

class _ExclusivityStat extends StatelessWidget {
  final String label;
  final String value;
  final AppTheme theme;

  const _ExclusivityStat({required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: theme.primary)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: theme.muted)),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final AppTheme theme;
  final Map<String, int> data;
  final List<Color> colors;

  const _BreakdownCard({required this.theme, required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final total = data.values.fold<int>(0, (s, v) => s + v);
    final entries = data.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 20,
              child: Row(
                children: entries.asMap().entries.map((e) {
                  final frac = e.value.value / total;
                  return Expanded(
                    flex: (frac * 100).round().clamp(1, 100),
                    child: Container(color: colors[e.key % colors.length]),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          ...entries.asMap().entries.map((e) {
            final pct = (e.value.value / total * 100).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: colors[e.key % colors.length],
                    borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value.key, style: GoogleFonts.inter(
                    fontSize: 12, color: t.secondary))),
                  Text('$pct%', style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: t.primary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  final AppTheme theme;
  final Map<String, int> data;

  const _BarChartCard({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final maxVal = data.values.fold<int>(0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(
        children: data.entries.map((e) {
          final pct = maxVal > 0 ? e.value / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text(e.key, style: GoogleFonts.inter(
                  fontSize: 12, color: t.secondary))),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 24,
                      child: Stack(
                        children: [
                          Container(color: t.background),
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              decoration: BoxDecoration(
                                color: t.accent.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: Text('${e.value}', style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _InsightCard({required this.theme, required this.icon,
    required this.title, required this.value, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: t.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
                    const Spacer(),
                    Text(value, style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: t.accent)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/startup.dart';
import '../services/startup_service.dart';

class StartupsScreen extends StatefulWidget {
  final AppTheme theme;
  const StartupsScreen({super.key, required this.theme});

  @override
  State<StartupsScreen> createState() => _StartupsScreenState();
}

class _StartupsScreenState extends State<StartupsScreen> with SingleTickerProviderStateMixin {
  List<AIStartup> _startups = [];
  List<JobForecast> _forecasts = [];
  bool _loading = true;
  String _categoryFilter = 'All';
  late TabController _tabCtrl;

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      StartupService.fetchStartups(category: _categoryFilter),
      StartupService.fetchForecasts(),
    ]);
    setState(() {
      _startups = results[0] as List<AIStartup>;
      _forecasts = results[1] as List<JobForecast>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Startups & Forecast', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabCtrl,
                labelColor: t.primary,
                unselectedLabelColor: t.muted,
                indicatorColor: t.primary,
                indicatorWeight: 1.5,
                labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'AI Startups'),
                  Tab(text: 'Job Forecast'),
                ],
              ),
              Divider(height: 1, color: t.divider),
            ],
          ),
        ),
      ),
      body: _loading
        ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
        : TabBarView(
            controller: _tabCtrl,
            children: [
              _buildStartupsTab(),
              _buildForecastTab(),
            ],
          ),
    );
  }

  Widget _buildStartupsTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(value: '${StartupService.totalStartups}', label: 'Tracked', theme: t),
              Container(width: 1, height: 28, color: t.divider),
              _MiniStat(value: '${StartupService.newThisMonth}', label: 'New', theme: t),
              Container(width: 1, height: 28, color: t.divider),
              _MiniStat(value: '\$12.4B', label: 'Total Raised', theme: t),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildChip('All', _categoryFilter == 'All', () {
                setState(() => _categoryFilter = 'All'); _load(); }),
              ...StartupService.categories.map((c) =>
                _buildChip(c, _categoryFilter == c, () {
                  setState(() => _categoryFilter = c); _load(); }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: _startups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _StartupCard(startup: _startups[i], theme: t),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider, width: 0.5),
          ),
          child: Column(
            children: [
              Text('2026 AI Job Market', style: GoogleFonts.sourceSerif4(
                fontSize: 22, fontWeight: FontWeight.w700, color: t.primary)),
              const SizedBox(height: 4),
              Text('Year-over-year growth in AI/ML roles', style: GoogleFonts.inter(
                fontSize: 13, color: t.muted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._forecasts.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ForecastCard(forecast: f, theme: t),
        )),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildChip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? t.primary.withValues(alpha: 0.2) : t.divider),
          ),
          child: Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? t.primary : t.secondary)),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final AppTheme theme;
  const _MiniStat({required this.value, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: theme.primary)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: theme.muted)),
    ]);
  }
}

class _StartupCard extends StatelessWidget {
  final AIStartup startup;
  final AppTheme theme;
  const _StartupCard({required this.startup, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () async {
        if (startup.website != null) {
          final uri = Uri.parse('https://${startup.website}');
          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(startup.name[0],
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: t.primary))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(startup.name, style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: t.primary))),
                      if (startup.isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text('New', style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text('${startup.category} · ${startup.location}',
                      style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 10),
            Text(startup.description, style: GoogleFonts.inter(
              fontSize: 13, color: t.secondary, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: startup.tags.map((tag) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.background, borderRadius: BorderRadius.circular(4)),
                child: Text(tag, style: GoogleFonts.inter(
                  fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
              ),
            ).toList()),
            const SizedBox(height: 12),
            Row(children: [
              Text(startup.stage, style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: t.primary)),
              if (startup.funding != null) ...[
                const SizedBox(width: 8),
                Text(startup.funding!, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: t.accent)),
              ],
              if (startup.teamSize != null) ...[
                const Spacer(),
                Icon(Icons.people_outline_rounded, size: 13, color: t.muted),
                const SizedBox(width: 4),
                Text('${startup.teamSize}', style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted)),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: t.muted),
              const SizedBox(width: 4),
              Text('Founded ${startup.founded}', style: GoogleFonts.inter(
                fontSize: 12, color: t.muted)),
              if (startup.lastFundingDate != null) ...[
                const Spacer(),
                Text('Last funded ${startup.lastFundingDate}', style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted)),
              ],
            ]),
            if (startup.website != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.open_in_new_rounded, size: 12, color: t.accent),
                const SizedBox(width: 4),
                Text(startup.website!, style: GoogleFonts.inter(
                  fontSize: 12, color: t.accent)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final JobForecast forecast;
  final AppTheme theme;
  const _ForecastCard({required this.forecast, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final maxGrowth = 160.0;
    final barWidth = (forecast.growthPercent / maxGrowth).clamp(0.05, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(forecast.role, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: t.primary))),
            Icon(
              forecast.trend == 'up' ? Icons.trending_up_rounded :
              forecast.trend == 'down' ? Icons.trending_down_rounded :
              Icons.trending_flat_rounded,
              size: 18,
              color: t.muted,
            ),
            const SizedBox(width: 6),
            Text('+${forecast.growthPercent.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: t.accent)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Stack(children: [
                Container(color: t.background),
                FractionallySizedBox(
                  widthFactor: barWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _ForecastMeta(label: 'Openings', value: _fmtNum(forecast.currentOpenings), theme: t),
            const SizedBox(width: 16),
            _ForecastMeta(label: 'Avg Salary', value: forecast.avgSalary, theme: t),
            const Spacer(),
            Text(forecast.demandLevel, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: t.secondary)),
          ]),
        ],
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }
}

class _ForecastMeta extends StatelessWidget {
  final String label, value;
  final AppTheme theme;
  const _ForecastMeta({required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: theme.primary)),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: theme.muted)),
    ]);
  }
}

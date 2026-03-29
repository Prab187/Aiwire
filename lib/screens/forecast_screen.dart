import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/startup.dart';
import '../services/startup_service.dart';
import 'job_board_screen.dart';

class ForecastScreen extends StatefulWidget {
  final AppTheme theme;
  const ForecastScreen({super.key, required this.theme});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  List<JobForecast> _forecasts = [];
  bool _loading = true;
  String _geoFilter = 'Global';

  AppTheme get t => widget.theme;

  static const _geoMultipliers = {
    'Global': 1.0,
    'US': 1.1,
    'UK': 0.85,
    'Asia': 1.25,
    'Europe': 0.9,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final forecasts = await StartupService.fetchForecasts();
    setState(() {
      _forecasts = forecasts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final multiplier = _geoMultipliers[_geoFilter] ?? 1.0;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('AI Job Forecast', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header card
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
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 13, color: t.muted),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Source: LinkedIn Talent Insights · BLS · World Economic Forum',
                              style: GoogleFonts.inter(fontSize: 11, color: t.muted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Data as of Q1 2026',
                        style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Geographic filter chips
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _geoMultipliers.keys.map((geo) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _geoFilter = geo),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _geoFilter == geo
                                ? t.primary.withValues(alpha: 0.08)
                                : t.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _geoFilter == geo
                                  ? t.primary.withValues(alpha: 0.2)
                                  : t.divider),
                          ),
                          child: Text(geo, style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: _geoFilter == geo ? FontWeight.w600 : FontWeight.w500,
                            color: _geoFilter == geo ? t.primary : t.secondary)),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ..._forecasts.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ForecastCard(
                    forecast: f,
                    theme: t,
                    multiplier: multiplier,
                  ),
                )),
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final JobForecast forecast;
  final AppTheme theme;
  final double multiplier;

  const _ForecastCard({
    required this.forecast,
    required this.theme,
    required this.multiplier,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final displayGrowth = forecast.growthPercent * multiplier;
    final displayOpenings = forecast.currentOpenings * multiplier;
    final isPositive = displayGrowth >= 0;

    // Bar width: capped at 200%
    final barWidth = min(displayGrowth.abs() / 200.0, 1.0);

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
          Row(
            children: [
              Expanded(
                child: Text(forecast.role, style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? t.primary.withValues(alpha: 0.08)
                      : Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${displayGrowth.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isPositive ? t.primary : Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${forecast.demandLevel} demand · Avg: ${forecast.avgSalary}',
            style: GoogleFonts.inter(fontSize: 13, color: t.muted, height: 1.4)),
          const SizedBox(height: 10),
          // Horizontal progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(children: [
                Container(color: t.background),
                FractionallySizedBox(
                  widthFactor: barWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isPositive
                          ? t.primary.withValues(alpha: 0.25)
                          : Colors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${displayOpenings.toStringAsFixed(0)} openings',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Trend: ${forecast.trend}',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // See open roles link
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => JobBoardScreen(theme: t, initialQuery: forecast.role),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 13, color: t.accent),
                  const SizedBox(width: 4),
                  Text('See open roles',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500, color: t.accent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/startup.dart';
import '../services/startup_service.dart';

class ForecastScreen extends StatefulWidget {
  final AppTheme theme;
  const ForecastScreen({super.key, required this.theme});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  List<JobForecast> _forecasts = [];
  bool _loading = true;

  AppTheme get t => widget.theme;

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
    final isPositive = forecast.growthPercent >= 0;
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
                  '${isPositive ? '+' : ''}${forecast.growthPercent.toStringAsFixed(1)}%',
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${forecast.currentOpenings.toStringAsFixed(0)} openings',
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
        ],
      ),
    );
  }
}

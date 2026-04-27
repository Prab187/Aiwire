import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/job_service.dart';
import 'job_board_screen.dart';

/// Live AI Job Forecast — pulls real job counts from the same APIs the Job Board
/// uses (Remotive, Adzuna, The Muse, Arbeitnow), so numbers reflect ACTUAL open
/// positions right now, not hardcoded data.
class ForecastScreen extends StatefulWidget {
  final AppTheme theme;
  const ForecastScreen({super.key, required this.theme});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  bool _loading = true;
  String? _error;
  List<_RoleStats> _stats = [];

  // Detected user location
  String _userCountry = '';
  String _userCountryCode = '';
  String _userCity = '';

  AppTheme get t => widget.theme;

  // Roles to probe live job APIs for
  static const _roles = [
    'ML Engineer',
    'Data Scientist',
    'AI Researcher',
    'MLOps Engineer',
    'NLP Engineer',
    'Computer Vision Engineer',
    'AI Product Manager',
    'Prompt Engineer',
    'LLM Engineer',
    'AI Ethics Specialist',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    // 1. Detect user's location: resume > device locale > 'us' last resort
    await _detectLocation();

    // 2. Query real job APIs for each role in parallel
    try {
      final results = await Future.wait(_roles.map((role) async {
        try {
          final jobs = await JobService.fetchJobs(
            query: role,
            country: _userCountryCode,
          );
          // Compute average salary across jobs that disclosed one
          final salaries = <int>[];
          for (final j in jobs) {
            final match = RegExp(r'(\d+)\s*[Kk]').firstMatch(j.salaryRange);
            final group = match?.group(1);
            if (group != null) {
              final val = int.tryParse(group);
              if (val != null && val >= 30 && val <= 500) salaries.add(val);
            }
          }
          final avgK = salaries.isEmpty
              ? null
              : (salaries.reduce((a, b) => a + b) / salaries.length).round();
          return _RoleStats(
            role: role,
            openings: jobs.length,
            avgSalaryK: avgK,
            demandLevel: _demandFromCount(jobs.length),
          );
        } catch (_) {
          return _RoleStats(role: role, openings: 0, demandLevel: 'Unknown');
        }
      }));

      // Sort by openings descending
      results.sort((a, b) => b.openings.compareTo(a.openings));

      if (mounted) setState(() {
        _stats = results;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Maps ISO country codes to Adzuna-supported codes (lowercase)
  static const _adzunaCountries = {
    'us','gb','ca','au','de','fr','in','nl','br','za','pl','es','it',
    'at','be','ch','nz','mx','sg','ru','se',
  };
  // Map country_code → full display name so header shows a proper city/country
  static const _codeToName = {
    'us': 'United States', 'gb': 'United Kingdom', 'ca': 'Canada',
    'au': 'Australia', 'de': 'Germany', 'fr': 'France', 'in': 'India',
    'nl': 'Netherlands', 'br': 'Brazil', 'za': 'South Africa',
    'pl': 'Poland', 'es': 'Spain', 'it': 'Italy', 'at': 'Austria',
    'be': 'Belgium', 'ch': 'Switzerland', 'nz': 'New Zealand',
    'mx': 'Mexico', 'sg': 'Singapore', 'ru': 'Russia', 'se': 'Sweden',
  };

  Future<void> _detectLocation() async {
    // PRIORITY 1: Resume-scanned country (most reliable signal)
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('user_country');
      final code = prefs.getString('user_country_code');
      if (saved != null && saved.isNotEmpty && code != null && code.isNotEmpty) {
        _userCountry = saved;
        _userCountryCode = code.toLowerCase();
        return;
      }
    } catch (_) {}

    // PRIORITY 2: Device locale (for users who haven't scanned a resume)
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final localeCc = locale.countryCode?.toLowerCase();
      if (localeCc != null && _adzunaCountries.contains(localeCc)) {
        _userCountryCode = localeCc;
        _userCountry = _codeToName[localeCc] ?? '';
        return;
      }
    } catch (_) {}

    // PRIORITY 3: Fall back to 'us' — only if all else fails
    _userCountryCode = 'us';
    _userCountry = 'United States';
  }

  String _demandFromCount(int n) {
    if (n >= 40) return 'Extreme';
    if (n >= 20) return 'Very High';
    if (n >= 10) return 'High';
    if (n >= 5) return 'Moderate';
    if (n >= 1) return 'Low';
    return 'No data';
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
          fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: t.primary, size: 20),
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: _loading
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: t.primary, strokeWidth: 1.5),
              const SizedBox(height: 16),
              Text('Querying live job boards…', style: GoogleFonts.inter(
                fontSize: 13, color: t.muted)),
            ]))
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Could not load forecast: $_error',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: t.muted))))
              : RefreshIndicator(
                  color: t.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      ..._stats.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ForecastCard(
                          stats: s, theme: t,
                          userCountry: _userCountry,
                          userCountryCode: _userCountryCode,
                          userCity: _userCity,
                        ),
                      )),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final totalOpenings = _stats.fold<int>(0, (sum, s) => sum + s.openings);
    final locationText = _userCountry.isEmpty
        ? 'Global market'
        : '${_userCity.isEmpty ? _userCountry : "$_userCity, $_userCountry"}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(children: [
        Text('AI Job Market', style: GoogleFonts.sourceSerif4(
          fontSize: 22, fontWeight: FontWeight.w700, color: t.primary)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.location_on_outlined, size: 13, color: t.muted),
          const SizedBox(width: 4),
          Text(locationText, style: GoogleFonts.inter(
            fontSize: 13, color: t.muted)),
        ]),
        const SizedBox(height: 12),
        Text(totalOpenings.toString(), style: GoogleFonts.sourceSerif4(
          fontSize: 34, fontWeight: FontWeight.w700, color: t.primary, height: 1)),
        const SizedBox(height: 4),
        Text('Open AI/ML positions found right now', style: GoogleFonts.inter(
          fontSize: 12, color: t.muted)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bolt_rounded, size: 12, color: const Color(0xFF10B981)),
            const SizedBox(width: 5),
            Text('Live data · refreshed now', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: const Color(0xFF047857))),
          ]),
        ),
      ]),
    );
  }
}

class _RoleStats {
  final String role;
  final int openings;
  final int? avgSalaryK;
  final String demandLevel;
  _RoleStats({
    required this.role,
    required this.openings,
    this.avgSalaryK,
    required this.demandLevel,
  });
}

class _ForecastCard extends StatelessWidget {
  final _RoleStats stats;
  final AppTheme theme;
  final String userCountry;
  final String userCountryCode;
  final String userCity;

  const _ForecastCard({
    required this.stats,
    required this.theme,
    required this.userCountry,
    required this.userCountryCode,
    required this.userCity,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;

    // Demand color
    final demandColor = stats.openings >= 20
        ? const Color(0xFF10B981)
        : stats.openings >= 5
            ? const Color(0xFFF59E0B)
            : t.muted;

    // Bar width based on openings relative to a realistic max (50)
    final barWidth = (stats.openings / 50.0).clamp(0.0, 1.0);

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
          Row(children: [
            Expanded(
              child: Text(stats.role, style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
            ),
            // Big openings number
            Text('${stats.openings}', style: GoogleFonts.sourceSerif4(
              fontSize: 22, fontWeight: FontWeight.w700, color: demandColor)),
            const SizedBox(width: 4),
            Text('open', style: GoogleFonts.inter(
              fontSize: 11, color: t.muted, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: demandColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
              child: Text(stats.demandLevel, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: demandColor)),
            ),
            if (stats.avgSalaryK != null) ...[
              const SizedBox(width: 8),
              Text('Avg salary: \$${stats.avgSalaryK}K', style: GoogleFonts.inter(
                fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
            ],
          ]),
          const SizedBox(height: 10),
          // Visual bar showing openings
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(children: [
                Container(color: t.background),
                FractionallySizedBox(
                  widthFactor: barWidth,
                  child: Container(decoration: BoxDecoration(
                    color: demandColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3))),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // See open roles — now opens Job Board filtered to user's country
          GestureDetector(
            onTap: stats.openings == 0 ? null : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobBoardScreen(
                    theme: t,
                    initialQuery: stats.role,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: stats.openings == 0 ? null : t.primary.withValues(alpha: 0.06),
                border: Border.all(
                  color: stats.openings == 0
                      ? t.divider
                      : t.primary.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_forward_rounded, size: 14,
                  color: stats.openings == 0 ? t.muted : t.primary),
                const SizedBox(width: 6),
                Text(
                  stats.openings == 0
                      ? 'No open roles'
                      : userCountry.isEmpty
                          ? 'See ${stats.openings} roles'
                          : 'See roles in $userCountry',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: stats.openings == 0 ? t.muted : t.primary)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

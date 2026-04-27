import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'job_board_screen.dart';
import 'events_hub_screen.dart';
import 'certification_screen.dart';
import 'forecast_screen.dart';
import 'investment_screen.dart';
import 'resume_scan_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final AppTheme theme;
  const DiscoverScreen({super.key, required this.theme});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchCtrl = TextEditingController();

  AppTheme get t => widget.theme;

  void _search(String query) {
    if (query.trim().isEmpty) return;
    _searchCtrl.clear();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobBoardScreen(theme: t, initialQuery: query.trim()),
      ),
    );
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            // ── Title ──
            Text(
              'Discover',
              style: GoogleFonts.sourceSerif4(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: t.primary,
              ),
            ),

            const SizedBox(height: 24),

            // ── Search ──
            TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(fontSize: 15, color: t.primary),
              decoration: InputDecoration(
                hintText: 'Search jobs, roles, skills...',
                hintStyle: GoogleFonts.inter(fontSize: 15, color: t.muted),
                prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 22),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: _searchCtrl,
                  builder: (_, v, __) => v.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: Icon(Icons.close_rounded, color: t.muted, size: 18),
                        )
                      : const SizedBox.shrink(),
                ),
                filled: true,
                fillColor: t.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.primary, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
            ),

            const SizedBox(height: 32),

            // ── Rows ──
            _row('Find Jobs', 'Near you, remote, hybrid', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => JobBoardScreen(theme: t)));
            }),
            _row('Scan Resume', 'AI matches your CV to top roles', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ResumeScanScreen(theme: t)));
            }),
            _row('Events Hub', 'Webinars, conferences & meetups', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => EventsHubScreen(theme: t)));
            }),
            _row('Certifications', 'Top courses from Google, AWS & more', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CertificationScreen(theme: t)));
            }),
            _row('AI Job Forecast', 'Market trends & demand by role', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ForecastScreen(theme: t)));
            }),
            _row('AI Investment Tracker', 'Funding rounds, sectors & capital flow',
                () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => InvestmentScreen(theme: t)));
            }, showDivider: false),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, String subtitle, VoidCallback onTap,
      {bool showDivider = true}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: t.divider, width: 0.5),
                ),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 13, color: t.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.muted, size: 16),
          ],
        ),
      ),
    );
  }
}

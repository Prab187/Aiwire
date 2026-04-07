import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/career_progress_service.dart';
import '../services/application_tracker_service.dart';

class CareerProgressScreen extends StatefulWidget {
  final AppTheme theme;
  const CareerProgressScreen({super.key, required this.theme});

  @override
  State<CareerProgressScreen> createState() => _CareerProgressScreenState();
}

class _CareerProgressScreenState extends State<CareerProgressScreen> {
  List<CareerSnapshot> _snapshots = [];
  int _streak = 0;
  Map<AppStatus, int> _appCounts = {};
  bool _loading = true;

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snaps = await CareerProgressService.all();
    final streak = await CareerProgressService.updateStreak();
    final counts = await ApplicationTrackerService.counts();

    // Add today's snapshot from current profile if not present
    final prefs = await SharedPreferences.getInstance();
    final skills = prefs.getStringList('user_skills') ?? [];
    final level = prefs.getString('user_level') ?? 'Mid';
    if (skills.isNotEmpty) {
      final today = DateTime.now().toIso8601String();
      final hasToday = snaps.any((s) => s.date.substring(0, 10) == today.substring(0, 10));
      if (!hasToday) {
        await CareerProgressService.add(CareerSnapshot(
          date: today,
          skillsCount: skills.length,
          matchScore: 0,
          atsScore: 0,
          level: level,
          skills: skills,
        ));
      }
    }

    final updated = await CareerProgressService.all();
    if (mounted) setState(() {
      _snapshots = updated..sort((a, b) => a.date.compareTo(b.date));
      _streak = streak;
      _appCounts = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final first = _snapshots.isNotEmpty ? _snapshots.first : null;
    final last = _snapshots.isNotEmpty ? _snapshots.last : null;
    final skillsDelta = (first != null && last != null)
        ? last.skillsCount - first.skillsCount
        : 0;
    final totalApps = _appCounts.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Career Progress', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Streak hero
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        const Color(0xFFEF4444).withValues(alpha: 0.08),
                      ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25))),
                  child: Row(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.local_fire_department_rounded,
                        size: 36, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$_streak day${_streak == 1 ? "" : "s"}', style: GoogleFonts.sourceSerif4(
                        fontSize: 28, fontWeight: FontWeight.w700, color: t.primary)),
                      Text(_streak == 0 ? 'Start your streak today' : 'Career streak ',
                        style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),

                // Stats grid
                Row(children: [
                  Expanded(child: _statCard(
                    label: 'Skills',
                    value: '${last?.skillsCount ?? 0}',
                    delta: skillsDelta > 0 ? '+$skillsDelta' : null,
                    color: const Color(0xFF3B82F6),
                    icon: Icons.bolt_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard(
                    label: 'Applications',
                    value: '$totalApps',
                    color: const Color(0xFF10B981),
                    icon: Icons.work_outline_rounded)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _statCard(
                    label: 'Interviews',
                    value: '${_appCounts[AppStatus.interviewing] ?? 0}',
                    color: const Color(0xFFF59E0B),
                    icon: Icons.event_available_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard(
                    label: 'Offers',
                    value: '${_appCounts[AppStatus.offer] ?? 0}',
                    color: const Color(0xFF8B5CF6),
                    icon: Icons.celebration_outlined)),
                ]),
                const SizedBox(height: 24),

                // Skill growth chart
                if (_snapshots.length >= 2) ...[
                  Text('Skill growth', style: GoogleFonts.sourceSerif4(
                    fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
                  const SizedBox(height: 4),
                  Text('${_snapshots.length} snapshots over ${_daysSpan()} days',
                    style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.surface, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.divider, width: 0.5)),
                    child: SizedBox(height: 120, child: _SparkChart(
                      data: _snapshots.map((s) => s.skillsCount.toDouble()).toList(),
                      color: const Color(0xFF3B82F6),
                      theme: t)),
                  ),
                ],

                const SizedBox(height: 24),
                if (last != null) ...[
                  Text('Current snapshot', style: GoogleFonts.sourceSerif4(
                    fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.surface, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.divider, width: 0.5)),
                    child: Wrap(spacing: 6, runSpacing: 6, children: last.skills.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(s, style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500, color: t.primary)),
                    )).toList()),
                  ),
                ],
                const SizedBox(height: 40),
              ]),
            ),
    );
  }

  int _daysSpan() {
    if (_snapshots.length < 2) return 0;
    try {
      final a = DateTime.parse(_snapshots.first.date);
      final b = DateTime.parse(_snapshots.last.date);
      return b.difference(a).inDays;
    } catch (_) { return 0; }
  }

  Widget _statCard({
    required String label,
    required String value,
    String? delta,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color),
          ),
          if (delta != null) ...[
            const Spacer(),
            Text(delta, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
          ],
        ]),
        const SizedBox(height: 12),
        Text(value, style: GoogleFonts.sourceSerif4(
          fontSize: 26, fontWeight: FontWeight.w700, color: t.primary)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
      ]),
    );
  }
}

class _SparkChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  final AppTheme theme;
  const _SparkChart({required this.data, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkPainter(data: data, color: color, dividerColor: theme.divider),
      child: const SizedBox.expand(),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color dividerColor;
  _SparkPainter({required this.data, required this.color, required this.dividerColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs() < 0.01 ? 1.0 : maxVal - minVal;

    // Grid line
    final gridPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fill = Path();
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1 ? size.width / 2 : (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, linePaint);

    // Dots
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1 ? size.width / 2 : (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

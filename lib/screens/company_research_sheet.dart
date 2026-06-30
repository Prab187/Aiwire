import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/company_research_service.dart';
import '../models/resume_profile.dart';

class CompanyResearchSheet extends StatefulWidget {
  final String company;
  final String jobTitle;
  final ResumeProfile profile;
  final AppTheme theme;

  const CompanyResearchSheet({
    super.key,
    required this.company,
    required this.jobTitle,
    required this.profile,
    required this.theme,
  });

  @override
  State<CompanyResearchSheet> createState() => _CompanyResearchSheetState();
}

class _CompanyResearchSheetState extends State<CompanyResearchSheet>
    with SingleTickerProviderStateMixin {
  String? _result;
  String? _error;
  bool _loading = true;
  String _statusMessage = '';
  Timer? _statusRotator;

  // Pulse animation for the research icon while loading — mirrors the
  // brain animation used on the resume-analysis screen.
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  static const _sections = [
    ('AI STRATEGY', 'AI Strategy', Icons.smart_toy_outlined, Color(0xFF3B82F6)),
    ('RECENT MOVES', 'Recent Moves', Icons.trending_up_rounded, Color(0xFF10B981)),
    ('ENGINEERING CULTURE', 'Engineering Culture', Icons.code_rounded, Color(0xFF8B5CF6)),
    ('KEY CHALLENGES', 'Key Challenges', Icons.warning_amber_rounded, Color(0xFFF59E0B)),
    ('COMPETITORS', 'Competitors', Icons.groups_outlined, Color(0xFFEC4899)),
    ('HOW TO POSITION YOURSELF', 'How to Position Yourself', Icons.person_pin_outlined, Color(0xFF6366F1)),
  ];

  // Rotating status messages that name what the research is actually doing.
  // {company} is replaced with the company name at runtime.
  static const List<String> _researchSteps = [
    'Connecting to the research desk…',
    'Reading recent news about {company}…',
    'Mapping {company}\'s AI strategy…',
    'Tracking their recent moves & launches…',
    'Surveying engineering culture & stack…',
    'Spotting key challenges they\'re facing…',
    'Sizing up the competitive landscape…',
    'Drafting your positioning angle…',
    'Polishing the brief…',
    'Almost there…',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _startStatusRotator();
    _fetch();
  }

  @override
  void dispose() {
    _statusRotator?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startStatusRotator() {
    _statusRotator?.cancel();
    var i = 0;
    setState(() => _statusMessage = _renderStep(_researchSteps[0]));
    _statusRotator = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted) return;
      i = (i + 1) % _researchSteps.length;
      setState(() => _statusMessage = _renderStep(_researchSteps[i]));
    });
  }

  String _renderStep(String template) =>
      template.replaceAll('{company}', widget.company);

  void _stopStatusRotator() {
    _statusRotator?.cancel();
    _statusRotator = null;
  }

  Future<void> _fetch() async {
    try {
      final text = await CompanyResearchService.research(
        company: widget.company,
        jobTitle: widget.jobTitle,
        profile: widget.profile,
      );
      _stopStatusRotator();
      if (mounted) setState(() { _result = text; _loading = false; });
    } catch (e) {
      _stopStatusRotator();
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<({String title, String body, IconData icon, Color color})> _parse(String text) {
    final result = <({String title, String body, IconData icon, Color color})>[];
    final lines = text.split('\n');
    int? currentIdx;
    final buf = StringBuffer();

    void flush() {
      final ci = currentIdx;
      if (ci != null) {
        final s = _sections[ci];
        final body = buf.toString().trim();
        if (body.isNotEmpty) {
          result.add((title: s.$2, body: body, icon: s.$3, color: s.$4));
        }
      }
      buf.clear();
    }

    for (final line in lines) {
      // Strip markdown markers (**, ##, ###, - at start) and whitespace
      final stripped = line
          .replaceAll(RegExp(r'\*{1,3}'), '')
          .replaceAll(RegExp(r'^#{1,6}\s*'), '')
          .trim();
      final upper = stripped.toUpperCase();

      // Match if line starts with OR equals a section name (with optional trailing colon)
      int idx = -1;
      for (int i = 0; i < _sections.length; i++) {
        final name = _sections[i].$1;
        if (upper == name ||
            upper == '$name:' ||
            upper.startsWith('$name ') ||
            upper.startsWith('$name:')) {
          idx = i;
          break;
        }
      }

      if (idx >= 0) {
        flush();
        currentIdx = idx;
        // If there's text after the header on the same line, include it
        final remaining = stripped.substring(_sections[idx].$1.length)
            .replaceFirst(RegExp(r'^[:\s]+'), '').trim();
        if (remaining.isNotEmpty) buf.writeln(remaining);
      } else if (currentIdx != null && stripped.isNotEmpty) {
        buf.writeln(stripped);
      }
    }
    flush();

    // Fallback: if parsing produced no sections, show raw text as a single section
    if (result.isEmpty && text.trim().isNotEmpty) {
      result.add((
        title: 'Research Brief',
        body: text.trim(),
        icon: Icons.description_outlined,
        color: const Color(0xFF3B82F6),
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle bar
          Center(child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: t.muted.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2)),
          )),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business_rounded, size: 18, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.company, style: GoogleFonts.sourceSerif4(
                  fontSize: 18, fontWeight: FontWeight.w700, color: t.primary)),
                Text('Research Brief · ${widget.jobTitle}', style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, size: 22, color: t.muted),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: t.divider),

          // Content
          Expanded(child: _loading
            ? Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Pulsing research icon — visually matches the Analyzing
                  // screen (same size, same B&W tint via t.primary, same
                  // motion); only the glyph differs to signal "research".
                  ScaleTransition(
                    scale: _pulse,
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: t.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle),
                      child: Icon(Icons.travel_explore_rounded,
                        size: 32, color: t.primary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Researching…',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: t.primary)),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      _statusMessage.isEmpty
                          ? 'Reading up on ${widget.company}…'
                          : _statusMessage,
                      key: ValueKey(_statusMessage),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14, color: t.muted, height: 1.45)),
                  ),
                ]),
              ))
            : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: t.muted),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: t.muted)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() { _loading = true; _error = null; });
                        _startStatusRotator();
                        _fetch();
                      },
                      child: Text('Try again', style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: t.accent)),
                    ),
                  ]),
                ))
              : ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    ..._parse(_result!).map((s) => _buildSection(s, t)),
                    // Copy button
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _result!));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Copied to clipboard',
                            style: GoogleFonts.inter(fontSize: 13)),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: t.divider),
                          borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.copy_rounded, size: 16, color: t.muted),
                          const SizedBox(width: 8),
                          Text('Copy Brief', style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600, color: t.secondary)),
                        ]),
                      ),
                    ),
                  ],
                ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSection(
    ({String title, String body, IconData icon, Color color}) s,
    AppTheme t,
  ) {
    final bullets = s.body.split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: s.color, width: 3)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7)),
              child: Icon(s.icon, size: 14, color: s.color),
            ),
            const SizedBox(width: 10),
            Text(s.title, style: GoogleFonts.sourceSerif4(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: t.primary, letterSpacing: -0.2)),
          ]),
        ),
        Divider(height: 1, color: t.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:
            bullets.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(width: 5, height: 5,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(b, style: GoogleFonts.sourceSerif4(
                  fontSize: 14, color: t.primary.withValues(alpha: 0.88),
                  height: 1.55))),
              ]),
            )).toList()),
        ),
      ]),
    );
  }
}

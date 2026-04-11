import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/claude_cache.dart';
import '../services/claude_error.dart';

class SalaryCalculatorScreen extends StatefulWidget {
  final AppTheme theme;
  const SalaryCalculatorScreen({super.key, required this.theme});

  @override
  State<SalaryCalculatorScreen> createState() => _SalaryCalculatorScreenState();
}

class _SalaryCalculatorScreenState extends State<SalaryCalculatorScreen> {
  String _role = 'ML Engineer';
  String _level = 'Mid';
  String _location = 'United States';
  int _years = 3;

  bool _loading = false;
  String? _error;

  // Result
  int? _p25, _p50, _p75;
  String? _negotiationScript;
  String? _insights;

  AppTheme get t => widget.theme;

  static const _roles = ['ML Engineer', 'Data Scientist', 'AI Researcher', 'MLOps Engineer', 'AI Product Manager', 'NLP Engineer', 'Computer Vision Engineer'];
  static const _levels = ['Junior', 'Mid', 'Senior', 'Lead', 'Principal'];
  static final _defaultLocations = ['United States', 'United Kingdom', 'Canada', 'Germany', 'Singapore', 'India', 'Australia', 'Remote'];
  late List<String> _locations;

  @override
  void initState() {
    super.initState();
    _locations = List.from(_defaultLocations);
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('user_job_title');
    final level = prefs.getString('user_level');
    final country = prefs.getString('user_country');
    if (title != null && _roles.contains(title)) _role = title;
    if (level != null && _levels.contains(level)) _level = level;
    // Pre-populate location from resume's detected country
    if (country != null && country.isNotEmpty) {
      if (_locations.contains(country)) {
        _location = country;
      } else {
        // Country not in the default list — add it dynamically
        _locations.insert(_locations.length - 1, country); // before "Remote"
        _location = country;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _calculate() async {
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true; _error = null;
      _p25 = null; _p50 = null; _p75 = null;
      _negotiationScript = null; _insights = null;
    });

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) {
      setState(() { _error = 'API key not configured'; _loading = false; });
      return;
    }

    // Cache by role+level+location+years (30 days — salary doesn't change fast)
    final cacheKey = ClaudeCache.keyFrom([_role, _level, _location, _years]);
    final cachedRaw = await ClaudeCache.get('salary', cacheKey,
        ttl: const Duration(days: 30));
    if (cachedRaw != null) {
      try {
        final parsed = json.decode(cachedRaw) as Map<String, dynamic>;
        setState(() {
          _p25 = (parsed['p25'] as num).toInt();
          _p50 = (parsed['p50'] as num).toInt();
          _p75 = (parsed['p75'] as num).toInt();
          _insights = parsed['insights'] as String?;
          _negotiationScript = parsed['negotiation_script'] as String?;
          _loading = false;
        });
        return;
      } catch (_) {
        // fall through to fresh fetch
      }
    }

    final prompt = '''Estimate the salary range for this AI/ML role based on current market data. Then provide a negotiation script.

ROLE: $_level $_role
LOCATION: $_location
EXPERIENCE: $_years years

Respond with ONLY a JSON object, no markdown:
{
  "p25": <25th percentile annual base in USD>,
  "p50": <50th percentile annual base in USD>,
  "p75": <75th percentile annual base in USD>,
  "insights": "2-3 sentences on what drives the range and what's typical for this role and location",
  "negotiation_script": "A specific negotiation script (4-6 sentences) the candidate can use when an offer comes in. Make it confident but not aggressive. Reference percentile data."
}''';

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': 'claude-haiku-4-5',
          'max_tokens': 700,
          'messages': [{'role': 'user', 'content': prompt}],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(claudeError(response.statusCode, response.body));
      }

      final data = json.decode(response.body);
      final raw = (data['content'][0]['text'] as String).trim();
      final cleaned = raw
          .replaceFirst(RegExp(r'^```json\s*'), '')
          .replaceFirst(RegExp(r'^```\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
      final parsed = json.decode(cleaned) as Map<String, dynamic>;
      await ClaudeCache.set('salary', cacheKey, cleaned);

      setState(() {
        _p25 = (parsed['p25'] as num).toInt();
        _p50 = (parsed['p50'] as num).toInt();
        _p75 = (parsed['p75'] as num).toInt();
        _insights = parsed['insights'] as String?;
        _negotiationScript = parsed['negotiation_script'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e.toString().replaceFirst("Exception: ", ""));
        _loading = false;
      });
    }
  }

  String _fmt(int n) {
    if (n >= 1000) return '\$${(n / 1000).round()}K';
    return '\$$n';
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
        title: Text('Salary Calculator', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF10B981).withValues(alpha: 0.15),
                const Color(0xFF22C55E).withValues(alpha: 0.08),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2))),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.payments_outlined, size: 22, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Know your worth', style: GoogleFonts.sourceSerif4(
                  fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
                const SizedBox(height: 2),
                Text('Salary range + AI negotiation script',
                  style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          _label('Role'),
          _picker(_roles, _role, (v) => setState(() => _role = v)),
          const SizedBox(height: 18),

          _label('Level'),
          _picker(_levels, _level, (v) => setState(() => _level = v)),
          const SizedBox(height: 18),

          _label('Years of experience: $_years'),
          Slider(
            value: _years.toDouble(), min: 0, max: 20, divisions: 20,
            activeColor: t.primary, inactiveColor: t.divider,
            onChanged: (v) => setState(() => _years = v.round()),
          ),
          const SizedBox(height: 12),

          _label('Location'),
          _picker(_locations, _location, (v) => setState(() => _location = v)),
          const SizedBox(height: 24),

          if (_error != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFFEF4444))),
          ),

          GestureDetector(
            onTap: _loading ? null : _calculate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: t.primary, borderRadius: BorderRadius.circular(12)),
              child: Center(child: _loading
                ? SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: t.background, strokeWidth: 2))
                : Text('Calculate Salary', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: t.background))),
            ),
          ),

          // Results
          if (_p50 != null) ...[
            const SizedBox(height: 28),
            Text('Estimated salary range', style: GoogleFonts.sourceSerif4(
              fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
            const SizedBox(height: 4),
            Text('$_level $_role · $_location · $_years yrs',
              style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.surface, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.divider, width: 0.5)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _percentile('25th', _p25!, const Color(0xFF6B7280)),
                  _percentile('Median', _p50!, const Color(0xFF10B981), big: true),
                  _percentile('75th', _p75!, const Color(0xFF6B7280)),
                ]),
                const SizedBox(height: 16),
                // Visual bar
                Container(height: 6, decoration: BoxDecoration(
                  color: t.divider, borderRadius: BorderRadius.circular(3)),
                  child: Row(children: [
                    Expanded(flex: 1, child: Container()),
                    Expanded(flex: 2, child: Container(decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(3)))),
                    Expanded(flex: 1, child: Container()),
                  ]),
                ),
              ]),
            ),
            if (_insights != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.divider, width: 0.5)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 14, color: t.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_insights!, style: GoogleFonts.inter(
                    fontSize: 13, color: t.primary.withValues(alpha: 0.85), height: 1.5))),
                ]),
              ),
            ],
            if (_negotiationScript != null) ...[
              const SizedBox(height: 24),
              Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.record_voice_over_outlined,
                    size: 14, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 10),
                Text('Negotiation script', style: GoogleFonts.sourceSerif4(
                  fontSize: 16, fontWeight: FontWeight.w700, color: t.primary)),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                      t.surface,
                    ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.18))),
                child: Text('"$_negotiationScript"', style: GoogleFonts.sourceSerif4(
                  fontSize: 14, color: t.primary, fontStyle: FontStyle.italic, height: 1.6)),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: _negotiationScript!));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Copied negotiation script',
                      style: GoogleFonts.inter(fontSize: 13)),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.divider),
                    borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.copy_rounded, size: 13, color: t.secondary),
                    const SizedBox(width: 6),
                    Text('Copy script', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: t.secondary)),
                  ])),
                ),
              ),
            ],
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _percentile(String label, int value, Color color, {bool big = false}) {
    return Column(children: [
      Text(_fmt(value), style: GoogleFonts.sourceSerif4(
        fontSize: big ? 28 : 20,
        fontWeight: FontWeight.w700,
        color: big ? color : t.muted)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(
        fontSize: 11,
        color: big ? color : t.muted,
        fontWeight: big ? FontWeight.w600 : FontWeight.w400)),
    ]);
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(s, style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w600,
      color: t.muted, letterSpacing: 0.4)),
  );

  Widget _picker(List<String> opts, String selected, ValueChanged<String> onChanged) {
    return Wrap(spacing: 8, runSpacing: 8, children: opts.map((o) {
      final sel = o == selected;
      return GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onChanged(o); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? t.primary : t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? t.primary : t.divider)),
          child: Text(o, style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? t.background : t.secondary)),
        ),
      );
    }).toList());
  }
}

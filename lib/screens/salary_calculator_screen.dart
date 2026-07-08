import '../config/secrets.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/claude_cache.dart';
import '../services/claude_error.dart';
import '../services/claude_http.dart';

import '../services/ai_quota_guard.dart';
import '../widgets/quota_paywall.dart';

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
  int? _p25, _p50, _p75;           // USD base salary
  int? _localP25, _localP50, _localP75;   // Local currency base salary
  String? _localCurrency;            // e.g. "INR", "GBP", "EUR"
  String? _localSymbol;              // e.g. "₹", "£", "€"
  int? _bonusPct;                    // Typical bonus % of base
  int? _equityAnnual;                // Annual equity in USD (if applicable)
  int? _totalCompUsd;                // Base + bonus + equity in USD
  String? _negotiationScript;
  String? _insights;
  String? _marketTrend;              // e.g. "+12% YoY"
  String? _dataCaveat;               // Source / cutoff info

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
    // Prevent double-tap race: if we're already calculating, ignore.
    if (_loading) return;
    HapticFeedback.lightImpact();
    
    // if (!await checkAiQuotaOrShowPaywall(context, t)) return;
    setState(() {
      _loading = true; _error = null;
      _p25 = null; _p50 = null; _p75 = null;
      _localP25 = null; _localP50 = null; _localP75 = null;
      _localCurrency = null; _localSymbol = null;
      _bonusPct = null; _equityAnnual = null; _totalCompUsd = null;
      _negotiationScript = null; _insights = null;
      _marketTrend = null; _dataCaveat = null;
    });

    const apiKey = Secrets.anthropicApiKey;
    if (apiKey.isEmpty) {
      setState(() { _error = 'API key not configured'; _loading = false; });
      return;
    }

    // Cache by role+level+location+years (14 days — salary changes quarterly)
    final cacheKey = ClaudeCache.keyFrom(['v2', _role, _level, _location, _years]);
    final cachedRaw = await ClaudeCache.get('salary', cacheKey,
        ttl: const Duration(days: 14));
    if (cachedRaw != null) {
      try {
        _applyParsed(json.decode(cachedRaw) as Map<String, dynamic>);
        return;
      } catch (_) {
        // fall through to fresh fetch
      }
    }

    final prompt = '''You are a compensation analyst with data from Levels.fyi, Glassdoor, Blind, LinkedIn Salary, and Payscale as of early 2026. Estimate TOTAL COMPENSATION (not just base) for this AI/ML role.

ROLE: $_level $_role
LOCATION: $_location
EXPERIENCE: $_years years

Respond with ONLY a JSON object, no markdown, no preamble:
{
  "p25": <25th percentile annual BASE salary in USD>,
  "p50": <50th percentile annual BASE salary in USD>,
  "p75": <75th percentile annual BASE salary in USD>,
  "local_currency": "<ISO currency code for $_location — e.g. INR for India, GBP for UK, EUR for Germany, USD for US>",
  "local_symbol": "<currency symbol: ₹ £ € \$ etc>",
  "local_p25": <p25 base in LOCAL currency — use 2026 exchange rates. For India multiply by ~83, UK by 0.79, EU by 0.92. Do NOT skip this.>,
  "local_p50": <p50 base in LOCAL currency>,
  "local_p75": <p75 base in LOCAL currency>,
  "typical_bonus_pct": <typical annual bonus as % of base, e.g. 10 for 10%. Use 15 for US FAANG, 10 for US non-FAANG, 12 for India product companies, 8 for India services>,
  "equity_annual_usd": <typical annual equity/RSU value in USD at market value — 0 for services/govt, 30000 for startup IC, 75000 for US non-FAANG mid, 150000 for US FAANG mid. Adjust by level.>,
  "total_comp_usd": <p50 base + bonus + equity, total in USD>,
  "market_trend": "<e.g. '+12% YoY' or 'flat' — based on real 2025-2026 trends>",
  "insights": "<3 concise sentences: (1) what drives the range for $_location specifically (company size, sector), (2) biggest factor that'd push user to p75 (specific skill or cert), (3) how remote work affects this number in $_location>",
  "negotiation_script": "<6 sentences the candidate says when offer comes. Reference their $_years years, mention p50 LOCAL currency figure explicitly, cite one specific skill from the role. Start with 'Thank you for the offer.' End with asking about total comp breakdown. Make it confident not aggressive.>",
  "data_caveat": "<1 sentence: which sources + recency, e.g. 'Based on Levels.fyi and Blind data Q4 2025; FAANG pays 30% above this p50, startups 20% below.'>"
}

CRITICAL:
- If $_location is a country that uses USD (e.g. United States), set local_currency=USD, local_symbol=\$, and local figures = USD figures.
- If $_location is "Remote", use the candidate's country context but note in insights that remote-from-India paying US rates is a 50% premium.
- Never return zero for any numeric field except equity_annual_usd (which can be 0).
- Use realistic 2026 numbers. For reference: Mid ML Engineer Bangalore India = \$35-55k base (₹29L-46L), Mid US non-FAANG = \$150-200k base + \$75k equity, Senior UK = £90-130k.

⚠️ HONESTY GUARD — REQUIRED:
- If your training data is older than 6 months for this role/location, say so in the data_caveat field.
- Prefer cautious middle estimates over bold outliers.
- If unsure about a specific number, round to nearest 5k and mention uncertainty in the insights field.
- Do NOT cite "Levels.fyi" or "Glassdoor" if you're inventing the number — only cite if genuinely drawn from that data in training.''';

    try {
      final response = await ClaudeHttp.post(
        apiKey: apiKey,
        timeout: const Duration(seconds: 45),
        body: {
          'model': 'claude-haiku-4-5',
          'max_tokens': 700,
          'messages': [{'role': 'user', 'content': prompt}],
        },
      );

      if (response.statusCode != 200) {
        throw Exception(claudeError(response.statusCode, response.body));
      }

      final data = json.decode(response.body);
      final contentList = data['content'] as List?;
      if (contentList == null || contentList.isEmpty) {
        throw Exception('Empty response from AI');
      }
      final raw = (contentList[0]['text'] as String? ?? '').trim();
      final cleaned = raw
          .replaceFirst(RegExp(r'^```json\s*'), '')
          .replaceFirst(RegExp(r'^```\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
      final parsed = json.decode(cleaned) as Map<String, dynamic>;
      await ClaudeCache.set('salary', cacheKey, cleaned);
      await AiQuotaGuard.record();
      _applyParsed(parsed);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e.toString().replaceFirst("Exception: ", ""));
        _loading = false;
      });
    }
  }

  void _applyParsed(Map<String, dynamic> parsed) {
    if (!mounted) return;
    setState(() {
      _p25 = (parsed['p25'] as num?)?.toInt();
      _p50 = (parsed['p50'] as num?)?.toInt();
      _p75 = (parsed['p75'] as num?)?.toInt();
      _localCurrency = parsed['local_currency'] as String?;
      _localSymbol = parsed['local_symbol'] as String?;
      _localP25 = (parsed['local_p25'] as num?)?.toInt();
      _localP50 = (parsed['local_p50'] as num?)?.toInt();
      _localP75 = (parsed['local_p75'] as num?)?.toInt();
      _bonusPct = (parsed['typical_bonus_pct'] as num?)?.toInt();
      _equityAnnual = (parsed['equity_annual_usd'] as num?)?.toInt();
      _totalCompUsd = (parsed['total_comp_usd'] as num?)?.toInt();
      _marketTrend = parsed['market_trend'] as String?;
      _insights = parsed['insights'] as String?;
      _negotiationScript = parsed['negotiation_script'] as String?;
      _dataCaveat = parsed['data_caveat'] as String?;
      _loading = false;
    });
  }

  /// Format a number in local currency (handles INR lakh, others as thousand)
  String _fmtLocal(int n) {
    final sym = _localSymbol ?? '\$';
    if (_localCurrency == 'INR') {
      // Indian: lakhs (100k) or crores (10M)
      if (n >= 10000000) return '$sym${(n / 10000000).toStringAsFixed(1)}Cr';
      if (n >= 100000) return '$sym${(n / 100000).toStringAsFixed(1)}L';
      return '$sym${(n / 1000).round()}K';
    }
    if (n >= 1000) return '$sym${(n / 1000).round()}K';
    return '$sym$n';
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
                // Header row: "Base salary (USD)" + market trend badge
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Base salary (USD)', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600, color: t.muted,
                    letterSpacing: 0.5)),
                  if (_marketTrend != null && _marketTrend!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.trending_up_rounded, size: 11, color: const Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(_marketTrend!, style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981))),
                      ]),
                    ),
                ]),
                const SizedBox(height: 12),
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
                // Local currency section (only if different from USD)
                if (_localCurrency != null && _localCurrency != 'USD' &&
                    _localP50 != null) ...[
                  const SizedBox(height: 18),
                  Divider(height: 1, color: t.divider),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Base salary (${_localCurrency!})', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: t.muted,
                      letterSpacing: 0.5)),
                  ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _percentileLocal('25th', _localP25!, const Color(0xFF6B7280)),
                    _percentileLocal('Median', _localP50!, const Color(0xFF3B82F6), big: true),
                    _percentileLocal('75th', _localP75!, const Color(0xFF6B7280)),
                  ]),
                ],
                // Total compensation breakdown
                if (_totalCompUsd != null) ...[
                  const SizedBox(height: 18),
                  Divider(height: 1, color: t.divider),
                  const SizedBox(height: 14),
                  Text('Total Comp (USD)', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600, color: t.muted,
                    letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _compRow('Base', _fmt(_p50!), t.primary)),
                    if (_bonusPct != null && _bonusPct! > 0)
                      Expanded(child: _compRow('Bonus', '${_bonusPct!}%', const Color(0xFF8B5CF6))),
                    if (_equityAnnual != null && _equityAnnual! > 0)
                      Expanded(child: _compRow('Equity/yr', _fmt(_equityAnnual!), const Color(0xFFF59E0B))),
                    Expanded(child: _compRow('Total', _fmt(_totalCompUsd!), const Color(0xFF10B981))),
                  ]),
                ],
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
            if (_dataCaveat != null && _dataCaveat!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 11, color: t.muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_dataCaveat!, style: GoogleFonts.inter(
                    fontSize: 11, color: t.muted, fontStyle: FontStyle.italic, height: 1.4))),
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

  Widget _percentileLocal(String label, int value, Color color, {bool big = false}) {
    return Column(children: [
      Text(_fmtLocal(value), style: GoogleFonts.sourceSerif4(
        fontSize: big ? 22 : 16,
        fontWeight: FontWeight.w700,
        color: big ? color : t.muted)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(
        fontSize: 10,
        color: big ? color : t.muted,
        fontWeight: big ? FontWeight.w600 : FontWeight.w400)),
    ]);
  }

  Widget _compRow(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: GoogleFonts.sourceSerif4(
        fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(
        fontSize: 10, color: t.muted)),
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

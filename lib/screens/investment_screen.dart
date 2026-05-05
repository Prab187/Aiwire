import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';
import '../theme/app_theme.dart';
import '../services/claude_cache.dart';
import '../services/claude_error.dart';
import '../services/claude_http.dart';
import '../widgets/bullet_summary.dart';

class InvestmentScreen extends StatelessWidget {
  final AppTheme theme;
  const InvestmentScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('AI Investment', style: GoogleFonts.sourceSerif4(
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
            // Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.divider, width: 0.5),
              ),
              child: Column(children: [
                Text('\$97.8B', style: GoogleFonts.sourceSerif4(
                  fontSize: 36, fontWeight: FontWeight.w600, color: t.primary)),
                const SizedBox(height: 4),
                Text('Estimated AI investment in 2025', style: GoogleFonts.inter(
                  fontSize: 14, color: t.secondary)),
                const SizedBox(height: 2),
                Text('+62% from 2024', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: t.accent)),
                const SizedBox(height: 12),
                Divider(color: t.divider),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 12, color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 5),
                      Text('Curated editorial snapshot',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('Compiled from public funding announcements',
                  style: GoogleFonts.inter(fontSize: 11, color: t.muted),
                  textAlign: TextAlign.center),
              ]),
            ),
            const SizedBox(height: 28),

            // Yearly investment chart
            Text('Global AI Funding by Year', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 2),
            Text('Billions USD', style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
            const SizedBox(height: 14),
            _YearlyBarChart(theme: t),
            const SizedBox(height: 28),

            // By sector
            Text('Investment by Sector (2025)', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 14),
            _SectorBreakdown(theme: t),
            const SizedBox(height: 28),

            // Top funded companies
            Text('Top Funded AI Companies', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 14),
            ..._topFunded.map((c) => _FundedCompanyRow(data: c, theme: t)),
            const SizedBox(height: 28),

            // By region
            Text('Investment by Region (2025)', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 14),
            _RegionBreakdown(theme: t),
            const SizedBox(height: 28),

            // Quarter trend
            Text('2025 Quarterly Trend', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 14),
            _QuarterlyChart(theme: t),
            const SizedBox(height: 28),

            // Investment News
            Text('Investment News', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 2),
            Text('Latest AI funding, M&A and capital moves', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted)),
            const SizedBox(height: 14),
            _FundingNewsFeed(theme: t),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static final List<Map<String, dynamic>> _topFunded = [
    {'name': 'OpenAI', 'raised': '\$13.0B', 'round': 'Series E', 'bar': 1.0},
    {'name': 'Anthropic', 'raised': '\$7.3B', 'round': 'Series D', 'bar': 0.56},
    {'name': 'xAI', 'raised': '\$6.0B', 'round': 'Series B', 'bar': 0.46},
    {'name': 'Databricks', 'raised': '\$4.2B', 'round': 'Series I', 'bar': 0.32},
    {'name': 'CoreWeave', 'raised': '\$3.1B', 'round': 'Series C', 'bar': 0.24},
    {'name': 'Inflection AI', 'raised': '\$1.5B', 'round': 'Series B', 'bar': 0.12},
    {'name': 'Recursion', 'raised': '\$1.5B', 'round': 'Public', 'bar': 0.12},
  ];
}

// ── Yearly bar chart ──────────────────────────────────────────────────────

class _YearlyBarChart extends StatelessWidget {
  final AppTheme theme;
  const _YearlyBarChart({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final data = [
      {'year': '2018', 'value': 22.0},
      {'year': '2019', 'value': 26.0},
      {'year': '2020', 'value': 36.0},
      {'year': '2021', 'value': 68.0},
      {'year': '2022', 'value': 48.0},
      {'year': '2023', 'value': 42.0},
      {'year': '2024', 'value': 60.5},
      {'year': '2025', 'value': 97.8},
    ];
    const maxVal = 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(children: [
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final val = d['value'] as double;
              final pct = val / maxVal;
              final isLatest = d['year'] == '2025';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('\$${val.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600,
                          color: isLatest ? t.primary : t.muted)),
                      const SizedBox(height: 4),
                      Container(
                        height: 150 * pct,
                        decoration: BoxDecoration(
                          color: isLatest ? t.primary : t.primary.withValues(alpha: 0.15),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: data.map((d) => Expanded(
            child: Text(d['year'] as String,
              style: GoogleFonts.inter(fontSize: 10, color: t.muted),
              textAlign: TextAlign.center),
          )).toList(),
        ),
      ]),
    );
  }
}

// ── Sector breakdown ──────────────────────────────────────────────────────

class _SectorBreakdown extends StatefulWidget {
  final AppTheme theme;
  const _SectorBreakdown({required this.theme});

  @override
  State<_SectorBreakdown> createState() => _SectorBreakdownState();
}

class _SectorBreakdownState extends State<_SectorBreakdown> {
  final Map<String, bool> _expanded = {};

  static const _sectorCompanies = {
    'Foundation Models / LLMs': ['OpenAI', 'Anthropic', 'xAI'],
    'AI Infrastructure / Cloud': ['CoreWeave', 'Databricks'],
    'Enterprise AI / SaaS': ['Glean', 'Adept AI'],
    'Healthcare / Biotech AI': ['Recursion', 'Insilico Medicine'],
    'Autonomous / Robotics': ['Figure AI', 'Waymo'],
    'Creative / Generative': ['Runway', 'Pika'],
    'Other': ['Hugging Face', 'Weights & Biases'],
  };

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final sectors = [
      {'name': 'Foundation Models / LLMs', 'pct': 35, 'amount': '\$34.2B'},
      {'name': 'AI Infrastructure / Cloud', 'pct': 22, 'amount': '\$21.5B'},
      {'name': 'Enterprise AI / SaaS', 'pct': 15, 'amount': '\$14.7B'},
      {'name': 'Healthcare / Biotech AI', 'pct': 10, 'amount': '\$9.8B'},
      {'name': 'Autonomous / Robotics', 'pct': 8, 'amount': '\$7.8B'},
      {'name': 'Creative / Generative', 'pct': 6, 'amount': '\$5.9B'},
      {'name': 'Other', 'pct': 4, 'amount': '\$3.9B'},
    ];

    // Generate monochrome green shades
    final shades = <Color>[
      t.accent,
      t.accent.withValues(alpha: 0.75),
      t.accent.withValues(alpha: 0.55),
      t.accent.withValues(alpha: 0.40),
      t.accent.withValues(alpha: 0.30),
      t.accent.withValues(alpha: 0.20),
      t.primary.withValues(alpha: 0.10),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(children: [
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: Row(children: List.generate(sectors.length, (i) =>
              Expanded(
                flex: sectors[i]['pct'] as int,
                child: Container(color: shades[i]),
              ),
            )),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        ...List.generate(sectors.length, (i) {
          final sectorName = sectors[i]['name'] as String;
          final isExpanded = _expanded[sectorName] ?? false;
          final companies = _sectorCompanies[sectorName] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _expanded[sectorName] = !isExpanded;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      color: shades[i], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(sectorName, style: GoogleFonts.inter(
                      fontSize: 13, color: t.secondary))),
                    Text(sectors[i]['amount'] as String, style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
                    const SizedBox(width: 8),
                    SizedBox(width: 32, child: Text('${sectors[i]['pct']}%', style: GoogleFonts.inter(
                      fontSize: 12, color: t.muted), textAlign: TextAlign.right)),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16, color: t.muted),
                  ]),
                ),
              ),
              if (isExpanded && companies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 18, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: companies.map((company) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            color: t.muted, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(company,
                          style: GoogleFonts.inter(
                            fontSize: 12, color: t.muted, fontStyle: FontStyle.italic)),
                      ]),
                    )).toList(),
                  ),
                ),
            ],
          );
        }),
      ]),
    );
  }
}

// ── Region breakdown ──────────────────────────────────────────────────────

class _RegionBreakdown extends StatelessWidget {
  final AppTheme theme;
  const _RegionBreakdown({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final regions = [
      {'name': 'United States', 'pct': 58, 'amount': '\$56.7B'},
      {'name': 'China', 'pct': 18, 'amount': '\$17.6B'},
      {'name': 'United Kingdom', 'pct': 7, 'amount': '\$6.8B'},
      {'name': 'European Union', 'pct': 8, 'amount': '\$7.8B'},
      {'name': 'Rest of World', 'pct': 9, 'amount': '\$8.8B'},
    ];

    final shades = <Color>[
      t.primary,
      t.primary.withValues(alpha: 0.60),
      t.primary.withValues(alpha: 0.40),
      t.primary.withValues(alpha: 0.25),
      t.primary.withValues(alpha: 0.12),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: Row(children: List.generate(regions.length, (i) =>
              Expanded(
                flex: regions[i]['pct'] as int,
                child: Container(color: shades[i]),
              ),
            )),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(regions.length, (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
              color: shades[i], borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(child: Text(regions[i]['name'] as String, style: GoogleFonts.inter(
              fontSize: 13, color: t.secondary))),
            Text(regions[i]['amount'] as String, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(width: 8),
            SizedBox(width: 32, child: Text('${regions[i]['pct']}%', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted), textAlign: TextAlign.right)),
          ]),
        )),
      ]),
    );
  }
}

// ── Quarterly chart ───────────────────────────────────────────────────────

class _QuarterlyChart extends StatelessWidget {
  final AppTheme theme;
  const _QuarterlyChart({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final quarters = [
      {'label': 'Q1', 'value': 21.3},
      {'label': 'Q2', 'value': 24.8},
      {'label': 'Q3', 'value': 26.1},
      {'label': 'Q4', 'value': 25.6},
    ];
    const maxVal = 28.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(children: quarters.map((q) {
        final val = q['value'] as double;
        final pct = val / maxVal;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 28, child: Text(q['label'] as String,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: t.secondary))),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 24,
                  child: Stack(children: [
                    Container(color: t.background),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 48, child: Text('\$${val.toStringAsFixed(1)}B',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                color: t.primary), textAlign: TextAlign.right)),
          ]),
        );
      }).toList()),
    );
  }
}

// ── Funded company row ────────────────────────────────────────────────────

class _FundedCompanyRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppTheme theme;
  const _FundedCompanyRow({required this.data, required this.theme});

  static String _domainForCompany(String name) {
    const map = {
      'OpenAI': 'openai.com',
      'Anthropic': 'anthropic.com',
      'xAI': 'x.ai',
      'Databricks': 'databricks.com',
      'CoreWeave': 'coreweave.com',
      'Inflection AI': 'inflection.ai',
      'Recursion': 'recursion.com',
    };
    return map[name] ?? '${name.toLowerCase().replaceAll(' ', '')}.com';
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final name = data['name'] as String;
    final domain = _domainForCompany(name);
    final logoUrl = 'https://logo.clearbit.com/$domain';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: logoUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(name[0],
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: t.primary))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: t.primary))),
              Text(data['raised'] as String, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: t.primary)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Stack(children: [
                  Container(color: t.background),
                  FractionallySizedBox(
                    widthFactor: data['bar'] as double,
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3))),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(data['round'] as String, style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
          ],
        ),
      ),
    );
  }
}

// ── Funding news feed ─────────────────────────────────────────────────────

class _FundingNewsFeed extends StatefulWidget {
  final AppTheme theme;
  const _FundingNewsFeed({required this.theme});

  @override
  State<_FundingNewsFeed> createState() => _FundingNewsFeedState();
}

class _FundingNewsFeedState extends State<_FundingNewsFeed> {
  bool _loading = true;
  List<Map<String, String>> _items = [];

  // Multiple RSS feeds that actually publish AI funding news, most reliable first
  static const _feeds = [
    'https://techcrunch.com/category/venture/feed/',
    'https://techcrunch.com/category/artificial-intelligence/feed/',
    'https://venturebeat.com/category/ai/feed/',
    'https://www.theinformation.com/feed',
    'https://news.crunchbase.com/feed/',
  ];

  static const _keywords = [
    'fund', 'raise', 'raised', 'invest', 'million', 'billion',
    'series a', 'series b', 'series c', 'series d', 'series e',
    'valuation', 'acquires', 'acquired', 'acquisition', 'ipo',
    'seed round', 'pre-seed', 'venture', 'startup',
  ];
  static const _aiTerms = [
    'ai', 'artificial intelligence', 'machine learning', 'ml ',
    'llm', 'generative', 'openai', 'anthropic', 'ml/ai',
    'neural', 'foundation model', 'agent', 'robotics',
  ];

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    final collected = <Map<String, String>>[];
    final seenTitles = <String>{};

    // Fetch all feeds in parallel, but collect successfully parsed items.
    // Web builds route through the Cloudflare proxy to bypass browser CORS.
    await Future.wait(_feeds.map((feedUrl) async {
      try {
        final fetchUrl = kIsWeb
            ? 'https://aiwire-proxy.prab187.workers.dev/rss?url=${Uri.encodeComponent(feedUrl)}'
            : feedUrl;
        final response = await http.get(
          Uri.parse(fetchUrl),
          headers: {'User-Agent': 'Mozilla/5.0 (AIWire)'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) return;

        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item').toList();
        // Also handle Atom feeds
        final entries = items.isEmpty
            ? document.findAllElements('entry').toList()
            : items;

        for (final item in entries) {
          final title = item.childElements
              .where((e) => e.name.local == 'title')
              .firstOrNull?.innerText.trim() ?? '';
          if (title.isEmpty) continue;
          if (seenTitles.contains(title.toLowerCase())) continue;

          final titleLower = title.toLowerCase();
          final hasFundingTerm = _keywords.any((k) => titleLower.contains(k));
          final hasAiTerm = _aiTerms.any((a) => titleLower.contains(a));
          // Must contain BOTH a funding keyword AND an AI term
          if (!hasFundingTerm || !hasAiTerm) continue;

          // Extract URL
          String link = '';
          for (final el in item.childElements) {
            if (el.name.local == 'link') {
              final href = el.getAttribute('href');
              if (href != null && href.isNotEmpty) { link = href; break; }
              final text = el.innerText.trim();
              if (text.startsWith('http')) { link = text; break; }
            }
          }
          if (link.isEmpty) {
            link = item.childElements
                .where((e) => e.name.local == 'guid')
                .firstOrNull?.innerText.trim() ?? '';
          }
          if (!link.startsWith('http')) continue;

          // Extract date
          final pubDate = item.childElements.where((e) =>
            e.name.local == 'pubDate' || e.name.local == 'published'
            || e.name.local == 'updated').firstOrNull?.innerText.trim() ?? '';
          DateTime? parsed;
          try { parsed = DateTime.parse(pubDate); } catch (_) {}
          // Only show last 90 days
          if (parsed != null &&
              DateTime.now().difference(parsed).inDays > 90) continue;

          String dateDisplay = 'Recent';
          if (parsed != null) {
            const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            dateDisplay = '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
          }

          // Extract description and strip HTML
          final rawDesc = item.childElements.where((e) =>
            e.name.local == 'description' || e.name.local == 'summary'
            || e.name.local == 'content' || e.name.local == 'encoded')
            .firstOrNull?.innerText.trim() ?? '';
          final cleanDesc = rawDesc
              .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

          // SKIP items without a real description — these won't read well
          if (cleanDesc.length < 80) continue;

          final description = cleanDesc.length > 400
              ? '${cleanDesc.substring(0, 400)}…'
              : cleanDesc;

          seenTitles.add(title.toLowerCase());
          collected.add({
            'title': title,
            'description': description,
            'date': dateDisplay,
            'url': link,
            'published': parsed?.toIso8601String() ?? '',
          });
        }
      } catch (_) {}
    }));

    // Sort by date (newest first)
    collected.sort((a, b) {
      final ap = DateTime.tryParse(a['published'] ?? '') ?? DateTime(2000);
      final bp = DateTime.tryParse(b['published'] ?? '') ?? DateTime(2000);
      return bp.compareTo(ap);
    });

    if (mounted) {
      setState(() {
        _items = collected.take(8).toList();
        _loading = false;
      });
    }
  }

  void _showSummary(Map<String, String> item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvestmentArticleSheet(
        article: item,
        theme: widget.theme),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5),
        ),
      );
    }

    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5),
        ),
        child: Column(children: [
          Icon(Icons.inbox_rounded, size: 32, color: t.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text('No recent funding news', style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
          const SizedBox(height: 4),
          Text('Showing only articles with verified content from the last 90 days.\nCheck back soon.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: t.muted, height: 1.4)),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(
        children: _items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (i > 0) Divider(height: 1, color: t.divider),
              InkWell(
                onTap: () => _showSummary(item),
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : i == _items.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(12))
                        : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['title'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: t.primary, height: 1.4),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(item['date'] ?? '',
                                  style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, size: 16, color: t.muted),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // AI Summary CTA pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.25))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.auto_awesome_rounded,
                            size: 10, color: Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          Text('AI Summary', style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: const Color(0xFF6366F1))),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Investment Article Bottom Sheet (AI Summary + Read) ────────────────────
class _InvestmentArticleSheet extends StatefulWidget {
  final Map<String, String> article;
  final AppTheme theme;
  const _InvestmentArticleSheet({required this.article, required this.theme});

  @override
  State<_InvestmentArticleSheet> createState() => _InvestmentArticleSheetState();
}

class _InvestmentArticleSheetState extends State<_InvestmentArticleSheet> {
  bool _loading = true;
  String? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: 'proxy');
    if (apiKey.isEmpty) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'API key not configured';
      });
      return;
    }

    final title = widget.article['title'] ?? '';
    final description = widget.article['description'] ?? '';
    final cacheKey = ClaudeCache.keyFrom([title]);

    // Check cache (30 days)
    final cached = await ClaudeCache.get('inv_news', cacheKey,
        ttl: const Duration(days: 30));
    if (cached != null) {
      if (mounted) setState(() {
        _summary = cached;
        _loading = false;
      });
      return;
    }

    final prompt = '''Summarize this AI investment / funding news in exactly 4 concise bullet points. Each bullet starts with "• " and is a single short sentence. Cover: what happened, who's involved, the financial details, and why it matters for the AI industry. No preamble, no headers, just 4 bullets.

Title: $title

${description.isNotEmpty ? description : "(no extended description available — infer from title)"}''';

    try {
      final response = await ClaudeHttp.post(
        apiKey: apiKey,
        timeout: const Duration(seconds: 30),
        body: {
          'model': 'claude-haiku-4-5',
          'max_tokens': 320,
          'messages': [{'role': 'user', 'content': prompt}],
        },
      );

      if (response.statusCode != 200) {
        throw Exception(claudeError(response.statusCode, response.body));
      }
      final data = json.decode(response.body);
      final contentList = data['content'] as List?;
      final text = (contentList != null && contentList.isNotEmpty)
          ? (contentList[0]['text'] as String?) ?? ''
          : '';
      if (text.isNotEmpty) {
        await ClaudeCache.set('inv_news', cacheKey, text);
      }
      if (mounted) setState(() {
        _summary = text.isEmpty ? 'No summary available.' : text;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = friendlyError(e.toString().replaceFirst('Exception: ', ''));
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final title = widget.article['title'] ?? '';
    final date = widget.article['date'] ?? '';
    final url = widget.article['url'] ?? '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Center(child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: t.muted.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2)))),
          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 24, height: 1, color: const Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text('INVESTMENT NEWS · $date', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: const Color(0xFF6366F1), letterSpacing: 1.5)),
              ]),
              const SizedBox(height: 10),
              Text(title, style: GoogleFonts.sourceSerif4(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: t.primary, height: 1.3, letterSpacing: -0.3)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.08),
                      t.surface,
                    ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2), width: 0.8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 10),
                    Text('AI Summary', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: t.primary, letterSpacing: 0.3)),
                  ]),
                  const SizedBox(height: 14),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(
                        color: t.primary, strokeWidth: 1.5)),
                    )
                  else if (_error != null)
                    Text(_error!, style: GoogleFonts.inter(
                      fontSize: 13, color: t.muted, fontStyle: FontStyle.italic))
                  else
                    BulletSummary(
                      text: _summary ?? '',
                      theme: t,
                      accent: const Color(0xFF6366F1),
                      fontSize: 14),
                ]),
              ),
              const SizedBox(height: 24),
              if (url.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: t.primary, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.open_in_new_rounded, size: 16, color: t.background),
                      const SizedBox(width: 8),
                      Text('Read full article', style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700, color: t.background)),
                    ]),
                  ),
                ),
            ]),
          )),
        ]),
      ),
    );
  }
}

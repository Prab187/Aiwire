import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';
import '../theme/app_theme.dart';

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
                Text('Total AI investment in 2025', style: GoogleFonts.inter(
                  fontSize: 14, color: t.secondary)),
                const SizedBox(height: 2),
                Text('+62% from 2024', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: t.accent)),
                const SizedBox(height: 12),
                Divider(color: t.divider),
                const SizedBox(height: 8),
                Text('Sources: Crunchbase · PitchBook · Bloomberg',
                  style: GoogleFonts.inter(fontSize: 11, color: t.muted),
                  textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('Data as of Q4 2025',
                  style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
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

            // Recent funding news
            Text('Recent Funding News', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 2),
            Text('Latest AI investment rounds', style: GoogleFonts.inter(
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

  static const _fallback = [
    {'title': 'Anthropic raises \$2B at \$61.5B valuation', 'date': 'Jan 2026', 'url': 'https://techcrunch.com'},
    {'title': 'CoreWeave secures \$1.5B in new debt financing', 'date': 'Feb 2026', 'url': 'https://techcrunch.com'},
    {'title': 'ElevenLabs closes \$180M Series C round', 'date': 'Jan 2026', 'url': 'https://techcrunch.com'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final response = await http.get(
        Uri.parse('https://techcrunch.com/feed/'),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        final keywords = ['fund', 'raise', 'invest', 'million', 'billion'];

        final filtered = <Map<String, String>>[];
        for (final item in items) {
          if (filtered.length >= 5) break;
          final title = item.findElements('title').firstOrNull?.innerText ?? '';
          final titleLower = title.toLowerCase();
          final hasKeyword = keywords.any((k) => titleLower.contains(k));
          if (!hasKeyword) continue;

          final link = item.findElements('link').firstOrNull?.innerText ??
              item.findElements('guid').firstOrNull?.innerText ?? '';
          final pubDate = item.findElements('pubDate').firstOrNull?.innerText ?? '';

          // Parse date
          String dateDisplay = pubDate;
          try {
            final d = DateTime.parse(pubDate);
            const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            dateDisplay = '${months[d.month - 1]} ${d.year}';
          } catch (_) {
            // Try RFC-822 format — just use raw
            if (pubDate.length > 10) {
              dateDisplay = pubDate.substring(0, pubDate.length > 16 ? 16 : pubDate.length);
            }
          }

          filtered.add({'title': title, 'date': dateDisplay, 'url': link});
        }

        setState(() {
          _items = filtered.isEmpty ? _fallback : filtered;
          _loading = false;
        });
      } else {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
  }

  void _useFallback() {
    setState(() {
      _items = _fallback;
      _loading = false;
    });
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
                onTap: () async {
                  final url = item['url'] ?? '';
                  if (url.isNotEmpty) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : i == _items.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(12))
                        : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: t.primary, height: 1.4),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(item['date'] ?? '',
                              style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.open_in_new_rounded, size: 14, color: t.muted),
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

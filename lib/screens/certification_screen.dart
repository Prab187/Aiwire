import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/certification.dart';
import '../services/certification_service.dart';

class CertificationScreen extends StatefulWidget {
  final AppTheme theme;
  const CertificationScreen({super.key, required this.theme});

  @override
  State<CertificationScreen> createState() => _CertificationScreenState();
}

class _CertificationScreenState extends State<CertificationScreen>
    with SingleTickerProviderStateMixin {
  List<Certification> _certs = [];
  bool _loading = true;
  String _levelFilter = 'All';
  String _providerFilter = 'All';
  late TabController _tabCtrl;

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadCerts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCerts() async {
    setState(() => _loading = true);
    final certs = await CertificationService.fetchCertifications(
      level: _levelFilter, providerType: _providerFilter);
    setState(() { _certs = certs; _loading = false; });
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
        title: Text('Certifications', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabCtrl,
                labelColor: t.primary,
                unselectedLabelColor: t.muted,
                indicatorColor: t.primary,
                indicatorWeight: 1.5,
                labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Browse'),
                  Tab(text: 'By Experience'),
                ],
              ),
              Divider(height: 1, color: t.divider),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildBrowseTab(),
          const _ExperienceGuideTab(),
        ],
      ),
    );
  }

  Widget _buildBrowseTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildChip('All Levels', _levelFilter == 'All', () {
                  setState(() => _levelFilter = 'All'); _loadCerts(); }),
                _buildChip('Beginner', _levelFilter == 'Beginner', () {
                  setState(() => _levelFilter = 'Beginner'); _loadCerts(); }),
                _buildChip('Intermediate', _levelFilter == 'Intermediate', () {
                  setState(() => _levelFilter = 'Intermediate'); _loadCerts(); }),
                _buildChip('Advanced', _levelFilter == 'Advanced', () {
                  setState(() => _levelFilter = 'Advanced'); _loadCerts(); }),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildChip('All Providers', _providerFilter == 'All', () {
                  setState(() => _providerFilter = 'All'); _loadCerts(); }),
                _buildChip('Tech Company', _providerFilter == 'Tech Company', () {
                  setState(() => _providerFilter = 'Tech Company'); _loadCerts(); }),
                _buildChip('University', _providerFilter == 'University', () {
                  setState(() => _providerFilter = 'University'); _loadCerts(); }),
                _buildChip('Platform', _providerFilter == 'Platform', () {
                  setState(() => _providerFilter = 'Platform'); _loadCerts(); }),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
            ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
            : _certs.isEmpty
              ? Center(child: Text('No certifications found', style: GoogleFonts.inter(color: t.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: _certs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CertCard(cert: _certs[i], theme: t),
                ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? t.primary.withValues(alpha: 0.2) : t.divider),
          ),
          child: Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? t.primary : t.secondary)),
        ),
      ),
    );
  }
}

class _CertCard extends StatelessWidget {
  final Certification cert;
  final AppTheme theme;

  const _CertCard({required this.cert, required this.theme});

  Future<void> _openSource() async {
    if (cert.url != null) {
      final uri = Uri.parse(cert.url!);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: _openSource,
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_providerIcon(cert.providerType),
                    color: t.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(cert.name, style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          if (cert.isNew) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('New', style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(cert.provider, style: GoogleFonts.inter(
                        fontSize: 13, color: t.secondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(cert.description, style: GoogleFonts.inter(
              fontSize: 13, color: t.muted, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            // Skills
            Wrap(
              spacing: 6, runSpacing: 6,
              children: cert.skills.take(4).map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(s, style: GoogleFonts.inter(
                  fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
              )).toList(),
            ),
            const SizedBox(height: 12),
            // Meta
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(cert.level, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: t.secondary)),
                if (cert.duration != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 14, color: t.muted),
                    const SizedBox(width: 4),
                    Text(cert.duration!, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                  ]),
                if (cert.rating != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 14, color: t.muted),
                    const SizedBox(width: 2),
                    Text(cert.rating!.toStringAsFixed(1), style: GoogleFonts.inter(
                      fontSize: 12, color: t.secondary, fontWeight: FontWeight.w500)),
                  ]),
                Text(cert.isFree ? 'Free' : cert.price ?? 'Paid',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                    color: t.primary)),
              ],
            ),
            if (cert.enrolledCount != null) ...[
              const SizedBox(height: 8),
              Text('${_formatNumber(cert.enrolledCount!)} enrolled',
                style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
            ],
            if (cert.url != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 14, color: t.accent),
                  const SizedBox(width: 6),
                  Text('Register / Enroll',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                      color: t.accent)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: t.accent),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _providerIcon(String type) {
    switch (type) {
      case 'Tech Company': return Icons.business_rounded;
      case 'University': return Icons.school_rounded;
      case 'Platform': return Icons.laptop_mac_rounded;
      default: return Icons.verified_outlined;
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }
}

// ─── Certifications by Experience Level ──────────────────────────────────────

class _ExperienceGuideTab extends StatelessWidget {
  const _ExperienceGuideTab();

  static const _tiers = [
    _ExpTier(
      range: '0 – 1 Year',
      label: 'Starting Out',
      icon: Icons.rocket_launch_outlined,
      description: 'Build a solid foundation. Focus on broad AI/ML literacy and one hands-on platform certification to demonstrate practical ability to employers.',
      certifications: [
        _CertEntry(
          name: 'Google AI Essentials',
          provider: 'Google',
          why: 'Covers core AI concepts and Google tools. No coding required — ideal first step.',
        ),
        _CertEntry(
          name: 'AWS Cloud Practitioner',
          provider: 'Amazon Web Services',
          why: 'Industry-standard cloud foundation. Pairs well with any AI/ML path.',
        ),
        _CertEntry(
          name: 'IBM AI Foundations for Everyone',
          provider: 'IBM / Coursera',
          why: 'Accessible, non-technical introduction to AI concepts and use cases.',
        ),
        _CertEntry(
          name: 'Microsoft Azure AI Fundamentals (AI-900)',
          provider: 'Microsoft',
          why: 'Entry-level Azure AI cert. Good for those targeting Microsoft-stack roles.',
        ),
      ],
      avoid: 'Avoid advanced certs (AWS ML Specialty, GCP Professional ML Engineer) — they require production experience to pass and to apply effectively.',
    ),
    _ExpTier(
      range: '1 – 2 Years',
      label: 'Building Depth',
      icon: Icons.auto_graph_rounded,
      description: 'You have the basics. Now specialise. Choose certifications that align with your focus area — cloud ML, data science, or applied engineering.',
      certifications: [
        _CertEntry(
          name: 'TensorFlow Developer Certificate',
          provider: 'Google',
          why: 'Demonstrates practical model-building skills. Highly recognised by ML teams.',
        ),
        _CertEntry(
          name: 'AWS Certified Machine Learning – Specialty',
          provider: 'Amazon Web Services',
          why: 'Validates end-to-end ML on AWS. Strong signal for cloud-first ML roles.',
        ),
        _CertEntry(
          name: 'Deep Learning Specialization',
          provider: 'DeepLearning.AI / Coursera',
          why: 'Andrew Ng\'s flagship series. Builds genuine neural network understanding.',
        ),
        _CertEntry(
          name: 'IBM Data Science Professional Certificate',
          provider: 'IBM / Coursera',
          why: 'Structured path covering Python, SQL, ML, and data viz in one bundle.',
        ),
      ],
      avoid: null,
    ),
    _ExpTier(
      range: '2 – 4 Years',
      label: 'Mid-Level',
      icon: Icons.insights_rounded,
      description: 'You have meaningful experience. Certifications should validate specialisation, not teach fundamentals. Target platform-specific or role-specific credentials.',
      certifications: [
        _CertEntry(
          name: 'GCP Professional ML Engineer',
          provider: 'Google Cloud',
          why: 'Rigorous, scenario-based exam. Strong signal for senior ML engineering roles at Google-stack companies.',
        ),
        _CertEntry(
          name: 'Azure AI Engineer Associate (AI-102)',
          provider: 'Microsoft',
          why: 'Covers real AI solution architecture on Azure. Valued in enterprise environments.',
        ),
        _CertEntry(
          name: 'MLOps Specialization',
          provider: 'DeepLearning.AI / Coursera',
          why: 'Addresses the production ML gap — deployment, monitoring, and pipelines.',
        ),
        _CertEntry(
          name: 'Databricks Certified Associate Developer for Apache Spark',
          provider: 'Databricks',
          why: 'Key credential for data engineering and large-scale ML pipelines.',
        ),
      ],
      avoid: 'Entry-level certs (AI Essentials, AI-900) add little value on a mid-level CV — they may signal a gap rather than growth.',
    ),
    _ExpTier(
      range: '5+ Years',
      label: 'Senior & Expert',
      icon: Icons.verified_rounded,
      description: 'At this level, your portfolio and track record carry more weight than certifications. Choose credentials that signal strategic capability or unlock specific enterprise contracts.',
      certifications: [
        _CertEntry(
          name: 'AWS Certified Solutions Architect – Professional',
          provider: 'Amazon Web Services',
          why: 'Signals architectural leadership across large-scale AI infrastructure.',
        ),
        _CertEntry(
          name: 'GCP Professional Data Engineer',
          provider: 'Google Cloud',
          why: 'Validates enterprise-scale data pipeline and ML system design.',
        ),
        _CertEntry(
          name: 'NVIDIA DLI – Advanced AI Certifications',
          provider: 'NVIDIA',
          why: 'Cutting-edge GPU and inference expertise. Differentiates in LLM and generative AI roles.',
        ),
        _CertEntry(
          name: 'Certified AI Professional (CAIP)',
          provider: 'Arcitura / Independent Bodies',
          why: 'Vendor-neutral professional credential. Relevant for consulting and advisory roles.',
        ),
      ],
      avoid: 'Foundation-level certs provide no return at this stage. Focus on thought leadership, open-source contributions, and speaking engagements alongside any formal credentials.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      itemCount: _tiers.length,
      itemBuilder: (_, i) => _ExpTierCard(tier: _tiers[i]),
    );
  }
}

class _ExpTier {
  final String range, label, description;
  final IconData icon;
  final List<_CertEntry> certifications;
  final String? avoid;
  const _ExpTier({
    required this.range, required this.label, required this.description,
    required this.icon, required this.certifications, required this.avoid,
  });
}

class _CertEntry {
  final String name, provider, why;
  const _CertEntry({required this.name, required this.provider, required this.why});
}

class _ExpTierCard extends StatefulWidget {
  final _ExpTier tier;
  const _ExpTierCard({required this.tier});

  @override
  State<_ExpTierCard> createState() => _ExpTierCardState();
}

class _ExpTierCardState extends State<_ExpTierCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final surface = colorScheme.surface;
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final outlineVariant = colorScheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.tier.icon, color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.tier.range,
                          style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700, color: onSurface)),
                        const SizedBox(height: 2),
                        Text(widget.tier.label,
                          style: GoogleFonts.inter(
                            fontSize: 12, color: onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: onSurfaceVariant, size: 22,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_expanded) ...[
            Divider(height: 1, color: outlineVariant),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.tier.description,
                    style: GoogleFonts.inter(
                      fontSize: 13, color: onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 16),
                  Text('Recommended Certifications',
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: onSurface)),
                  const SizedBox(height: 10),
                  ...widget.tier.certifications.map((c) => _CertRow(entry: c, primary: primary, onSurface: onSurface, onSurfaceVariant: onSurfaceVariant, outlineVariant: outlineVariant)),
                  if (widget.tier.avoid != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(widget.tier.avoid!,
                              style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.orange.shade700, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CertRow extends StatelessWidget {
  final _CertEntry entry;
  final Color primary, onSurface, onSurfaceVariant, outlineVariant;
  const _CertRow({required this.entry, required this.primary, required this.onSurface, required this.onSurfaceVariant, required this.outlineVariant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6, height: 6,
            decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
                Text(entry.provider,
                  style: GoogleFonts.inter(fontSize: 11, color: onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(entry.why,
                  style: GoogleFonts.inter(fontSize: 12, color: onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

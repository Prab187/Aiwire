import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<Certification> _allCerts = [];
  List<Certification> _certs = [];
  bool _loading = true;
  String _levelFilter = 'All';
  String _providerFilter = 'All';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;

  // Resume-based recommendation state
  List<String> _userSkills = [];
  String _userLevel = '';
  String _userJobTitle = '';
  bool _hasResume = false;

  // Manual skill input state (when no resume)
  String? _selectedSkill;
  String _selectedYears = '0-1';

  AppTheme get t => widget.theme;

  static const _commonSkills = [
    'Python', 'Machine Learning', 'Deep Learning', 'NLP',
    'Computer Vision', 'Data Science', 'TensorFlow', 'PyTorch',
    'Cloud (AWS/GCP/Azure)', 'MLOps', 'SQL', 'Statistics',
    'LLM', 'Generative AI', 'Reinforcement Learning',
  ];

  static const _yearOptions = ['0-1', '1-2', '2-4', '5+'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadCerts();
    _loadResumeSkills();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadResumeSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final skills = prefs.getStringList('user_skills') ?? [];
    final level = prefs.getString('user_level') ?? '';
    final title = prefs.getString('user_job_title') ?? '';
    if (mounted) setState(() {
      _userSkills = skills;
      _userLevel = level;
      _userJobTitle = title;
      _hasResume = skills.isNotEmpty;
      if (skills.isNotEmpty) _selectedSkill = skills.first;
    });
  }

  Future<void> _loadCerts() async {
    setState(() => _loading = true);
    final certs = await CertificationService.fetchCertifications(
      level: _levelFilter, providerType: _providerFilter);
    _allCerts = certs;
    _applySearch();
    if (mounted) setState(() => _loading = false);
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _certs = List.from(_allCerts);
    } else {
      final q = _searchQuery.toLowerCase();
      _certs = _allCerts.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.provider.toLowerCase().contains(q) ||
        c.skills.any((s) => s.toLowerCase().contains(q))
      ).toList();
    }
  }

  // Get recommended certs based on skill + experience
  List<Certification> get _recommended {
    final skill = _selectedSkill?.toLowerCase() ?? '';
    final years = _selectedYears;

    if (skill.isEmpty) return _allCerts.take(5).toList();

    // Map years to cert levels
    final targetLevels = <String>[];
    switch (years) {
      case '0-1': targetLevels.addAll(['Beginner']);
      case '1-2': targetLevels.addAll(['Beginner', 'Intermediate']);
      case '2-4': targetLevels.addAll(['Intermediate', 'Advanced']);
      case '5+': targetLevels.addAll(['Advanced']);
    }

    // Score certs by relevance
    final scored = _allCerts.map((c) {
      int score = 0;
      // Skill match
      if (c.skills.any((s) => s.toLowerCase().contains(skill))) score += 3;
      if (c.name.toLowerCase().contains(skill)) score += 2;
      if (c.description.toLowerCase().contains(skill)) score += 1;
      // Level match
      if (targetLevels.contains(c.level)) score += 2;
      return (cert: c, score: score);
    }).where((r) => r.score > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(6).map((r) => r.cert).toList();
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
          fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            TabBar(
              controller: _tabCtrl,
              labelColor: t.primary,
              unselectedLabelColor: t.muted,
              indicatorColor: t.primary,
              indicatorWeight: 1.5,
              labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 14),
              tabs: const [Tab(text: 'Browse'), Tab(text: 'For You')],
            ),
            Divider(height: 1, color: t.divider),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildBrowseTab(),
          _buildForYouTab(),
        ],
      ),
    );
  }

  // ── Browse Tab ─────────────────────────────────────────────────────────────
  Widget _buildBrowseTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          style: GoogleFonts.inter(color: t.primary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search certifications, skills...',
            hintStyle: GoogleFonts.inter(color: t.muted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 20),
            filled: true, fillColor: t.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.divider)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.divider)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (v) => setState(() { _searchQuery = v; _applySearch(); }),
        ),
      ),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final l in ['All', 'Beginner', 'Intermediate', 'Advanced'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildChip(l == 'All' ? 'All Levels' : l, _levelFilter == l, () {
                  setState(() => _levelFilter = l); _loadCerts();
                }),
              ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final p in ['All', 'Tech Company', 'University', 'Platform'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildChip(p == 'All' ? 'All Providers' : p, _providerFilter == p, () {
                  setState(() => _providerFilter = p); _loadCerts();
                }),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
          : _certs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.school_outlined, size: 44, color: t.muted.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No certifications found', style: GoogleFonts.sourceSerif4(
                  fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
                const SizedBox(height: 4),
                Text('Try different filters', style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                itemCount: _certs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CertCard(cert: _certs[i], theme: t),
              ),
      ),
    ]);
  }

  // ── For You Tab (Resume-based or Manual) ───────────────────────────────────
  Widget _buildForYouTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Profile card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF6366F1)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                _hasResume ? 'Based on your resume' : 'Select your skill',
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: t.primary))),
            ]),
            const SizedBox(height: 12),

            if (_hasResume) ...[
              // Show detected skills from resume
              Text('Skills: ${_userSkills.take(5).join(", ")}', style: GoogleFonts.inter(
                fontSize: 13, color: t.muted)),
              if (_userJobTitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Role: $_userJobTitle · $_userLevel', style: GoogleFonts.inter(
                  fontSize: 13, color: t.muted)),
              ],
              const SizedBox(height: 12),
              Text('We recommend courses to strengthen your profile:', style: GoogleFonts.inter(
                fontSize: 13, color: t.secondary, height: 1.4)),
            ] else ...[
              // Manual skill picker
              Text('Pick your primary skill:', style: GoogleFonts.inter(
                fontSize: 13, color: t.muted)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: _commonSkills.map((s) =>
                GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedSkill = s); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedSkill == s
                        ? t.primary.withValues(alpha: 0.1) : t.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _selectedSkill == s
                          ? t.primary.withValues(alpha: 0.3) : t.divider)),
                    child: Text(s, style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: _selectedSkill == s ? FontWeight.w600 : FontWeight.w400,
                      color: _selectedSkill == s ? t.primary : t.secondary)),
                  ),
                ),
              ).toList()),
              const SizedBox(height: 14),

              // Years of experience
              Text('Years of experience:', style: GoogleFonts.inter(
                fontSize: 13, color: t.muted)),
              const SizedBox(height: 8),
              Row(children: _yearOptions.map((y) => Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedYears = y); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedYears == y
                        ? t.primary.withValues(alpha: 0.1) : t.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedYears == y
                          ? t.primary.withValues(alpha: 0.3) : t.divider)),
                    child: Center(child: Text('$y yr${y == '5+' ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _selectedYears == y ? FontWeight.w700 : FontWeight.w400,
                        color: _selectedYears == y ? t.primary : t.secondary))),
                  ),
                ),
              ))).toList()),
            ],
          ]),
        ),

        const SizedBox(height: 20),

        // Recommended certs
        if (_selectedSkill != null || _hasResume) ...[
          Text('Recommended for you', style: GoogleFonts.sourceSerif4(
            fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
          const SizedBox(height: 4),
          Text(
            _hasResume
              ? 'Based on your $_userLevel profile in $_userJobTitle'
              : 'Based on $_selectedSkill · $_selectedYears years',
            style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
          const SizedBox(height: 12),

          if (_loading)
            Center(child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5)))
          else if (_recommended.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No matching certifications found',
                style: GoogleFonts.inter(fontSize: 13, color: t.muted))),
            )
          else
            ..._recommended.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CertCard(cert: c, theme: t, showWhy: true,
                skill: _selectedSkill ?? (_userSkills.isNotEmpty ? _userSkills.first : '')),
            )),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Column(children: [
              Icon(Icons.touch_app_outlined, size: 40, color: t.muted.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('Select a skill above', style: GoogleFonts.inter(
                fontSize: 14, color: t.muted)),
              const SizedBox(height: 4),
              Text('to get personalized recommendations', style: GoogleFonts.inter(
                fontSize: 13, color: t.muted.withValues(alpha: 0.6))),
            ])),
          ),
      ]),
    );
  }

  Widget _buildChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? t.primary.withValues(alpha: 0.2) : t.divider)),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          color: active ? t.primary : t.secondary)),
      ),
    );
  }
}

// ── Cert Card ──────────────────────────────────────────────────────────────────
class _CertCard extends StatelessWidget {
  final Certification cert;
  final AppTheme theme;
  final bool showWhy;
  final String skill;

  const _CertCard({required this.cert, required this.theme,
    this.showWhy = false, this.skill = ''});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (cert.url != null) {
          final uri = Uri.parse(cert.url!);
          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(_providerIcon(cert.providerType), color: t.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cert.name, style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: t.primary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(cert.provider, style: GoogleFonts.inter(fontSize: 12, color: t.secondary)),
              ],
            )),
          ]),
          const SizedBox(height: 8),

          // Why this cert (for "For You" tab)
          if (showWhy && skill.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Recommended for $skill professionals at ${cert.level} level',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6366F1), height: 1.4))),
              ]),
            ),
            const SizedBox(height: 8),
          ],

          // Skills
          Wrap(spacing: 5, runSpacing: 5, children: cert.skills.take(4).map((s) =>
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: t.background, borderRadius: BorderRadius.circular(4)),
              child: Text(s, style: GoogleFonts.inter(
                fontSize: 10, color: t.secondary, fontWeight: FontWeight.w500)),
            )).toList()),
          const SizedBox(height: 8),

          // Meta row
          Row(children: [
            Text(cert.level, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: t.secondary)),
            if (cert.duration != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.schedule_rounded, size: 13, color: t.muted),
              const SizedBox(width: 3),
              Text(cert.duration!, style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
            ],
            if (cert.rating != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.star_rounded, size: 13, color: t.muted),
              const SizedBox(width: 2),
              Text(cert.rating!.toStringAsFixed(1), style: GoogleFonts.inter(
                fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
            ],
            const Spacer(),
            Text(cert.isFree ? 'Free' : (cert.price ?? 'Paid'), style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: cert.isFree ? t.accent : t.primary)),
          ]),
        ]),
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
}

import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/resume_profile.dart';
import '../models/job.dart';
import '../models/certification.dart';
import '../models/article.dart';
import '../services/resume_service.dart';
import '../services/job_service.dart';
import '../services/certification_service.dart';
import '../services/news_service.dart';
import '../services/application_tracker_service.dart';
import '../services/profile_storage_service.dart';

enum _ScanState { idle, analyzing, results, error }

class ResumeScanScreen extends StatefulWidget {
  final AppTheme theme;
  const ResumeScanScreen({super.key, required this.theme});

  @override
  State<ResumeScanScreen> createState() => _ResumeScanScreenState();
}

class _ResumeScanScreenState extends State<ResumeScanScreen>
    with TickerProviderStateMixin {
  _ScanState _state = _ScanState.idle;
  String _statusMessage = '';
  String? _errorMessage;
  ResumeProfile? _profile;
  List<Job> _jobs = [];

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late TabController _tabCtrl;

  // Career recommendation
  String? _recommendation;
  bool _recLoading = false;

  // Recommended courses + news (resume-based)
  List<Certification> _recommendedCerts = [];
  List<Article> _recommendedNews = [];
  bool _certsLoading = false;
  bool _newsLoading = false;

  // Manual input (no resume)
  String _manualName = '';
  String _manualSkill = '';
  String _manualYears = '0-1';
  String _manualCerts = '';
  final _nameCtrl = TextEditingController();
  final _certCtrl = TextEditingController();

  AppTheme get t => widget.theme;

  static const _skillOptions = [
    'Python', 'Machine Learning', 'Deep Learning', 'NLP',
    'Computer Vision', 'Data Science', 'TensorFlow', 'PyTorch',
    'Cloud (AWS/GCP)', 'MLOps', 'LLM', 'Generative AI',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _certCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan({bool useSample = false}) async {
    final file = useSample
        ? ResumeService.sampleResumeFile()
        : await ResumeService.pickResumeFile();
    if (file == null) return;

    setState(() {
      _state = _ScanState.analyzing;
      _statusMessage = useSample ? 'Loading sample resume\u2026' : 'Reading your resume\u2026';
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _statusMessage = 'Extracting skills & experience\u2026');

      final profile = await ResumeService.analyzeResume(file);

      // Save skills for other screens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_skills', profile.skills);
      await prefs.setString('user_job_title', profile.jobTitle);
      await prefs.setString('user_level', profile.experienceLevel);

      // Save full profile to multi-profile storage
      await ProfileStorageService.save(SavedProfile(
        id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
        label: profile.jobTitle,
        profile: profile,
        createdAt: DateTime.now().toIso8601String(),
      ));

      setState(() => _statusMessage = 'Finding jobs in ${profile.country}\u2026');

      final jobs = await JobService.fetchJobsForResume(
        skills: profile.skills,
        countryCode: profile.countryCode,
        jobTitle: profile.jobTitle,
      );

      setState(() {
        _profile = profile;
        _jobs = jobs;
        _state = _ScanState.results;
      });

      _generateRecommendation();
      _loadRecommendedCerts();
      _loadRecommendedNews();
    } catch (e) {
      setState(() {
        _state = _ScanState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _shareCareerPlan() async {
    if (_profile == null) return;
    HapticFeedback.lightImpact();
    final p = _profile!;
    final text = '''My AI Career Plan — built with AIWire

${p.name ?? "I"} · ${p.jobTitle} · ${p.experienceLevel} (${p.yearsOfExperience}y)

Top skills: ${p.skills.take(5).join(", ")}
ATS Score: ${p.atsScore}/100

${_recommendation ?? "Career plan loading..."}

Get yours: aiwire.app''';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _generateRecommendation({String? manualContext}) async {
    setState(() { _recLoading = true; _recommendation = null; });

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) {
      setState(() { _recLoading = false; _recommendation = 'API key not configured.'; });
      return;
    }

    String prompt;
    if (manualContext != null) {
      prompt = manualContext;
    } else {
      final p = _profile!;
      final pLower = p.skills.map((s) => s.toLowerCase()).toSet();
      final matchScores = _jobs.take(5).map((j) {
        final matched = j.skills.where((s) => pLower.contains(s.toLowerCase())).length;
        final pct = j.skills.isEmpty ? 0 : ((matched / j.skills.length) * 100).round();
        return '${j.title} at ${j.company}: $pct% match';
      }).join('\n');

      final avgMatch = _jobs.isEmpty ? 0 : _jobs.take(10).map((j) {
        final matched = j.skills.where((s) => pLower.contains(s.toLowerCase())).length;
        return j.skills.isEmpty ? 0 : ((matched / j.skills.length) * 100).round();
      }).reduce((a, b) => a + b) ~/ _jobs.take(10).length;

      prompt = '''You are a senior AI/ML career advisor. Analyze this resume profile in depth and give a highly personalized recommendation. Reference SPECIFIC items from their resume to show the advice is tailored.

CANDIDATE PROFILE:
Name: ${p.name ?? 'User'}
Current Role: ${p.jobTitle}
Experience: ${p.experienceLevel} (${p.yearsOfExperience} years)
Country: ${p.country}
Education: ${p.education ?? 'Not specified'}
Skills: ${p.skills.join(', ')}
Certifications: ${p.certifications.isNotEmpty ? p.certifications.join(', ') : 'None listed'}
Key Projects: ${p.projects.isNotEmpty ? p.projects.join(' | ') : 'Not detailed'}
Strengths identified: ${p.strengths.isNotEmpty ? p.strengths.join(', ') : 'General AI/ML skills'}
Gaps identified: ${p.gaps.isNotEmpty ? p.gaps.join(', ') : 'None identified'}
Summary: ${p.summary}

JOB MARKET DATA:
Average match score across top 10 jobs: $avgMatch%
Top job matches:
$matchScores

Provide a structured recommendation using these EXACT headers:

CAREER PATH
[Address them by first name. Reference their specific experience (${p.yearsOfExperience} years as ${p.jobTitle}) and projects. Describe 2-3 realistic next career moves. Mention which of their skills (name specific ones) make them competitive and which gaps hold them back.]

90-DAY ACTION PLAN
[4-5 numbered, specific action items. Each item should reference something from their profile. Example: "Since you have ${p.skills.isNotEmpty ? p.skills.first : 'Python'} but lack X, do Y". Include specific course names, platforms, or certifications to pursue.]

SKILLS TO ADD
[3 specific skills based on their gaps: ${p.gaps.join(', ')}. For each skill explain WHY it matters for their career level and how it connects to jobs they're matching with.]

JOB READINESS
[Start with: "Based on your profile, you match $avgMatch% of AI/ML roles in ${p.country}." Then explain what's driving that score — which skills helped and which gaps hurt. End with one concrete action that would increase their match rate the most.]

Be specific, reference their actual resume content, not generic advice. Address them by first name.''';
    }

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
          'max_tokens': 1000,
          'messages': [{'role': 'user', 'content': prompt}],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final contentList = data['content'] as List?;
        final text = (contentList != null && contentList.isNotEmpty)
            ? (contentList[0]['text'] as String?) ?? 'No recommendation available.'
            : 'No recommendation available.';
        if (mounted) setState(() { _recommendation = text; _recLoading = false; });
      } else {
        if (mounted) setState(() { _recommendation = 'Could not generate recommendation.'; _recLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _recommendation = 'Error: ${e.toString().replaceFirst("Exception: ", "")}'; _recLoading = false; });
    }
  }

  void _generateManualRecommendation() {
    if (_manualName.isEmpty || _manualSkill.isEmpty) return;
    HapticFeedback.lightImpact();

    final prompt = '''Give a personalized AI/ML career recommendation for this person.

Name: $_manualName
Primary Skill: $_manualSkill
Years of Experience: $_manualYears
Certifications/Projects: ${_manualCerts.isNotEmpty ? _manualCerts : 'None mentioned'}

Provide a structured recommendation in this exact format (use these exact headers):

CAREER PATH
[2-3 sentences on their ideal career trajectory]

90-DAY ACTION PLAN
[3-4 numbered action items for the next 90 days]

SKILLS TO ADD
[2-3 specific skills they should learn next]

JOB READINESS
[1 sentence: estimate what % of AI/ML roles they could apply for, then 1 sentence of advice]

Keep it concise, direct, actionable. Address them by first name.''';

    _generateRecommendation(manualContext: prompt);
  }

  Future<void> _loadRecommendedCerts() async {
    if (_profile == null) return;
    setState(() => _certsLoading = true);
    try {
      final all = await CertificationService.fetchCertifications();
      final p = _profile!;
      final gapsLower = p.gaps.map((g) => g.toLowerCase()).toList();
      // If no gaps were extracted, fall back to current skills as a fuzzy match
      final keywords = gapsLower.isNotEmpty
          ? gapsLower
          : p.skills.take(5).map((s) => s.toLowerCase()).toList();

      final scored = all.map((c) {
        var score = 0;
        for (final kw in keywords) {
          if (kw.isEmpty) continue;
          for (final s in c.skills) {
            final sl = s.toLowerCase();
            if (sl.contains(kw) || kw.contains(sl)) {
              score++;
              break;
            }
          }
          if (c.name.toLowerCase().contains(kw)) score++;
        }
        return (cert: c, score: score);
      }).where((r) => r.score > 0).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      // If nothing matched at all, just take top 4 from full list
      final picks = scored.isEmpty
          ? all.take(4).toList()
          : scored.take(4).map((r) => r.cert).toList();

      if (mounted) {
        setState(() {
          _recommendedCerts = picks;
          _certsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _certsLoading = false);
    }
  }

  Future<void> _loadRecommendedNews() async {
    if (_profile == null) return;
    setState(() => _newsLoading = true);
    try {
      final all = await NewsService.fetchAINews();
      final p = _profile!;
      final keywords = <String>{
        p.jobTitle.toLowerCase(),
        ...p.skills.take(3).map((s) => s.toLowerCase()),
        ...p.gaps.map((g) => g.toLowerCase()),
      }.where((k) => k.isNotEmpty).toList();

      final scored = all.map((a) {
        final text = '${a.title} ${a.description ?? ""}'.toLowerCase();
        var score = 0;
        for (final kw in keywords) {
          if (text.contains(kw)) score++;
        }
        return (article: a, score: score);
      }).where((r) => r.score > 0).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      final picks = scored.isEmpty
          ? all.take(4).toList()
          : scored.take(4).map((r) => r.article).toList();

      if (mounted) {
        setState(() {
          _recommendedNews = picks;
          _newsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _newsLoading = false);
    }
  }

  void _reset() => setState(() {
    _state = _ScanState.idle;
    _profile = null;
    _jobs = [];
    _errorMessage = null;
    _recommendation = null;
    _recLoading = false;
    _recommendedCerts = [];
    _recommendedNews = [];
    _certsLoading = false;
    _newsLoading = false;
  });

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
        title: Text('Resume Scanner',
          style: GoogleFonts.sourceSerif4(
            fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        actions: _state == _ScanState.results
            ? [
                IconButton(
                  icon: Icon(Icons.ios_share_rounded, color: t.primary, size: 19),
                  onPressed: _shareCareerPlan,
                  tooltip: 'Share career plan',
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text('Rescan', style: GoogleFonts.inter(fontSize: 13, color: t.accent)),
                ),
              ]
            : null,
        bottom: _state == _ScanState.results
            ? PreferredSize(
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
                    tabs: const [Tab(text: 'Recommendation'), Tab(text: 'All Jobs')],
                  ),
                  Divider(height: 1, color: t.divider),
                ]))
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: t.divider)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: switch (_state) {
          _ScanState.idle     => _buildIdle(),
          _ScanState.analyzing => _buildAnalyzing(),
          _ScanState.results  => TabBarView(
            controller: _tabCtrl,
            children: [_buildRecommendation(), _buildJobResults()],
          ),
          _ScanState.error    => _buildError(),
        },
      ),
    );
  }

  // ── Idle ───────────────────────────────────────────────────────────────────
  Widget _buildIdle() {
    return SingleChildScrollView(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 20),
        // Upload section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.divider, width: 0.5)),
          child: Column(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.upload_file_rounded, size: 30, color: t.primary),
            ),
            const SizedBox(height: 20),
            Text('Scan Your Resume', style: GoogleFonts.sourceSerif4(
              fontSize: 22, fontWeight: FontWeight.w700, color: t.primary)),
            const SizedBox(height: 8),
            Text('Get matched jobs + career recommendation', textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: t.muted, height: 1.4)),
            const SizedBox(height: 4),
            Text('PDF, TXT, DOC, DOCX',
              style: GoogleFonts.inter(fontSize: 12, color: t.muted.withValues(alpha: 0.6))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _pickAndScan(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: t.primary, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('Upload Resume', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w600, color: t.background))),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickAndScan(useSample: true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: t.divider),
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.science_outlined, size: 14, color: t.secondary),
                  const SizedBox(width: 6),
                  Text('Try with sample resume', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500, color: t.secondary)),
                ])),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        // OR divider
        Row(children: [
          Expanded(child: Divider(color: t.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('or get recommendations without a resume',
              style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
          ),
          Expanded(child: Divider(color: t.divider)),
        ]),

        const SizedBox(height: 24),

        // Manual input
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.divider, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF6366F1)),
              ),
              const SizedBox(width: 10),
              Text('Quick Career Check', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
            ]),
            const SizedBox(height: 16),

            // Name
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(color: t.primary, fontSize: 14),
              decoration: _inputDecor('Your name'),
              onChanged: (v) => _manualName = v,
            ),
            const SizedBox(height: 12),

            // Skill picker
            Text('Primary skill', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _skillOptions.map((s) =>
              GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _manualSkill = s); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _manualSkill == s ? t.primary.withValues(alpha: 0.1) : t.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _manualSkill == s ? t.primary.withValues(alpha: 0.3) : t.divider)),
                  child: Text(s, style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: _manualSkill == s ? FontWeight.w600 : FontWeight.w400,
                    color: _manualSkill == s ? t.primary : t.secondary)),
                ),
              ),
            ).toList()),
            const SizedBox(height: 14),

            // Years
            Text('Years of experience', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(children: ['0-1', '1-2', '2-4', '5+'].map((y) => Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _manualYears = y); },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _manualYears == y ? t.primary.withValues(alpha: 0.1) : t.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _manualYears == y ? t.primary.withValues(alpha: 0.3) : t.divider)),
                  child: Center(child: Text('$y yr', style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: _manualYears == y ? FontWeight.w700 : FontWeight.w400,
                    color: _manualYears == y ? t.primary : t.secondary))),
                ),
              ),
            ))).toList()),
            const SizedBox(height: 12),

            // Certs/projects
            TextField(
              controller: _certCtrl,
              style: GoogleFonts.inter(color: t.primary, fontSize: 14),
              decoration: _inputDecor('Certifications or projects (optional)'),
              onChanged: (v) => _manualCerts = v,
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: (_manualName.isNotEmpty && _manualSkill.isNotEmpty)
                  ? _generateManualRecommendation
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: (_manualName.isNotEmpty && _manualSkill.isNotEmpty)
                      ? t.primary : t.muted.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: _recLoading
                  ? SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: t.background, strokeWidth: 2))
                  : Text('Get Recommendation', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: (_manualName.isNotEmpty && _manualSkill.isNotEmpty)
                        ? t.background : t.muted))),
              ),
            ),

            // Show recommendation inline if generated from manual input
            if (_recommendation != null && _profile == null) ...[
              const SizedBox(height: 20),
              _RecommendationContent(text: _recommendation!, theme: t),
            ],
          ]),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  InputDecoration _inputDecor(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: t.muted, fontSize: 14),
    filled: true, fillColor: t.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.divider)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.divider)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.primary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  // ── Analyzing ─────────────────────────────────────────────────────────────
  Widget _buildAnalyzing() {
    return Center(
      key: const ValueKey('analyzing'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(Icons.psychology_rounded, size: 32, color: t.primary),
            ),
          ),
          const SizedBox(height: 28),
          Text('Analyzing\u2026', style: GoogleFonts.sourceSerif4(
            fontSize: 22, fontWeight: FontWeight.w700, color: t.primary)),
          const SizedBox(height: 10),
          Text(_statusMessage, textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: t.muted)),
        ]),
      ),
    );
  }

  // ── Job Results Tab ───────────────────────────────────────────────────────
  Widget _buildJobResults() {
    final p = _profile!;

    final profileSkillsLower = p.skills.map((s) => s.toLowerCase()).toSet();
    final seen = <String>{};
    final skillGaps = <String>[];
    for (final job in _jobs) {
      for (final s in job.skills) {
        final lower = s.toLowerCase();
        if (!profileSkillsLower.contains(lower) && !seen.contains(lower)) {
          seen.add(lower);
          skillGaps.add(s);
          if (skillGaps.length >= 6) break;
        }
      }
      if (skillGaps.length >= 6) break;
    }

    return ListView(
      key: const ValueKey('jobs'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(p.flagEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (p.name != null) Text(p.name!, style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: t.primary)),
                Text(p.jobTitle, style: GoogleFonts.inter(fontSize: 13, color: t.secondary)),
                Text('${p.country} · ${p.experienceLevel} · ${p.yearsOfExperience} yrs',
                  style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
              ])),
            ]),
            if (p.education != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.school_outlined, size: 13, color: t.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(p.education!, style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (p.certifications.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.verified_outlined, size: 13, color: t.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(p.certifications.join(', '), style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted), maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: p.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4)),
              child: Text(s, style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w500, color: t.primary)),
            )).toList()),
          ]),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Text('${_jobs.length} jobs matched', style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
          const SizedBox(width: 6),
          Text('in ${p.country}', style: GoogleFonts.inter(fontSize: 14, color: t.muted)),
        ]),

        if (skillGaps.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.divider, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.lightbulb_outline_rounded, size: 15, color: t.accent),
                const SizedBox(width: 6),
                Text('Skills to close the gap', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: skillGaps.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.accent.withValues(alpha: 0.2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_circle_outline_rounded, size: 12, color: t.accent),
                  const SizedBox(width: 4),
                  Text(s, style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w500, color: t.accent)),
                ]),
              )).toList()),
            ]),
          ),
        ],
        const SizedBox(height: 12),

        // Job cards
        ..._jobs.map((job) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ResumeJobCard(job: job, theme: t, profile: p),
        )),
      ],
    );
  }

  // ── Recommendation Tab ────────────────────────────────────────────────────

  List<({Job job, int score})> get _topMatches {
    if (_profile == null) return [];
    final p = _profile!;
    final pLower = p.skills.map((s) => s.toLowerCase()).toSet();
    final scored = _jobs.map((j) {
      final matched = j.skills.where((s) => pLower.contains(s.toLowerCase())).length;
      final pct = j.skills.isEmpty ? 0 : ((matched / j.skills.length) * 100).round();
      return (job: j, score: pct);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).toList();
  }

  Widget _buildRecommendation() {
    final top = _topMatches;

    return SingleChildScrollView(
      key: const ValueKey('rec'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Career Recommendation', style: GoogleFonts.sourceSerif4(
              fontSize: 18, fontWeight: FontWeight.w700, color: t.primary)),
            Text('Personalized for ${_profile?.name ?? "you"}', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted)),
          ])),
        ]),
        const SizedBox(height: 20),

        // ATS Score gauge
        if (_profile != null && _profile!.atsScore > 0) ...[
          _AtsScoreCard(
            score: _profile!.atsScore,
            issues: _profile!.atsIssues,
            theme: t),
          const SizedBox(height: 18),
        ],

        // AI recommendation sections
        if (_recLoading)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              CircularProgressIndicator(color: t.primary, strokeWidth: 1.5),
              const SizedBox(height: 16),
              Text('Analyzing your profile...', style: GoogleFonts.inter(
                fontSize: 13, color: t.muted)),
            ]),
          ))
        else if (_recommendation != null)
          _RecommendationContent(text: _recommendation!, theme: t)
        else
          Center(child: Text('No recommendation available', style: GoogleFonts.inter(
            fontSize: 13, color: t.muted))),

        // Top matched jobs to apply
        if (top.isNotEmpty && !_recLoading) ...[
          const SizedBox(height: 28),
          Text('Start applying', style: GoogleFonts.sourceSerif4(
            fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
          const SizedBox(height: 4),
          Text('Your best matches based on resume analysis', style: GoogleFonts.inter(
            fontSize: 12, color: t.muted)),
          const SizedBox(height: 14),
          ...top.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TopMatchCard(job: m.job, score: m.score, theme: t),
          )),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _tabCtrl.animateTo(1);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: t.divider),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('See all ${_jobs.length} matched jobs',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: t.primary))),
            ),
          ),
        ],

        // ── Recommended Courses ──────────────────────────────────────────────
        if (_profile != null && (_certsLoading || _recommendedCerts.isNotEmpty)) ...[
          const SizedBox(height: 32),
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.school_outlined,
                size: 14, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(width: 10),
            Text('Recommended courses', style: GoogleFonts.sourceSerif4(
              fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
          ]),
          const Padding(
            padding: EdgeInsets.only(left: 38, top: 2),
            child: SizedBox(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 2),
            child: Text('Matched to your skill gaps', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted)),
          ),
          const SizedBox(height: 14),
          if (_certsLoading)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5)))
          else
            ..._recommendedCerts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecCertCard(cert: c, theme: t),
            )),
        ],

        // ── News for You ────────────────────────────────────────────────────
        if (_profile != null && (_newsLoading || _recommendedNews.isNotEmpty)) ...[
          const SizedBox(height: 32),
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.article_outlined,
                size: 14, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 10),
            Text('Read up on this', style: GoogleFonts.sourceSerif4(
              fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 2),
            child: Text('News articles relevant to your profile',
              style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
          ),
          const SizedBox(height: 14),
          if (_newsLoading)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5)))
          else
            ..._recommendedNews.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecNewsCard(article: a, theme: t),
            )),
        ],
      ]),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, size: 48, color: t.muted),
          const SizedBox(height: 16),
          Text('Something went wrong', style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
          const SizedBox(height: 8),
          Text(_errorMessage ?? 'Unknown error', textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: t.muted, height: 1.4)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: t.primary), borderRadius: BorderRadius.circular(8)),
              child: Text('Try again', style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Top Match Card (compact with Apply button) ──────────────────────────────
class _TopMatchCard extends StatelessWidget {
  final Job job;
  final int score;
  final AppTheme theme;
  const _TopMatchCard({required this.job, required this.score, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final scoreColor = score >= 70
        ? const Color(0xFF22C55E) : score >= 40
        ? const Color(0xFFF59E0B) : t.muted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5)),
      child: Row(children: [
        // Logo
        if (job.companyLogo != null && job.companyLogo!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: job.companyLogo!, width: 36, height: 36, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _letterAvatar(t)),
          )
        else
          _letterAvatar(t),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(job.title, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: t.primary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(job.company, style: GoogleFonts.inter(fontSize: 12, color: t.secondary)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
              child: Text('$score% match', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: scoreColor)),
            ),
            const SizedBox(width: 6),
            Text(job.salaryRange, style: GoogleFonts.inter(
              fontSize: 11, color: t.muted)),
          ]),
        ])),
        const SizedBox(width: 10),
        // Apply button
        if (job.applyUrl.isNotEmpty)
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              // Track in application tracker as Applied
              await ApplicationTrackerService.add(TrackedApplication(
                id: job.id,
                jobTitle: job.title,
                company: job.company,
                location: job.location,
                salaryRange: job.salaryRange,
                applyUrl: job.applyUrl,
                companyLogo: job.companyLogo,
                status: AppStatus.applied,
                savedAt: DateTime.now().toIso8601String(),
                appliedAt: DateTime.now().toIso8601String(),
              ));
              final uri = Uri.parse(job.applyUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: t.primary, borderRadius: BorderRadius.circular(8)),
              child: Text('Apply', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: t.background)),
            ),
          ),
      ]),
    );
  }

  Widget _letterAvatar(AppTheme t) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: t.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
    child: Center(child: Text(
      job.company.isNotEmpty ? job.company[0] : '?',
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: t.primary))),
  );
}

// ── Recommendation Content (parsed sections) ────────────────────────────────
class _RecommendationContent extends StatelessWidget {
  final String text;
  final AppTheme theme;
  const _RecommendationContent({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Parse sections by headers
    final sections = <({String title, String body, IconData icon, Color color})>[];
    final lines = text.split('\n');
    String currentTitle = '';
    final buffer = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed == 'CAREER PATH' || trimmed == '**CAREER PATH**') {
        if (currentTitle.isNotEmpty) {
          sections.add(_makeSection(currentTitle, buffer.toString().trim()));
        }
        currentTitle = 'Career Path';
        buffer.clear();
      } else if (trimmed == '90-DAY ACTION PLAN' || trimmed == '**90-DAY ACTION PLAN**') {
        if (currentTitle.isNotEmpty) {
          sections.add(_makeSection(currentTitle, buffer.toString().trim()));
        }
        currentTitle = '90-Day Action Plan';
        buffer.clear();
      } else if (trimmed == 'SKILLS TO ADD' || trimmed == '**SKILLS TO ADD**') {
        if (currentTitle.isNotEmpty) {
          sections.add(_makeSection(currentTitle, buffer.toString().trim()));
        }
        currentTitle = 'Skills to Add';
        buffer.clear();
      } else if (trimmed == 'JOB READINESS' || trimmed == '**JOB READINESS**') {
        if (currentTitle.isNotEmpty) {
          sections.add(_makeSection(currentTitle, buffer.toString().trim()));
        }
        currentTitle = 'Job Readiness';
        buffer.clear();
      } else {
        buffer.writeln(trimmed);
      }
    }
    if (currentTitle.isNotEmpty) {
      sections.add(_makeSection(currentTitle, buffer.toString().trim()));
    }

    // Fallback: if parsing failed, show raw text
    if (sections.isEmpty) {
      return Text(text, style: GoogleFonts.inter(
        fontSize: 14, color: t.primary, height: 1.6));
    }

    return Column(children: sections.map((s) {
      // For Job Readiness, extract leading percentage if present
      String? percentBadge;
      var bodyText = s.body;
      if (s.title == 'Job Readiness') {
        final match = RegExp(r'(\d{1,3})\s*%').firstMatch(s.body);
        if (match != null) {
          percentBadge = '${match.group(1)}%';
        }
      }

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              s.color.withValues(alpha: 0.06),
              t.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: s.color.withValues(alpha: 0.18), width: 0.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9)),
              child: Icon(s.icon, size: 16, color: s.color),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text(s.title, style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: t.primary,
              letterSpacing: -0.2))),
            if (percentBadge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: BorderRadius.circular(20)),
                child: Text(percentBadge, style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
          ]),
          const SizedBox(height: 12),
          Text(bodyText, style: GoogleFonts.inter(
            fontSize: 14, color: t.primary.withValues(alpha: 0.88), height: 1.6)),
        ]),
      );
    }).toList());
  }

  ({String title, String body, IconData icon, Color color}) _makeSection(String title, String body) {
    switch (title) {
      case 'Career Path':
        return (title: title, body: body, icon: Icons.route_rounded, color: const Color(0xFF3B82F6));
      case '90-Day Action Plan':
        return (title: title, body: body, icon: Icons.checklist_rounded, color: const Color(0xFF10B981));
      case 'Skills to Add':
        return (title: title, body: body, icon: Icons.school_outlined, color: const Color(0xFFF59E0B));
      case 'Job Readiness':
        return (title: title, body: body, icon: Icons.rocket_launch_outlined, color: const Color(0xFF8B5CF6));
      default:
        return (title: title, body: body, icon: Icons.info_outline_rounded, color: const Color(0xFF6366F1));
    }
  }
}

// ── Job card ────────────────────────────────────────────────────────────────
class _ResumeJobCard extends StatelessWidget {
  final Job job;
  final AppTheme theme;
  final ResumeProfile profile;
  const _ResumeJobCard({required this.job, required this.theme, required this.profile});

  int _matchScore() {
    if (job.skills.isEmpty) return 0;
    final profileSkillsLower = profile.skills.map((s) => s.toLowerCase()).toSet();
    final matched = job.skills.where((s) => profileSkillsLower.contains(s.toLowerCase())).length;
    return ((matched / job.skills.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final score = _matchScore();
    final scoreColor = score >= 70
        ? const Color(0xFF22C55E) : score >= 40
        ? const Color(0xFFF59E0B) : t.muted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _buildLogo(t),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job.title, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: t.primary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(job.company, style: GoogleFonts.inter(fontSize: 12, color: t.secondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$score%', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: scoreColor)),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 5, runSpacing: 5, children: job.skills.take(4).map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: t.background, borderRadius: BorderRadius.circular(4)),
          child: Text(s, style: GoogleFonts.inter(
            fontSize: 10, color: t.secondary, fontWeight: FontWeight.w500)),
        )).toList()),
        const SizedBox(height: 8),
        Row(children: [
          Text(job.location, style: GoogleFonts.inter(fontSize: 11, color: t.muted),
            overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text(job.salaryRange, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600, color: t.primary)),
        ]),
        if (job.applyUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(job.applyUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: t.primary), borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('Apply Now', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: t.primary))),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildLogo(AppTheme t) {
    if (job.companyLogo != null && job.companyLogo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: job.companyLogo!, width: 36, height: 36, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _letterAvatar(t)),
      );
    }
    return _letterAvatar(t);
  }

  Widget _letterAvatar(AppTheme t) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: t.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
    child: Center(child: Text(
      job.company.isNotEmpty ? job.company[0] : '?',
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: t.primary))),
  );
}

// ── ATS Score Card ──────────────────────────────────────────────────────────
class _AtsScoreCard extends StatelessWidget {
  final int score;
  final List<String> issues;
  final AppTheme theme;
  const _AtsScoreCard({required this.score, required this.issues, required this.theme});

  Color get _color => score >= 80
      ? const Color(0xFF10B981) : score >= 60
      ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

  String get _label => score >= 80 ? 'Strong' : score >= 60 ? 'Decent' : 'Needs work';

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            _color.withValues(alpha: 0.10),
            t.surface,
          ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.25), width: 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Circular gauge
          SizedBox(
            width: 64, height: 64,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 64, height: 64,
                child: CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 5,
                  backgroundColor: _color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(_color),
                ),
              ),
              Text('$score', style: GoogleFonts.sourceSerif4(
                fontSize: 18, fontWeight: FontWeight.w700, color: _color)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('ATS Score', style: GoogleFonts.sourceSerif4(
                fontSize: 16, fontWeight: FontWeight.w700, color: t.primary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(_label, style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _color)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('How well your resume passes automated scanners',
              style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
          ])),
        ]),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: t.divider),
          const SizedBox(height: 12),
          Text('How to improve', style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700, color: t.muted, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          ...issues.map((issue) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 4, height: 4,
                decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(issue, style: GoogleFonts.inter(
                fontSize: 13, color: t.primary.withValues(alpha: 0.85), height: 1.5))),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ── Recommended Cert Card ───────────────────────────────────────────────────
class _RecCertCard extends StatelessWidget {
  final Certification cert;
  final AppTheme theme;
  const _RecCertCard({required this.cert, required this.theme});

  IconData get _icon {
    switch (cert.providerType) {
      case 'University': return Icons.school_rounded;
      case 'Tech Company': return Icons.business_rounded;
      case 'Platform': return Icons.laptop_mac_rounded;
      default: return Icons.verified_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    const accent = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(_icon, size: 18, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cert.name, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: t.primary),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(cert.provider, style: GoogleFonts.inter(fontSize: 12, color: t.secondary)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
              child: Text(cert.level, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
            ),
            if (cert.duration != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.schedule_rounded, size: 11, color: t.muted),
              const SizedBox(width: 3),
              Flexible(child: Text(cert.duration!, style: GoogleFonts.inter(
                fontSize: 11, color: t.muted), overflow: TextOverflow.ellipsis)),
            ],
            if (cert.rating != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.star_rounded, size: 11, color: t.muted),
              const SizedBox(width: 2),
              Text(cert.rating!.toStringAsFixed(1), style: GoogleFonts.inter(
                fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
            ],
          ]),
        ])),
        const SizedBox(width: 10),
        if (cert.url != null && cert.url!.isNotEmpty)
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final uri = Uri.parse(cert.url!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: t.primary, borderRadius: BorderRadius.circular(8)),
              child: Text('Enroll', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: t.background)),
            ),
          ),
      ]),
    );
  }
}

// ── Recommended News Card ───────────────────────────────────────────────────
class _RecNewsCard extends StatelessWidget {
  final Article article;
  final AppTheme theme;
  const _RecNewsCard({required this.article, required this.theme});

  String? get _domain {
    try {
      return Uri.parse(article.url).host.replaceFirst('www.', '');
    } catch (_) {
      return null;
    }
  }

  String get _relativeTime {
    if (article.publishedAt == null) return '';
    try {
      final published = DateTime.parse(article.publishedAt!);
      final diff = DateTime.now().difference(published);
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final domain = _domain;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Favicon
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: domain != null
              ? CachedNetworkImage(
                  imageUrl: 'https://www.google.com/s2/favicons?domain=$domain&sz=64',
                  width: 36, height: 36, fit: BoxFit.cover,
                  placeholder: (_, __) => _letterAvatar(t),
                  errorWidget: (_, __, ___) => _letterAvatar(t))
              : _letterAvatar(t),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(article.title, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: t.primary, height: 1.3),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            if (article.source != null && article.source!.isNotEmpty)
              Flexible(child: Text(article.source!, style: GoogleFonts.inter(
                fontSize: 12, color: t.secondary), overflow: TextOverflow.ellipsis)),
            if (_relativeTime.isNotEmpty) ...[
              Text('  ·  ', style: GoogleFonts.inter(
                fontSize: 11, color: t.muted.withValues(alpha: 0.5))),
              Text(_relativeTime, style: GoogleFonts.inter(
                fontSize: 11, color: t.muted)),
            ],
          ]),
        ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            final uri = Uri.parse(article.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: t.primary),
              borderRadius: BorderRadius.circular(8)),
            child: Text('Read', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
          ),
        ),
      ]),
    );
  }

  Widget _letterAvatar(AppTheme t) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: t.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8)),
    child: Center(child: Icon(
      Icons.article_outlined,
      size: 16, color: t.muted)),
  );
}

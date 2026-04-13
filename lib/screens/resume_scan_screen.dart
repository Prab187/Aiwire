import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../models/resume_profile.dart';
import '../models/job.dart';
import '../models/certification.dart';
import '../models/article.dart';
import '../models/event.dart';
import '../services/resume_service.dart';
import '../services/job_service.dart';
import '../services/certification_service.dart';
import '../services/events_service.dart';
import '../services/news_service.dart';
import '../services/youtube_service.dart';
import '../services/profile_storage_service.dart';
import '../services/application_tracker_service.dart';
import '../services/claude_cache.dart';
import '../services/claude_error.dart';
import '../widgets/bullet_summary.dart';
// Premium gate disabled during testing — re-enable before App Store launch
// import '../widgets/quota_paywall.dart';
// import '../services/ai_quota_guard.dart';
import 'mock_interview_screen.dart';
import '../services/analytics_service.dart';

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
  List<Certification> _recommendedCourses = [];
  List<AIEvent> _recommendedEvents = [];
  List<Article> _recommendedNews = [];
  List<YouTubeVideo> _recommendedVideos = [];
  bool _certsLoading = false;
  bool _eventsLoading = false;
  bool _newsLoading = false;
  bool _videosLoading = false;

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
    // Premium gate disabled during testing
    // if (!await checkAiQuotaOrShowPaywall(context, t)) return;

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

      // Save skills + country for other screens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_skills', profile.skills);
      await prefs.setString('user_job_title', profile.jobTitle);
      await prefs.setString('user_level', profile.experienceLevel);
      await prefs.setString('user_country', profile.country);
      await prefs.setString('user_country_code', profile.countryCode);

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
        country: profile.country,
      );

      // Premium gate disabled during testing
      // await AiQuotaGuard.record();
      // await AiQuotaGuard.record();

      setState(() {
        _profile = profile;
        _jobs = jobs;
        _state = _ScanState.results;
      });

      // Track in analytics
      if (useSample) {
        AnalyticsService.sampleResumeUsed();
      } else {
        AnalyticsService.resumeScanned(country: profile.country);
      }

      _generateRecommendation();
      _loadRecommendedCerts();
      _loadRecommendedEvents();
      _loadRecommendedNews();
      _loadRecommendedVideos();
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
      // Use qualified matches (fuzzy, ≥10%) for both the prompt and avg score
      final qualified = _qualifiedMatches;
      debugPrint('AIWire DEBUG: _jobs.length=${_jobs.length}, qualified.length=${qualified.length}');
      for (final m in qualified.take(5)) {
        debugPrint('AIWire DEBUG: ${m.job.title} @ ${m.job.company} = ${m.score}% | skills: ${m.job.skills.join(", ")}');
      }
      debugPrint('AIWire DEBUG: user skills = ${_profile!.skills.join(", ")}');

      final matchScores = qualified.take(5).map((m) =>
        '${m.job.title} at ${m.job.company}: ${m.score}% match'
      ).join('\n');

      int avgMatch;
      if (qualified.isNotEmpty) {
        avgMatch = qualified.take(10).map((m) => m.score).reduce((a, b) => a + b) ~/ qualified.take(10).length;
      } else if (_jobs.isNotEmpty) {
        // Jobs exist but none met the 10% threshold — compute raw average across all jobs
        final allScores = _jobs.map((j) {
          if (j.skills.isEmpty) return 0;
          final pLower = p.skills.map((s) => s.toLowerCase()).toList();
          final jobText = '${j.title} ${j.description} ${j.skills.join(" ")}'.toLowerCase();
          var matched = 0;
          for (final s in pLower) {
            if (s.isEmpty) continue;
            if (j.skills.any((js) => js.toLowerCase().contains(s) || s.contains(js.toLowerCase()))) {
              matched++;
            } else if (jobText.contains(s)) {
              matched++;
            }
          }
          return pLower.isEmpty ? 0 : ((matched / pLower.length) * 100).round();
        }).toList();
        avgMatch = allScores.isEmpty ? 15 : (allScores.reduce((a, b) => a + b) ~/ allScores.length).clamp(5, 100);
      } else {
        // No jobs at all — estimate based on profile strength
        avgMatch = p.skills.length >= 6 ? 35 : (p.skills.length >= 3 ? 20 : 10);
      }
      debugPrint('AIWire DEBUG: avgMatch=$avgMatch');

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

REGIONAL CONTEXT (CRITICAL):
This candidate is based in ${p.country}. EVERY recommendation in this response
MUST be specific to the ${p.country} market. Do NOT give generic global advice:
- For salary figures, use ${p.country}'s local currency and current market rates
- For certifications, prioritize providers and credentials recognized by ${p.country} employers
- For networking and communities, mention ${p.country}-specific meetups, Slacks, and conferences
- For job platforms, reference ones popular in ${p.country} (e.g. Naukri in India, StepStone in Germany, Seek in Australia)
- For skills to add, reflect ${p.country}'s AI/ML hiring trends specifically
- For the 90-day action plan, include at least 2 ${p.country}-specific concrete steps
If you are unsure about something ${p.country}-specific, say so rather than substituting US data.

Provide a structured recommendation using these EXACT headers IN THIS EXACT ORDER.
CRITICAL FORMATTING RULES:
- Every section MUST have EXACTLY 4 numbered points (1. 2. 3. 4.)
- Each point is ONE concise sentence — no paragraphs
- Start each point with a verb or key insight
- In SKILLS TO ACQUIRE, write the FULL skill name clearly (e.g. "1. Large Language Model Fine-Tuning (LoRA/QLoRA): ...")
- Do NOT use bullet dashes or bullet dots — ONLY use "1." "2." "3." "4." numbering

JOB READINESS
1. [Start with: "You match $avgMatch% of AI/ML roles in ${p.country}."]
2. [What's helping their score — reference specific strong skills]
3. [What's hurting their score — reference specific missing skills]
4. [The single most impactful action to improve their readiness]

GAP ANALYSIS
1. [Biggest gap: what ${p.country}'s market demands that they lack — name the skill]
2. [Second gap: another missing competency vs top job requirements]
3. [Experience gap: what level/type of project experience is missing]
4. [Industry gap: what domain knowledge or certification would close the gap]

SKILLS TO ACQUIRE
1. [Start now: FULL SKILL NAME — one sentence explaining why it matters in ${p.country}]
2. [Start now: FULL SKILL NAME — one sentence with a specific resource to learn it]
3. [Learn next: FULL SKILL NAME — one sentence explaining why it matters in ${p.country}]
4. [Learn next: FULL SKILL NAME — one sentence with a specific resource to learn it]

90-DAY PLAN
1. [Month 1 action: specific skill to learn or certification to start, ${p.country}-specific]
2. [Month 1-2 action: specific project to build referencing their profile]
3. [Month 2-3 action: community/event in ${p.country} to join or attend]
4. [Month 3 action: specific application target or portfolio milestone]

Be direct, specific, and ${p.country}-focused. No generic advice. Address by first name. Each point must be a COMPLETE sentence with no truncation.''';
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
          'max_tokens': 1600,
          'messages': [{'role': 'user', 'content': prompt}],
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final contentList = data['content'] as List?;
        final text = (contentList != null && contentList.isNotEmpty)
            ? (contentList[0]['text'] as String?) ?? 'No recommendation available.'
            : 'No recommendation available.';
        if (mounted) setState(() { _recommendation = text; _recLoading = false; });
      } else {
        final errMsg = claudeError(response.statusCode, response.body);
        if (mounted) setState(() {
          _recommendation = friendlyError(errMsg);
          _recLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) setState(() { _recommendation = 'Request timed out. Please try again.'; _recLoading = false; });
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

Provide a structured recommendation using these EXACT headers IN THIS EXACT ORDER.
CRITICAL: Every section MUST have EXACTLY 4 numbered points (1. 2. 3. 4.). Each point is ONE complete sentence. In SKILLS TO ACQUIRE, write the FULL skill name clearly.

JOB READINESS
1. [Estimate what % of AI/ML roles they could apply for]
2. [What's helping their profile]
3. [What's holding them back]
4. [Single most impactful action to improve]

GAP ANALYSIS
1. [Biggest missing skill vs market demands]
2. [Second gap in their profile]
3. [Experience or project gap]
4. [Certification or domain knowledge gap]

SKILLS TO ACQUIRE
1. [Start now: FULL SKILL NAME — why it matters]
2. [Start now: FULL SKILL NAME — specific resource to learn]
3. [Learn next: FULL SKILL NAME — why it matters]
4. [Learn next: FULL SKILL NAME — specific resource to learn]

90-DAY PLAN
1. [Month 1: skill or certification to start]
2. [Month 1-2: project to build]
3. [Month 2-3: community or event to join]
4. [Month 3: application or portfolio milestone]

Be concise, direct, actionable. Address them by first name.''';

    _generateRecommendation(manualContext: prompt);
  }

  /// Heuristic: does this item look like a formal certification vs a
  /// standalone learning course? Certifications tend to come from Tech
  /// Companies (AWS, Google, Microsoft) or have "Certificate",
  /// "Certification", "Specialization", "Professional" in the name.
  bool _looksLikeCertification(Certification c) {
    if (c.providerType == 'Tech Company') return true;
    final n = c.name.toLowerCase();
    return n.contains('certificat')
        || n.contains('specialization')
        || n.contains('professional')
        || n.contains('associate')
        || n.contains('expert');
  }

  Future<void> _loadRecommendedCerts() async {
    if (_profile == null) return;
    setState(() => _certsLoading = true);
    try {
      final all = await CertificationService.fetchCertifications();
      final p = _profile!;
      final gapsLower = p.gaps.map((g) => g.toLowerCase()).toList();
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
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      // Split the pool: certifications (formal credentials) vs courses
      // (standalone learning paths). Use score > 0 matches first, fall
      // back to the general pool if nothing matched.
      final pool = scored.any((r) => r.score > 0)
          ? scored.where((r) => r.score > 0).map((r) => r.cert).toList()
          : all;

      final certs = <Certification>[];
      final courses = <Certification>[];
      for (final c in pool) {
        if (_looksLikeCertification(c)) {
          if (certs.length < 2) certs.add(c);
        } else {
          if (courses.length < 2) courses.add(c);
        }
        if (certs.length >= 2 && courses.length >= 2) break;
      }

      // Fallbacks so neither section is ever empty if data exists
      if (certs.isEmpty && pool.isNotEmpty) {
        certs.addAll(pool.take(2));
      }
      if (courses.isEmpty && pool.length > certs.length) {
        courses.addAll(pool.skip(certs.length).take(2));
      }

      if (mounted) {
        setState(() {
          _recommendedCerts = certs;
          _recommendedCourses = courses;
          _certsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _certsLoading = false);
    }
  }

  Future<void> _loadRecommendedEvents() async {
    if (_profile == null) return;
    setState(() => _eventsLoading = true);
    try {
      // Pass country so the service returns virtual events + in-person events
      // matching the user's country (filtered at the service layer)
      final all = await EventsService.fetchEvents(country: _profile!.country);
      final p = _profile!;
      final keywords = <String>{
        ...p.skills.take(5).map((s) => s.toLowerCase()),
        ...p.gaps.map((g) => g.toLowerCase()),
        p.jobTitle.toLowerCase(),
      }.where((k) => k.isNotEmpty).toList();

      final scored = all.map((e) {
        var score = 0;
        final text = '${e.title} ${e.description} ${e.topics.join(" ")}'.toLowerCase();
        for (final kw in keywords) {
          if (kw.isEmpty) continue;
          if (text.contains(kw)) score++;
        }
        return (event: e, score: score);
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      // Minimum 3 events guaranteed: top up from unscored online list
      final picks = <AIEvent>[];
      final seen = <String>{};
      for (final r in scored.take(5)) {
        if (r.score == 0) break;
        if (picks.length >= 3) break;
        if (seen.add(r.event.id)) picks.add(r.event);
      }
      for (final e in all) {
        if (picks.length >= 3) break;
        if (seen.add(e.id)) picks.add(e);
      }

      if (mounted) {
        setState(() {
          _recommendedEvents = picks;
          _eventsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  Future<void> _loadRecommendedVideos() async {
    if (_profile == null) return;
    setState(() => _videosLoading = true);
    try {
      final p = _profile!;
      // Metadata-only fetch — no Claude calls here. Summaries happen
      // on-demand when the user taps a video card.
      final videos = await YouTubeService.fetchForProfile(
        skills: p.skills,
        jobTitle: p.jobTitle,
        country: p.country,
        maxResults: 3,
      );
      if (mounted) {
        setState(() {
          _recommendedVideos = videos;
          _videosLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _videosLoading = false);
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

      final countryLower = p.country.toLowerCase();
      final scored = all.map((a) {
        final text = '${a.title} ${a.description ?? ""}'.toLowerCase();
        var score = 0;
        for (final kw in keywords) {
          if (text.contains(kw)) score++;
        }
        // Boost articles mentioning the user's country
        if (countryLower.isNotEmpty && text.contains(countryLower)) score += 2;
        return (article: a, score: score);
      }).where((r) => r.score > 0).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      // Minimum 3 articles. If scoring yields fewer, top up from the unscored pool.
      final picks = <Article>[];
      final seen = <String>{};
      for (final r in scored.take(4)) {
        if (picks.length >= 3) break;
        if (seen.add(r.article.url)) picks.add(r.article);
      }
      // Top up to 3 from the general pool if needed
      for (final a in all) {
        if (picks.length >= 3) break;
        if (seen.add(a.url)) picks.add(a);
      }

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
    _recommendedCourses = [];
    _recommendedEvents = [];
    _recommendedNews = [];
    _recommendedVideos = [];
    _certsLoading = false;
    _eventsLoading = false;
    _newsLoading = false;
    _videosLoading = false;
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
                    tabs: const [Tab(text: 'AI Roadmap'), Tab(text: 'Jobs for You')],
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
        const SizedBox(height: 8),

        // ── PRIMARY: Quick Career Check (low friction) ──
        Text('Get Your AI Career Plan', style: GoogleFonts.sourceSerif4(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: t.primary, letterSpacing: -0.4)),
        const SizedBox(height: 4),
        Text('Answer 3 questions — takes 30 seconds',
          style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
        const SizedBox(height: 20),

        // Name
        TextField(
          controller: _nameCtrl,
          style: GoogleFonts.inter(color: t.primary, fontSize: 14),
          decoration: _inputDecor('Your name'),
          onChanged: (v) => _manualName = v,
        ),
        const SizedBox(height: 12),

        // Skill picker
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Primary skill', style: GoogleFonts.inter(
            fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _skillOptions.map((s) =>
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _manualSkill = s); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _manualSkill == s ? t.primary.withValues(alpha: 0.1) : t.surface,
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
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Years of experience', style: GoogleFonts.inter(
            fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 8),
        Row(children: ['0-1', '1-2', '2-4', '5+'].map((y) => Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _manualYears = y); },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _manualYears == y ? t.primary.withValues(alpha: 0.1) : t.surface,
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
        const SizedBox(height: 18),

        // Get Recommendation button
        GestureDetector(
          onTap: (_manualName.isNotEmpty && _manualSkill.isNotEmpty)
              ? _generateManualRecommendation
              : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: (_manualName.isNotEmpty && _manualSkill.isNotEmpty)
                  ? t.primary : t.muted.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: _recLoading
              ? SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: t.background, strokeWidth: 2))
              : Text('Get AI Career Plan', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: (_manualName.isNotEmpty && _manualSkill.isNotEmpty)
                    ? t.background : t.muted))),
          ),
        ),

        // Inline recommendation result
        if (_recommendation != null && _profile == null) ...[
          const SizedBox(height: 20),
          _RecommendationContent(text: _recommendation!, theme: t),
        ],

        const SizedBox(height: 28),

        // ── SECONDARY: Have a resume? ──
        Row(children: [
          Expanded(child: Divider(color: t.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('or upload your resume for a deeper analysis',
              style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
          ),
          Expanded(child: Divider(color: t.divider)),
        ]),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _pickAndScan(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: t.divider),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.upload_file_rounded, size: 16, color: t.primary),
                const SizedBox(width: 8),
                Text('Upload CV', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
              ])),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => _pickAndScan(useSample: true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: t.divider),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.science_outlined, size: 14, color: t.secondary),
                const SizedBox(width: 6),
                Text('Try sample', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500, color: t.secondary)),
              ])),
            ),
          )),
        ]),
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
    final qualified = _qualifiedMatches;
    final qualifiedJobs = qualified.map((m) => m.job).toList();

    final profileSkillsLower = p.skills.map((s) => s.toLowerCase()).toSet();
    final seen = <String>{};
    final skillGaps = <String>[];
    for (final job in qualifiedJobs) {
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
          Text('${qualifiedJobs.length} matched job${qualifiedJobs.length == 1 ? "" : "s"}',
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
          const SizedBox(width: 6),
          Text('in ${p.country}', style: GoogleFonts.inter(fontSize: 14, color: t.muted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${_kMinMatchPct}%+ only', style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600, color: t.muted)),
          ),
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

        // Job cards (filtered to >=10% match)
        if (qualifiedJobs.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.divider, width: 0.5)),
            child: Column(children: [
              Icon(Icons.search_off_rounded, size: 40,
                color: t.muted.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('No strong matches yet', style: GoogleFonts.sourceSerif4(
                fontSize: 16, fontWeight: FontWeight.w700, color: t.primary)),
              const SizedBox(height: 4),
              Text('Add the suggested skills above to unlock matches',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: t.muted, height: 1.4)),
            ]),
          )
        else
          ...qualifiedJobs.map((job) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ResumeJobCard(job: job, theme: t, profile: p),
          )),
      ],
    );
  }

  // ── Recommendation Tab ────────────────────────────────────────────────────

  static const int _kMinMatchPct = 10;

  /// All matched jobs scoring at least _kMinMatchPct, sorted high to low.
  /// Uses fuzzy matching: checks if user skill appears anywhere in job skill
  /// text (substring match), not just exact equality. This handles cases like
  /// user has "Python" and job lists "Python/Django" or "Machine Learning"
  /// matching user's "ML".
  List<({Job job, int score})> get _qualifiedMatches {
    if (_profile == null) return [];
    final p = _profile!;
    final pLower = p.skills.map((s) => s.toLowerCase()).where((s) => s.isNotEmpty).toList();
    if (pLower.isEmpty) return [];

    return _jobs.map((j) {
      if (j.skills.isEmpty) {
        // No skills listed — check title/description for user's skills
        final jobText = '${j.title} ${j.description}'.toLowerCase();
        final found = pLower.where((s) => jobText.contains(s)).length;
        final pct = ((found / pLower.length) * 100).round();
        return (job: j, score: pct);
      }

      final jobText = '${j.title} ${j.description} ${j.skills.join(" ")}'.toLowerCase();
      var matched = 0;
      for (final skill in pLower) {
        // Check if any job skill contains this user skill (or vice versa)
        if (j.skills.any((js) {
          final jl = js.toLowerCase();
          return jl.contains(skill) || skill.contains(jl);
        })) {
          matched++;
        } else if (jobText.contains(skill)) {
          // Broader: skill mentioned anywhere in title/description
          matched++;
        }
      }
      // Use the smaller set as denominator — measures overlap from user's perspective
      final denominator = pLower.length;
      final pct = ((matched / denominator) * 100).round();
      return (job: j, score: pct);
    }).where((r) => r.score >= _kMinMatchPct).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  List<({Job job, int score})> get _topMatches => _qualifiedMatches.take(3).toList();

  Widget _buildRecommendation() {
    final top = _topMatches;

    return SingleChildScrollView(
      key: const ValueKey('rec'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header card with ATS score inline
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6366F1).withValues(alpha: 0.12),
                t.surface,
              ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 20, height: 1, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text('YOUR AI CAREER REPORT', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: const Color(0xFF6366F1), letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 10),
            Text(
              _profile?.name != null
                ? 'AI Career Plan for ${_profile!.name!.split(" ").first}'
                : 'Your AI Career Plan',
              style: GoogleFonts.sourceSerif4(
                fontSize: 24, fontWeight: FontWeight.w700,
                color: t.primary, letterSpacing: -0.5, height: 1.15)),
            const SizedBox(height: 6),
            Text('AI-generated, based on your resume analysis',
              style: GoogleFonts.inter(
                fontSize: 12, color: t.muted, letterSpacing: 0.1)),
            // ATS Score inline
            if (_profile != null && _profile!.atsScore > 0) ...[
              const SizedBox(height: 16),
              Row(children: [
                // Circular gauge (small)
                SizedBox(
                  width: 44, height: 44,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(width: 44, height: 44,
                      child: CircularProgressIndicator(
                        value: _profile!.atsScore / 100.0,
                        strokeWidth: 4,
                        backgroundColor: t.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _profile!.atsScore >= 70
                              ? const Color(0xFF10B981)
                              : _profile!.atsScore >= 50
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444)))),
                    Text('${_profile!.atsScore}', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: t.primary)),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ATS Score', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: t.primary)),
                  const SizedBox(height: 2),
                  Text(
                    _profile!.atsScore >= 70 ? 'Strong — your resume passes most scanners'
                      : _profile!.atsScore >= 50 ? 'Decent — a few improvements will help'
                      : 'Needs work — expand below for fixes',
                    style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
                ])),
                // Expand arrow for details
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.5,
                        minChildSize: 0.3,
                        maxChildSize: 0.8,
                        builder: (_, ctrl) => Container(
                          decoration: BoxDecoration(
                            color: t.background,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20))),
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
                              child: _AtsScoreCard(
                                score: _profile!.atsScore,
                                issues: _profile!.atsIssues,
                                theme: t),
                            )),
                          ]),
                        ),
                      ),
                    );
                  },
                  child: Icon(Icons.chevron_right_rounded,
                    size: 18, color: t.muted),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 8),

        // ── GROUP 2: YOUR PLAN ───────────────────────────────────────────
        if (_recLoading) ...[
          _groupHeader(t, 'YOUR AI ROADMAP'),
          // Shimmer skeleton — mimics 4 collapsed rows
          ...List.generate(4, (i) => Shimmer.fromColors(
            baseColor: t.surface,
            highlightColor: t.divider,
            child: Container(
              height: 56,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ]
        else if (_recommendation != null) ...[
          _groupHeader(t, 'YOUR AI ROADMAP'),
          _RecommendationContent(text: _recommendation!, theme: t, collapsible: true),
        ] else if (!_recLoading)
          Center(child: Text('No recommendation available', style: GoogleFonts.inter(
            fontSize: 13, color: t.muted))),

        // No qualified matches note
        if (top.isEmpty && !_recLoading && _profile != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.divider, width: 0.5)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 14, color: t.muted),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Jobs shown only for ${_kMinMatchPct}%+ skill overlap',
                  style: GoogleFonts.inter(fontSize: 12, color: t.muted))),
              ]),
            ),
          ),

        // ── GROUP 3: YOUR RESOURCES (ordered by engagement priority) ─────
        if (_profile != null && !_recLoading) ...[
          _groupHeader(t, 'YOUR AI TOOLKIT'),

          // 1. Mock Interview (highest engagement)
          if (top.isNotEmpty)
            _CollapsibleRow(
              theme: t,
              icon: Icons.psychology_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'AI Interview Prep',
              count: 0,
              children: [
                ...top.map((m) =>
                  _MockInterviewJobCard(job: m.job, score: m.score, theme: t)),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _tabCtrl.animateTo(1);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.divider),
                      borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(
                      'See all ${_qualifiedMatches.length} matched jobs',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600, color: t.primary))),
                  ),
                ),
              ],
            ),

          // 2. Courses (directly maps to skill gaps)
          if (_recommendedCourses.isNotEmpty)
            _CollapsibleRow(
              theme: t,
              icon: Icons.school_outlined,
              color: const Color(0xFF10B981),
              title: 'AI Courses',
              count: 0,
              children: _recommendedCourses.asMap().entries.map((e) =>
                _RecCertCard(cert: e.value, theme: t,
                  sequenceLabel: e.key == 0 ? 'Start with this' : 'Take next'),
              ).toList(),
            ),

          // 3. Certifications (longer commitment)
          if (_certsLoading || _recommendedCerts.isNotEmpty)
            _CollapsibleRow(
              theme: t,
              icon: Icons.verified_outlined,
              color: const Color(0xFFF59E0B),
              title: 'AI Certifications',
              count: 0,
              loading: _certsLoading,
              children: _recommendedCerts.asMap().entries.map((e) =>
                _RecCertCard(cert: e.value, theme: t,
                  sequenceLabel: e.key == 0 ? 'Start with this' : 'Take next'),
              ).toList(),
            ),

          // 4. Online events (networking)
          if (_eventsLoading || _recommendedEvents.isNotEmpty)
            _CollapsibleRow(
              theme: t,
              icon: Icons.event_outlined,
              color: const Color(0xFFEC4899),
              title: 'AI Events',
              count: 0,
              loading: _eventsLoading,
              children: _recommendedEvents.map((e) =>
                _RecEventCard(event: e, theme: t)).toList(),
            ),

          // 5. News (awareness)
          if (_newsLoading || _recommendedNews.isNotEmpty)
            _CollapsibleRow(
              theme: t,
              icon: Icons.article_outlined,
              color: const Color(0xFF3B82F6),
              title: 'AI News for You',
              count: 0,
              loading: _newsLoading,
              children: _recommendedNews.map((a) =>
                _RecNewsCard(article: a, theme: t)).toList(),
            ),

          // 6. Videos (passive learning)
          if (_videosLoading || _recommendedVideos.isNotEmpty)
            _CollapsibleRow(
              theme: t,
              icon: Icons.smart_display_outlined,
              color: const Color(0xFFFF0000),
              title: 'AI Videos',
              count: 0,
              loading: _videosLoading,
              children: _recommendedVideos.map((v) =>
                _RecVideoCard(video: v, theme: t)).toList(),
            ),

          // ── Quick Start CTA ──
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // Open the first course if available, else mock interview
              if (_recommendedCourses.isNotEmpty && _recommendedCourses.first.url != null) {
                final uri = Uri.parse(_recommendedCourses.first.url!);
                canLaunchUrl(uri).then((ok) {
                  if (ok) launchUrl(uri, mode: LaunchMode.externalApplication);
                });
              } else if (top.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => MockInterviewScreen(theme: t)));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: t.primary,
                borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('Take your first step',
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: t.background))),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: Text(
            _recommendedCourses.isNotEmpty
                ? 'Opens your first recommended course'
                : 'Starts a mock interview for your top match',
            style: GoogleFonts.inter(fontSize: 11, color: t.muted))),
        ],
      ]),
    );
  }

  Widget _groupHeader(AppTheme t, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(children: [
        Container(width: 20, height: 1, color: t.muted.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: t.muted, letterSpacing: 1.5)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1,
          color: t.muted.withValues(alpha: 0.15))),
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

// ── Mock Interview Job Card (practice instead of apply) ────────────────────
class _MockInterviewJobCard extends StatelessWidget {
  final Job job;
  final int score;
  final AppTheme theme;
  const _MockInterviewJobCard({
    required this.job, required this.score, required this.theme});

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
            Flexible(child: Text(job.level, style: GoogleFonts.inter(
              fontSize: 11, color: t.muted), overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            // Persist the chosen role so MockInterviewScreen picks it up
            // via _loadProfileDefaults() from SharedPreferences.
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_job_title', job.title);
            await prefs.setString('user_level', job.level);
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MockInterviewScreen(theme: t)));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.psychology_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text('Practice', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
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
  final bool collapsible;
  const _RecommendationContent({
    required this.text, required this.theme, this.collapsible = false});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Parse sections by headers
    final sections = <({String title, String body, IconData icon, Color color})>[];
    final lines = text.split('\n');
    String currentTitle = '';
    final buffer = StringBuffer();

    // Map of all recognized headers → display title. Handles both old
    // (single career path) and new (2 paths with individual plans) formats.
    final headerMap = <String, String>{
      'GAP ANALYSIS': 'GAP Analysis',
      'WHAT TO DO NEXT': 'GAP Analysis',
      'CAREER PATH 1': 'Career Path 1',
      'CAREER PATH 2': 'Career Path 2',
      'CAREER PATH': 'Career Path',
      '90-DAY PLAN FOR PATH 1': '90-Day Plan — Path 1',
      '90-DAY PLAN FOR PATH 2': '90-Day Plan — Path 2',
      '90-DAY PLAN': '90-Day Plan',
      '90-DAY ACTION PLAN': '90-Day Action Plan',
      'SKILLS TO ADD': 'Skills to Acquire',
      'SKILLS TO ACQUIRE': 'Skills to Acquire',
      'JOB READINESS': 'Job Readiness',
    };

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final upper = trimmed.replaceAll('*', '').replaceAll('#', '').trim();
      String? matchedTitle;
      for (final entry in headerMap.entries) {
        if (upper == entry.key) {
          matchedTitle = entry.value;
          break;
        }
      }

      if (matchedTitle != null) {
        if (currentTitle.isNotEmpty) {
          sections.add(_makeSection(currentTitle, buffer.toString().trim()));
        }
        currentTitle = matchedTitle;
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

    if (!collapsible) {
      return Column(children: [
        for (var i = 0; i < sections.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : 14),
            child: _SectionCard(section: sections[i], index: i, theme: t),
          ),
      ]);
    }

    // Collapsible mode — each AI section is a compact expandable row
    return Column(children: [
      for (var i = 0; i < sections.length; i++)
        _CollapsibleRow(
          theme: t,
          icon: sections[i].icon,
          color: sections[i].color,
          title: sections[i].title,
          count: 0, // no count for AI sections
          children: [_SectionCard(
            section: sections[i], index: i, theme: t)],
        ),
    ]);
  }

  ({String title, String body, IconData icon, Color color}) _makeSection(String title, String body) {
    if (title == 'GAP Analysis' || title == 'What to Do Next') {
      return (title: title, body: body, icon: Icons.analytics_outlined, color: const Color(0xFFEF4444));
    }
    if (title.startsWith('Career Path')) {
      return (title: title, body: body, icon: Icons.route_rounded, color: const Color(0xFF3B82F6));
    }
    if (title.startsWith('90-Day')) {
      return (title: title, body: body, icon: Icons.checklist_rounded, color: const Color(0xFF10B981));
    }
    switch (title) {
      case 'Skills to Add':
      case 'Skills to Acquire':
        return (title: title, body: body, icon: Icons.school_outlined, color: const Color(0xFFF59E0B));
      case 'Job Readiness':
        return (title: title, body: body, icon: Icons.rocket_launch_outlined, color: const Color(0xFF8B5CF6));
      default:
        return (title: title, body: body, icon: Icons.info_outline_rounded, color: const Color(0xFF6366F1));
    }
  }
}

// ── Section Card (professional editorial layout per section type) ───────────
class _SectionCard extends StatelessWidget {
  final ({String title, String body, IconData icon, Color color}) section;
  final int index;
  final AppTheme theme;

  const _SectionCard({required this.section, required this.index, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final s = section;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.divider, width: 0.5),
        boxShadow: [BoxShadow(
          color: t.primary.withValues(alpha: 0.025),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header strip — colored top border + icon + title
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: s.color, width: 3)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(s.icon, size: 16, color: s.color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'PART ${_roman(index + 1)}',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: s.color,
                  letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(s.title, style: GoogleFonts.sourceSerif4(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: t.primary, letterSpacing: -0.3, height: 1.1)),
            ])),
          ]),
        ),
        Divider(height: 1, color: t.divider),

        // Body — different layout per section type
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: _buildBody(t),
        ),
      ]),
    );
  }

  Widget _buildBody(AppTheme t) {
    final s = section;
    // Both the old "90-Day Action Plan" and new "90-Day Plan — Path 1/2"
    // use the numbered list renderer
    if (s.title.startsWith('90-Day')) return _buildActionPlan(t);
    switch (s.title) {
      case 'Skills to Add':
      case 'Skills to Acquire':
        return _buildSkillsToAdd(t);
      case 'Job Readiness':
        return _buildJobReadiness(t);
      case 'GAP Analysis':
      case 'Gap Analysis':
        return _buildNumberedSection(t);
      default:
        return _buildNumberedSection(t);
    }
  }

  /// Default editorial paragraph style — used for Career Path
  Widget _buildProse(AppTheme t) {
    return Text(section.body, style: GoogleFonts.sourceSerif4(
      fontSize: 15, color: t.primary.withValues(alpha: 0.88),
      height: 1.65, letterSpacing: 0.05));
  }

  /// Numbered list — extracts items by leading "1.", "2)", "•", etc.
  Widget _buildActionPlan(AppTheme t) {
    final items = _parseListItems(section.body);
    if (items.isEmpty) return _buildProse(t);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.12),
                shape: BoxShape.circle),
              child: Center(child: Text('${i + 1}', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800, color: section.color))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(items[i], style: GoogleFonts.sourceSerif4(
              fontSize: 14, color: t.primary.withValues(alpha: 0.88),
              height: 1.55, letterSpacing: 0.05))),
          ]),
        ),
    ]);
  }

  /// Skill chips on top + flowing description below
  Widget _buildSkillsToAdd(AppTheme t) {
    final items = _parseListItems(section.body);
    if (items.isEmpty) return _buildProse(t);

    // Extract the actual skill name from items like:
    //   "Start now: LLM Fine-Tuning and Deployment (LoRA/QLoRA...)"
    //   "Learn next: A/B testing rigor"
    //   "Cloud Infrastructure (AWS/GCP): ..."
    final chips = <String>[];
    for (final item in items) {
      // Strip "Start now:", "Learn next:", or similar prefixes first
      var cleaned = item.replaceFirst(RegExp(r'^(?:start now|learn next|add|acquire)\s*:\s*', caseSensitive: false), '');

      // Now extract the skill name — text before the first colon, dash, period, or parenthesis
      final m = RegExp(r'^([A-Za-z][\w\+\#\.\-/ ]{1,40}?)(?:\s*[:\-—(.]|\.\s)').firstMatch(cleaned);
      if (m != null) {
        chips.add(m.group(1)!.trim());
      } else {
        // Fallback: take up to first sentence or 5 words
        final words = cleaned.split(' ').take(5).join(' ');
        if (words.length <= 40) chips.add(words);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (chips.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8, children: chips.map((c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: section.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: section.color.withValues(alpha: 0.25))),
          child: Text(c, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: section.color, letterSpacing: -0.1)),
        )).toList()),
        const SizedBox(height: 16),
      ],
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(width: 5, height: 5,
              decoration: BoxDecoration(
                color: section.color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(item, style: GoogleFonts.sourceSerif4(
            fontSize: 14, color: t.primary.withValues(alpha: 0.88),
            height: 1.55, letterSpacing: 0.05))),
        ]),
      )),
    ]);
  }

  /// Big readiness percentage gauge + numbered points
  Widget _buildJobReadiness(AppTheme t) {
    final match = RegExp(r'(\d{1,3})\s*%').firstMatch(section.body);
    final pct = match != null ? int.tryParse(match.group(1)!) : null;
    final items = _parseListItems(section.body);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (pct != null) ...[
        Center(child: Column(children: [
          SizedBox(
            width: 96, height: 96,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 96, height: 96, child: CircularProgressIndicator(
                value: pct / 100.0,
                strokeWidth: 6,
                backgroundColor: section.color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(section.color))),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$pct', style: GoogleFonts.sourceSerif4(
                  fontSize: 28, fontWeight: FontWeight.w700, color: section.color,
                  height: 1.0)),
                Text('%', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: section.color.withValues(alpha: 0.7))),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          Text('Match rate across top roles', style: GoogleFonts.inter(
            fontSize: 11, color: t.muted,
            fontWeight: FontWeight.w500, letterSpacing: 0.2)),
        ])),
        const SizedBox(height: 18),
        Divider(height: 1, color: t.divider.withValues(alpha: 0.6)),
        const SizedBox(height: 16),
      ],
      if (items.isNotEmpty)
        ...items.asMap().entries.map((e) => Padding(
          padding: EdgeInsets.only(bottom: e.key == items.length - 1 ? 0 : 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.12),
                shape: BoxShape.circle),
              child: Center(child: Text('${e.key + 1}', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800, color: section.color))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(e.value, style: GoogleFonts.sourceSerif4(
              fontSize: 14, color: t.primary.withValues(alpha: 0.88),
              height: 1.55, letterSpacing: 0.05))),
          ]),
        ))
      else
        Text(section.body, style: GoogleFonts.sourceSerif4(
          fontSize: 14, color: t.primary.withValues(alpha: 0.88),
          height: 1.65, letterSpacing: 0.05)),
    ]);
  }

  /// Generic numbered section — parses list items and renders numbered circles
  Widget _buildNumberedSection(AppTheme t) {
    final items = _parseListItems(section.body);
    if (items.isEmpty) return _buildProse(t);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.12),
                shape: BoxShape.circle),
              child: Center(child: Text('${i + 1}', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800, color: section.color))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(items[i], style: GoogleFonts.sourceSerif4(
              fontSize: 14, color: t.primary.withValues(alpha: 0.88),
              height: 1.55, letterSpacing: 0.05))),
          ]),
        ),
    ]);
  }

  /// Strips markdown bold/italic markers and leading/trailing whitespace
  static String _stripMarkdown(String s) {
    return s.replaceAll(RegExp(r'\*{1,3}'), '').replaceAll(RegExp(r'_{1,3}'), '').trim();
  }

  /// Splits a body string into list items based on common patterns:
  /// "1. ...", "1) ...", "- ...", "• ..."
  List<String> _parseListItems(String body) {
    final lines = body.split('\n').map((l) => _stripMarkdown(l)).where((l) => l.isNotEmpty).toList();
    final items = <String>[];
    StringBuffer? current;

    void flush() {
      if (current != null) {
        final v = current.toString().trim();
        if (v.isNotEmpty) items.add(v);
        current = null;
      }
    }

    for (final line in lines) {
      // Numbered (1. or 1)) or bulleted (- or •) start of new item
      final match = RegExp(r'^(?:\d+[\.\)]\s+|[-•]\s+)(.*)$').firstMatch(line);
      if (match != null) {
        flush();
        current = StringBuffer(match.group(1)!);
      } else {
        // Continuation line
        if (current != null) {
          current!.write(' ');
          current!.write(line);
        } else {
          // Body has no list at all — treat each line as an item
          items.add(line);
        }
      }
    }
    flush();
    return items;
  }

  String _roman(int n) {
    const map = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI'};
    return map[n] ?? '$n';
  }
}

// ── Job card ────────────────────────────────────────────────────────────────
class _ResumeJobCard extends StatelessWidget {
  final Job job;
  final AppTheme theme;
  final ResumeProfile profile;
  const _ResumeJobCard({required this.job, required this.theme, required this.profile});

  int _matchScore() {
    final pLower = profile.skills.map((s) => s.toLowerCase()).where((s) => s.isNotEmpty).toList();
    if (pLower.isEmpty) return 0;
    final jobText = '${job.title} ${job.description} ${job.skills.join(" ")}'.toLowerCase();
    var matched = 0;
    for (final skill in pLower) {
      if (job.skills.any((js) {
        final jl = js.toLowerCase();
        return jl.contains(skill) || skill.contains(jl);
      })) {
        matched++;
      } else if (jobText.contains(skill)) {
        matched++;
      }
    }
    return ((matched / pLower.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final score = _matchScore();
    final scoreColor = score >= 60
        ? const Color(0xFF22C55E) : score >= 30
        ? const Color(0xFFF59E0B) : t.muted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.divider, width: 0.5),
        boxShadow: [BoxShadow(
          color: t.primary.withValues(alpha: 0.02),
          blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Row 1: Logo + Title + Score badge
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildLogo(t),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job.title, style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: t.primary, height: 1.2),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(job.company, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w500, color: t.secondary)),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scoreColor.withValues(alpha: 0.3))),
            child: Text('$score% match', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: scoreColor)),
          ),
        ]),

        const SizedBox(height: 12),

        // Row 2: Location + Type + Salary
        Row(children: [
          Icon(Icons.location_on_outlined, size: 13, color: t.muted),
          const SizedBox(width: 3),
          Flexible(child: Text(job.location, style: GoogleFonts.inter(fontSize: 12, color: t.muted),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4)),
            child: Text(job.type, style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600, color: t.secondary)),
          ),
          const Spacer(),
          Text(job.salaryRange, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700, color: t.primary)),
        ]),

        const SizedBox(height: 10),

        // Row 3: Skill chips
        Wrap(spacing: 6, runSpacing: 6, children: job.skills.take(5).map((s) {
          final isMatch = profile.skills.any((ps) {
            final psl = ps.toLowerCase();
            final sl = s.toLowerCase();
            return sl.contains(psl) || psl.contains(sl);
          });
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isMatch
                  ? const Color(0xFF22C55E).withValues(alpha: 0.08)
                  : t.background,
              borderRadius: BorderRadius.circular(6),
              border: isMatch
                  ? Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3))
                  : null),
            child: Text(s, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: isMatch ? const Color(0xFF22C55E) : t.secondary)),
          );
        }).toList()),

        // Row 4: Apply + Save
        const SizedBox(height: 12),
        Row(children: [
          if (job.applyUrl.isNotEmpty)
            Expanded(child: GestureDetector(
              onTap: () async {
                final uri = Uri.parse(job.applyUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('Apply Now', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: t.background))),
              ),
            )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await ApplicationTrackerService.add(TrackedApplication(
                id: job.id,
                jobTitle: job.title,
                company: job.company,
                location: job.location,
                salaryRange: job.salaryRange,
                applyUrl: job.applyUrl,
                companyLogo: job.companyLogo,
                status: AppStatus.saved,
                savedAt: DateTime.now().toIso8601String(),
              ));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Saved to Job Tracker',
                    style: GoogleFonts.inter(fontSize: 13)),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2)));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: t.divider),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.bookmark_add_outlined, size: 18, color: t.muted),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildLogo(AppTheme t) {
    if (job.companyLogo != null && job.companyLogo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: job.companyLogo!, width: 40, height: 40, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _letterAvatar(t)),
      );
    }
    return _letterAvatar(t);
  }

  Widget _letterAvatar(AppTheme t) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: t.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
    child: Center(child: Text(
      job.company.isNotEmpty ? job.company[0] : '?',
      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: t.primary))),
  );
}

// ── Collapsible Row (compact expandable section) ────────────────────────────
class _CollapsibleRow extends StatefulWidget {
  final AppTheme theme;
  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final bool loading;
  final List<Widget> children;

  const _CollapsibleRow({
    required this.theme, required this.icon, required this.color,
    required this.title, required this.count, required this.children,
    this.loading = false,
  });

  @override
  State<_CollapsibleRow> createState() => _CollapsibleRowState();
}

class _CollapsibleRowState extends State<_CollapsibleRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5)),
      child: Column(children: [
        // Header — always visible, tap to toggle
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(widget.icon, size: 15, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: t.primary))),
              if (widget.loading)
                SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                    color: t.muted, strokeWidth: 1.5))
              else ...[
                if (widget.count > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text('${widget.count}', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
                  ),
                  const SizedBox(width: 8),
                ],
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right_rounded,
                    size: 18, color: t.muted),
                ),
              ],
            ]),
          ),
        ),
        // Content — collapsible
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: widget.children.map((c) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: c,
              )).toList(),
            ),
          ),
        ),
      ]),
    );
  }
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
  final String? sequenceLabel;
  const _RecCertCard({required this.cert, required this.theme, this.sequenceLabel});

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sequence label
        if (sequenceLabel != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sequenceLabel == 'Start with this'
                  ? accent.withValues(alpha: 0.12)
                  : t.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                sequenceLabel == 'Start with this'
                    ? Icons.play_arrow_rounded
                    : Icons.skip_next_rounded,
                size: 12,
                color: sequenceLabel == 'Start with this' ? accent : t.muted),
              const SizedBox(width: 4),
              Text(sequenceLabel!, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: sequenceLabel == 'Start with this' ? accent : t.muted)),
            ]),
          ),
        ],
        Row(children: [
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
          ])),
        ]),
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
          const Spacer(),
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
      ]),
    );
  }
}

// ── Recommended Event Card (virtual events) ────────────────────────────────
class _RecEventCard extends StatelessWidget {
  final AIEvent event;
  final AppTheme theme;
  const _RecEventCard({required this.event, required this.theme});

  static const _pink = Color(0xFFEC4899);

  IconData get _typeIcon {
    switch (event.type.toLowerCase()) {
      case 'webinar': return Icons.videocam_outlined;
      case 'workshop': return Icons.build_outlined;
      case 'meetup': return Icons.groups_outlined;
      case 'seminar': return Icons.school_outlined;
      default: return Icons.event_outlined;
    }
  }

  String get _dateDisplay {
    try {
      final d = DateTime.parse(event.date);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return event.date;
    }
  }

  String? get _countdown {
    try {
      final d = DateTime.parse(event.date);
      final days = d.difference(DateTime.now()).inDays;
      if (days < 0) return null;
      if (days == 0) return 'Today';
      if (days == 1) return 'Tomorrow';
      if (days < 7) return 'In ${days}d';
      if (days < 30) return 'In ${(days / 7).round()}w';
      return 'In ${(days / 30).round()}mo';
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final cd = _countdown;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final url = event.registrationUrl;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Date block
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _pink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _pink.withValues(alpha: 0.18))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_dateDisplay.split(' ').first, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: _pink)),
              const SizedBox(height: 1),
              Text(_dateDisplay.split(' ').length > 1 ? _dateDisplay.split(' ')[1] : '',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _pink, height: 1.0)),
            ]),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Type + online badge
            Row(children: [
              Icon(_typeIcon, size: 11, color: t.muted),
              const SizedBox(width: 4),
              Text(event.type, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w600, color: t.muted)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_rounded, size: 8, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 2),
                  Text('Online', style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6))),
                ]),
              ),
              if (cd != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3)),
                  child: Text(cd, style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700, color: t.accent)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(event.title, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: t.primary, height: 1.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(event.organizer, style: GoogleFonts.inter(
              fontSize: 11, color: t.secondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Text(event.isFree ? 'Free' : (event.price ?? 'Paid'),
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: event.isFree ? t.accent : t.primary)),
              if (event.time.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('·', style: GoogleFonts.inter(fontSize: 10, color: t.muted)),
                const SizedBox(width: 6),
                Text('${event.time} ${event.timezone}',
                  style: GoogleFonts.inter(fontSize: 10, color: t.muted)),
              ],
            ]),
          ])),
          const SizedBox(width: 8),
          if (event.registrationUrl != null && event.registrationUrl!.isNotEmpty)
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: t.muted),
        ]),
      ),
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _NewsArticleSheet(article: article, theme: t),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 16, color: t.muted),
          ]),
          const SizedBox(height: 10),
          // AI Summary pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome_rounded,
                size: 10, color: Color(0xFF3B82F6)),
              const SizedBox(width: 4),
              Text('AI Summary', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: const Color(0xFF3B82F6))),
            ]),
          ),
        ]),
      ),
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

// ── News Article Bottom Sheet (AI Summary + Read) ──────────────────────────
class _NewsArticleSheet extends StatefulWidget {
  final Article article;
  final AppTheme theme;
  const _NewsArticleSheet({required this.article, required this.theme});

  @override
  State<_NewsArticleSheet> createState() => _NewsArticleSheetState();
}

class _NewsArticleSheetState extends State<_NewsArticleSheet> {
  static const _blue = Color(0xFF3B82F6);

  bool _loading = true;
  String? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'API key not configured';
      });
      return;
    }

    final title = widget.article.title;
    final description = widget.article.description ?? '';
    final cacheKey = ClaudeCache.keyFrom([title]);

    // Cache for 30 days — same article never re-hits Claude
    final cached = await ClaudeCache.get('news_sum', cacheKey,
        ttl: const Duration(days: 30));
    if (cached != null) {
      if (mounted) setState(() {
        _summary = cached;
        _loading = false;
      });
      return;
    }

    final prompt = '''Summarize this AI news article in exactly 4 concise bullet points. Each bullet starts with "• " and is a single short sentence. Cover: the core news, who's involved, the key insight, and why it matters. No preamble, no headers — just 4 bullets.

Title: $title

${description.isNotEmpty ? description : "(no extended description — infer from title)"}''';

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
          'max_tokens': 320,
          'messages': [{'role': 'user', 'content': prompt}],
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception(claudeError(response.statusCode, response.body));
      }
      final data = json.decode(response.body);
      final contentList = data['content'] as List?;
      final text = (contentList != null && contentList.isNotEmpty)
          ? (contentList[0]['text'] as String?) ?? ''
          : '';
      if (text.isNotEmpty) {
        await ClaudeCache.set('news_sum', cacheKey, text);
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
    final article = widget.article;
    final dateTxt = _relativeTime(article.publishedAt);
    final source = article.source ?? '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
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
                Container(width: 24, height: 1, color: _blue),
                const SizedBox(width: 8),
                Flexible(child: Text(
                  [
                    'NEWS',
                    if (source.isNotEmpty) source.toUpperCase(),
                    if (dateTxt.isNotEmpty) dateTxt.toUpperCase(),
                  ].join(' · '),
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _blue, letterSpacing: 1.2),
                  overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 10),
              Text(article.title, style: GoogleFonts.sourceSerif4(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: t.primary, height: 1.3, letterSpacing: -0.3)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      _blue.withValues(alpha: 0.08),
                      t.surface,
                    ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _blue.withValues(alpha: 0.2), width: 0.8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: _blue),
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
                      accent: _blue,
                      fontSize: 14),
                ]),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(article.url);
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

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return '';
    }
  }
}

// ── Recommended Video Card (thumbnail + title + AI Summary pill) ────────────
class _RecVideoCard extends StatelessWidget {
  final YouTubeVideo video;
  final AppTheme theme;
  const _RecVideoCard({required this.video, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _VideoSummarySheet(video: video, theme: t),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail with duration overlay
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                width: 112, height: 64, fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 112, height: 64, color: t.divider),
                errorWidget: (_, __, ___) => Container(
                  width: 112, height: 64, color: t.divider,
                  child: Icon(Icons.smart_display_outlined,
                    color: t.muted.withValues(alpha: 0.4), size: 24)),
              ),
            ),
            if (video.duration != null)
              Positioned(bottom: 4, right: 4, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3)),
                child: Text(video.duration!, style: GoogleFonts.inter(
                  fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: t.primary, height: 1.3)),
              const SizedBox(height: 4),
              Row(children: [
                Flexible(child: Text(video.channelName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: t.muted))),
                if (video.viewCount != null && video.viewCount!.isNotEmpty) ...[
                  Text('  ·  ', style: GoogleFonts.inter(
                    fontSize: 11, color: t.muted.withValues(alpha: 0.5))),
                  Text(video.viewCount!, style: GoogleFonts.inter(
                    fontSize: 11, color: t.muted)),
                ],
              ]),
              const SizedBox(height: 6),
              // AI Summary pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome_rounded,
                    size: 10, color: Color(0xFFFF0000)),
                  const SizedBox(width: 3),
                  Text('AI Summary', style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF0000))),
                ]),
              ),
            ],
          )),
        ]),
      ),
    );
  }
}

// ── Video Summary Sheet (lazy summarization on tap, cached 7 days) ─────────
class _VideoSummarySheet extends StatefulWidget {
  final YouTubeVideo video;
  final AppTheme theme;
  const _VideoSummarySheet({required this.video, required this.theme});

  @override
  State<_VideoSummarySheet> createState() => _VideoSummarySheetState();
}

class _VideoSummarySheetState extends State<_VideoSummarySheet> {
  static const _red = Color(0xFFFF0000);

  bool _loading = true;
  String? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    try {
      final s = await YouTubeService.summarizeVideo(widget.video);
      if (mounted) setState(() { _summary = s; _loading = false; });
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
    final v = widget.video;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
              // Thumbnail
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: v.thumbnailUrl,
                    width: double.infinity, height: 200, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 200, color: t.surface),
                    errorWidget: (_, __, ___) => Container(height: 200, color: t.surface,
                      child: Icon(Icons.smart_display_outlined,
                        color: t.muted.withValues(alpha: 0.4), size: 48))),
                ),
                if (v.duration != null)
                  Positioned(bottom: 10, right: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text(v.duration!, style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 24, height: 1, color: _red),
                const SizedBox(width: 8),
                Flexible(child: Text(
                  [
                    'VIDEO',
                    v.channelName.toUpperCase(),
                    if (v.viewCount != null && v.viewCount!.isNotEmpty) v.viewCount!.toUpperCase(),
                  ].join(' · '),
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _red, letterSpacing: 1.2),
                  overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 10),
              Text(v.title, style: GoogleFonts.sourceSerif4(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: t.primary, height: 1.3, letterSpacing: -0.3)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      _red.withValues(alpha: 0.06),
                      t.surface,
                    ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _red.withValues(alpha: 0.18), width: 0.8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: _red),
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
                      accent: _red,
                      fontSize: 14),
                ]),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(v.watchUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Watch on YouTube', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
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

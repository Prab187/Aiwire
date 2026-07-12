import '../config/secrets.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
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
import '../services/web_unload_guard.dart';
import '../services/certification_service.dart';
import '../services/events_service.dart';
import '../services/news_service.dart';
import '../services/youtube_service.dart';
import '../services/profile_storage_service.dart';
import '../services/application_tracker_service.dart';
import '../services/claude_cache.dart';
import '../services/claude_error.dart';
import '../services/curated_resources.dart';
import '../services/user_activity_context.dart';
import '../services/job_scoring_service.dart';
import '../services/ghost_job_detector.dart';
import '../models/job_grade.dart';
import '../models/job_legitimacy.dart';
import '../widgets/bullet_summary.dart';
import '../widgets/beginner_starter_plan.dart';
import 'company_research_sheet.dart';
import '../widgets/quota_paywall.dart';
import '../services/ai_quota_guard.dart';
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
  Map<String, JobLegitimacy> _legitimacyMap = {};

  /// Set to false when the resume parse returned too little information to
  /// trust ANY downstream suggestions. When false, every tab shows an honest
  /// "we couldn't read your resume" message instead of fabricated advice.
  bool _profileReadable = true;

  PlatformFile? _originalResumeFile;
  String? _optimizedResumeText;
  bool _generatingOptimized = false;
  String _optimizeStatusMessage = '';
  Timer? _optimizeStatusRotator;

  /// setState of the ATS bottom sheet (if currently open). Modal sheets don't
  /// rebuild on parent setState, so the optimize-status rotator calls this
  /// too to animate the button label inside the sheet.
  StateSetter? _sheetSetState;
  static const List<String> _optimizeMessages = [
    'Reading your resume…',
    'Analysing structure…',
    'Fixing weak phrases…',
    'Adding quantified impact…',
    'Injecting ATS keywords…',
    'Strengthening action verbs…',
    'Restructuring sections…',
    'Keeping your dates intact…',
    'Polishing the wording…',
    'Final formatting pass…',
    'Almost ready…',
  ];

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late TabController _tabCtrl;

  Timer? _statusRotator;
  static const List<String> _analyzingMessages = [
    'Reading your resume…',
    'Extracting your skills…',
    'Spotting experience…',
    'Decoding job titles…',
    'Tallying years of impact…',
    'Sniffing for keywords…',
    'Cross-referencing the job market…',
    'Hunting for hidden strengths…',
    'Measuring ATS-friendliness…',
    'Connecting the dots…',
    'Polishing the profile…',
    'Almost there…',
  ];

  // Career recommendation
  String? _recommendation;
  bool _recLoading = false;
  String _recStatusMessage = '';
  Timer? _recStatusRotator;
  static const List<String> _planMessages = [
    'Crafting your roadmap…',
    'Mapping skills to market demand…',
    'Researching opportunities…',
    'Pinpointing high-impact next moves…',
    'Drafting your 90-day plan…',
    'Pulling together resources…',
    'Sharpening the recommendations…',
    'Almost done…',
  ];

  void _startRecStatusRotator() {
    _recStatusRotator?.cancel();
    var i = 0;
    setState(() => _recStatusMessage = _planMessages[0]);
    _recStatusRotator = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted) return;
      i = (i + 1) % _planMessages.length;
      setState(() => _recStatusMessage = _planMessages[i]);
    });
  }

  void _stopRecStatusRotator() {
    _recStatusRotator?.cancel();
    _recStatusRotator = null;
  }

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
  String _manualSkill = 'None';
  String _manualYears = 'No exp';
  String _manualCerts = '';
  bool _showBeginnerPlan = false;
  final _nameCtrl = TextEditingController();
  final _certCtrl = TextEditingController();

  // Beginner discovery fields
  int _discoveryStep = 0; // 0 = not started, 1 = education, 2 = background, 3 = domain
  String _starterEducation = '';
  String _starterWorkExp = 'No';
  String _starterWorkYears = '';
  String _starterRole = '';
  String _starterDomain = '';
  final _starterRoleCtrl = TextEditingController();
  final _starterYearsCtrl = TextEditingController();

  // Additional context for realistic career planning (collected in manual flow)
  String _manualCountry = '';          // e.g. "India", "United States"
  String _manualHoursPerWeek = '';     // e.g. "5-10", "10-20", "20+"
  String _manualGoal = '';             // e.g. "First AI job", "Career switch", "Level up", "Freelance"
  String _manualWhy = '';              // e.g. "Interest", "Higher pay", "Job security"

  AppTheme get t => widget.theme;

  static const _skillOptions = [
    'None', 'Python', 'Machine Learning', 'Deep Learning', 'NLP',
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
    // Auto-restore the last session if the user reloaded the page / reopened
    // the app. No-op when there's no saved blob.
    unawaited(_restorePersistedSession());
  }

  @override
  void dispose() {
    _statusRotator?.cancel();
    _recStatusRotator?.cancel();
    _optimizeStatusRotator?.cancel();
    // Drop the browser unload guard when this screen goes away so other
    // screens don't inherit a stale prompt.
    setUnloadGuard(enabled: false);
    _pulseCtrl.dispose();
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _certCtrl.dispose();
    _starterRoleCtrl.dispose();
    _starterYearsCtrl.dispose();
    super.dispose();
  }

  void _startStatusRotator() {
    _statusRotator?.cancel();
    var i = 0;
    setState(() => _statusMessage = _analyzingMessages[0]);
    _statusRotator = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      i = (i + 1) % _analyzingMessages.length;
      setState(() => _statusMessage = _analyzingMessages[i]);
    });
  }

  void _stopStatusRotator() {
    _statusRotator?.cancel();
    _statusRotator = null;
  }

  void _startOptimizeStatusRotator() {
    _optimizeStatusRotator?.cancel();
    var i = 0;
    _setOptimizeState(() => _optimizeStatusMessage = _optimizeMessages[0]);
    _optimizeStatusRotator =
        Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      i = (i + 1) % _optimizeMessages.length;
      _setOptimizeState(() => _optimizeStatusMessage = _optimizeMessages[i]);
    });
  }

  /// Updates both the screen AND the open ATS bottom sheet (if any).
  void _setOptimizeState(VoidCallback fn) {
    setState(fn);
    _sheetSetState?.call(() {});
  }

  void _stopOptimizeStatusRotator() {
    _optimizeStatusRotator?.cancel();
    _optimizeStatusRotator = null;
  }

  Future<void> _generateOptimizedResume() async {
    if (_profile == null || _originalResumeFile == null) return;

    // If already generated, just re-open the sheet — no need to re-pay Claude.
    if (_optimizedResumeText != null) {
      _showOptimizedResumeDialog();
      return;
    }

    _setOptimizeState(() => _generatingOptimized = true);
    _startOptimizeStatusRotator();

    try {
      final optimized = await ResumeService.generateOptimizedResume(
        _originalResumeFile!,
        _profile!,
      );
      _stopOptimizeStatusRotator();
      if (mounted) {
        _setOptimizeState(() {
          _optimizedResumeText = optimized;
          _generatingOptimized = false;
        });
        _showOptimizedResumeDialog();
      }
    } catch (e) {
      _stopOptimizeStatusRotator();
      if (mounted) {
        _setOptimizeState(() => _generatingOptimized = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate optimized resume: $e'),
            backgroundColor: t.muted,
          ),
        );
      }
    }
  }

  void _showOptimizedResumeDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OptimizedResumeSheet(
        optimizedText: _optimizedResumeText ?? '',
        theme: t,
      ),
    );
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
      _errorMessage = null;
    });
    _startStatusRotator();

    try {
      final profile = await ResumeService.analyzeResume(file);
      if (!mounted) {
        _stopStatusRotator();
        return;
      }

      // Persist profile data in parallel \u2014 don't block the UI on disk writes.
      // Wrap in try/catch so failures (rare but possible) are logged rather
      // than silently swallowed; the parsed profile is still in memory.
      unawaited(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await Future.wait([
            prefs.setStringList('user_skills', profile.skills),
            prefs.setString('user_job_title', profile.jobTitle),
            prefs.setString('user_level', profile.experienceLevel),
            prefs.setString('user_country', profile.country),
            prefs.setString('user_country_code', profile.countryCode),
            ProfileStorageService.save(SavedProfile(
              id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
              label: profile.jobTitle,
              profile: profile,
              createdAt: DateTime.now().toIso8601String(),
            )),
          ]);
        } catch (e) {
          debugPrint('AIWire: profile persistence failed \u2014 $e');
        }
      }());

      await AiQuotaGuard.record();
      await AiQuotaGuard.record();

      // ⚠️ GLOBAL GATE: If the resume parse returned too little signal,
      // set _profileReadable=false so EVERY tab shows the honest "can't read
      // your resume" message instead of fabricated advice. We also skip all
      // downstream Claude calls — saves API cost and prevents confusing UX.
      final readable = !_profileIsWeak(profile);

      // Flip UI to results immediately so the user sees their parsed profile
      // right away. Jobs and downstream features populate in the background.
      _stopStatusRotator();
      setState(() {
        _profile = profile;
        _originalResumeFile = file;
        _optimizedResumeText = null;
        _jobs = <Job>[];
        _legitimacyMap = {};
        _profileReadable = readable;
        _state = _ScanState.results;
      });

      // Arm the browser's beforeunload guard so an accidental refresh / back
      // doesn't wipe the parsed profile + plan. No-op on iOS/Android.
      setUnloadGuard(enabled: true);

      // Persist the parsed profile JSON so reloading the page restores it
      // without re-uploading the resume. Stored in SharedPreferences (which
      // maps to localStorage on web).
      unawaited(_persistLastSession());

      // Track in analytics
      if (useSample) {
        AnalyticsService.sampleResumeUsed();
      } else {
        AnalyticsService.resumeScanned(country: profile.country);
      }

      // Only fire downstream features if the resume was actually readable
      if (readable) {
        // Non-Claude features (public APIs) fire right away — no TPM impact.
        _loadRecommendedCerts();
        _loadRecommendedEvents();
        _loadRecommendedNews();
        _loadRecommendedVideos();

        // Fetch jobs in the background; once they arrive, update the UI and
        // kick off the Claude recommendation. The jobs API round-trip naturally
        // spaces this Claude call out from the resume-analysis call, so the
        // previous artificial 3s TPM-drain delay is no longer needed.
        unawaited(JobService.fetchJobsForResume(
          skills: profile.skills,
          countryCode: profile.countryCode,
          jobTitle: profile.jobTitle,
          country: profile.country,
          city: profile.city,
        ).then((jobs) {
          if (!mounted) return;
          setState(() {
            _jobs = jobs;
            _legitimacyMap = GhostJobDetector.evaluateAll(jobs);
          });
          _generateRecommendation();
        }).catchError((e, st) {
          // Critical: if the jobs API fails, still fire the recommendation
          // (with no job context) so the Career Plan tab doesn't hang silently.
          debugPrint('AIWire: jobs fetch failed — $e');
          if (!mounted) return;
          _generateRecommendation();
        }));
      }
    } catch (e) {
      _stopStatusRotator();
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _shareCareerPlan() async {
    if (_profile == null) return;
    // Don't share a half-loaded plan — bail with a friendly toast instead.
    if (_recommendation == null || _recLoading) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _recLoading
              ? 'Career plan is still generating — try again in a moment.'
              : 'Generate your career plan first, then share it.',
            style: GoogleFonts.inter(fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)));
      }
      return;
    }
    HapticFeedback.lightImpact();
    final p = _profile!;
    final text = '''My AI Career Plan — built with AIWire

${p.name ?? "I"} · ${p.jobTitle} · ${p.experienceLevel} (${p.yearsOfExperience}y)

Top skills: ${p.skills.take(5).join(", ")}
ATS Score: ${p.atsScore}/100

$_recommendation

Get yours: aiwire.app''';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Returns true if the parsed resume has enough signal to generate a useful
  /// career plan. If false, we REFUSE to fabricate advice and tell the user
  /// their resume couldn't be read properly.
  bool _profileIsWeak(ResumeProfile p) {
    // Need at least 3 skills AND (a job title OR some work experience signal)
    final hasSkills = p.skills.length >= 3;
    final hasRoleSignal = p.jobTitle.trim().isNotEmpty
        && p.jobTitle.toLowerCase() != 'ai/ml engineer'; // default fallback value
    final hasExperienceSignal = p.yearsOfExperience > 0
        || p.projects.isNotEmpty
        || p.education != null;
    return !(hasSkills && (hasRoleSignal || hasExperienceSignal));
  }

  Future<void> _generateRecommendation({String? manualContext}) async {
    setState(() { _recLoading = true; _recommendation = null; });
    _startRecStatusRotator();

    const apiKey = Secrets.anthropicApiKey;
    if (apiKey.isEmpty) {
      _stopRecStatusRotator();
      setState(() { _recLoading = false; _recommendation = 'API key not configured.'; });
      return;
    }

    String prompt;
    if (manualContext != null) {
      prompt = manualContext;
    } else {
      // Upstream gate (_profileReadable check in _analyzeResume) already
      // prevented this from firing for unreadable resumes. Defensive re-check:
      if (!_profileReadable) {
        _stopRecStatusRotator();
        setState(() { _recLoading = false; _recommendation = null; });
        return;
      }
      final p = _profile!;

      // Use qualified matches (fuzzy, ≥10%) for both the prompt and avg score
      final qualified = _qualifiedMatches;

      final matchScores = qualified.take(5).map((m) =>
        '${m.job.title} at ${m.job.company}: Grade ${m.grade.letter} (${m.grade.composite}%)'
      ).join('\n');

      // ── HONEST MATCH COMPUTATION ────────────────────────────────────
      // Only show a percentage if we have REAL data to back it up.
      // No more "p.skills.length >= 6 ? 35 : 20" fabrications.
      int? avgMatch;      // null = insufficient data
      String matchStatus;  // What we actually know

      if (qualified.isNotEmpty) {
        // Best case: real matches against real jobs
        avgMatch = qualified.take(10).map((m) => m.grade.composite).reduce((a, b) => a + b) ~/ qualified.take(10).length;
        matchStatus = 'Based on ${qualified.length} real job matches above ${_kMinMatchPct}% threshold';
      } else if (_jobs.isNotEmpty) {
        // Jobs exist but none hit threshold — compute raw average honestly (no clamping)
        final allScores = _jobs.map((j) {
          if (j.skills.isEmpty) return -1; // -1 = don't count
          final pLower = p.skills.map((s) => s.toLowerCase()).toList();
          var matched = 0;
          for (final s in pLower) {
            if (s.isEmpty) continue;
            if (j.skills.any((js) => js.toLowerCase().contains(s) || s.contains(js.toLowerCase()))) {
              matched++;
            }
          }
          return pLower.isEmpty ? -1 : ((matched / pLower.length) * 100).round();
        }).where((s) => s >= 0).toList();
        if (allScores.isNotEmpty) {
          avgMatch = allScores.reduce((a, b) => a + b) ~/ allScores.length;
          matchStatus = 'Weak match — ${_jobs.length} jobs scanned, none above ${_kMinMatchPct}% threshold';
        } else {
          avgMatch = null;
          matchStatus = 'Jobs returned no comparable skill data';
        }
      } else {
        // No jobs at all — be HONEST that we can't compute
        avgMatch = null;
        matchStatus = 'No open jobs found in ${p.country} for your role right now';
      }
      // Trimmed prompt — ~40% fewer tokens than before, same output quality
      final readinessLine1 = avgMatch != null
          ? '1. Start EXACTLY with: "You match $avgMatch% of AI/ML roles in ${p.country}."'
          : '1. Start EXACTLY with: "Match unavailable — ${matchStatus.toLowerCase()}."';

      prompt = '''Senior AI/ML career advisor: generate a specific, ${p.country}-focused recommendation for this candidate. Reference their actual resume details.

PROFILE:
Name: ${p.name ?? 'User'} | Role: ${p.jobTitle} | Level: ${p.experienceLevel} (${p.yearsOfExperience}y) | Country: ${p.country}
Education: ${p.education ?? 'Not specified'}
Skills: ${p.skills.join(', ')}
${p.certifications.isNotEmpty ? "Certs: ${p.certifications.join(', ')}" : ""}
${p.projects.isNotEmpty ? "Projects: ${p.projects.join(' | ')}" : ""}
${p.strengths.isNotEmpty ? "Strengths: ${p.strengths.join(', ')}" : ""}
${p.gaps.isNotEmpty ? "Gaps: ${p.gaps.join(', ')}" : ""}

JOB MATCH DATA:
${avgMatch != null ? "Avg match: $avgMatch% ($matchStatus)" : "Match UNAVAILABLE ($matchStatus)"}
${matchScores.isEmpty ? "(no qualifying matches)" : matchScores}

RULES:
- Every section = EXACTLY 4 numbered points (1. 2. 3. 4.), one concise sentence each.
- Localize: ${p.country} salary/currency, ${p.country}-specific courses + communities (e.g. Naukri for India, StepStone for Germany, Seek for AU).
- NO invented match %. Use only what's given above or say "unavailable".
- NO fabricated skills/gaps not supported by the profile data.
- Name SPECIFIC courses/providers — pick from: ${CuratedResources.compactProviders.trim().replaceAll(RegExp(r'\s+'), ' ').substring(0, 350)}...

OUTPUT THESE 4 SECTIONS IN THIS ORDER:

JOB READINESS
$readinessLine1
2. What's HELPING — cite specific skills from their resume.
3. What's HURTING — cite specific gaps. If thin data, say so.
4. Single most impactful next action. Concrete (named skill/cert/project), not generic.

GAP ANALYSIS
1. Biggest gap for ${p.country} AI/ML market — name the skill.
2. Second gap.
3. Experience/project gap.
4. Credential or domain gap.

SKILLS TO ACQUIRE
1. Start now: FULL SKILL — why it matters in ${p.country}.
2. Start now: FULL SKILL — named resource to learn it.
3. Learn next: FULL SKILL — why.
4. Learn next: FULL SKILL — named resource.

90-DAY PLAN (each item needs: action + named resource + hrs/wk + outcome)
1. Month 1 — Skill/cert: Course by Provider (hrs/wk, local price). Outcome.
2. Month 1-2 — Portfolio project referencing their skills. Where to publish.
3. Month 2-3 — Named ${p.country} meetup/Slack/Discord. Outcome: 3 connections.
4. Month 3 — Apply to 5-10 specific ${p.jobTitle} roles. Local community: ${CuratedResources.communitiesFor(p.country)}

Address by first name. Direct. Complete sentences.''';
    }

    // Retry loop: iOS can close sockets unexpectedly, giving "bad file
    // descriptor". We try up to 3 times with exponential backoff.
    const maxAttempts = 3;
    http.Response? response;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      // Use a fresh HTTP client per attempt so we never reuse a dead socket
      final client = http.Client();
      try {
        response = await client.post(
          Uri.parse('https://aiwire-proxy.prab187.workers.dev'),
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
        break; // success
      } on TimeoutException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
        // Retry on socket/network errors (bad file descriptor, connection
        // closed, etc.) — NOT on HTTP errors (those need no retry).
        final msg = e.toString().toLowerCase();
        final isTransient = msg.contains('bad file descriptor')
            || msg.contains('connection closed')
            || msg.contains('socket')
            || msg.contains('broken pipe')
            || msg.contains('connection reset');
        if (!isTransient) break;
      } finally {
        client.close();
      }
      if (attempt < maxAttempts) {
        // Exponential backoff: 500ms, 1500ms
        await Future.delayed(Duration(milliseconds: 500 * attempt * attempt));
      }
    }

    try {
      if (response == null) {
        throw Exception(lastError?.toString() ?? 'Network unavailable');
      }
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final contentList = data['content'] as List?;
        final text = (contentList != null && contentList.isNotEmpty)
            ? (contentList[0]['text'] as String?) ?? 'No recommendation available.'
            : 'No recommendation available.';
        _stopRecStatusRotator();
        if (mounted) setState(() { _recommendation = text; _recLoading = false; });
        unawaited(_persistLastSession()); // refresh saved blob with the plan
      } else {
        final errMsg = claudeError(response.statusCode, response.body);
        _stopRecStatusRotator();
        if (mounted) setState(() {
          _recommendation = friendlyError(errMsg);
          _recLoading = false;
        });
      }
    } on TimeoutException {
      _stopRecStatusRotator();
      if (mounted) setState(() { _recommendation = 'Request timed out. Please try again.'; _recLoading = false; });
    } catch (e) {
      _stopRecStatusRotator();
      final msg = e.toString().replaceFirst('Exception: ', '');
      // Convert technical errors into friendlier messages
      final friendly = msg.toLowerCase().contains('bad file descriptor')
          || msg.toLowerCase().contains('socket')
          ? 'Network connection dropped. Please check your internet and try again.'
          : msg;
      if (mounted) setState(() { _recommendation = 'Error: $friendly'; _recLoading = false; });
    }
  }

  void _generateManualRecommendation() {
    if (_manualName.isEmpty) return;
    HapticFeedback.lightImpact();

    final isNewbie = _manualYears == 'No exp';
    final hasNoSkill = _manualSkill == 'None';
    final country = _manualCountry.isEmpty ? 'Global (country not specified)' : _manualCountry;

    // ── Pure beginner shortcut — use hardcoded starter plan (NO Claude call) ──
    // This gives the user a rich, immediately-useful 7-day kickstart plan without
    // spending API credits. The BeginnerStarterPlan widget already personalizes
    // using the discovery data they entered (education, domain, prior role).
    if (isNewbie && hasNoSkill) {
      setState(() {
        _showBeginnerPlan = true;
        _recommendation = null;
      });
      return;
    }

    // Build a rich context block that ACTUALLY uses every input the user gave.
    // Previously the Claude prompt ignored education, prior work, domain, etc.
    // which is why beginners saw generic advice that felt disconnected.
    final backgroundLines = <String>[];
    if (_starterEducation.isNotEmpty) {
      backgroundLines.add('- Education: $_starterEducation');
    }
    if (_starterWorkExp == 'Yes' && _starterRole.isNotEmpty) {
      final yrs = _starterWorkYears.isNotEmpty ? '$_starterWorkYears yrs as ' : '';
      backgroundLines.add('- Prior non-AI work: $yrs$_starterRole');
      backgroundLines.add('  → Identify 2 TRANSFERABLE skills from being a $_starterRole that apply to AI roles (be specific — e.g., if Teacher: instructional design transfers to LLM prompt crafting + user-facing AI explanation; if Sales: customer empathy transfers to AI product work).');
    } else if (_starterWorkExp == 'No') {
      backgroundLines.add('- Prior work experience: None — fresh start');
    }
    if (_starterDomain.isNotEmpty && _starterDomain != 'Not sure yet') {
      backgroundLines.add('- Target industry: $_starterDomain');
      backgroundLines.add('  → Recommend 1 domain-specific AI application in $_starterDomain they should build as a portfolio project.');
    }
    final backgroundBlock = backgroundLines.isEmpty
        ? ''
        : '\n\nBACKGROUND DETAILS (use these to tailor advice — do NOT ignore):\n${backgroundLines.join("\n")}';

    // Time + goal context — hugely affects realistic plan scale
    final planningContext = <String>[];
    if (_manualHoursPerWeek.isNotEmpty) {
      planningContext.add('- Hours available per week: $_manualHoursPerWeek');
      planningContext.add('  → Scale the 90-day plan to this budget. At 5hrs/wk expect 3-6 months to first cert; at 20+hrs/wk expect 2-3 months.');
    }
    if (_manualGoal.isNotEmpty) {
      planningContext.add('- Primary goal: $_manualGoal');
    }
    if (_manualWhy.isNotEmpty) {
      planningContext.add('- Motivation: $_manualWhy');
    }
    final planBlock = planningContext.isEmpty
        ? ''
        : '\n\nPLANNING CONTEXT:\n${planningContext.join("\n")}';

    final expLine = isNewbie
        ? 'Experience: Complete beginner — no prior AI/ML work experience'
        : 'Years of Experience: $_manualYears';

    final newbieContext = isNewbie
        ? '''
IMPORTANT: This person is a BEGINNER in AI/ML. Be realistic but encouraging.
- Do NOT assume they know industry jargon — explain terms briefly
- Prioritize FREE resources (Coursera financial aid, Fast.ai, Hugging Face courses, Kaggle Learn, YouTube)
- Focus on building a public portfolio (GitHub + Kaggle) from zero
- Suggest entry-level roles appropriate for their background (use Education + Prior Role above)
- Build on their TRANSFERABLE skills — don't treat them as a blank slate if they have non-tech work experience'''
        : '';

    final skillLine = hasNoSkill
        ? 'Primary Skill: No specific AI/ML skill yet — complete beginner'
        : 'Primary Skill: $_manualSkill';

    final prompt = '''Give a personalized AI/ML career recommendation for this person. Use EVERY detail below — do not give a generic plan.

Name: $_manualName
Country: $country
$skillLine
$expLine
Certifications/Projects: ${_manualCerts.isNotEmpty ? _manualCerts : 'None mentioned'}
$backgroundBlock
$planBlock
$newbieContext

REGIONAL CONTEXT (CRITICAL):
EVERY recommendation MUST be specific to $country:
- Salary: local currency (₹ for India, £ for UK, € for EU, \$ for US)
- Courses: prefer providers with local pricing/availability
- Communities: name ACTUAL meetups/Slacks in $country (e.g. PyData Bangalore for India, London AI Meetup for UK, MLOps Community for US)
- Job boards: Naukri for India, Seek for Australia, StepStone for Germany, LinkedIn globally

Provide a structured recommendation using these EXACT headers IN THIS EXACT ORDER.
CRITICAL: Every section MUST have EXACTLY 4 numbered points (1. 2. 3. 4.). Each point is ONE complete sentence with specifics (named tools, courses, companies — not vague advice).

JOB READINESS
1. [${isNewbie ? "Honestly assess their starting point given their education (${_starterEducation.isNotEmpty ? _starterEducation : "not specified"}) and background — it's okay to be at 5-15%" : "Estimate what % of AI/ML roles they could apply for TODAY"}]
2. [${isNewbie ? "ONE concrete advantage from their background (education, prior role, or domain interest) that helps" : "What's helping their profile"}]
3. [${isNewbie ? "The biggest thing they must build first (specific skill or portfolio artifact)" : "What's holding them back"}]
4. [${isNewbie ? "The single best first step to take THIS WEEK" : "Single most impactful action to improve"}]

GAP ANALYSIS
1. [Biggest missing skill for ${_starterDomain.isNotEmpty && _starterDomain != "Not sure yet" ? "$_starterDomain AI roles" : "AI/ML roles"} in $country right now]
2. [Second gap — experience/portfolio/communication/domain]
3. [Third gap — credential or certification]
4. [Fourth gap — network, visibility, or project diversity]

SKILLS TO ACQUIRE
1. [Start now: FULL SKILL NAME — one sentence: why + named resource (Coursera/Udemy/Fast.ai/etc.) + cost in $country currency]
2. [Start now: FULL SKILL NAME — one sentence: why + named resource + cost]
3. [Learn next (after 1-2 months): FULL SKILL NAME — why this is the right second skill for them]
4. [Learn next: FULL SKILL NAME — specific to their target ${_starterDomain.isNotEmpty && _starterDomain != "Not sure yet" ? "($_starterDomain)" : "industry"}]

90-DAY PLAN
Each item MUST include: (a) action, (b) SPECIFIC named resource (actual course/book/competition — NO placeholders), (c) hrs/week tuned to ${_manualHoursPerWeek.isEmpty ? "their availability (default 8-10 hrs)" : "$_manualHoursPerWeek hrs/wk"}, (d) measurable outcome.
1. [Month 1: First skill or certification with named provider, cost, and week-by-week breakdown]
2. [Month 1-2: Portfolio project using learnings — specific GitHub/Kaggle/HuggingFace deliverable. If they have domain interest (${_starterDomain.isNotEmpty ? _starterDomain : "not set"}), the project MUST be in that domain]
3. [Month 2-3: Community engagement — named local meetup/Slack in $country + content they should post (blog, LinkedIn, Twitter)]
4. [Month 3: Application target — specific companies hiring in $country + their referral strategy]

Be concise, direct, actionable, and encouraging. Address them by first name.${isNewbie ? " Remember: they have ZERO AI experience but they DO have life/work experience — build on it, don't ignore it." : ""}''';

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
    if (!mounted) return;
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
    } catch (e) {
      debugPrint('AIWire: certifications fetch failed — $e');
      if (mounted) setState(() {
        _certsLoading = false;
      });
    }
  }

  Future<void> _loadRecommendedEvents() async {
    if (_profile == null) return;
    if (!mounted) return;
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
    } catch (e) {
      debugPrint('AIWire: events fetch failed — $e');
      if (mounted) setState(() {
        _eventsLoading = false;
      });
    }
  }

  Future<void> _loadRecommendedVideos() async {
    if (_profile == null) return;
    if (!mounted) return;
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
    } catch (e) {
      debugPrint('AIWire: videos fetch failed — $e');
      if (mounted) setState(() {
        _videosLoading = false;
      });
    }
  }

  Future<void> _loadRecommendedNews() async {
    if (_profile == null) return;
    if (!mounted) return;
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
    } catch (e) {
      debugPrint('AIWire: news fetch failed — $e');
      if (mounted) setState(() {
        _newsLoading = false;
      });
    }
  }

  void _reset() {
    // User explicitly cleared the session — drop the browser-refresh guard
    // and wipe the persisted session so reload doesn't re-restore.
    setUnloadGuard(enabled: false);
    unawaited(_clearPersistedSession());
    setState(() {
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
  }

  // ── Session persistence (per Arundhathi's feedback — don't lose results
  //    on refresh / browser close / accidental nav)
  static const _kSessionKey = 'last_resume_session_v1';

  Future<void> _persistLastSession() async {
    try {
      if (_profile == null) return;
      final prefs = await SharedPreferences.getInstance();
      final blob = json.encode({
        'savedAt': DateTime.now().toIso8601String(),
        'profile': _profile!.toJson(),
        'recommendation': _recommendation,
      });
      await prefs.setString(_kSessionKey, blob);
    } catch (e) {
      debugPrint('AIWire: persist session failed — $e');
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
    } catch (_) {}
  }

  Future<void> _restorePersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blob = prefs.getString(_kSessionKey);
      if (blob == null) return;
      final data = json.decode(blob) as Map<String, dynamic>;
      final profileJson = data['profile'] as Map<String, dynamic>?;
      if (profileJson == null) return;
      final profile = ResumeProfile.fromJson(profileJson);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileReadable = !_profileIsWeak(profile);
        _recommendation = data['recommendation'] as String?;
        _state = _ScanState.results;
      });
      setUnloadGuard(enabled: true);
      // Re-fetch jobs in the background — those weren't persisted (they go
      // stale fast anyway). The recommendation we restore as-is.
      if (_profileReadable) {
        unawaited(JobService.fetchJobsForResume(
          skills: profile.skills,
          countryCode: profile.countryCode,
          jobTitle: profile.jobTitle,
          country: profile.country,
          city: profile.city,
        ).then((jobs) {
          if (!mounted) return;
          setState(() {
            _jobs = jobs;
            _legitimacyMap = GhostJobDetector.evaluateAll(jobs);
          });
        }).catchError((e, st) {
          debugPrint('AIWire: jobs re-fetch after restore failed — $e');
        }));
      }
    } catch (e) {
      debugPrint('AIWire: restore session failed — $e');
    }
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
        title: Text('Resume Scanner',
          style: GoogleFonts.sourceSerif4(
            fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
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
          onChanged: (v) => setState(() => _manualName = v),
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
              child: Text(s == 'None' ? 'Not sure yet' : s, style: GoogleFonts.inter(
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
        Wrap(spacing: 6, runSpacing: 6, children: ['No exp', '0-1', '1-2', '2-4', '5+'].map((y) => GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _manualYears = y); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _manualYears == y ? t.primary.withValues(alpha: 0.1) : t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _manualYears == y ? t.primary.withValues(alpha: 0.3) : t.divider)),
            child: Text(y == 'No exp' ? 'No experience' : '$y yr', style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: _manualYears == y ? FontWeight.w700 : FontWeight.w400,
              color: _manualYears == y ? t.primary : t.secondary)),
          ),
        )).toList()),
        const SizedBox(height: 14),

        // ── Country picker — enables local salary/courses/communities ──
        if (_manualName.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Your country', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            'India', 'United States', 'United Kingdom', 'Canada', 'Australia',
            'Germany', 'Singapore', 'Brazil', 'Other',
          ].map((c) => GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _manualCountry = c); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _manualCountry == c ? t.primary.withValues(alpha: 0.1) : t.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _manualCountry == c ? t.primary.withValues(alpha: 0.3) : t.divider)),
              child: Text(c, style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: _manualCountry == c ? FontWeight.w600 : FontWeight.w400,
                color: _manualCountry == c ? t.primary : t.secondary)),
            ),
          )).toList()),
          const SizedBox(height: 14),

          // ── Hours per week — scales the plan realistically ──
          Align(
            alignment: Alignment.centerLeft,
            child: Text('How many hours per week can you dedicate?', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            '2-5 hrs', '5-10 hrs', '10-20 hrs', '20+ hrs',
          ].map((h) => GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _manualHoursPerWeek = h); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _manualHoursPerWeek == h ? t.primary.withValues(alpha: 0.1) : t.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _manualHoursPerWeek == h ? t.primary.withValues(alpha: 0.3) : t.divider)),
              child: Text(h, style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: _manualHoursPerWeek == h ? FontWeight.w600 : FontWeight.w400,
                color: _manualHoursPerWeek == h ? t.primary : t.secondary)),
            ),
          )).toList()),
          const SizedBox(height: 14),

          // ── Goal — what do they actually want? ──
          Align(
            alignment: Alignment.centerLeft,
            child: Text('What\'s your goal?', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            'First AI/ML job',
            'Career switch to AI',
            'Level up in current AI role',
            'Freelance / consulting',
            'Just exploring',
          ].map((g) => GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _manualGoal = g); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _manualGoal == g ? t.primary.withValues(alpha: 0.1) : t.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _manualGoal == g ? t.primary.withValues(alpha: 0.3) : t.divider)),
              child: Text(g, style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: _manualGoal == g ? FontWeight.w600 : FontWeight.w400,
                color: _manualGoal == g ? t.primary : t.secondary)),
            ),
          )).toList()),
          const SizedBox(height: 14),
        ],

        // ── Beginner Discovery Flow (step-by-step cards) ──
        // Now triggers for anyone with no/minimal experience OR no chosen skill —
        // broader capture so transferable skills from prior careers are considered.
        if ((_manualYears == 'No exp' || _manualYears == '0-1')
            && (_manualSkill == 'None' || _manualSkill.isEmpty)
            && _manualName.isNotEmpty
            && _manualCountry.isNotEmpty
            && _manualHoursPerWeek.isNotEmpty
            && _manualGoal.isNotEmpty
            && !_showBeginnerPlan) ...[
          const SizedBox(height: 8),

          // Step indicator
          Row(children: [
            ...List.generate(3, (i) => Expanded(child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              height: 3,
              decoration: BoxDecoration(
                color: i <= _discoveryStep
                    ? const Color(0xFF8B5CF6)
                    : t.divider,
                borderRadius: BorderRadius.circular(2)),
            ))),
            const SizedBox(width: 8),
            Text('${_discoveryStep + 1}/3', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: const Color(0xFF8B5CF6))),
          ]),
          const SizedBox(height: 14),

          // ── Step 1: Education ──
          if (_discoveryStep == 0)
            _DiscoveryCard(
              theme: t,
              emoji: '🎓',
              question: 'What\'s your education level?',
              hint: 'This helps us match careers to your background',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  'High School', 'Diploma', 'Bachelor\'s', 'Master\'s', 'PhD', 'Self-taught',
                ].map((e) => _discoveryChip(e, _starterEducation == e, () {
                  HapticFeedback.selectionClick();
                  setState(() => _starterEducation = e);
                })).toList()),
              ]),
              canContinue: _starterEducation.isNotEmpty,
              onContinue: () => setState(() => _discoveryStep = 1),
            ),

          // ── Step 2: Work Background ──
          if (_discoveryStep == 1)
            _DiscoveryCard(
              theme: t,
              emoji: '💼',
              question: 'Any work experience?',
              hint: 'Even non-tech experience is an advantage in AI',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ('Fresh start — no work yet', 'No'),
                  ('Yes, I\'ve worked before', 'Yes'),
                ].map((e) => _discoveryChip(e.$1, _starterWorkExp == e.$2, () {
                  HapticFeedback.selectionClick();
                  setState(() => _starterWorkExp = e.$2);
                })).toList()),
                if (_starterWorkExp == 'Yes') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _starterYearsCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(color: t.primary, fontSize: 14),
                      decoration: _inputDecor('Years'),
                      onChanged: (v) => setState(() => _starterWorkYears = v),
                    )),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: TextField(
                      controller: _starterRoleCtrl,
                      style: GoogleFonts.inter(color: t.primary, fontSize: 14),
                      decoration: _inputDecor('Your role (e.g. Teacher, Sales)'),
                      onChanged: (v) => setState(() => _starterRole = v),
                    )),
                  ]),
                ],
              ]),
              canContinue: _starterWorkExp.isNotEmpty,
              onContinue: () => setState(() => _discoveryStep = 2),
              onBack: () => setState(() => _discoveryStep = 0),
            ),

          // ── Step 3: Domain Interest ──
          if (_discoveryStep == 2)
            _DiscoveryCard(
              theme: t,
              emoji: '🚀',
              question: 'Which industry excites you?',
              hint: 'Pick one — you can always change later',
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                ('🏥', 'Healthcare'), ('💰', 'Finance'), ('📚', 'Education'),
                ('📢', 'Marketing'), ('🛒', 'E-commerce'), ('🏠', 'Real Estate'),
                ('🎨', 'Content Creation'), ('💻', 'Tech / SaaS'), ('🤷', 'Not sure yet'),
              ].map((e) => _discoveryChipWithEmoji(
                e.$1, e.$2, _starterDomain == e.$2, () {
                  HapticFeedback.selectionClick();
                  setState(() => _starterDomain = e.$2);
                },
              )).toList()),
              canContinue: _starterDomain.isNotEmpty,
              onContinue: _generateManualRecommendation,
              onBack: () => setState(() => _discoveryStep = 1),
              continueLabel: 'Build My Starter Plan',
              continueIcon: Icons.rocket_launch_rounded,
            ),
        ] else if (_manualSkill != 'None' || _manualYears != 'No exp') ...[
          // Certs/projects (for experienced users)
          TextField(
            controller: _certCtrl,
            style: GoogleFonts.inter(color: t.primary, fontSize: 14),
            decoration: _inputDecor('Certifications or projects (optional)'),
            onChanged: (v) => _manualCerts = v,
          ),
          const SizedBox(height: 18),
          // Get Recommendation button — needs name + country + hours + goal for a truly tailored plan
          Builder(builder: (_) {
            final canGenerate = _manualName.isNotEmpty
                && _manualSkill.isNotEmpty
                && _manualCountry.isNotEmpty
                && _manualHoursPerWeek.isNotEmpty
                && _manualGoal.isNotEmpty;
            final missing = <String>[];
            if (_manualCountry.isEmpty) missing.add('country');
            if (_manualHoursPerWeek.isEmpty) missing.add('hours/week');
            if (_manualGoal.isEmpty) missing.add('goal');

            return Column(children: [
              GestureDetector(
                onTap: canGenerate ? _generateManualRecommendation : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: canGenerate ? t.primary : t.muted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: _recLoading
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                            color: t.background, strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Flexible(child: Text(
                          _recStatusMessage.isEmpty ? 'Working…' : _recStatusMessage,
                          style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: t.background),
                          overflow: TextOverflow.ellipsis)),
                      ])
                    : Text('Get AI Career Plan', style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: canGenerate ? t.background : t.muted))),
                ),
              ),
              if (!canGenerate && missing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Please fill in: ${missing.join(", ")}',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: t.muted, fontStyle: FontStyle.italic)),
              ],
            ]);
          }),
        ],

        // Beginner starter plan (instant, no API call)
        if (_showBeginnerPlan && _profile == null) ...[
          const SizedBox(height: 20),
          BeginnerStarterPlan(
            theme: t,
            userName: _manualName,
            education: _starterEducation,
            hasWorkExp: _starterWorkExp == 'Yes',
            workYears: _starterWorkYears,
            workRole: _starterRole,
            domain: _starterDomain,
            onUnlock30Day: () {
              // After 7 days, generate an AI career path based on their picked career
              setState(() => _showBeginnerPlan = false);
              _manualYears = '0-1';
              SharedPreferences.getInstance().then((prefs) {
                final career = prefs.getString('starter_career_pick');
                if (career != null) _manualSkill = career;
              }).then((_) => _generateManualRecommendation());
            },
          ),
        ],

        // AI-generated recommendation (for experienced users)
        if (_recommendation != null && _profile == null && !_showBeginnerPlan) ...[
          const SizedBox(height: 20),
          _RecommendationContent(text: _recommendation!, theme: t, collapsible: true),
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

  Widget _discoveryChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
              : t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                : t.divider,
            width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? const Color(0xFF8B5CF6) : t.secondary)),
      ),
    );
  }

  Widget _discoveryChipWithEmoji(
    String emoji, String label, bool selected, VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
              : t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                : t.divider,
            width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? const Color(0xFF8B5CF6) : t.secondary)),
        ]),
      ),
    );
  }

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
  /// Shown in every results tab when the resume parse returned too little
  /// information. Tells the user honestly that we can't help instead of
  /// fabricating advice.
  Widget _unreadableResumeCard() {
    final p = _profile;
    final skillsFound = p?.skills ?? const [];
    final roleFound = p?.jobTitle ?? '';
    final yearsFound = p?.yearsOfExperience ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      children: [
        Center(child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
          ),
          child: const Icon(Icons.description_outlined,
            size: 36, color: Color(0xFFB45309)),
        )),
        const SizedBox(height: 20),
        Text('We couldn\'t read your resume',
          textAlign: TextAlign.center,
          style: GoogleFonts.sourceSerif4(
            fontSize: 22, fontWeight: FontWeight.w700, color: t.primary)),
        const SizedBox(height: 10),
        Text(
          'Your resume didn\'t contain enough readable text for us to generate '
          'reliable suggestions. We won\'t fabricate advice — that would mislead you.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14, color: t.muted, height: 1.5)),
        const SizedBox(height: 24),

        // What we found (if anything)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider, width: 0.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('What we detected', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: t.muted, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            _detectRow(Icons.work_outline_rounded, 'Role',
              roleFound.isEmpty ? 'Not detected' : roleFound,
              roleFound.isEmpty),
            const SizedBox(height: 6),
            _detectRow(Icons.psychology_alt_outlined, 'Skills',
              skillsFound.isEmpty
                ? 'Not detected'
                : '${skillsFound.length} found: ${skillsFound.take(3).join(", ")}${skillsFound.length > 3 ? "..." : ""}',
              skillsFound.length < 3),
            const SizedBox(height: 6),
            _detectRow(Icons.schedule_outlined, 'Experience',
              yearsFound > 0 ? '$yearsFound years' : 'Not detected',
              yearsFound == 0),
          ]),
        ),
        const SizedBox(height: 20),

        // Fix suggestions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: const Color(0xFF1D4ED8)),
              const SizedBox(width: 6),
              Text('How to fix this', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A8A))),
            ]),
            const SizedBox(height: 10),
            _fixRow('Upload a text-based PDF (not scanned images)'),
            _fixRow('Use a simple, single-column layout'),
            _fixRow('Avoid heavy graphics, icons, or charts'),
            _fixRow('Try exporting from Word or Google Docs as PDF'),
            _fixRow('If you scanned a paper resume, use OCR to convert it first'),
          ]),
        ),
        const SizedBox(height: 24),

        // Upload again CTA
        Center(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _reset();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: t.primary, borderRadius: BorderRadius.circular(10)),
              child: Text('Upload Another Resume',
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: t.background)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detectRow(IconData icon, String label, String value, bool missing) {
    return Row(children: [
      Icon(icon, size: 15, color: missing ? t.muted : t.primary),
      const SizedBox(width: 8),
      SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w600, color: t.muted))),
      Expanded(child: Text(value, style: GoogleFonts.inter(
        fontSize: 12,
        color: missing ? t.muted.withValues(alpha: 0.7) : t.primary,
        fontStyle: missing ? FontStyle.italic : FontStyle.normal,
        fontWeight: missing ? FontWeight.w400 : FontWeight.w500))),
      if (missing) Icon(Icons.close_rounded, size: 13,
        color: const Color(0xFFEF4444)),
    ]);
  }

  Widget _fixRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(width: 4, height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6), shape: BoxShape.circle)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.inter(
          fontSize: 12, color: const Color(0xFF1E3A8A), height: 1.5))),
      ]),
    );
  }

  Widget _buildJobResults() {
    // ── GLOBAL GATE: if resume isn't readable, show honest message ─────
    if (!_profileReadable) return _unreadableResumeCard();
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

        // ── Structured gaps with severity/timeline/resource (if Claude returned them) ──
        if (p.structuredGaps.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.lightbulb_rounded, size: 15, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 8),
                Text('Skills to Acquire', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
              ]),
              const SizedBox(height: 4),
              Text('Ranked by market impact in ${p.country}', style: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFF92400E).withValues(alpha: 0.7), height: 1.3)),
              const SizedBox(height: 12),
              ...p.structuredGaps.map((g) => _buildStructuredGap(g, t)),
            ]),
          ),
        ]
        // Fallback: legacy plain gaps tags (from job matching, not Claude)
        else if (skillGaps.isNotEmpty) ...[
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
          ...qualified.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ResumeJobCard(
              job: m.job, theme: t, profile: p,
              grade: m.grade,
              legitimacy: _legitimacyMap[m.job.id],
            ),
          )),
      ],
    );
  }

  // ── Recommendation Tab ────────────────────────────────────────────────────

  static const int _kMinMatchPct = 10;

  /// All matched jobs with A-F grades, filtered to composite >= _kMinMatchPct
  List<({Job job, JobGrade grade})> get _qualifiedMatches {
    if (_profile == null) return [];
    // Don't surface match scores if the resume wasn't readable — prevents
    // the Interview Prep section from showing fake "46% match" suggestions.
    if (!_profileReadable) return [];
    final p = _profile!;

    return _jobs.map((j) {
      final grade = JobScoringService.grade(j, p);
      return (job: j, grade: grade);
    }).where((r) => r.grade.composite >= _kMinMatchPct).toList()
      ..sort((a, b) => b.grade.composite.compareTo(a.grade.composite));
  }

  List<({Job job, JobGrade grade})> get _topMatches => _qualifiedMatches.take(3).toList();

  Widget _buildRecommendation() {
    // ── GLOBAL GATE: if resume isn't readable, show honest message ─────
    if (!_profileReadable) return _unreadableResumeCard();
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
                      builder: (_) => StatefulBuilder(
                        builder: (sheetCtx, sheetSetState) {
                          _sheetSetState = sheetSetState;
                          return DraggableScrollableSheet(
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
                                    theme: t,
                                    onOptimizePressed: _generateOptimizedResume,
                                    isGenerating: _generatingOptimized,
                                    generatingStatus: _optimizeStatusMessage,
                                    hasOptimized: _optimizedResumeText != null,
                                  ),
                                )),
                              ]),
                            ),
                          );
                        },
                      ),
                    ).whenComplete(() => _sheetSetState = null);
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
          // Rotating status caption so the long wait isn't silent
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(children: [
              SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(color: t.muted, strokeWidth: 2)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _recStatusMessage.isEmpty ? 'Working…' : _recStatusMessage,
                style: GoogleFonts.inter(
                  fontSize: 13, color: t.muted, fontStyle: FontStyle.italic))),
            ]),
          ),
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
                  _MockInterviewJobCard(job: m.job, grade: m.grade, theme: t)),
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
              title: 'Knowledge Videos',
              count: 0,
              loading: _videosLoading,
              children: _recommendedVideos.map((v) =>
                _RecVideoCard(video: v, theme: t, profile: _profile)).toList(),
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

  // ── Structured skill gap card (from Claude's gap analysis) ─────────────────
  Widget _buildStructuredGap(SkillGap g, AppTheme t) {
    // Severity color: CRITICAL=red, HIGH=orange, MEDIUM=amber
    Color sevColor;
    switch (g.severity.toUpperCase()) {
      case 'CRITICAL': sevColor = const Color(0xFFDC2626); break;
      case 'HIGH':     sevColor = const Color(0xFFEA580C); break;
      default:         sevColor = const Color(0xFFF59E0B);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Severity pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: sevColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
              child: Text(g.severity, style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w800, color: sevColor,
                letterSpacing: 0.5)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(g.name, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: const Color(0xFFB45309)))),
          ]),
          if (g.marketReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(g.marketReason, style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFF92400E).withValues(alpha: 0.85),
              height: 1.4)),
          ],
          const SizedBox(height: 8),
          // Timeline + cost row
          Row(children: [
            if (g.timeToClose.isNotEmpty) ...[
              Icon(Icons.schedule_rounded, size: 12, color: t.muted),
              const SizedBox(width: 3),
              Text(g.timeToClose, style: GoogleFonts.inter(
                fontSize: 11, color: t.muted, fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
            ],
            if (g.cost != null && g.cost!.isNotEmpty) ...[
              Icon(Icons.payments_outlined, size: 12, color: t.muted),
              const SizedBox(width: 3),
              Text(g.cost!, style: GoogleFonts.inter(
                fontSize: 11, color: t.muted, fontWeight: FontWeight.w500)),
            ],
          ]),
          if (g.resource.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: g.resourceUrl != null && g.resourceUrl!.isNotEmpty
                  ? () async {
                      final uri = Uri.tryParse(g.resourceUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    g.resourceUrl != null ? Icons.open_in_new_rounded : Icons.menu_book_outlined,
                    size: 12, color: const Color(0xFFB45309)),
                  const SizedBox(width: 5),
                  Flexible(child: Text(g.resource, style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: const Color(0xFFB45309)))),
                ]),
              ),
            ),
          ],
        ]),
      ),
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

// ── Discovery Step Card (beginner onboarding) ──────────────────────────────
class _DiscoveryCard extends StatelessWidget {
  final AppTheme theme;
  final String emoji;
  final String question;
  final String hint;
  final Widget child;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final String continueLabel;
  final IconData? continueIcon;

  const _DiscoveryCard({
    required this.theme,
    required this.emoji,
    required this.question,
    required this.hint,
    required this.child,
    required this.canContinue,
    required this.onContinue,
    this.onBack,
    this.continueLabel = 'Continue',
    this.continueIcon,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.divider),
        boxShadow: [BoxShadow(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
          blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(question, style: GoogleFonts.sourceSerif4(
              fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
            const SizedBox(height: 2),
            Text(hint, style: GoogleFonts.inter(
              fontSize: 11, color: t.muted)),
          ])),
        ]),
        const SizedBox(height: 16),

        // Content
        child,
        const SizedBox(height: 18),

        // Buttons row
        Row(children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.divider)),
                child: Icon(Icons.arrow_back_rounded, size: 18, color: t.muted),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: GestureDetector(
            onTap: canContinue ? () {
              HapticFeedback.lightImpact();
              onContinue();
            } : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canContinue
                    ? const Color(0xFF8B5CF6)
                    : t.muted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                boxShadow: canContinue ? [BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 8, offset: const Offset(0, 3))] : null),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (continueIcon != null) ...[
                  Icon(continueIcon, size: 16,
                    color: canContinue ? Colors.white : t.muted),
                  const SizedBox(width: 6),
                ],
                Text(continueLabel, style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: canContinue ? Colors.white : t.muted)),
              ]),
            ),
          )),
        ]),
      ]),
    );
  }
}

// ── Mock Interview Job Card (practice instead of apply) ────────────────────
class _MockInterviewJobCard extends StatelessWidget {
  final Job job;
  final JobGrade grade;
  final AppTheme theme;
  const _MockInterviewJobCard({
    required this.job, required this.grade, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final scoreColor = grade.color;

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
              child: Text('${grade.composite}% match', style: GoogleFonts.inter(
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
      'MUST-WATCH TED TALKS': 'Must-Watch TED Talks',
      'TED TALKS': 'Must-Watch TED Talks',
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

    // Fallback: if parsing failed, show stripped text (no raw ###/**)
    if (sections.isEmpty) {
      return Text(_SectionCard._stripMarkdown(text), style: GoogleFonts.inter(
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

    // Collapsible mode — all sections start collapsed; user taps to expand.
    return Column(children: [
      for (var i = 0; i < sections.length; i++)
        _AccordionSection(
          theme: t,
          section: sections[i],
          index: i,
          initiallyExpanded: false,
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
      case 'Must-Watch TED Talks':
        return (title: title, body: body, icon: Icons.play_circle_outline_rounded, color: const Color(0xFFEF4444));
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
  final bool headerless;

  const _SectionCard({
    required this.section, required this.index, required this.theme,
    this.headerless = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final s = section;

    // Headerless mode — just the body content, no card/border/header
    if (headerless) {
      return _buildBody(t);
    }

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
      case 'Must-Watch TED Talks':
        return _buildTedTalks(t);
      default:
        return _buildNumberedSection(t);
    }
  }

  /// Default editorial paragraph style — used for Career Path
  Widget _buildProse(AppTheme t) {
    return Text(_stripMarkdown(section.body), style: GoogleFonts.sourceSerif4(
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
    final bodyLower = section.body.toLowerCase();
    // Detect explicit "unavailable" signals — don't show a fake gauge
    final isUnavailable = bodyLower.contains('unavailable')
        || bodyLower.contains('no match')
        || bodyLower.contains('insufficient data')
        || bodyLower.contains('cannot assess')
        || bodyLower.contains('no qualifying');
    final match = RegExp(r'(\d{1,3})\s*%').firstMatch(section.body);
    final pct = (!isUnavailable && match != null)
        ? int.tryParse(match.group(1)!)
        : null;
    final items = _parseListItems(section.body);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isUnavailable) ...[
        // Honest "can't compute match" state — grey card, not fake number
        Center(child: Column(children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              color: t.muted.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: t.muted.withValues(alpha: 0.3), width: 2)),
            child: Icon(Icons.help_outline_rounded, size: 36, color: t.muted),
          ),
          const SizedBox(height: 8),
          Text('Match unavailable', style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: t.muted)),
          const SizedBox(height: 2),
          Text('Not enough data to score you',
            style: GoogleFonts.inter(fontSize: 11, color: t.muted, fontStyle: FontStyle.italic)),
        ])),
        const SizedBox(height: 18),
        Divider(height: 1, color: t.divider.withValues(alpha: 0.6)),
        const SizedBox(height: 16),
      ] else if (pct != null) ...[
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
        Text(_stripMarkdown(section.body), style: GoogleFonts.sourceSerif4(
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

  /// TED Talks section — each item shows title, description, and a tappable link
  Widget _buildTedTalks(AppTheme t) {
    final items = _parseListItems(section.body);
    if (items.isEmpty) return _buildProse(t);

    final urlRegex = RegExp(r'(https?://\S+)');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 16),
          child: () {
            final item = items[i];
            final urlMatch = urlRegex.firstMatch(item);
            final url = urlMatch?.group(1)?.replaceAll(RegExp(r'[),.\]]+$'), '');
            final textWithoutUrl = item.replaceAll(urlRegex, '').replaceAll('—', '—').trim();
            // Clean trailing punctuation/dashes from text
            final cleanText = textWithoutUrl.replaceAll(RegExp(r'\s*[—\-]+\s*$'), '').trim();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: section.color.withValues(alpha: 0.15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: section.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.play_arrow_rounded, size: 16, color: section.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(cleanText, style: GoogleFonts.sourceSerif4(
                    fontSize: 14, color: t.primary.withValues(alpha: 0.88),
                    height: 1.5))),
                ]),
                if (url != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: section.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.open_in_new_rounded, size: 13, color: section.color),
                        const SizedBox(width: 6),
                        Text('Watch on TED.com', style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: section.color)),
                      ]),
                    ),
                  ),
                ],
              ]),
            );
          }(),
        ),
    ]);
  }

  /// Strips markdown formatting markers so raw model output renders cleanly.
  /// Handles: # / ## / ### / etc. headers (at line start OR mid-paragraph
  /// when the LLM joins them inline), **bold**, *italic*, _underline_,
  /// --- horizontal rules, > blockquotes, `inline code`, and trims.
  /// Carefully avoids breaking things like "C#" or "issue #5".
  static String _stripMarkdown(String s) {
    return s
        // Heading markers at line start (## / ### / etc. + whitespace)
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
        // Heading markers appearing mid-paragraph after the LLM joined lines.
        // Requires whitespace on BOTH sides so "C# .NET" or "issue #5" are safe.
        .replaceAll(RegExp(r'\s+#{1,6}\s+'), ' ')
        // Horizontal rules — a line of --- or *** or ___
        .replaceAll(RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$', multiLine: true), '')
        // Blockquote markers at line start
        .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '')
        // Bold/italic markers (** *** _ __ ___)
        .replaceAll(RegExp(r'\*{1,3}'), '')
        .replaceAll(RegExp(r'_{1,3}'), '')
        // Inline code backticks
        .replaceAll('`', '')
        .trim();
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
  final JobGrade grade;
  final JobLegitimacy? legitimacy;
  const _ResumeJobCard({
    required this.job, required this.theme, required this.profile,
    required this.grade, this.legitimacy,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;

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
          // Match % badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: grade.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: grade.color.withValues(alpha: 0.3))),
            child: Text(grade.percentLabel, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w800, color: grade.color)),
          ),
        ]),

        // Grade reason + Legitimacy badge
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Row(children: [
            Expanded(child: Text(grade.reason, style: GoogleFonts.inter(
              fontSize: 11, color: t.muted, fontStyle: FontStyle.italic))),
            if (legitimacy != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: legitimacy!.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(legitimacy!.icon, size: 11, color: legitimacy!.color),
                  const SizedBox(width: 3),
                  Text(legitimacy!.label, style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700, color: legitimacy!.color)),
                ]),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 6),

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

        // Row 4: Apply + Research + Save
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
                child: Center(child: Text('Apply', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: t.background))),
              ),
            )),
          const SizedBox(width: 8),
          // Research button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CompanyResearchSheet(
                  company: job.company,
                  jobTitle: job.title,
                  profile: profile,
                  theme: theme,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: t.accent.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.business_outlined, size: 14, color: t.accent),
                const SizedBox(width: 5),
                Text('Research', style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: t.accent)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await UserActivityContext.recordSavedJob(job.title, job.company);
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

// ── Accordion Section (polished expandable career plan card) ────────────────
class _AccordionSection extends StatefulWidget {
  final AppTheme theme;
  final ({String title, String body, IconData icon, Color color}) section;
  final int index;
  final bool initiallyExpanded;

  const _AccordionSection({
    required this.theme,
    required this.section,
    required this.index,
    this.initiallyExpanded = false,
  });

  @override
  State<_AccordionSection> createState() => _AccordionSectionState();
}

class _AccordionSectionState extends State<_AccordionSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animCtrl.forward();
      } else {
        _animCtrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final s = widget.section;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? s.color.withValues(alpha: 0.3) : t.divider,
          width: _expanded ? 1 : 0.5,
        ),
        boxShadow: _expanded
            ? [BoxShadow(
                color: s.color.withValues(alpha: 0.06),
                blurRadius: 12, offset: const Offset(0, 3))]
            : null,
      ),
      child: Column(children: [
        // ── Header row — always visible ──
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: _expanded
                ? BoxDecoration(
                    color: s.color.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)),
                  )
                : null,
            child: Row(children: [
              // Icon badge
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9)),
                child: Icon(s.icon, size: 17, color: s.color),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: GoogleFonts.sourceSerif4(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: t.primary, letterSpacing: -0.2)),
                  if (!_expanded) ...[
                    const SizedBox(height: 2),
                    Text(
                      _previewText(s.body),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11, color: t.muted, height: 1.3)),
                  ],
                ],
              )),
              const SizedBox(width: 8),
              // Chevron
              RotationTransition(
                turns: _rotateAnim,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 22, color: _expanded ? s.color : t.muted),
              ),
            ]),
          ),
        ),

        // ── Expandable body ──
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: Column(children: [
            Divider(height: 1, color: t.divider.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: _SectionCard(
                section: s, index: widget.index, theme: t,
                headerless: true,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  String _previewText(String body) {
    final first = body.split('\n').firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => body,
    );
    return first.replaceAll(RegExp(r'^[\d\.\)\-•\*]+\s*'), '').trim();
  }
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

// ── Optimized Resume Sheet ──────────────────────────────────────────────────
class _OptimizedResumeSheet extends StatefulWidget {
  final String optimizedText;
  final AppTheme theme;
  const _OptimizedResumeSheet({
    required this.optimizedText,
    required this.theme,
  });

  @override
  State<_OptimizedResumeSheet> createState() => _OptimizedResumeSheetState();
}

class _OptimizedResumeSheetState extends State<_OptimizedResumeSheet> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '✨ Optimized Resume',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: t.primary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, color: t.muted, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your resume has been rewritten to address all ATS issues',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: t.muted,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.divider, width: 0.5),
              ),
              child: Text(
                widget.optimizedText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  color: t.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.optimizedText),
                      );
                      setState(() => _copied = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _copied = false);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Copied to clipboard!',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _copied
                          ? const Color(0xFF10B981)
                          : t.primary.withValues(alpha: 0.1),
                      foregroundColor:
                          _copied ? Colors.white : t.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      _copied ? Icons.done_rounded : Icons.content_copy_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _copied ? 'Copied!' : 'Copy',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Generating PDF...',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          backgroundColor: t.muted,
                        ),
                      );
                      try {
                        final pdfPath = await ResumeService.exportResumeToPdf(
                          widget.optimizedText,
                          'Resume_Optimized',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'PDF ready: $pdfPath',
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e',
                                  style: GoogleFonts.inter(fontSize: 13)),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: Text(
                      'PDF',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Generating Word...',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          backgroundColor: t.muted,
                        ),
                      );
                      try {
                        final wordPath = await ResumeService.exportResumeToWord(
                          widget.optimizedText,
                          'Resume_Optimized',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Word ready: $wordPath',
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e',
                                  style: GoogleFonts.inter(fontSize: 13)),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: Text(
                      'Word',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final timestamp =
                          DateTime.now().toIso8601String().split('T')[0];
                      Share.share(
                        widget.optimizedText,
                        subject: 'Optimized Resume - $timestamp',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1)
                          .withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: Text(
                      'Share',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Review and personalize before sending. Add company-specific details for the best results.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF4F46E5),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ATS Score Card ──────────────────────────────────────────────────────────
class _AtsScoreCard extends StatelessWidget {
  final int score;
  final List<String> issues;
  final AppTheme theme;
  final VoidCallback? onOptimizePressed;
  final bool isGenerating;
  final String generatingStatus;
  final bool hasOptimized;
  const _AtsScoreCard({
    required this.score,
    required this.issues,
    required this.theme,
    this.onOptimizePressed,
    this.isGenerating = false,
    this.generatingStatus = '',
    this.hasOptimized = false,
  });

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
          const SizedBox(height: 12),
          if (onOptimizePressed != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isGenerating ? null : onOptimizePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color.withValues(alpha: 0.15),
                  foregroundColor: _color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: _color.withValues(alpha: 0.3)),
                  ),
                ),
                icon: isGenerating
                    ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_color),
                      ),
                    )
                    : Icon(hasOptimized ? Icons.done_all_rounded : Icons.auto_fix_high_rounded),
                label: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isGenerating
                        ? (generatingStatus.isEmpty ? 'Optimizing…' : generatingStatus)
                        : (hasOptimized ? 'View Optimized Resume' : 'Auto-Fix Resume'),
                    key: ValueKey(isGenerating ? generatingStatus : hasOptimized),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    const apiKey = Secrets.anthropicApiKey;
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
        Uri.parse('https://aiwire-proxy.prab187.workers.dev'),
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
  /// Profile from the resume currently being viewed. When tapped, the summary
  /// sheet will personalize its last bullet to this profile.
  final ResumeProfile? profile;
  const _RecVideoCard({required this.video, required this.theme, this.profile});

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
          builder: (_) => _VideoSummarySheet(
            video: video, theme: t, personalizeFor: profile),
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
  /// When provided, the summary's last bullet is tailored to this profile.
  /// Only set from the Resume Scan results tab — never from generic screens.
  final ResumeProfile? personalizeFor;
  const _VideoSummarySheet({
    required this.video,
    required this.theme,
    this.personalizeFor,
  });

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
      final s = await YouTubeService.summarizeVideo(
        widget.video,
        personalizeFor: widget.personalizeFor,
      );
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import '../services/claude_cache.dart';
import '../services/claude_error.dart';
import '../services/claude_http.dart';
import '../services/star_story_service.dart';
import '../services/user_activity_context.dart';
import '../models/star_story.dart';
// Premium gate disabled during testing
// import '../services/ai_quota_guard.dart';
// import '../widgets/quota_paywall.dart';

enum _IvState { setup, prepGuide, asking, feedback }

class _Turn {
  final String question;
  String answer = '';
  String? feedback;        // Overall actionable feedback
  int? score;              // Overall score 1-10
  // Rubric breakdown (each 0-5)
  int? communicationScore;
  int? technicalScore;
  int? approachScore;
  int? completenessScore;
  String? betterAnswer;    // Example of a stronger answer
  _Turn(this.question);
}

class MockInterviewScreen extends StatefulWidget {
  final AppTheme theme;
  const MockInterviewScreen({super.key, required this.theme});

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen>
    with SingleTickerProviderStateMixin {
  _IvState _state = _IvState.setup;
  String _role = 'ML Engineer';
  String _level = 'Mid';
  String _type = 'Behavioral';
  String _company = ''; // Optional — e.g. "Meta", "early-stage startup"
  final _companyCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final List<_Turn> _turns = [];
  int _idx = 0;
  final _answerCtrl = TextEditingController();

  // Prep guide
  String? _prepGuide;
  bool _prepLoading = false;
  String? _prepError;

  // Story Bank
  List<StarStory> _savedStories = [];
  int _newlySavedCount = 0;

  // Speech-to-text
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  bool _listening = false;
  String _answerBeforeListening = '';
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  AppTheme get t => widget.theme;

  static const _roles = ['ML Engineer', 'Data Scientist', 'AI Researcher', 'MLOps Engineer', 'AI Product Manager'];
  static const _levels = ['Junior', 'Mid', 'Senior', 'Lead'];
  static const _types = ['Behavioral', 'Technical', 'System Design'];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadProfileDefaults();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _stt.initialize(
        onError: (e) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted) setState(() => _listening = false);
          }
        },
      );
      if (mounted) setState(() => _sttAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _sttAvailable = false);
    }
  }

  Future<void> _toggleListening() async {
    HapticFeedback.lightImpact();
    // Drop the keyboard so the transcript area is fully visible while speaking
    FocusManager.instance.primaryFocus?.unfocus();
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_sttAvailable) return;
    _answerBeforeListening = _answerCtrl.text;
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
      localeId: 'en_US',
      onResult: (result) {
        final combined = _answerBeforeListening.isEmpty
            ? result.recognizedWords
            : '$_answerBeforeListening ${result.recognizedWords}';
        if (mounted) {
          setState(() {
            _answerCtrl.text = combined;
            _answerCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _answerCtrl.text.length));
          });
        }
      },
    );
    if (mounted) setState(() => _listening = true);
  }

  Future<void> _loadProfileDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('user_job_title');
    final level = prefs.getString('user_level');
    if (title != null && _roles.contains(title)) _role = title;
    if (level != null && _levels.contains(level)) _level = level;
    // Load saved stories
    _savedStories = await StarStoryService.all();
    if (mounted) setState(() {});
  }

  Future<void> _autoSaveStories() async {
    final bankable = _turns.where((t) => t.score != null && t.score! >= 7);
    var count = 0;
    for (final turn in bankable) {
      final tags = StarStoryService.extractTags(turn.question, turn.answer);
      await StarStoryService.save(StarStory(
        id: '${DateTime.now().millisecondsSinceEpoch}_$count',
        question: turn.question,
        answer: turn.answer,
        score: turn.score!,
        feedback: turn.feedback,
        role: _role,
        type: _type,
        createdAt: DateTime.now().toIso8601String(),
        tags: tags,
      ));
      count++;
    }
    _savedStories = await StarStoryService.all();
    if (mounted && count > 0) {
      _newlySavedCount = count;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _stt.stop();
    _pulseCtrl.dispose();
    _answerCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _startInterview() async {
    HapticFeedback.lightImpact();
    // Premium gate disabled during testing
    // if (!await checkAiQuotaOrShowPaywall(context, t)) return;
    setState(() { _loading = true; _error = null; });

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) {
      setState(() { _error = 'API key not configured'; _loading = false; });
      return;
    }

    // Cache questions by role+level+type+company for 3 days
    final companyKey = _company.trim().isEmpty ? 'generic' : _company.trim().toLowerCase();
    final cacheKey = ClaudeCache.keyFrom(['v2', _role, _level, _type, companyKey]);
    String? cleaned = await ClaudeCache.get('iv_q', cacheKey,
        ttl: const Duration(days: 3));

    final companyLine = _company.trim().isEmpty
        ? 'COMPANY TYPE: Generic top tech company (FAANG-style bar)'
        : 'COMPANY: ${_company.trim()} — calibrate the difficulty, question style, and focus areas to how THIS company actually interviews (e.g. Meta = behavioral + coding + system design; Google = coding-heavy; startups = pragmatic shipping; Anthropic/OpenAI = research + ethics)';

    final typeGuidance = switch (_type.toLowerCase()) {
      'behavioral' => 'Questions should target: conflict resolution, leadership, project ownership, dealing with ambiguity, failure stories. Use STAR-answerable format. Reference ${_level.toLowerCase()}-level responsibilities.',
      'technical' => 'Questions should target: $_role domain depth (ML algorithms, model debugging, evaluation metrics, infra choices, trade-offs). NO coding — this is verbal technical depth. Include at least 1 question that probes "why" not just "how".',
      'system design' => 'Questions should be ML system design at $_level scope: e.g. "Design a recommendation system", "Design real-time fraud detection". Include constraints (latency, scale, cost). Match complexity to $_level.',
      _ => 'Mix of ${_type} questions appropriate for $_level level.',
    };

    final prompt = '''You will do a TWO-PASS generation for $_type interview questions for a $_level $_role role.

$companyLine
$typeGuidance

PASS 1: Brainstorm 10 candidate questions internally (don't output them).
PASS 2: Self-critique: rate each by (a) specificity, (b) calibration to $_level, (c) $_type fit, (d) whether a lazy candidate could BS through it.
PASS 3: Pick the TOP 5 — the ones that would actually reveal skill differences between a 5/10 and 9/10 candidate.

Output ONLY the final 5 as a JSON array of strings, no markdown, no preamble. Example: ["Question 1?", "Question 2?", ...]

Rules:
- Each question must be SPECIFIC (not "Tell me about yourself"). Include a scenario, constraint, or concrete angle.
- Mix 2 open-ended + 3 scenario-specific.
- For $_level: Junior = fundamentals + learning mindset; Mid = production experience + trade-offs; Senior = architectural thinking + mentorship; Lead/Principal = org/business impact.
- If company is specified: 2 of the 5 must be flavored to that company's known interview style.
- No canned LeetCode problems — these are conversation questions.
- No question should be answerable with a single sentence. Each should need a 2-3 min response to do well.''';

    try {
      if (cleaned == null) {
        final response = await ClaudeHttp.post(
          apiKey: apiKey,
          timeout: const Duration(seconds: 45),
          body: {
            'model': 'claude-haiku-4-5',
            'max_tokens': 600,
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
        cleaned = raw
            .replaceFirst(RegExp(r'^```json\s*'), '')
            .replaceFirst(RegExp(r'^```\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
        await ClaudeCache.set('iv_q', cacheKey, cleaned);
      }

      final decoded = json.decode(cleaned);
      final questions = (decoded is List ? decoded : <dynamic>[]).cast<String>();

      _turns.clear();
      for (final q in questions) {
        _turns.add(_Turn(q));
      }
      // await AiQuotaGuard.record();
      AnalyticsService.interviewStarted(role: _role, type: _type);
      setState(() {
        _state = _IvState.asking;
        _idx = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e.toString().replaceFirst("Exception: ", ""));
        _loading = false;
      });
    }
  }

  Future<void> _generatePrepGuide() async {
    HapticFeedback.lightImpact();
    setState(() {
      _state = _IvState.prepGuide;
      _prepLoading = true;
      _prepError = null;
      _prepGuide = null;
    });

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) {
      setState(() {
        _prepError = 'API key not configured';
        _prepLoading = false;
      });
      return;
    }

    // Optional: enrich with user's saved skills
    final prefs = await SharedPreferences.getInstance();
    final userSkills = (prefs.getStringList('user_skills') ?? []).take(8).join(', ');
    final userContext = userSkills.isNotEmpty
        ? '\n\nThe candidate has these skills already: $userSkills. Personalize accordingly.'
        : '';

    // Cache by role+level+type+skills (14 days)
    final cacheKey = ClaudeCache.keyFrom([_role, _level, _type, userSkills]);
    final cached = await ClaudeCache.get('iv_prep', cacheKey,
        ttl: const Duration(days: 14));
    if (cached != null) {
      if (mounted) {
        setState(() { _prepGuide = cached; _prepLoading = false; });
      }
      return;
    }

    final prompt = '''You are a senior $_role interviewer at a top tech company. Generate a focused, actionable interview prep guide for someone preparing for a $_level $_role $_type interview.$userContext

Use these EXACT section headers (uppercase, on their own lines):

WHAT TO EXPECT
[2-3 sentences on the format, length, and what interviewers actually evaluate at this level]

TOPICS TO MASTER
[5-7 specific concepts/topics this candidate should revise — be concrete, name actual algorithms, frameworks, or principles]

LIKELY QUESTIONS
[6-8 specific real-world questions interviewers commonly ask for this role/level/type. Make them realistic, not generic]

ANSWER FRAMEWORK
[2-3 sentences on the optimal way to structure answers for THIS interview type — STAR for behavioral, problem framing for system design, think-aloud for technical, etc.]

QUICK WINS
[4-5 specific things they can do TODAY to boost their performance — name resources, courses, books, practice sites]

RED FLAGS TO AVOID
[3-4 common mistakes candidates at this level make — be specific and honest]

Keep it concise, direct, and tailored. No fluff. No generic advice. Reference $_role and $_level specifics throughout.''';

    try {
      final response = await ClaudeHttp.post(
        apiKey: apiKey,
        timeout: const Duration(seconds: 60),
        body: {
          'model': 'claude-haiku-4-5',
          'max_tokens': 1400,
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
      final text = (contentList[0]['text'] as String? ?? '').trim();
      await ClaudeCache.set('iv_prep', cacheKey, text);
      if (mounted) {
        setState(() {
          _prepGuide = text;
          _prepLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _prepError = friendlyError(e.toString().replaceFirst("Exception: ", ""));
          _prepLoading = false;
        });
      }
    }
  }

  Future<void> _submitAnswer() async {
    if (_answerCtrl.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    // Dismiss the keyboard so the next question + mic button are visible
    FocusManager.instance.primaryFocus?.unfocus();
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
    }
    final answer = _answerCtrl.text.trim();
    _turns[_idx].answer = answer;
    _answerCtrl.clear();

    setState(() => _loading = true);

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    final companyLine = _company.trim().isEmpty
        ? 'COMPANY: Top tech company (FAANG-style bar)'
        : 'COMPANY: ${_company.trim()} — score as if this company\'s interviewer was evaluating';
    final prompt = '''You are a senior $_role interviewer evaluating a candidate's answer. Score using a rubric and give SPECIFIC feedback with a concrete example of a stronger answer.

ROLE: $_level $_role
TYPE: $_type interview
$companyLine
QUESTION: ${_turns[_idx].question}
CANDIDATE'S ANSWER: $answer

Respond with ONLY a JSON object, no markdown, no preamble:
{
  "communication": <0-5 score for structure, clarity, conciseness>,
  "technical": <0-5 score for accuracy, depth, domain knowledge>,
  "approach": <0-5 score for problem-solving framework, trade-off analysis>,
  "completeness": <0-5 score for covering all parts of the question>,
  "overall_10": <weighted overall 1-10 = (communication + technical + approach + completeness) / 2>,
  "feedback": "2-3 sentences. Be SPECIFIC: quote what they said and say why it's weak/strong. Don't say 'add more depth' — say 'You said X. Better: Y, because Z.'",
  "better_answer": "One paragraph (40-70 words) showing a model answer for this question at $_level level. Use specific tools, numbers, or frameworks. Must be concrete, not templated."
}

Rules:
- Calibrate to $_level: Junior = basic correctness OK, Senior = depth + trade-offs required, Principal = systems thinking + business impact.
- If answer is <20 words or off-topic, communication/approach can be 0-1.
- better_answer should be realistic — not inflated — what a strong $_level candidate would actually say.''';

    try {
      final response = await ClaudeHttp.post(
        apiKey: apiKey,
        timeout: const Duration(seconds: 45),
        body: {
          'model': 'claude-haiku-4-5',
          'max_tokens': 600,
          'messages': [{'role': 'user', 'content': prompt}],
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final contentList = data['content'] as List?;
        final text = (contentList != null && contentList.isNotEmpty
            ? (contentList[0]['text'] as String? ?? '')
            : '').trim();
        try {
          // Strip any accidental code fences
          final cleaned = text
              .replaceFirst(RegExp(r'^```json\s*'), '')
              .replaceFirst(RegExp(r'^```\s*'), '')
              .replaceFirst(RegExp(r'\s*```$'), '').trim();
          final parsed = json.decode(cleaned) as Map<String, dynamic>;
          _turns[_idx].communicationScore = (parsed['communication'] as num?)?.toInt();
          _turns[_idx].technicalScore = (parsed['technical'] as num?)?.toInt();
          _turns[_idx].approachScore = (parsed['approach'] as num?)?.toInt();
          _turns[_idx].completenessScore = (parsed['completeness'] as num?)?.toInt();
          _turns[_idx].score = (parsed['overall_10'] as num?)?.toInt();
          _turns[_idx].feedback = parsed['feedback'] as String? ?? '';
          _turns[_idx].betterAnswer = parsed['better_answer'] as String?;
        } catch (_) {
          // Fallback: regex-extract old format — safely handle null group
          final scoreMatch = RegExp(r'(?:SCORE|overall_10)[:\s"]*\s*(\d+)').firstMatch(text);
          final scoreStr = scoreMatch?.group(1);
          _turns[_idx].score = scoreStr != null ? int.tryParse(scoreStr) : null;
          _turns[_idx].feedback = text;
        }
      } else {
        _turns[_idx].feedback = 'Feedback unavailable — ${claudeError(response.statusCode, response.body)}';
      }
    } catch (e) {
      _turns[_idx].feedback = 'Network error: ${e.toString().replaceFirst("Exception: ", "")}';
    }

    final isLast = _idx >= _turns.length - 1;
    if (isLast) {
      // Auto-save strong answers (score >= 7) to Story Bank
      _autoSaveStories();
      // Record results into user activity context so future Claude calls
      // know the user's rubric strengths/weaknesses.
      final scored = _turns.where((t) => t.score != null).toList();
      if (scored.isNotEmpty) {
        final avg = (scored.map((t) => t.score!).reduce((a, b) => a + b) / scored.length).round();
        // Find weakest rubric area (average across all turns)
        int sumComm = 0, sumTech = 0, sumAppr = 0, sumCov = 0, n = 0;
        for (final t in _turns) {
          if (t.communicationScore == null) continue;
          sumComm += t.communicationScore!;
          sumTech += t.technicalScore ?? 0;
          sumAppr += t.approachScore ?? 0;
          sumCov += t.completenessScore ?? 0;
          n++;
        }
        String weakest = 'balanced';
        if (n > 0) {
          final scores = {
            'Communication': sumComm / n,
            'Technical depth': sumTech / n,
            'Approach/framework': sumAppr / n,
            'Completeness': sumCov / n,
          };
          final min = scores.entries.reduce((a, b) => a.value < b.value ? a : b);
          weakest = min.key;
        }
        UserActivityContext.recordInterviewResult(
          avgScore10: avg, weakestArea: weakest);
      }
    }
    setState(() {
      _loading = false;
      if (!isLast) {
        _idx++;
      } else {
        _state = _IvState.feedback;
      }
    });
  }

  void _restart() {
    setState(() {
      _state = _IvState.setup;
      _turns.clear();
      _idx = 0;
      _answerCtrl.clear();
      _error = null;
      _prepGuide = null;
      _prepError = null;
      _prepLoading = false;
    });
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
        title: Text('Mock Interview', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        actions: _state == _IvState.prepGuide
          ? [TextButton(
              onPressed: () => setState(() => _state = _IvState.setup),
              child: Text('Back', style: GoogleFonts.inter(fontSize: 13, color: t.accent)))]
          : (_state != _IvState.setup
              ? [TextButton(
                  onPressed: _restart,
                  child: Text('Restart', style: GoogleFonts.inter(fontSize: 13, color: t.accent)))]
              : null),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider)),
      ),
      // Tap outside the text field to dismiss the keyboard
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_state) {
          _IvState.setup     => _buildSetup(),
          _IvState.prepGuide => _buildPrepGuide(),
          _IvState.asking    => _buildAsking(),
          _IvState.feedback  => _buildSummary(),
        },
      ),
      ),
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      key: const ValueKey('setup'),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                const Color(0xFF6366F1).withValues(alpha: 0.08),
              ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2))),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.psychology_rounded, size: 24, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Practice with AI', style: GoogleFonts.sourceSerif4(
                fontSize: 18, fontWeight: FontWeight.w700, color: t.primary)),
              const SizedBox(height: 2),
              Text('5 realistic questions, instant scoring & feedback',
                style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
            ])),
          ]),
        ),
        const SizedBox(height: 28),

        _label('Role'),
        _picker(_roles, _role, (v) => setState(() => _role = v)),
        const SizedBox(height: 20),

        _label('Experience level'),
        _picker(_levels, _level, (v) => setState(() => _level = v)),
        const SizedBox(height: 20),

        _label('Interview type'),
        _picker(_types, _type, (v) => setState(() => _type = v)),
        const SizedBox(height: 20),

        _label('Target company (optional)'),
        TextField(
          controller: _companyCtrl,
          style: GoogleFonts.inter(fontSize: 14, color: t.primary),
          decoration: InputDecoration(
            hintText: 'e.g. Meta, Anthropic, early-stage startup',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: t.muted),
            filled: true,
            fillColor: t.surface,
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
          onChanged: (v) => _company = v,
        ),
        const SizedBox(height: 6),
        Text('We\'ll calibrate questions to how this company actually interviews',
          style: GoogleFonts.inter(fontSize: 11, color: t.muted, fontStyle: FontStyle.italic)),
        const SizedBox(height: 28),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFFEF4444))),
          ),

        // Prep Guide — secondary outlined button
        GestureDetector(
          onTap: _loading ? null : _generatePrepGuide,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.divider, width: 1)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.menu_book_outlined, size: 17, color: t.primary),
              const SizedBox(width: 8),
              Text('Prepare for this interview',
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // Start Interview — primary filled button
        GestureDetector(
          onTap: _loading ? null : _startInterview,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: t.primary, borderRadius: BorderRadius.circular(12)),
            child: Center(child: _loading
              ? SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: t.background, strokeWidth: 2))
              : Text('Start Interview', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: t.background))),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Read the prep first, then practice',
          style: GoogleFonts.inter(fontSize: 11, color: t.muted))),
      ]),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? t.primary : t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? t.primary : t.divider)),
          child: Text(o, style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? t.background : t.secondary)),
        ),
      );
    }).toList());
  }

  Widget _buildAsking() {
    return Column(
      key: const ValueKey('asking'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top: progress + question (fixed) ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Question ${_idx + 1} of ${_turns.length}',
                style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                width: 80, height: 4,
                decoration: BoxDecoration(
                  color: t.divider, borderRadius: BorderRadius.circular(2)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_idx + 1) / _turns.length,
                  child: Container(decoration: BoxDecoration(
                    color: t.accent, borderRadius: BorderRadius.circular(2))),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.divider, width: 0.5)),
              child: Text(_turns[_idx].question, style: GoogleFonts.sourceSerif4(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: t.primary, height: 1.4)),
            ),
          ]),
        ),

        // ── Middle: scrollable text field area ────────────────────────────
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: _answerCtrl,
            maxLines: null,
            minLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            scrollPadding: const EdgeInsets.all(60),
            style: GoogleFonts.inter(fontSize: 15, color: t.primary, height: 1.5),
            decoration: InputDecoration(
              hintText: _listening
                  ? 'Listening… speak naturally'
                  : (_sttAvailable
                      ? 'Type or tap the mic to speak…'
                      : 'Type your answer…'),
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: _listening ? const Color(0xFFEF4444) : t.muted,
                fontStyle: _listening ? FontStyle.italic : FontStyle.normal),
              filled: true, fillColor: t.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.divider)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _listening
                      ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                      : t.divider)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.primary)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        )),

        // ── Listening banner (only when listening) ───────────────────────
        if (_listening) Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Row(children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 6 + (_pulse.value * 2), height: 6 + (_pulse.value * 2),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444), shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 8),
            Text('Listening… tap mic to stop',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600)),
          ]),
        ),

        // ── Bottom: mic button + submit (always visible above keyboard) ───
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(children: [
            if (_sttAvailable)
              GestureDetector(
                onTap: _loading ? null : _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _listening
                        ? const Color(0xFFEF4444)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _listening
                          ? const Color(0xFFEF4444)
                          : t.divider,
                      width: 1.5),
                    boxShadow: _listening
                        ? [BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                            blurRadius: 12, spreadRadius: 1)]
                        : null,
                  ),
                  child: Icon(
                    _listening ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 22,
                    color: _listening ? Colors.white : t.primary),
                ),
              ),
            if (_sttAvailable) const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _loading ? null : _submitAnswer,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: t.primary, borderRadius: BorderRadius.circular(10)),
                child: Center(child: _loading
                  ? SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: t.background, strokeWidth: 2))
                  : Text(
                      _idx < _turns.length - 1 ? 'Submit & Next' : 'Submit & Finish',
                      style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: t.background))),
              ),
            )),
          ]),
        ),
      ],
    );
  }

  Widget _buildPrepGuide() {
    return SingleChildScrollView(
      key: const ValueKey('prep'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Editorial header
        Row(children: [
          Container(width: 24, height: 1, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          Text('INTERVIEW PREP', style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: const Color(0xFF8B5CF6), letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 8),
        Text('Your Prep Guide', style: GoogleFonts.sourceSerif4(
          fontSize: 26, fontWeight: FontWeight.w700,
          color: t.primary, letterSpacing: -0.6, height: 1.15)),
        const SizedBox(height: 4),
        Text('$_level $_role · $_type', style: GoogleFonts.inter(
          fontSize: 13, color: t.muted)),
        const SizedBox(height: 24),

        if (_prepLoading)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              CircularProgressIndicator(color: t.primary, strokeWidth: 1.5),
              const SizedBox(height: 16),
              Text('Building your prep guide…', style: GoogleFonts.inter(
                fontSize: 13, color: t.muted)),
            ]),
          ))
        else if (_prepError != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.divider, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.error_outline_rounded,
                  size: 16, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Text('Could not generate guide', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: t.primary)),
              ]),
              const SizedBox(height: 8),
              Text(_prepError!, style: GoogleFonts.inter(
                fontSize: 12, color: t.muted, height: 1.5)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _generatePrepGuide,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.primary, borderRadius: BorderRadius.circular(8)),
                  child: Text('Try again', style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: t.background)),
                ),
              ),
            ]),
          )
        else if (_prepGuide != null) ...[
          _PrepGuideContent(text: _prepGuide!, theme: t),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              setState(() => _state = _IvState.setup);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startInterview();
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: t.primary, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('Start Interview Now', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: t.background))),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _state = _IvState.setup),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: t.divider),
                borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('Back to Setup', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: t.primary))),
            ),
          ),
        ],
      ]),
    );
  }

  /// Small bar showing rubric score (0-5) with color gradient based on value
  Widget _rubricBar(String label, int score, AppTheme t) {
    final pct = (score / 5.0).clamp(0.0, 1.0);
    final color = score >= 4
        ? const Color(0xFF10B981)
        : score >= 3
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w600, color: t.muted,
        letterSpacing: 0.3)),
      const SizedBox(height: 3),
      Container(
        height: 4,
        decoration: BoxDecoration(
          color: t.divider.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: pct,
          child: Container(decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
        ),
      ),
      const SizedBox(height: 3),
      Text('$score/5', style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    ]);
  }

  Widget _buildSummary() {
    final scores = _turns.where((t) => t.score != null).map((t) => t.score!).toList();
    final avg = scores.isEmpty ? 0 : (scores.reduce((a, b) => a + b) / scores.length).round();
    final color = avg >= 8
        ? const Color(0xFF10B981) : avg >= 6
        ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    return SingleChildScrollView(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Column(children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3)),
            child: Center(child: Text('$avg', style: GoogleFonts.sourceSerif4(
              fontSize: 44, fontWeight: FontWeight.w700, color: color))),
          ),
          const SizedBox(height: 16),
          Text('Your average score', style: GoogleFonts.inter(
            fontSize: 13, color: t.muted)),
          const SizedBox(height: 4),
          Text(
            avg >= 8 ? 'Strong performance' : avg >= 6 ? 'Good — keep practicing' : 'Room to improve',
            style: GoogleFonts.sourceSerif4(
              fontSize: 18, fontWeight: FontWeight.w700, color: t.primary)),
        ])),
        const SizedBox(height: 28),
        Text('Detailed feedback', style: GoogleFonts.sourceSerif4(
          fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
        const SizedBox(height: 12),
        ..._turns.asMap().entries.map((e) {
          final i = e.key;
          final turn = e.value;
          final tColor = (turn.score ?? 0) >= 8
              ? const Color(0xFF10B981) : (turn.score ?? 0) >= 6
              ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.divider, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Q${i + 1}', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
                const Spacer(),
                if (turn.score != null) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text('${turn.score}/10', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: tColor)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(turn.question, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
              // Rubric breakdown (only if we have scores)
              if (turn.communicationScore != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _rubricBar('Comm', turn.communicationScore!, t)),
                  const SizedBox(width: 6),
                  Expanded(child: _rubricBar('Tech', turn.technicalScore ?? 0, t)),
                  const SizedBox(width: 6),
                  Expanded(child: _rubricBar('Approach', turn.approachScore ?? 0, t)),
                  const SizedBox(width: 6),
                  Expanded(child: _rubricBar('Cover', turn.completenessScore ?? 0, t)),
                ]),
              ],
              if (turn.feedback != null && turn.feedback!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(turn.feedback!, style: GoogleFonts.inter(
                  fontSize: 12, color: t.secondary, height: 1.5)),
              ],
              // Better answer example (expandable)
              if (turn.betterAnswer != null && turn.betterAnswer!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.lightbulb_rounded, size: 12, color: const Color(0xFF10B981)),
                      const SizedBox(width: 5),
                      Text('Stronger answer', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857), letterSpacing: 0.3)),
                    ]),
                    const SizedBox(height: 6),
                    Text(turn.betterAnswer!, style: GoogleFonts.sourceSerif4(
                      fontSize: 12.5, fontStyle: FontStyle.italic,
                      color: const Color(0xFF064E3B), height: 1.5)),
                  ]),
                ),
              ],
            ]),
          );
        }),

        // Story Bank auto-save banner
        if (_newlySavedCount > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.25))),
            child: Row(children: [
              const Icon(Icons.auto_stories_rounded, size: 20, color: Color(0xFF22C55E)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$_newlySavedCount answer${_newlySavedCount == 1 ? "" : "s"} saved to Story Bank',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF22C55E))),
                Text('Your best answers are saved for future interviews',
                  style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
              ])),
            ]),
          ),
        ],

        // Story Bank section
        if (_savedStories.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(children: [
            const Icon(Icons.auto_stories_rounded, size: 16, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            Text('Your Story Bank', style: GoogleFonts.sourceSerif4(
              fontSize: 17, fontWeight: FontWeight.w700, color: t.primary)),
            const Spacer(),
            Text('${_savedStories.length} stories', style: GoogleFonts.inter(
              fontSize: 12, color: t.muted)),
          ]),
          const SizedBox(height: 12),
          ..._savedStories.take(5).map((story) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surface, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.divider, width: 0.5)),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7)),
                child: Center(child: Text('${story.score}', style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6)))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(story.question, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: t.primary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${story.role} · ${story.type}', style: GoogleFonts.inter(
                  fontSize: 10, color: t.muted)),
              ])),
              GestureDetector(
                onTap: () async {
                  await StarStoryService.remove(story.id);
                  _savedStories = await StarStoryService.all();
                  if (mounted) setState(() {});
                },
                child: Icon(Icons.close_rounded, size: 16, color: t.muted),
              ),
            ]),
          )),
        ],

        const SizedBox(height: 24),
        GestureDetector(
          onTap: _restart,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: t.primary, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('Practice Again', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: t.background))),
          ),
        ),
      ]),
    );
  }
}

// ── Prep Guide Content (parsed editorial sections) ─────────────────────────
class _PrepGuideContent extends StatelessWidget {
  final String text;
  final AppTheme theme;
  const _PrepGuideContent({required this.text, required this.theme});

  static const _headers = [
    ('WHAT TO EXPECT', 'What to Expect', Icons.visibility_outlined, Color(0xFF3B82F6)),
    ('TOPICS TO MASTER', 'Topics to Master', Icons.menu_book_outlined, Color(0xFF10B981)),
    ('LIKELY QUESTIONS', 'Likely Questions', Icons.help_outline_rounded, Color(0xFFF59E0B)),
    ('ANSWER FRAMEWORK', 'Answer Framework', Icons.architecture_outlined, Color(0xFF8B5CF6)),
    ('QUICK WINS', 'Quick Wins', Icons.bolt_rounded, Color(0xFFEC4899)),
    ('RED FLAGS TO AVOID', 'Red Flags to Avoid', Icons.warning_amber_rounded, Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final sections = _parse(text);

    if (sections.isEmpty) {
      return Text(text, style: GoogleFonts.sourceSerif4(
        fontSize: 14, color: t.primary, height: 1.65));
    }

    return Column(children: [
      for (var i = 0; i < sections.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : 14),
          child: _buildCard(sections[i], i, t),
        ),
    ]);
  }

  Widget _buildCard(({String title, String body, IconData icon, Color color}) s,
      int index, AppTheme t) {
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
        // Header strip with colored top border
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
              Text('STEP ${index + 1}', style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: s.color, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(s.title, style: GoogleFonts.sourceSerif4(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: t.primary, letterSpacing: -0.3, height: 1.1)),
            ])),
          ]),
        ),
        Divider(height: 1, color: t.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: _renderBody(s, t),
        ),
      ]),
    );
  }

  Widget _renderBody(({String title, String body, IconData icon, Color color}) s,
      AppTheme t) {
    final items = _parseListItems(s.body);

    // What to Expect & Answer Framework: render as prose
    if (s.title == 'What to Expect' || s.title == 'Answer Framework') {
      return Text(s.body, style: GoogleFonts.sourceSerif4(
        fontSize: 14, color: t.primary.withValues(alpha: 0.88),
        height: 1.65, letterSpacing: 0.05));
    }

    // Likely Questions: render with quote-mark prefix
    if (s.title == 'Likely Questions' && items.isNotEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('“', style: GoogleFonts.sourceSerif4(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: s.color, height: 1.0)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(items[i], style: GoogleFonts.sourceSerif4(
                fontSize: 14, color: t.primary.withValues(alpha: 0.88),
                height: 1.55, fontStyle: FontStyle.italic, letterSpacing: 0.05))),
            ]),
          ),
      ]);
    }

    // Default for Topics, Quick Wins, Red Flags: bulleted list
    if (items.isNotEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 7),
                width: 5, height: 5,
                decoration: BoxDecoration(
                  color: s.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 11),
              Expanded(child: Text(items[i], style: GoogleFonts.sourceSerif4(
                fontSize: 14, color: t.primary.withValues(alpha: 0.88),
                height: 1.55, letterSpacing: 0.05))),
            ]),
          ),
      ]);
    }

    return Text(s.body, style: GoogleFonts.sourceSerif4(
      fontSize: 14, color: t.primary.withValues(alpha: 0.88), height: 1.65));
  }

  List<({String title, String body, IconData icon, Color color})> _parse(String text) {
    final result = <({String title, String body, IconData icon, Color color})>[];
    final lines = text.split('\n');

    int? currentIdx;
    final buf = StringBuffer();

    void flush() {
      if (currentIdx != null) {
        final h = _headers[currentIdx];
        final body = buf.toString().trim();
        if (body.isNotEmpty) {
          result.add((title: h.$2, body: body, icon: h.$3, color: h.$4));
        }
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Check if this line is a header
      final upper = trimmed.replaceAll('*', '').replaceAll('#', '').trim();
      var matchedHeader = -1;
      for (var i = 0; i < _headers.length; i++) {
        if (upper == _headers[i].$1) {
          matchedHeader = i;
          break;
        }
      }
      if (matchedHeader >= 0) {
        flush();
        currentIdx = matchedHeader;
        buf.clear();
      } else {
        buf.writeln(trimmed);
      }
    }
    flush();
    return result;
  }

  List<String> _parseListItems(String body) {
    final lines = body.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
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
      final match = RegExp(r'^(?:\d+[\.\)]\s+|[-•*]\s+)(.*)$').firstMatch(line);
      if (match != null) {
        flush();
        current = StringBuffer(match.group(1)!);
      } else {
        if (current != null) {
          current!.write(' ');
          current!.write(line);
        } else {
          items.add(line);
        }
      }
    }
    flush();
    return items;
  }
}

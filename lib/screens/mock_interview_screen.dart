import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

enum _IvState { setup, asking, feedback }

class _Turn {
  final String question;
  String answer;
  String? feedback;
  int? score;
  _Turn(this.question, {this.answer = '', this.feedback, this.score});
}

class MockInterviewScreen extends StatefulWidget {
  final AppTheme theme;
  const MockInterviewScreen({super.key, required this.theme});

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  _IvState _state = _IvState.setup;
  String _role = 'ML Engineer';
  String _level = 'Mid';
  String _type = 'Behavioral';
  bool _loading = false;
  String? _error;

  final List<_Turn> _turns = [];
  int _idx = 0;
  final _answerCtrl = TextEditingController();

  AppTheme get t => widget.theme;

  static const _roles = ['ML Engineer', 'Data Scientist', 'AI Researcher', 'MLOps Engineer', 'AI Product Manager'];
  static const _levels = ['Junior', 'Mid', 'Senior', 'Lead'];
  static const _types = ['Behavioral', 'Technical', 'System Design'];

  @override
  void initState() {
    super.initState();
    _loadProfileDefaults();
  }

  Future<void> _loadProfileDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('user_job_title');
    final level = prefs.getString('user_level');
    if (title != null && _roles.contains(title)) _role = title;
    if (level != null && _levels.contains(level)) _level = level;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _startInterview() async {
    HapticFeedback.lightImpact();
    setState(() { _loading = true; _error = null; });

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) {
      setState(() { _error = 'API key not configured'; _loading = false; });
      return;
    }

    final prompt = '''Generate exactly 5 $_type interview questions for a $_level $_role role.
Return ONLY a JSON array of strings, no markdown, no preamble. Example: ["Question 1?", "Question 2?", ...]
Make questions realistic and challenging for the experience level. Mix open-ended with specific.''';

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
          'max_tokens': 600,
          'messages': [{'role': 'user', 'content': prompt}],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('API ${response.statusCode}');
      }
      final data = json.decode(response.body);
      final raw = (data['content'][0]['text'] as String).trim();
      final cleaned = raw
          .replaceFirst(RegExp(r'^```json\s*'), '')
          .replaceFirst(RegExp(r'^```\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
      final questions = (json.decode(cleaned) as List).cast<String>();

      _turns.clear();
      for (final q in questions) {
        _turns.add(_Turn(q));
      }
      setState(() {
        _state = _IvState.asking;
        _idx = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not generate questions. ${e.toString().replaceFirst("Exception: ", "")}';
        _loading = false;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_answerCtrl.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    final answer = _answerCtrl.text.trim();
    _turns[_idx].answer = answer;
    _answerCtrl.clear();

    setState(() => _loading = true);

    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    final prompt = '''You are an expert $_role interviewer. Score this candidate's answer on a scale of 1-10 and give 2-3 sentences of specific, actionable feedback.

ROLE: $_level $_role
TYPE: $_type interview
QUESTION: ${_turns[_idx].question}
CANDIDATE'S ANSWER: $answer

Respond in this exact format:
SCORE: <number 1-10>
FEEDBACK: <2-3 sentences>''';

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
          'max_tokens': 300,
          'messages': [{'role': 'user', 'content': prompt}],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = (data['content'][0]['text'] as String).trim();
        final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(text);
        final feedbackMatch = RegExp(r'FEEDBACK:\s*(.+)', dotAll: true).firstMatch(text);
        _turns[_idx].score = scoreMatch != null ? int.tryParse(scoreMatch.group(1)!) : null;
        _turns[_idx].feedback = feedbackMatch?.group(1)?.trim() ?? text;
      } else {
        _turns[_idx].feedback = 'Could not get feedback';
      }
    } catch (e) {
      _turns[_idx].feedback = 'Network error';
    }

    setState(() {
      _loading = false;
      if (_idx < _turns.length - 1) {
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
        actions: _state != _IvState.setup
          ? [TextButton(
              onPressed: _restart,
              child: Text('Restart', style: GoogleFonts.inter(fontSize: 13, color: t.accent)))]
          : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_state) {
          _IvState.setup    => _buildSetup(),
          _IvState.asking   => _buildAsking(),
          _IvState.feedback => _buildSummary(),
        },
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
        const SizedBox(height: 28),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFFEF4444))),
          ),

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
    return Padding(
      key: const ValueKey('asking'),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Question ${_idx + 1} of ${_turns.length}',
            style: GoogleFonts.inter(fontSize: 12, color: t.muted, fontWeight: FontWeight.w500)),
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
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.divider, width: 0.5)),
          child: Text(_turns[_idx].question, style: GoogleFonts.sourceSerif4(
            fontSize: 17, fontWeight: FontWeight.w600, color: t.primary, height: 1.4)),
        ),
        const SizedBox(height: 20),
        Expanded(child: TextField(
          controller: _answerCtrl,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: GoogleFonts.inter(fontSize: 14, color: t.primary, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Type your answer...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: t.muted),
            filled: true, fillColor: t.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.divider)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.divider)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.primary)),
            contentPadding: const EdgeInsets.all(14),
          ),
        )),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _loading ? null : _submitAnswer,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: t.primary, borderRadius: BorderRadius.circular(10)),
            child: Center(child: _loading
              ? SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: t.background, strokeWidth: 2))
              : Text(_idx < _turns.length - 1 ? 'Submit & Next' : 'Submit & Finish',
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: t.background))),
          ),
        ),
      ]),
    );
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
              if (turn.feedback != null) ...[
                const SizedBox(height: 8),
                Text(turn.feedback!, style: GoogleFonts.inter(
                  fontSize: 12, color: t.secondary, height: 1.5)),
              ],
            ]),
          );
        }),
      ]),
    );
  }
}

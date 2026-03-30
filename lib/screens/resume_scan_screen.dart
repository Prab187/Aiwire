import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/resume_profile.dart';
import '../models/job.dart';
import '../services/resume_service.dart';
import '../services/job_service.dart';

enum _ScanState { idle, analyzing, results, error }

class ResumeScanScreen extends StatefulWidget {
  final AppTheme theme;
  const ResumeScanScreen({super.key, required this.theme});

  @override
  State<ResumeScanScreen> createState() => _ResumeScanScreenState();
}

class _ResumeScanScreenState extends State<ResumeScanScreen>
    with SingleTickerProviderStateMixin {
  _ScanState _state = _ScanState.idle;
  String _statusMessage = '';
  String? _errorMessage;
  ResumeProfile? _profile;
  List<Job> _jobs = [];

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan() async {
    // Pick file
    final file = await ResumeService.pickResumeFile();
    if (file == null) return; // user cancelled

    setState(() {
      _state = _ScanState.analyzing;
      _statusMessage = 'Reading your resume\u2026';
      _errorMessage = null;
    });

    try {
      // Step 1: Analyze resume with Claude
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _statusMessage = 'Extracting skills & experience\u2026');

      final profile = await ResumeService.analyzeResume(file);

      setState(() => _statusMessage =
          'Finding jobs in ${profile.country}\u2026');

      // Step 2: Fetch country-matched jobs
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
    } catch (e) {
      setState(() {
        _state = _ScanState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _reset() => setState(() {
    _state = _ScanState.idle;
    _profile = null;
    _jobs = [];
    _errorMessage = null;
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
            fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
        centerTitle: true,
        actions: _state == _ScanState.results
            ? [
                TextButton(
                  onPressed: _reset,
                  child: Text('Rescan',
                    style: GoogleFonts.inter(fontSize: 13, color: t.accent)),
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: switch (_state) {
          _ScanState.idle     => _buildIdle(),
          _ScanState.analyzing => _buildAnalyzing(),
          _ScanState.results  => _buildResults(),
          _ScanState.error    => _buildError(),
        },
      ),
    );
  }

  // ── Idle: upload prompt ────────────────────────────────────────────────────

  Widget _buildIdle() {
    return Center(
      key: const ValueKey('idle'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.upload_file_rounded, size: 36, color: t.primary),
            ),
            const SizedBox(height: 24),
            Text('Scan Your Resume',
              style: GoogleFonts.sourceSerif4(
                fontSize: 24, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 12),
            Text(
              'Upload your CV and we\'ll find AI/ML jobs '
              'matching your skills from your country.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: t.muted, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text('PDF, TXT, DOC, DOCX supported',
              style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pickAndScan,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Upload Resume',
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: t.background)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Analyzing: animated status ─────────────────────────────────────────────

  Widget _buildAnalyzing() {
    return Center(
      key: const ValueKey('analyzing'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_rounded, size: 32, color: t.primary),
              ),
            ),
            const SizedBox(height: 28),
            Text('Analyzing\u2026',
              style: GoogleFonts.sourceSerif4(
                fontSize: 22, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 10),
            Text(_statusMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: t.muted)),
          ],
        ),
      ),
    );
  }

  // ── Results: profile card + job list ──────────────────────────────────────

  Widget _buildResults() {
    final p = _profile!;

    // Compute skill gaps: skills from all jobs that user doesn't have
    final profileSkillsLower = p.skills.map((s) => s.toLowerCase()).toSet();
    final allJobSkills = <String>[];
    for (final job in _jobs) {
      for (final s in job.skills) {
        if (!profileSkillsLower.contains(s.toLowerCase())) {
          allJobSkills.add(s);
        }
      }
    }
    // Deduplicate preserving order, take top 8
    final seen = <String>{};
    final skillGaps = <String>[];
    for (final s in allJobSkills) {
      final lower = s.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        skillGaps.add(s);
        if (skillGaps.length >= 8) break;
      }
    }

    return ListView(
      key: const ValueKey('results'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(p.flagEmoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.name != null)
                      Text(p.name!,
                        style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: t.primary)),
                    Text(p.jobTitle,
                      style: GoogleFonts.inter(fontSize: 13, color: t.secondary)),
                    Text('${p.country} · ${p.experienceLevel}',
                      style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                  ],
                )),
              ]),
              if (p.summary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.summary,
                  style: GoogleFonts.inter(
                    fontSize: 13, color: t.muted, height: 1.4)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: p.skills.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: t.primary)),
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Job count header
        Row(children: [
          Text('${_jobs.length} jobs matched',
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
          const SizedBox(width: 6),
          Text('in ${p.country}',
            style: GoogleFonts.inter(fontSize: 14, color: t.muted)),
        ]),
        // Skill gap section
        if (skillGaps.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 15, color: t.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Skills appearing in these jobs you don\'t have yet',
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
                  ),
                ]),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: skillGaps.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_circle_outline_rounded, size: 12, color: t.accent),
                      const SizedBox(width: 4),
                      Text(s,
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w500, color: t.accent)),
                    ]),
                  )).toList(),
                ),
              ],
            ),
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

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: t.muted),
            const SizedBox(height: 16),
            Text('Something went wrong',
              style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: t.muted, height: 1.4)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _reset,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: t.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Try again',
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: t.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Job card (resume-tailored, always shows Apply Now) ──────────────────────

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

  void _showCoverLetter(BuildContext context) {
    final t = theme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _CoverLetterSheet(
        job: job,
        profile: profile,
        theme: t,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final score = _matchScore();
    final scoreColor = score >= 70
        ? const Color(0xFF22C55E)
        : score >= 40
            ? const Color(0xFFF59E0B)
            : t.muted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Company logo or letter avatar
            _buildLogo(t),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title,
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: t.primary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(job.company,
                  style: GoogleFonts.inter(fontSize: 13, color: t.secondary)),
              ],
            )),
            // Match score pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Match: $score%',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: scoreColor)),
            ),
          ]),
          const SizedBox(height: 4),
          // Level pill
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(job.level,
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: t.primary)),
            ),
          ),
          const SizedBox(height: 8),
          Text(job.description,
            style: GoogleFonts.inter(fontSize: 13, color: t.muted, height: 1.4),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: job.skills.take(4).map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.background, borderRadius: BorderRadius.circular(4)),
              child: Text(s,
                style: GoogleFonts.inter(
                  fontSize: 11, color: t.secondary,
                  fontWeight: FontWeight.w500)),
            )).toList(),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 13, color: t.muted),
            const SizedBox(width: 3),
            Flexible(child: Text(job.location,
              style: GoogleFonts.inter(fontSize: 12, color: t.muted),
              overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(job.type,
              style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
            const Spacer(),
            Text(job.salaryRange,
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: t.primary)),
          ]),
          if (job.applyUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(job.applyUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: t.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('Apply Now',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: t.primary))),
              ),
            ),
            const SizedBox(height: 8),
            // Draft cover letter button
            GestureDetector(
              onTap: () => _showCoverLetter(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: t.muted.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 15, color: t.secondary),
                    const SizedBox(width: 6),
                    Text('Draft Cover Letter',
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: t.secondary)),
                  ],
                )),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogo(AppTheme t) {
    if (job.companyLogo != null && job.companyLogo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: job.companyLogo!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _letterAvatar(t),
        ),
      );
    }
    return _letterAvatar(t);
  }

  Widget _letterAvatar(AppTheme t) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Text(
        job.company.isNotEmpty ? job.company[0] : '?',
        style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: t.primary),
      )),
    );
  }
}

// ── Cover letter bottom sheet ─────────────────────────────────────────────

class _CoverLetterSheet extends StatefulWidget {
  final Job job;
  final ResumeProfile profile;
  final AppTheme theme;
  const _CoverLetterSheet({required this.job, required this.profile, required this.theme});

  @override
  State<_CoverLetterSheet> createState() => _CoverLetterSheetState();
}

class _CoverLetterSheetState extends State<_CoverLetterSheet> {
  bool _loading = true;
  String? _letter;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'ANTHROPIC_API_KEY not configured';
      });
      return;
    }

    final p = widget.profile;
    final j = widget.job;
    final candidateName = p.name ?? p.jobTitle;
    final prompt =
        'Write a short (150 word) cover letter for $candidateName applying for '
        '${j.title} at ${j.company}. Skills: ${p.skills.join(', ')}. '
        'Keep it professional and concise.';

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
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('API error: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final text = (data['content'][0]['text'] as String).trim();
      setState(() {
        _letter = text;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: t.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Cover Letter Draft',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 18, fontWeight: FontWeight.w700, color: t.primary)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('${widget.job.title} at ${widget.job.company}',
                style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: t.divider),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                          ),
                        )
                      : SingleChildScrollView(
                          controller: ctrl,
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(
                            _letter ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14, color: t.primary, height: 1.6),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

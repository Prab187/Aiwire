import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Hard-coded beginner AI starter plan — no API call needed.
/// 3 sections: 7-Day Kickstart, AI Careers, Success Stories.
class BeginnerStarterPlan extends StatefulWidget {
  final AppTheme theme;
  final String userName;
  final String education;
  final bool hasWorkExp;
  final String workYears;
  final String workRole;
  final String domain;
  final VoidCallback? onUnlock30Day;

  const BeginnerStarterPlan({
    super.key,
    required this.theme,
    required this.userName,
    this.education = '',
    this.hasWorkExp = false,
    this.workYears = '',
    this.workRole = '',
    this.domain = '',
    this.onUnlock30Day,
  });

  @override
  State<BeginnerStarterPlan> createState() => _BeginnerStarterPlanState();
}

class _BeginnerStarterPlanState extends State<BeginnerStarterPlan> {
  AppTheme get t => widget.theme;

  final List<bool> _daysDone = List.filled(7, false);
  String? _pickedCareer;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 7; i++) {
      _daysDone[i] = prefs.getBool('starter_day_${i + 1}') ?? false;
    }
    _pickedCareer = prefs.getString('starter_career_pick');
    if (mounted) setState(() {});
  }

  Future<void> _toggleDay(int index) async {
    final nowDone = !_daysDone[index];
    setState(() => _daysDone[index] = nowDone);
    // Stronger haptic on completion
    if (nowDone) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('starter_day_${index + 1}', nowDone);
  }

  Future<void> _pickCareer(String career) async {
    HapticFeedback.mediumImpact();
    setState(() => _pickedCareer = career);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('starter_career_pick', career);
  }

  int get _completedDays => _daysDone.where((d) => d).length;
  bool get _allDone => _completedDays == 7;

  /// Index of the first uncompleted day — this is the "current" day.
  int get _currentDay {
    for (var i = 0; i < 7; i++) {
      if (!_daysDone[i]) return i;
    }
    return 7; // all done
  }

  /// Personalized welcome subtitle based on discovery data.
  String _welcomeSubtitle(String firstName) {
    final parts = <String>[];
    if (widget.education.isNotEmpty) parts.add(widget.education);
    if (widget.hasWorkExp && widget.workRole.isNotEmpty) {
      final yrs = widget.workYears.isNotEmpty ? '${widget.workYears}yr ' : '';
      parts.add('$yrs${widget.workRole}');
    }
    final hasDomain = widget.domain.isNotEmpty && widget.domain != 'Not sure yet';
    if (hasDomain && parts.isNotEmpty) {
      return "${parts.join(" · ")} → AI in ${widget.domain} is booming. 15 min/day, 7 days — let's get you in.";
    }
    if (hasDomain) {
      return "AI in ${widget.domain} is one of the fastest-growing fields. 15 min/day, 7 days — you're starting now.";
    }
    if (parts.isNotEmpty) {
      return "${parts.join(" · ")} — perfect starting point for AI. 15 min/day, 7 days.";
    }
    return "Most people think about AI. You're actually starting. 15 min/day, 7 days — that's it.";
  }

  /// Domain-specific tip for career cards.
  String get _domainHint {
    switch (widget.domain) {
      case 'Healthcare': return 'AI is transforming diagnostics, drug discovery & patient care';
      case 'Finance': return 'AI drives fraud detection, trading bots & risk analysis';
      case 'Education': return 'AI powers personalized learning, grading & curriculum design';
      case 'Marketing': return 'AI automates ad targeting, content creation & customer insights';
      case 'E-commerce': return 'AI runs recommendation engines, pricing & inventory management';
      case 'Real Estate': return 'AI predicts property values, automates listings & lead scoring';
      case 'Content Creation': return 'AI generates copy, videos, images & social media strategies';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userName.split(' ').first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Welcome header ──
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.12),
            const Color(0xFF3B82F6).withValues(alpha: 0.08),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(
              _completedDays == 0
                  ? "Hey $firstName! Let's go."
                  : _allDone
                      ? "$firstName, you crushed it!"
                      : "Day ${_currentDay + 1} awaits, $firstName",
              style: GoogleFonts.sourceSerif4(
                fontSize: 20, fontWeight: FontWeight.w700, color: t.primary),
            )),
          ]),
          const SizedBox(height: 4),
          Text(
            _completedDays == 0
                ? _welcomeSubtitle(firstName)
                : _allDone
                    ? "You completed all 7 days. You're ahead of 95% of people who just talk about getting into AI."
                    : "$_completedDays down, ${7 - _completedDays} to go. You're already ahead of most people.",
            style: GoogleFonts.inter(fontSize: 13, color: t.secondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          // Progress bar with day dots
          Row(children: [
            ...List.generate(7, (i) => Expanded(child: Container(
              margin: EdgeInsets.only(right: i < 6 ? 3 : 0),
              height: 6,
              decoration: BoxDecoration(
                color: _daysDone[i]
                    ? const Color(0xFF10B981)
                    : i == _currentDay
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                        : t.divider,
                borderRadius: BorderRadius.circular(3)),
            ))),
            const SizedBox(width: 10),
            Text('$_completedDays/7', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: _allDone ? const Color(0xFF10B981) : const Color(0xFF8B5CF6))),
          ]),
        ]),
      ),
      const SizedBox(height: 16),

      // ── Section 1: 7-Day Kickstart ──
      _AccordionCard(
        theme: t,
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF10B981),
        title: '7-Day AI Kickstart',
        subtitle: '15 min/day — your action plan',
        badge: '$_completedDays/7',
        initiallyExpanded: true,
        child: _build7Days(),
      ),

      // ── Section 2: AI Careers ──
      _AccordionCard(
        theme: t,
        icon: Icons.work_outline_rounded,
        color: const Color(0xFF3B82F6),
        title: 'AI Careers That Don\'t Need Coding',
        subtitle: _domainHint.isNotEmpty ? _domainHint : 'Tap the one that excites you',
        child: _buildCareers(),
      ),

      // ── Section 3: Success Stories ──
      _AccordionCard(
        theme: t,
        icon: Icons.emoji_events_outlined,
        color: const Color(0xFFF59E0B),
        title: 'People Who Started From Zero',
        subtitle: 'Real transitions — no CS degree needed',
        child: _buildStories(),
      ),

      // ── Unlock 30-Day Path ──
      if (_allDone) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: widget.onUnlock30Day,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_open_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text('Unlock Your 30-Day Career Path', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ])),
          ),
        ),
      ] else ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider)),
          child: Row(children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: t.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Complete all 7 days to unlock your personalized 30-Day Career Path',
              style: GoogleFonts.inter(fontSize: 12, color: t.muted))),
          ]),
        ),
      ],
      const SizedBox(height: 24),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 7-Day Kickstart
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _build7Days() {
    final days = [
      (
        title: 'What Even Is AI?',
        desc: 'Watch a simple 10-min video that explains AI like you\'re 5. Write down 3 things that surprised you.',
        links: [
          ('Watch: AI Explained Simply', 'https://www.youtube.com/watch?v=ad79nYk2keg'),
          ('Follow: Fireship (100-sec explainers)', 'https://www.youtube.com/@Fireship'),
        ],
        minutes: 10,
      ),
      (
        title: 'Talk To AI For The First Time',
        desc: 'Open Claude or ChatGPT (both free). Ask it to: explain your job in a funny way, plan your weekend, write a birthday message. Just play.',
        links: [
          ('Open Claude (free)', 'https://claude.ai'),
          ('Open ChatGPT (free)', 'https://chat.openai.com'),
        ],
        minutes: 15,
      ),
      (
        title: 'Make AI Solve YOUR Problem',
        desc: 'Use AI to do something genuinely useful — rewrite your LinkedIn bio, summarize an article, draft an email, or create a meal plan.',
        links: [
          ('50 best AI prompts to try', 'https://www.youtube.com/watch?v=sTeoEFzVNSc'),
        ],
        minutes: 15,
      ),
      (
        title: 'Discover AI Careers',
        desc: 'Scroll down to "AI Careers" and browse 6 real roles. Tap the one that excites you. Then take Google\'s free AI course.',
        links: [
          ('Google AI Essentials (free)', 'https://grow.google/intl/en_in/googleaiessentials/'),
        ],
        minutes: 15,
      ),
      (
        title: 'Learn The #1 AI Skill: Prompting',
        desc: 'This skill separates beginners from pros. Learn 5 tricks: be specific, give examples, assign a role, set the format, and iterate.',
        links: [
          ('Watch: Prompt Engineering Basics', 'https://www.youtube.com/watch?v=jC4v5AS4RIM'),
          ('Free Course on Coursera', 'https://www.coursera.org/learn/prompt-engineering'),
        ],
        minutes: 15,
      ),
      (
        title: 'Build Something With AI (No Code)',
        desc: 'Create something real with zero coding — a website, a presentation, or an app. Pick one tool and spend 15 minutes.',
        links: [
          ('Bolt — build apps with AI', 'https://bolt.new'),
          ('Gamma — AI presentations', 'https://gamma.app'),
          ('Canva AI — design anything', 'https://www.canva.com'),
        ],
        minutes: 15,
      ),
      (
        title: 'Set Your Path & Join The Community',
        desc: 'Join 1 AI community, follow 3 AI creators, and set your 30-day goal based on the career you picked on Day 4.',
        links: [
          ('Join r/artificial on Reddit', 'https://www.reddit.com/r/artificial/'),
          ('Follow: AI Jason on YouTube', 'https://www.youtube.com/@AIJason'),
          ('Follow: Matt Wolfe (AI tools)', 'https://www.youtube.com/@maboroshi'),
        ],
        minutes: 15,
      ),
    ];

    return Column(children: [
      for (var i = 0; i < days.length; i++)
        _buildDayCard(i, days[i]),
    ]);
  }

  Widget _buildDayCard(
    int i,
    ({String title, String desc, List<(String, String)> links, int minutes}) day,
  ) {
    final done = _daysDone[i];
    final isCurrent = i == _currentDay;

    // ── Completed day: compact single line ──
    if (done) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleDay(i),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('Day ${i + 1}', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: const Color(0xFF10B981))),
            const SizedBox(width: 8),
            Expanded(child: Text(day.title, style: GoogleFonts.inter(
              fontSize: 13, color: t.muted,
              decoration: TextDecoration.lineThrough,
              decorationColor: t.muted.withValues(alpha: 0.5)))),
          ]),
        ),
      );
    }

    // ── Current day: highlighted with "START HERE" ──
    // ── Future days: dimmed, still tappable ──
    final isFuture = !done && !isCurrent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF10B981).withValues(alpha: 0.04)
            : t.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : t.divider.withValues(alpha: isFuture ? 0.5 : 1),
          width: isCurrent ? 1.5 : 0.5,
        ),
        boxShadow: isCurrent
            ? [BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                blurRadius: 12, offset: const Offset(0, 3))]
            : null,
      ),
      child: Opacity(
        opacity: isFuture ? 0.55 : 1.0,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Checkbox
            GestureDetector(
              onTap: () => _toggleDay(i),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF10B981)
                        : t.muted.withValues(alpha: 0.4),
                    width: isCurrent ? 2 : 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text('DAY ${i + 1}', style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981), letterSpacing: 0.5)),
                ),
                const SizedBox(width: 8),
                Text('${day.minutes} min', style: GoogleFonts.inter(
                  fontSize: 10, color: t.muted)),
                if (isCurrent) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text('START HERE', style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 0.5)),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              Text(day.title, style: GoogleFonts.sourceSerif4(
                fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
              const SizedBox(height: 4),
              Text(day.desc, style: GoogleFonts.inter(
                fontSize: 12, color: t.secondary, height: 1.5)),
            ])),
          ]),
          if (day.links.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(spacing: 6, runSpacing: 6, children: day.links.map((link) =>
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(link.$2);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.open_in_new_rounded, size: 12,
                        color: Color(0xFF10B981)),
                      const SizedBox(width: 5),
                      Flexible(child: Text(link.$1, style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981)))),
                    ]),
                  ),
                ),
              ).toList()),
            ),
          ],
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AI Careers
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCareers() {
    const careers = [
      (
        title: 'AI Trainer / Data Annotator',
        desc: 'Teach AI models by labeling data and evaluating outputs. The fastest entry point into AI.',
        salary: '\$40K – \$75K',
        difficulty: 1,
        time: '1-2 weeks',
        icon: Icons.school_outlined,
        badge: 'EASIEST ENTRY',
        badgeColor: Color(0xFF10B981),
      ),
      (
        title: 'Prompt Engineer',
        desc: 'Write instructions that make AI produce amazing results. The hottest new role — no coding.',
        salary: '\$65K – \$140K',
        difficulty: 1,
        time: '1-3 months',
        icon: Icons.chat_bubble_outline_rounded,
        badge: 'MOST IN-DEMAND',
        badgeColor: Color(0xFF8B5CF6),
      ),
      (
        title: 'AI Content Creator',
        desc: 'Create content using AI tools — writing, images, video, social media. Creative + AI.',
        salary: '\$45K – \$120K',
        difficulty: 1,
        time: '1-2 months',
        icon: Icons.brush_outlined,
        badge: '',
        badgeColor: Color(0xFF3B82F6),
      ),
      (
        title: 'No-Code AI Builder',
        desc: 'Build AI apps and automations using drag-and-drop tools like Bolt, Zapier, and Make.',
        salary: '\$55K – \$110K',
        difficulty: 2,
        time: '2-4 months',
        icon: Icons.widgets_outlined,
        badge: '',
        badgeColor: Color(0xFF3B82F6),
      ),
      (
        title: 'AI Product Manager',
        desc: 'Decide what AI products to build and how. Business skills matter more than coding.',
        salary: '\$90K – \$180K',
        difficulty: 2,
        time: '3-6 months',
        icon: Icons.dashboard_outlined,
        badge: 'HIGHEST PAY',
        badgeColor: Color(0xFFF59E0B),
      ),
      (
        title: 'AI Consultant',
        desc: 'Help businesses adopt AI tools. Your industry expertise + AI knowledge = premium rates.',
        salary: '\$70K – \$160K',
        difficulty: 3,
        time: '3-6 months',
        icon: Icons.business_center_outlined,
        badge: '',
        badgeColor: Color(0xFF3B82F6),
      ),
    ];

    return Column(children: [
      // Instruction
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.touch_app_rounded, size: 14,
            color: const Color(0xFF3B82F6).withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Tap the career that excites you most — we\'ll use this for your 30-day plan',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF3B82F6)),
          )),
        ]),
      ),
      ...careers.map((c) {
        final isSelected = _pickedCareer == c.title;
        return GestureDetector(
          onTap: () => _pickCareer(c.title),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.08)
                  : t.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                    : t.divider,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                        : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9)),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF3B82F6))
                      : Icon(c.icon, size: 18, color: const Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c.title, style: GoogleFonts.sourceSerif4(
                      fontSize: 15, fontWeight: FontWeight.w700, color: t.primary))),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text('YOUR PICK', style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white,
                          letterSpacing: 0.5)),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(c.desc, style: GoogleFonts.inter(
                    fontSize: 12, color: t.secondary, height: 1.4)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _tag(c.salary, const Color(0xFF10B981)),
                    _tag(c.time, const Color(0xFFF59E0B)),
                    // Difficulty
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.divider.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        ...List.generate(3, (j) => Padding(
                          padding: EdgeInsets.only(right: j < 2 ? 2 : 0),
                          child: Icon(Icons.circle, size: 6,
                            color: j < c.difficulty
                                ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                                : t.divider),
                        )),
                      ]),
                    ),
                    if (c.badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text(c.badge, style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: c.badgeColor, letterSpacing: 0.3)),
                      ),
                  ]),
                ])),
              ]),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Success Stories
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStories() {
    const stories = [
      (
        name: 'Sarah K.',
        before: 'High school teacher',
        after: 'AI Product Manager at EdTech startup',
        time: '8 months',
        quote: 'I didn\'t write a single line of code. I learned how AI works, how to manage AI projects, and how to translate teacher problems into AI solutions. My education background was my superpower.',
        color: Color(0xFF3B82F6),
      ),
      (
        name: 'Marcus J.',
        before: 'Barista & college dropout',
        after: 'Prompt Engineer — \$85K/year',
        time: '4 months',
        quote: 'I spent my free time getting really good at prompting. Built a portfolio, shared it online, and a startup reached out. No degree, no coding — just creativity and persistence.',
        color: Color(0xFF10B981),
      ),
      (
        name: 'Priya M.',
        before: 'Accountant',
        after: 'AI Consultant — 3x her old salary',
        time: '6 months',
        quote: 'I already had domain expertise — accounting. I just learned how AI applies to finance. Now I help firms automate their workflows. My industry knowledge was the real advantage.',
        color: Color(0xFFF59E0B),
      ),
    ];

    return Column(children: stories.map((s) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Name + transition
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              shape: BoxShape.circle),
            child: Center(child: Text(
              s.name.substring(0, 1),
              style: GoogleFonts.sourceSerif4(
                fontSize: 16, fontWeight: FontWeight.w700, color: s.color),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(s.name, style: GoogleFonts.sourceSerif4(
            fontSize: 16, fontWeight: FontWeight.w700, color: t.primary))),
          _tag('${s.time}', s.color),
        ]),
        const SizedBox(height: 8),
        // Before → After
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: s.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(child: Text(s.before, style: GoogleFonts.inter(
              fontSize: 12, color: t.secondary))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, size: 14, color: s.color),
            ),
            Expanded(child: Text(s.after, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: s.color))),
          ]),
        ),
        const SizedBox(height: 10),
        // Quote
        Text(
          '"${s.quote}"',
          style: GoogleFonts.sourceSerif4(
            fontSize: 13, color: t.primary.withValues(alpha: 0.8),
            fontStyle: FontStyle.italic, height: 1.55),
        ),
      ]),
    )).toList());
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Accordion card — reusable collapsible section
// ═════════════════════════════════════════════════════════════════════════════
class _AccordionCard extends StatefulWidget {
  final AppTheme theme;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final bool initiallyExpanded;
  final Widget child;

  const _AccordionCard({
    required this.theme,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
    this.badge,
    this.initiallyExpanded = false,
  });

  @override
  State<_AccordionCard> createState() => _AccordionCardState();
}

class _AccordionCardState extends State<_AccordionCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _ctrl;
  late Animation<double> _expandAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = !_expanded;
      _expanded ? _ctrl.forward() : _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? widget.color.withValues(alpha: 0.3) : t.divider,
          width: _expanded ? 1 : 0.5,
        ),
        boxShadow: _expanded
            ? [BoxShadow(
                color: widget.color.withValues(alpha: 0.06),
                blurRadius: 12, offset: const Offset(0, 3))]
            : null,
      ),
      child: Column(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: _expanded
                ? BoxDecoration(
                    color: widget.color.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)))
                : null,
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9)),
                child: Icon(widget.icon, size: 18, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: GoogleFonts.sourceSerif4(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: t.primary, letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(widget.subtitle, style: GoogleFonts.inter(
                    fontSize: 11, color: t.muted)),
                ],
              )),
              if (widget.badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(widget.badge!, style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: widget.color)),
                ),
                const SizedBox(width: 6),
              ],
              RotationTransition(
                turns: _rotateAnim,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 22, color: _expanded ? widget.color : t.muted),
              ),
            ]),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: Column(children: [
            Divider(height: 1, color: t.divider.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: widget.child,
            ),
          ]),
        ),
      ]),
    );
  }
}

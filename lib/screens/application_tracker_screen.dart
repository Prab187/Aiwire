import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/application_tracker_service.dart';

class ApplicationTrackerScreen extends StatefulWidget {
  final AppTheme theme;
  const ApplicationTrackerScreen({super.key, required this.theme});

  @override
  State<ApplicationTrackerScreen> createState() => _ApplicationTrackerScreenState();
}

class _ApplicationTrackerScreenState extends State<ApplicationTrackerScreen>
    with SingleTickerProviderStateMixin {
  List<TrackedApplication> _all = [];
  bool _loading = true;
  late TabController _tabCtrl;

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await ApplicationTrackerService.all();
    if (mounted) setState(() { _all = all; _loading = false; });
  }

  List<TrackedApplication> _filtered(AppStatus status) =>
      _all.where((a) => a.status == status).toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  Color _statusColor(AppStatus s) {
    switch (s) {
      case AppStatus.saved: return const Color(0xFF6B7280);
      case AppStatus.applied: return const Color(0xFF3B82F6);
      case AppStatus.interviewing: return const Color(0xFFF59E0B);
      case AppStatus.offer: return const Color(0xFF10B981);
      case AppStatus.rejected: return const Color(0xFFEF4444);
    }
  }

  void _showAppDetail(TrackedApplication app) {
    HapticFeedback.lightImpact();
    final notesCtrl = TextEditingController(text: app.notes);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(
                width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: t.muted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2)))),
              Text(app.jobTitle, style: GoogleFonts.sourceSerif4(
                fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
              const SizedBox(height: 4),
              Text(app.company, style: GoogleFonts.inter(fontSize: 14, color: t.secondary)),
              if (app.location != null) ...[
                const SizedBox(height: 4),
                Text(app.location!, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
              ],
              const SizedBox(height: 18),
              Text('Status', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: t.muted, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: AppStatus.values.map((s) {
                final selected = app.status == s;
                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    app.status = s;
                    if (s == AppStatus.applied && app.appliedAt == null) {
                      app.appliedAt = DateTime.now().toIso8601String();
                    }
                    if (s == AppStatus.interviewing && app.interviewAt == null) {
                      app.interviewAt = DateTime.now().toIso8601String();
                    }
                    await ApplicationTrackerService.update(app);
                    setSheet(() {});
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _statusColor(s) : t.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? _statusColor(s) : t.divider)),
                    child: Text(s.label, style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : t.secondary)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 20),
              Text('Notes', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: t.muted, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 14, color: t.primary),
                decoration: InputDecoration(
                  hintText: 'Recruiter contact, follow-up date, interview prep notes...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: t.muted),
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
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (v) async {
                  app.notes = v;
                  await ApplicationTrackerService.update(app);
                },
              ),
              const SizedBox(height: 20),
              Row(children: [
                if (app.applyUrl != null && app.applyUrl!.isNotEmpty)
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(app.applyUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: t.primary, borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('Open Job', style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: t.background))),
                    ),
                  )),
                if (app.applyUrl != null) const SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ApplicationTrackerService.remove(app.id);
                    if (mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444), size: 18),
                  ),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
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
        title: Text('Job Tracker', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: t.primary,
              unselectedLabelColor: t.muted,
              indicatorColor: t.primary,
              indicatorWeight: 1.5,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              tabs: AppStatus.values.map((s) {
                final count = _filtered(s).length;
                return Tab(text: '${s.label}${count > 0 ? "  $count" : ""}');
              }).toList(),
            ),
            Divider(height: 1, color: t.divider),
          ]),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
          : TabBarView(
              controller: _tabCtrl,
              children: AppStatus.values.map((s) {
                final list = _filtered(s);
                if (list.isEmpty) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.work_outline_rounded, size: 44,
                        color: t.muted.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No ${s.label.toLowerCase()} jobs yet', style: GoogleFonts.sourceSerif4(
                        fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
                      const SizedBox(height: 4),
                      Text(_emptyHint(s), textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                    ]),
                  ));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AppCard(
                    app: list[i],
                    theme: t,
                    statusColor: _statusColor(list[i].status),
                    onTap: () => _showAppDetail(list[i]),
                  ),
                );
              }).toList(),
            ),
    );
  }

  String _emptyHint(AppStatus s) {
    switch (s) {
      case AppStatus.saved: return 'Tap the bookmark icon on any job to save it here';
      case AppStatus.applied: return 'Mark a job as applied to track follow-ups';
      case AppStatus.interviewing: return 'Move applied jobs here when you get an interview';
      case AppStatus.offer: return 'Celebrate offers here ';
      case AppStatus.rejected: return 'Track rejections to learn and improve';
    }
  }
}

class _AppCard extends StatelessWidget {
  final TrackedApplication app;
  final AppTheme theme;
  final Color statusColor;
  final VoidCallback onTap;
  const _AppCard({required this.app, required this.theme,
    required this.statusColor, required this.onTap});

  String _relativeTime(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 7) return '${(diff.inDays / 7).round()}w ago';
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      return 'just now';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.business_center_outlined, size: 18, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.jobTitle, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: t.primary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(app.company, style: GoogleFonts.inter(fontSize: 12, color: t.secondary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(app.status.label, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          if (app.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(app.notes, style: GoogleFonts.inter(
              fontSize: 12, color: t.muted, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Row(children: [
            if (app.location != null) ...[
              Icon(Icons.location_on_outlined, size: 11, color: t.muted),
              const SizedBox(width: 3),
              Flexible(child: Text(app.location!, style: GoogleFonts.inter(
                fontSize: 11, color: t.muted), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
            ],
            if (app.salaryRange != null) ...[
              Text(app.salaryRange!, style: GoogleFonts.inter(
                fontSize: 11, color: t.muted, fontWeight: FontWeight.w500)),
            ],
            const Spacer(),
            Text(_relativeTime(app.savedAt), style: GoogleFonts.inter(
              fontSize: 10, color: t.muted)),
          ]),
        ]),
      ),
    );
  }
}

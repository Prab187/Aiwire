import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/event.dart';
import '../services/events_service.dart';

class EventsHubScreen extends StatefulWidget {
  final AppTheme theme;
  const EventsHubScreen({super.key, required this.theme});

  @override
  State<EventsHubScreen> createState() => _EventsHubScreenState();
}

class _EventsHubScreenState extends State<EventsHubScreen> {
  List<AIEvent> _allEvents = [];
  bool _loading = true;

  String _modeFilter = 'All';
  String _typeFilter = 'All';
  String _dateFilter = 'All Dates';
  String _searchQuery = '';
  bool _calendarView = false;
  final _searchCtrl = TextEditingController();

  AppTheme get t => widget.theme;

  bool get _hasActiveFilter =>
      _modeFilter != 'All' || _typeFilter != 'All' || _dateFilter != 'All Dates';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final events = await EventsService.fetchEvents();
    if (mounted) setState(() { _allEvents = events; _loading = false; });
  }

  List<AIEvent> get _filtered {
    final now = DateTime.now();
    return _allEvents.where((e) {
      if (_modeFilter == 'Online' && e.format != 'Virtual') return false;
      if (_modeFilter == 'In-Person' && e.format == 'Virtual') return false;
      if (_typeFilter != 'All') {
        if (_typeFilter == 'Round Table' && !e.type.toLowerCase().contains('round')) return false;
        if (_typeFilter == 'Podcast' && !e.type.toLowerCase().contains('podcast') &&
            !e.title.toLowerCase().contains('podcast')) return false;
        if (_typeFilter != 'Round Table' && _typeFilter != 'Podcast' && e.type != _typeFilter) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!'${e.title} ${e.organizer} ${e.description}'.toLowerCase().contains(q)) return false;
      }
      try {
        final d = DateTime.parse(e.date);
        if (d.isBefore(DateTime(now.year, now.month, now.day))) return false;
        if (_dateFilter == 'This Week' && d.difference(now).inDays > 7) return false;
        if (_dateFilter == 'This Month' && d.difference(now).inDays > 30) return false;
      } catch (_) {}
      return true;
    }).toList();
  }

  Map<String, List<AIEvent>> get _grouped {
    final map = <String, List<AIEvent>>{};
    for (final e in _filtered) {
      final key = e.date.length >= 10 ? e.date.substring(0, 10) : e.date;
      map.putIfAbsent(key, () => []).add(e);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  void _showFilterSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: t.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(
              width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: t.muted.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2)),
            )),

            // Header
            Row(children: [
              Text('Filters', style: GoogleFonts.sourceSerif4(
                fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
              const Spacer(),
              if (_hasActiveFilter)
                GestureDetector(
                  onTap: () {
                    setModalState(() {});
                    setState(() { _modeFilter = 'All'; _typeFilter = 'All'; _dateFilter = 'All Dates'; });
                  },
                  child: Text('Reset', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500, color: t.accent)),
                ),
            ]),
            const SizedBox(height: 20),

            // Mode
            Text('Format', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: t.muted, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: ['All', 'Online', 'In-Person', 'Hybrid'].map((m) =>
              _filterOption(m, _modeFilter == m, () {
                setModalState(() {});
                setState(() => _modeFilter = m);
              }),
            ).toList()),
            const SizedBox(height: 20),

            // Type
            Text('Type', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: t.muted, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              'All', 'Conference', 'Webinar', 'Seminar', 'Workshop',
              'Round Table', 'Podcast', 'Meetup',
            ].map((ty) =>
              _filterOption(ty, _typeFilter == ty, () {
                setModalState(() {});
                setState(() => _typeFilter = ty);
              }),
            ).toList()),
            const SizedBox(height: 20),

            // Date
            Text('When', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: t.muted, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: ['All Dates', 'This Week', 'This Month'].map((d) =>
              _filterOption(d, _dateFilter == d, () {
                setModalState(() {});
                setState(() => _dateFilter = d);
              }),
            ).toList()),
            const SizedBox(height: 24),

            // Apply button
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(
                  'Show ${_filtered.length} events',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: t.background))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _filterOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? t.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? t.primary : t.divider)),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? t.background : t.secondary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _filtered;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Events', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _calendarView ? Icons.view_list_rounded : Icons.calendar_month_rounded,
              color: t.primary, size: 20),
            onPressed: () => setState(() => _calendarView = !_calendarView),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: Column(children: [
        // Search + Filter button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(color: t.primary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search events...',
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
              onChanged: (v) => setState(() => _searchQuery = v),
            )),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _hasActiveFilter ? t.primary : t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _hasActiveFilter ? t.primary : t.divider)),
                child: Stack(children: [
                  Center(child: Icon(Icons.tune_rounded,
                    size: 20,
                    color: _hasActiveFilter ? t.background : t.muted)),
                  if (_hasActiveFilter)
                    Positioned(top: 6, right: 6, child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _hasActiveFilter ? t.primary : t.surface, width: 1.5)),
                    )),
                ]),
              ),
            ),
          ]),
        ),

        // Active filter summary
        if (_hasActiveFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Text(
                [
                  if (_modeFilter != 'All') _modeFilter,
                  if (_typeFilter != 'All') _typeFilter,
                  if (_dateFilter != 'All Dates') _dateFilter,
                ].join(' · '),
                style: GoogleFonts.inter(fontSize: 12, color: t.accent, fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              Text('· ${events.length} results', style: GoogleFonts.inter(
                fontSize: 12, color: t.muted)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _modeFilter = 'All'; _typeFilter = 'All'; _dateFilter = 'All Dates';
                }),
                child: Text('Clear', style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted,
                  decoration: TextDecoration.underline,
                  decorationColor: t.muted)),
              ),
            ]),
          ),

        // Content
        Expanded(
          child: _loading
            ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
            : events.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.event_busy_rounded, size: 44, color: t.muted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('No events found', style: GoogleFonts.sourceSerif4(
                    fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
                  const SizedBox(height: 4),
                  Text('Try different filters', style: GoogleFonts.inter(
                    fontSize: 13, color: t.muted)),
                ]))
              : RefreshIndicator(
                  color: t.primary, backgroundColor: t.surface,
                  onRefresh: _loadEvents,
                  child: _calendarView ? _buildCalendarView() : _buildListView(events),
                ),
        ),
      ]),
    );
  }

  Widget _buildListView(List<AIEvent> events) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _EventCard(event: events[i], theme: t),
    );
  }

  Widget _buildCalendarView() {
    final grouped = _grouped;
    if (grouped.isEmpty) return const SizedBox();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final dateKey = grouped.keys.elementAt(i);
        final dayEvents = grouped[dateKey]!;
        final dateLabel = _formatDateHeader(dateKey);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(dateLabel, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: t.primary)),
              ),
              const SizedBox(width: 8),
              Text('${dayEvents.length} event${dayEvents.length > 1 ? "s" : ""}',
                style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
            ]),
          ),
          ...dayEvents.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _EventCard(event: e, theme: t),
          )),
        ]);
      },
    );
  }

  String _formatDateHeader(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;

      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

      if (diff == 0) return 'Today · ${months[d.month - 1]} ${d.day}';
      if (diff == 1) return 'Tomorrow · ${months[d.month - 1]} ${d.day}';
      return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ── Event Card ─────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final AIEvent event;
  final AppTheme theme;
  const _EventCard({required this.event, required this.theme});

  Color get _formatColor {
    if (event.format == 'Virtual') return const Color(0xFF3B82F6);
    if (event.format == 'In-Person') return const Color(0xFF10B981);
    return const Color(0xFFF59E0B);
  }

  IconData get _typeIcon {
    switch (event.type.toLowerCase()) {
      case 'webinar': return Icons.videocam_outlined;
      case 'seminar': return Icons.school_outlined;
      case 'workshop': return Icons.build_outlined;
      case 'meetup': return Icons.groups_outlined;
      case 'podcast': return Icons.podcasts_outlined;
      default: return Icons.event_outlined;
    }
  }

  String? _countdown() {
    try {
      final d = DateTime.parse(event.date);
      final days = d.difference(DateTime.now()).inDays;
      if (days < 0 || days > 90) return null;
      if (days == 0) return 'Today';
      if (days == 1) return 'Tomorrow';
      if (days < 7) return 'In $days days';
      return 'In ${(days / 7).round()}w';
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final cd = _countdown();
    String dateDisplay = event.date;
    try {
      final d = DateTime.parse(event.date);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      dateDisplay = '${m[d.month - 1]} ${d.day}';
    } catch (_) {}

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (event.registrationUrl != null) {
          final uri = Uri.parse(event.registrationUrl!);
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
          // Badges row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _formatColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(event.format == 'Virtual' ? Icons.wifi_rounded : Icons.location_on_outlined,
                  size: 10, color: _formatColor),
                const SizedBox(width: 3),
                Text(event.format, style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _formatColor)),
              ]),
            ),
            const SizedBox(width: 6),
            Icon(_typeIcon, size: 12, color: t.muted),
            const SizedBox(width: 3),
            Text(event.type, style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
            const Spacer(),
            if (cd != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
              child: Text(cd, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
            ),
          ]),
          const SizedBox(height: 10),

          Text(event.title, style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600, color: t.primary),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(event.organizer, style: GoogleFonts.inter(fontSize: 12, color: t.secondary)),
          const SizedBox(height: 10),

          // Topics
          if (event.topics.isNotEmpty)
            Wrap(spacing: 5, runSpacing: 5, children: event.topics.take(3).map((topic) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: t.background, borderRadius: BorderRadius.circular(4)),
                child: Text(topic, style: GoogleFonts.inter(
                  fontSize: 10, color: t.secondary, fontWeight: FontWeight.w500)),
              )).toList()),
          const SizedBox(height: 10),

          // Bottom meta
          Row(children: [
            Text(dateDisplay, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(width: 8),
            Text(event.isFree ? 'Free' : (event.price ?? 'Paid'), style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: event.isFree ? t.accent : t.primary)),
            const Spacer(),
            if (event.location != null && event.format != 'Virtual') ...[
              Icon(Icons.location_on_outlined, size: 12, color: t.muted),
              const SizedBox(width: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Text(event.location!, style: GoogleFonts.inter(
                  fontSize: 11, color: t.muted), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
            ],
            GestureDetector(
              onTap: () async {
                final url = _calUrl();
                if (url.isNotEmpty) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Icon(Icons.calendar_today_rounded, size: 14, color: t.secondary),
            ),
          ]),
        ]),
      ),
    );
  }

  String _calUrl() {
    try {
      final d = DateTime.parse(event.date);
      final ds = '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
      return 'https://calendar.google.com/calendar/render?action=TEMPLATE'
          '&text=${Uri.encodeComponent(event.title)}'
          '&dates=$ds/$ds'
          '&details=${Uri.encodeComponent(event.description)}';
    } catch (_) { return ''; }
  }
}

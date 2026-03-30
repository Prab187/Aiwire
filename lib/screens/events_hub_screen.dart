import 'package:flutter/material.dart';
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
  List<AIEvent> _filteredEvents = [];
  bool _loading = true;
  String _typeFilter = 'All';
  String _formatFilter = 'All';
  String _dateFilter = 'All Dates';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  AppTheme get t => widget.theme;

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
    final events = await EventsService.fetchEvents(
      type: _typeFilter, format: _formatFilter);
    _allEvents = events;
    _applyFilters();
    setState(() => _loading = false);
  }

  void _applyFilters() {
    final now = DateTime.now();
    var list = _allEvents.where((event) {
      // Type filter
      if (_typeFilter != 'All' && event.type != _typeFilter) return false;
      // Format filter
      if (_formatFilter != 'All' && event.format != _formatFilter) return false;
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final haystack = '${event.title} ${event.organizer} ${event.description}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();

    // Date filter — exclude past events unless unparseable
    list = list.where((event) {
      DateTime? eventDate;
      try {
        eventDate = DateTime.parse(event.date);
      } catch (_) {
        return true; // keep if unparseable
      }
      if (eventDate.isBefore(DateTime(now.year, now.month, now.day))) {
        return false; // exclude past events
      }
      if (_dateFilter == 'This Week') {
        return eventDate.difference(now).inDays <= 7;
      }
      if (_dateFilter == 'This Month') {
        return eventDate.difference(now).inDays <= 30;
      }
      return true;
    }).toList();

    _filteredEvents = list;
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
        title: Text('Events Hub', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(color: t.primary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search events, organizers...',
                hintStyle: GoogleFonts.inter(color: t.muted, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 20),
                filled: true,
                fillColor: t.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _applyFilters();
                });
              },
            ),
          ),
          // Type filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildChip('All', _typeFilter == 'All', () {
                    setState(() { _typeFilter = 'All'; _applyFilters(); }); _loadEvents(); }),
                  _buildChip('Conference', _typeFilter == 'Conference', () {
                    setState(() { _typeFilter = 'Conference'; _applyFilters(); }); _loadEvents(); }),
                  _buildChip('Webinar', _typeFilter == 'Webinar', () {
                    setState(() { _typeFilter = 'Webinar'; _applyFilters(); }); _loadEvents(); }),
                  _buildChip('Workshop', _typeFilter == 'Workshop', () {
                    setState(() { _typeFilter = 'Workshop'; _applyFilters(); }); _loadEvents(); }),
                  _buildChip('Seminar', _typeFilter == 'Seminar', () {
                    setState(() { _typeFilter = 'Seminar'; _applyFilters(); }); _loadEvents(); }),
                  _buildChip('Meetup', _typeFilter == 'Meetup', () {
                    setState(() { _typeFilter = 'Meetup'; _applyFilters(); }); _loadEvents(); }),
                ],
              ),
            ),
          ),
          // Format filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildChip('All Formats', _formatFilter == 'All', () {
                    setState(() { _formatFilter = 'All'; _applyFilters(); }); _loadEvents(); }),
                  _buildChip('Virtual', _formatFilter == 'Virtual', () {
                    setState(() { _formatFilter = 'Virtual'; _applyFilters(); }); _loadEvents(); }),
                  _buildChip('In-Person', _formatFilter == 'In-Person', () {
                    setState(() { _formatFilter = 'In-Person'; _applyFilters(); }); _loadEvents(); }),
                  _buildChip('Hybrid', _formatFilter == 'Hybrid', () {
                    setState(() { _formatFilter = 'Hybrid'; _applyFilters(); }); _loadEvents(); }),
                ],
              ),
            ),
          ),
          // Date filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildChip('All Dates', _dateFilter == 'All Dates', () {
                    setState(() { _dateFilter = 'All Dates'; _applyFilters(); }); }),
                  _buildChip('This Week', _dateFilter == 'This Week', () {
                    setState(() { _dateFilter = 'This Week'; _applyFilters(); }); }),
                  _buildChip('This Month', _dateFilter == 'This Month', () {
                    setState(() { _dateFilter = 'This Month'; _applyFilters(); }); }),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
              ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
              : _filteredEvents.isEmpty
                ? Center(child: Text('No events found', style: GoogleFonts.inter(color: t.muted)))
                : RefreshIndicator(
                    color: t.primary,
                    backgroundColor: t.surface,
                    onRefresh: _loadEvents,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: _filteredEvents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _EventCard(event: _filteredEvents[i], theme: t),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? t.primary.withValues(alpha: 0.2) : t.divider),
          ),
          child: Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? t.primary : t.secondary)),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final AIEvent event;
  final AppTheme theme;

  const _EventCard({required this.event, required this.theme});

  String? _countdownText() {
    try {
      final d = DateTime.parse(event.date);
      final now = DateTime.now();
      final days = d.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (days < 0) return null; // past
      if (days > 90) return null; // too far
      if (days == 0) return 'Today';
      if (days == 1) return 'Tomorrow';
      if (days < 7) return 'In $days days';
      if (days < 30) return 'In ${(days / 7).round()} weeks';
      return 'In ${(days / 30).round()} months';
    } catch (_) {
      return null;
    }
  }

  String _googleCalendarUrl() {
    try {
      final d = DateTime.parse(event.date);
      final dateStr = '${d.year.toString().padLeft(4, '0')}'
          '${d.month.toString().padLeft(2, '0')}'
          '${d.day.toString().padLeft(2, '0')}';
      final title = Uri.encodeComponent(event.title);
      final details = Uri.encodeComponent(event.description);
      return 'https://calendar.google.com/calendar/render?action=TEMPLATE'
          '&text=$title'
          '&dates=$dateStr/$dateStr'
          '&details=$details';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final countdown = _countdownText();

    String dateDisplay = event.date;
    try {
      final d = DateTime.parse(event.date);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      dateDisplay = '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {}

    return GestureDetector(
      onTap: () async {
        if (event.registrationUrl != null) {
          final uri = Uri.parse(event.registrationUrl!);
          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date badge
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(dateDisplay.split(' ').first,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: t.secondary)),
                      Text(dateDisplay.split(' ').length > 1 ? dateDisplay.split(' ')[1].replaceAll(',', '') : '',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: t.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: t.primary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(event.organizer, style: GoogleFonts.inter(
                        fontSize: 13, color: t.secondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(event.type, style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500, color: t.muted)),
                    if (countdown != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(countdown,
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(event.description, style: GoogleFonts.inter(
              fontSize: 13, color: t.muted, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            // Topics
            Wrap(
              spacing: 6, runSpacing: 6,
              children: event.topics.take(4).map((topic) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(topic, style: GoogleFonts.inter(
                  fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
              )).toList(),
            ),
            const SizedBox(height: 12),
            // Meta
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: t.muted),
                const SizedBox(width: 4),
                Flexible(child: Text('$dateDisplay · ${event.time} ${event.timezone}',
                  style: GoogleFonts.inter(fontSize: 12, color: t.muted),
                  overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(event.isFree ? 'Free' : event.price ?? 'Paid',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                    color: t.primary)),
                const SizedBox(width: 10),
                Text(event.format, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                const Spacer(),
                if (event.location != null && event.format != 'Virtual') ...[
                  Icon(Icons.location_on_outlined, size: 13, color: t.muted),
                  const SizedBox(width: 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(event.location!, style: GoogleFonts.inter(
                      fontSize: 11, color: t.muted), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                ],
                if (event.attendeeCount != null) ...[
                  Icon(Icons.people_outline_rounded, size: 13, color: t.muted),
                  const SizedBox(width: 3),
                  Text(_formatNumber(event.attendeeCount!),
                    style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
                ],
              ],
            ),
            // Register + Add to Calendar row
            if (event.registrationUrl != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 13, color: t.accent),
                  const SizedBox(width: 6),
                  Text('Register / Learn more',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                      color: t.accent)),
                  const Spacer(),
                  // Add to calendar
                  GestureDetector(
                    onTap: () async {
                      final url = _googleCalendarUrl();
                      if (url.isNotEmpty) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: t.secondary),
                        const SizedBox(width: 4),
                        Text('Add to calendar',
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w500, color: t.secondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Show calendar link even without registration URL
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final url = _googleCalendarUrl();
                  if (url.isNotEmpty) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: t.secondary),
                    const SizedBox(width: 4),
                    Text('Add to calendar',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500, color: t.secondary)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }
}

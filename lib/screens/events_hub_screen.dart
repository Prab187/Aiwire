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
  List<AIEvent> _events = [];
  bool _loading = true;
  String _typeFilter = 'All';
  String _formatFilter = 'All';

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final events = await EventsService.fetchEvents(
      type: _typeFilter, format: _formatFilter);
    setState(() { _events = events; _loading = false; });
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
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildChip('All', _typeFilter == 'All', () {
                    setState(() => _typeFilter = 'All'); _loadEvents(); }),
                  _buildChip('Conference', _typeFilter == 'Conference', () {
                    setState(() => _typeFilter = 'Conference'); _loadEvents(); }),
                  _buildChip('Webinar', _typeFilter == 'Webinar', () {
                    setState(() => _typeFilter = 'Webinar'); _loadEvents(); }),
                  _buildChip('Workshop', _typeFilter == 'Workshop', () {
                    setState(() => _typeFilter = 'Workshop'); _loadEvents(); }),
                  _buildChip('Seminar', _typeFilter == 'Seminar', () {
                    setState(() => _typeFilter = 'Seminar'); _loadEvents(); }),
                  _buildChip('Meetup', _typeFilter == 'Meetup', () {
                    setState(() => _typeFilter = 'Meetup'); _loadEvents(); }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildChip('All Formats', _formatFilter == 'All', () {
                    setState(() => _formatFilter = 'All'); _loadEvents(); }),
                  _buildChip('Virtual', _formatFilter == 'Virtual', () {
                    setState(() => _formatFilter = 'Virtual'); _loadEvents(); }),
                  _buildChip('In-Person', _formatFilter == 'In-Person', () {
                    setState(() => _formatFilter = 'In-Person'); _loadEvents(); }),
                  _buildChip('Hybrid', _formatFilter == 'Hybrid', () {
                    setState(() => _formatFilter = 'Hybrid'); _loadEvents(); }),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
              ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
              : _events.isEmpty
                ? Center(child: Text('No events found', style: GoogleFonts.inter(color: t.muted)))
                : RefreshIndicator(
                    color: t.primary,
                    backgroundColor: t.surface,
                    onRefresh: _loadEvents,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: _events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _EventCard(event: _events[i], theme: t),
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

  @override
  Widget build(BuildContext context) {
    final t = theme;

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
                Text(event.type, style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w500, color: t.muted)),
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
            if (event.registrationUrl != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 13, color: t.accent),
                  const SizedBox(width: 6),
                  Text('Register / Learn more',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                      color: t.accent)),
                ],
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

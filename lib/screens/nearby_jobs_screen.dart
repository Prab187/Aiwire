import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../services/job_service.dart';
import '../services/location_service.dart';

enum _LocState { idle, locating, loading, results, denied, error }

class NearbyJobsScreen extends StatefulWidget {
  final AppTheme theme;
  const NearbyJobsScreen({super.key, required this.theme});

  @override
  State<NearbyJobsScreen> createState() => _NearbyJobsScreenState();
}

class _NearbyJobsScreenState extends State<NearbyJobsScreen> {
  _LocState _state = _LocState.idle;
  LocationResult? _location;
  List<Job> _jobs = [];
  String _errorMessage = '';
  int _radiusKm = 50;
  bool _includeRemote = true;

  AppTheme get t => widget.theme;

  static const _radii = [25, 50, 100, 0]; // 0 = Nationwide
  static const _radiusLabels = ['25 km', '50 km', '100 km', 'Nationwide'];

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() { _state = _LocState.locating; _errorMessage = ''; });
    try {
      final loc = await LocationService.getCurrentLocation();
      setState(() { _location = loc; _state = _LocState.loading; });
      await _loadJobs(loc);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      final isDenied = msg.toLowerCase().contains('denied') ||
          msg.toLowerCase().contains('permission');
      setState(() {
        _state = isDenied ? _LocState.denied : _LocState.error;
        _errorMessage = msg;
      });
    }
  }

  Future<void> _loadJobs(LocationResult loc) async {
    setState(() => _state = _LocState.loading);
    try {
      final jobs = await JobService.fetchNearbyJobs(
        city: loc.city,
        country: loc.country,
        countryCode: loc.countryCode,
        lat: loc.lat,
        lng: loc.lng,
        radiusKm: _radiusKm,
        includeRemote: _includeRemote,
      );
      setState(() { _jobs = jobs; _state = _LocState.results; });
    } catch (e) {
      setState(() {
        _state = _LocState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
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
        title: Text('Jobs Near You', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        actions: _state == _LocState.results ? [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: t.primary, size: 20),
            onPressed: () => _locate(),
          ),
        ] : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: switch (_state) {
          _LocState.idle     => _buildIdle(),
          _LocState.locating => _buildLocating(),
          _LocState.loading  => _buildLoading(),
          _LocState.results  => _buildResults(),
          _LocState.denied   => _buildDenied(),
          _LocState.error    => _buildError(),
        },
      ),
    );
  }

  // ── Idle ──────────────────────────────────────────────────────────────────
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
              child: Icon(Icons.location_on_rounded, size: 36, color: t.primary),
            ),
            const SizedBox(height: 24),
            Text('Find Jobs Near You', style: GoogleFonts.sourceSerif4(
              fontSize: 24, fontWeight: FontWeight.w700, color: t.primary)),
            const SizedBox(height: 12),
            Text(
              'We\'ll detect your location and find AI/ML jobs in your city and nearby.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: t.muted, height: 1.5),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _locate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location_rounded, color: t.background, size: 18),
                    const SizedBox(width: 8),
                    Text('Use My Location', style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: t.background)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Locating ──────────────────────────────────────────────────────────────
  Widget _buildLocating() {
    return Center(
      key: const ValueKey('locating'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: t.primary, strokeWidth: 1.5),
            const SizedBox(height: 24),
            Text('Detecting your location…', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 8),
            Text('This takes just a moment', style: GoogleFonts.inter(
              fontSize: 13, color: t.muted)),
          ],
        ),
      ),
    );
  }

  // ── Loading jobs ──────────────────────────────────────────────────────────
  Widget _buildLoading() {
    final loc = _location;
    return Center(
      key: const ValueKey('loading'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: t.primary, strokeWidth: 1.5),
            const SizedBox(height: 24),
            Text('Searching jobs…', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
            if (loc != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: t.muted),
                  const SizedBox(width: 4),
                  Text(loc.displayName, style: GoogleFonts.inter(
                    fontSize: 13, color: t.muted)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────
  Widget _buildResults() {
    final loc = _location!;
    final localJobs = _jobs.where((j) =>
      j.location.toLowerCase().contains(loc.city.toLowerCase()) ||
      j.location.toLowerCase().contains(loc.country.toLowerCase())).length;
    final remoteJobs = _jobs.length - localJobs;

    return Column(
      key: const ValueKey('results'),
      children: [
        // Location header card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.divider, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.location_on_rounded, color: t.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.displayName, style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: t.primary)),
                      const SizedBox(height: 2),
                      Text(
                        '${loc.lat.toStringAsFixed(4)}° N, ${loc.lng.toStringAsFixed(4)}° E',
                        style: GoogleFonts.inter(fontSize: 11, color: t.muted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _locate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 13, color: t.secondary),
                        const SizedBox(width: 4),
                        Text('Refresh', style: GoogleFonts.inter(
                          fontSize: 12, color: t.secondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Radius filter
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _radii.length + 1,
            itemBuilder: (_, i) {
              if (i < _radii.length) {
                final r = _radii[i];
                final active = _radiusKm == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _radiusKm = r);
                      _loadJobs(loc);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? t.primary.withValues(alpha: 0.2) : t.divider),
                      ),
                      child: Text(_radiusLabels[i], style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? t.primary : t.secondary)),
                    ),
                  ),
                );
              } else {
                // Remote toggle
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _includeRemote = !_includeRemote);
                      _loadJobs(loc);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _includeRemote ? t.primary.withValues(alpha: 0.08) : t.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _includeRemote ? t.primary.withValues(alpha: 0.2) : t.divider),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.wifi_rounded, size: 12,
                          color: _includeRemote ? t.primary : t.secondary),
                        const SizedBox(width: 5),
                        Text('+ Remote', style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: _includeRemote ? FontWeight.w600 : FontWeight.w500,
                          color: _includeRemote ? t.primary : t.secondary)),
                      ]),
                    ),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 8),

        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('${_jobs.length} jobs', style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: t.primary)),
              const SizedBox(width: 6),
              Text('·', style: GoogleFonts.inter(color: t.muted)),
              const SizedBox(width: 6),
              Icon(Icons.location_on_outlined, size: 12, color: t.muted),
              const SizedBox(width: 2),
              Text('$localJobs local', style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
              const SizedBox(width: 6),
              Text('·', style: GoogleFonts.inter(color: t.muted)),
              const SizedBox(width: 6),
              Icon(Icons.wifi_rounded, size: 12, color: t.muted),
              const SizedBox(width: 2),
              Text('$remoteJobs remote', style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Job list
        Expanded(
          child: RefreshIndicator(
            color: t.primary,
            backgroundColor: t.surface,
            onRefresh: () => _loadJobs(loc),
            child: _jobs.isEmpty
              ? Center(child: Text('No jobs found nearby', style: GoogleFonts.inter(color: t.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: _jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _NearbyJobCard(
                    job: _jobs[i],
                    theme: t,
                    userCity: loc.city,
                    userCountry: loc.country,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  // ── Denied ────────────────────────────────────────────────────────────────
  Widget _buildDenied() {
    return Center(
      key: const ValueKey('denied'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, size: 52, color: t.muted),
            const SizedBox(height: 20),
            Text('Location Access Needed', style: GoogleFonts.sourceSerif4(
              fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: t.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Open Settings', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: t.background)),
              ),
            ),
          ],
        ),
      ),
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
            Text('Could not get location', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 8),
            Text(_errorMessage, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: t.muted, height: 1.4)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _locate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: t.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Try again', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Job card ─────────────────────────────────────────────────────────────────

class _NearbyJobCard extends StatelessWidget {
  final Job job;
  final AppTheme theme;
  final String userCity;
  final String userCountry;

  const _NearbyJobCard({
    required this.job,
    required this.theme,
    required this.userCity,
    required this.userCountry,
  });

  bool get _isLocal =>
    job.location.toLowerCase().contains(userCity.toLowerCase()) ||
    job.location.toLowerCase().contains(userCountry.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () => _showDetail(context),
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
                // Logo
                _buildLogo(t),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title, style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: t.primary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(job.company, style: GoogleFonts.inter(
                        fontSize: 13, color: t.secondary)),
                    ],
                  ),
                ),
                // Local / Remote badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isLocal
                      ? t.primary.withValues(alpha: 0.08)
                      : t.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _isLocal ? Icons.location_on_rounded : Icons.wifi_rounded,
                      size: 10,
                      color: _isLocal ? t.primary : t.accent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _isLocal ? 'Local' : 'Remote',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: _isLocal ? t.primary : t.accent),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(job.description, style: GoogleFonts.inter(
              fontSize: 13, color: t.muted, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: job.skills.take(4).map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.background, borderRadius: BorderRadius.circular(4)),
                child: Text(s, style: GoogleFonts.inter(
                  fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
              )).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: t.muted),
                const SizedBox(width: 3),
                Flexible(child: Text(job.location, style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(job.type, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                const Spacer(),
                Text(job.salaryRange, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: t.primary)),
              ],
            ),
            // Posted date
            if (job.postedAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_relativeDate(job.postedAt), style: GoogleFonts.inter(
                fontSize: 11, color: t.muted)),
            ],
            if (job.applyUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(job.applyUrl);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('Apply Now', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: t.primary))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(AppTheme t) {
    if (job.companyLogo != null && job.companyLogo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: job.companyLogo!,
          width: 40, height: 40, fit: BoxFit.cover,
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
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: t.primary),
      )),
    );
  }

  void _showDetail(BuildContext context) {
    final t = theme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: t.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(job.title, style: GoogleFonts.sourceSerif4(
              fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
            const SizedBox(height: 4),
            Text(job.company, style: GoogleFonts.inter(fontSize: 15, color: t.secondary)),
            const SizedBox(height: 16),
            Text(job.description, style: GoogleFonts.inter(
              fontSize: 14, color: t.muted, height: 1.6)),
            const SizedBox(height: 16),
            Wrap(spacing: 6, runSpacing: 6, children: job.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: t.background, borderRadius: BorderRadius.circular(4)),
              child: Text(s, style: GoogleFonts.inter(fontSize: 12, color: t.secondary)),
            )).toList()),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: t.muted),
              const SizedBox(width: 4),
              Text(job.location, style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
              const SizedBox(width: 12),
              Text(job.type, style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
              const Spacer(),
              Text(job.salaryRange, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
            ]),
            const SizedBox(height: 20),
            if (job.applyUrl.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(job.applyUrl);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: t.primary, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('Apply Now', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: t.background))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) return '${diff}d ago';
      if (diff < 30) return '${(diff / 7).floor()}w ago';
      return '${(diff / 30).floor()}mo ago';
    } catch (_) {
      return dateStr;
    }
  }
}

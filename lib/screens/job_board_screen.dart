import 'dart:async';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../services/job_service.dart';
import '../services/user_activity_context.dart';

class JobBoardScreen extends StatefulWidget {
  final AppTheme theme;
  final String? initialQuery;
  const JobBoardScreen({super.key, required this.theme, this.initialQuery});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  List<Job> _allJobs = [];
  bool _loading = true;
  String _typeFilter = 'All';
  String _levelFilter = 'All';
  String _salaryFilter = 'Any';
  String _searchQuery = '';
  String _region = 'us';
  String _regionLabel = 'US';
  final _searchController = TextEditingController();
  final Set<String> _savedJobIds = {};
  bool _showSavedOnly = false;
  Timer? _searchDebounce;

  AppTheme get t => widget.theme;

  static const _regionMap = {
    'US': 'us', 'GB': 'gb', 'UK': 'gb', 'CA': 'ca', 'AU': 'au',
    'DE': 'de', 'FR': 'fr', 'IN': 'in', 'NL': 'nl', 'BR': 'br',
    'SG': 'sg', 'NZ': 'nz', 'IT': 'it', 'ES': 'es', 'PL': 'pl',
    'AT': 'at', 'CH': 'ch', 'ZA': 'za', 'RU': 'ru', 'SE': 'se',
  };

  static const _regionLabels = {
    'us': 'US', 'gb': 'UK', 'ca': 'Canada', 'au': 'Australia',
    'de': 'Germany', 'fr': 'France', 'in': 'India', 'nl': 'Netherlands',
    'br': 'Brazil', 'sg': 'Singapore', 'nz': 'New Zealand',
    'it': 'Italy', 'es': 'Spain', 'pl': 'Poland',
    'at': 'Austria', 'ch': 'Switzerland', 'za': 'South Africa',
    'ru': 'Russia', 'se': 'Sweden',
  };

  void _detectRegion() {
    // Fast sync default based on device locale — will be refined by
    // _loadRegionFromPrefs() which is async and reads resume country.
    final locale = ui.PlatformDispatcher.instance.locale;
    final cc = locale.countryCode?.toUpperCase() ?? 'US';
    _region = _regionMap[cc] ?? 'us';
    _regionLabel = _regionLabels[_region] ?? 'Global';
  }

  /// Priority: Resume-scanned country > device locale. Runs async after init.
  Future<void> _loadRegionFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('user_country_code');
      if (savedCode != null && savedCode.isNotEmpty) {
        final lower = savedCode.toLowerCase();
        // Match to our region map
        if (_regionLabels.containsKey(lower)) {
          if (mounted) setState(() {
            _region = lower;
            _regionLabel = _regionLabels[lower] ?? _regionLabel;
          });
          // Reload jobs with the corrected region
          _loadJobs();
        }
      }
    } catch (_) {}
  }

  List<Job> get _filteredJobs {
    var jobs = _allJobs;

    // Salary filter
    if (_salaryFilter != 'Any') {
      final threshold = _salaryThreshold(_salaryFilter);
      if (threshold != null) {
        jobs = jobs.where((job) {
          final salary = job.salaryRange;
          if (salary.toLowerCase().contains('not disclosed') || salary.isEmpty) {
            return true;
          }
          final match = RegExp(r'\d+').firstMatch(salary.replaceAll(',', ''));
          if (match == null) return true;
          var num = int.tryParse(match.group(0) ?? '0') ?? 0;
          if (num < 1000) num = num * 1000;
          return num >= threshold;
        }).toList();
      }
    }

    // Saved filter
    if (_showSavedOnly) {
      jobs = jobs.where((job) => _savedJobIds.contains(job.id)).toList();
    }

    return jobs;
  }

  int? _salaryThreshold(String filter) {
    switch (filter) {
      case '\$50K+': return 50000;
      case '\$100K+': return 100000;
      case '\$150K+': return 150000;
      case '\$200K+': return 200000;
      default: return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _detectRegion();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!;
      _searchController.text = widget.initialQuery!;
    }
    _loadJobs();
    // Refine region using resume-scanned country if available (runs async)
    _loadRegionFromPrefs();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final jobs = await JobService.fetchJobs(
        query: _searchQuery.isEmpty ? null : _searchQuery,
        type: _typeFilter,
        level: _levelFilter,
        country: _region,
      );
      if (!mounted) return;
      setState(() { _allJobs = jobs; _loading = false; });
    } catch (e) {
      // Don't leave UI stuck in loading state on network failure.
      if (!mounted) return;
      setState(() { _allJobs = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayJobs = _filteredJobs;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Find Jobs', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w700, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: t.primary, fontSize: 14),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search jobs, companies, skills...',
                hintStyle: GoogleFonts.inter(color: t.muted, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadJobs();
                        },
                        child: Icon(Icons.close_rounded, color: t.muted, size: 18),
                      )
                    : null,
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
                setState(() => _searchQuery = v);
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                  if (mounted) _loadJobs();
                });
              },
              onSubmitted: (v) {
                _searchDebounce?.cancel();
                setState(() => _searchQuery = v);
                UserActivityContext.recordSearch(v);
                _loadJobs();
              },
            ),
          ),
          // Filters
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(label: _regionLabel, theme: t, active: true, onTap: () => _showFilterSheet('region')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Type: $_typeFilter', theme: t, onTap: () => _showFilterSheet('type')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Level: $_levelFilter', theme: t, onTap: () => _showFilterSheet('level')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Salary: $_salaryFilter', theme: t, onTap: () => _showFilterSheet('salary')),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Saved',
                  theme: t,
                  active: _showSavedOnly,
                  onTap: () => setState(() => _showSavedOnly = !_showSavedOnly),
                ),
                const SizedBox(width: 8),
                _FilterChip(label: '${displayJobs.length} jobs', theme: t, active: true, onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Job list
          Expanded(
            child: _loading
              ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
              : displayJobs.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off_rounded, size: 48, color: t.muted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No jobs found', style: GoogleFonts.sourceSerif4(
                        fontSize: 18, fontWeight: FontWeight.w600, color: t.primary)),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No matches for "$_searchQuery" in $_regionLabel.\nTry different keywords or change region.'
                            : 'No jobs match your filters.\nTry widening the search or changing region.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: t.muted, height: 1.4)),
                      const SizedBox(height: 20),
                      if (_searchQuery.isNotEmpty || _typeFilter != 'All' || _levelFilter != 'All' || _salaryFilter != 'Any')
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _typeFilter = 'All';
                              _levelFilter = 'All';
                              _salaryFilter = 'Any';
                            });
                            _loadJobs();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: t.primary),
                              borderRadius: BorderRadius.circular(8)),
                            child: Text('Clear filters', style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
                          ),
                        ),
                    ]),
                  ))
                : RefreshIndicator(
                    color: t.primary,
                    backgroundColor: t.surface,
                    onRefresh: _loadJobs,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: displayJobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _JobCard(
                        job: displayJobs[i],
                        theme: t,
                        isSaved: _savedJobIds.contains(displayJobs[i].id),
                        onToggleSave: (id) {
                          final job = displayJobs[i];
                          setState(() {
                            if (_savedJobIds.contains(id)) {
                              _savedJobIds.remove(id);
                            } else {
                              _savedJobIds.add(id);
                              // Feed into LLM context
                              UserActivityContext.recordSavedJob(job.title, job.company);
                            }
                          });
                        },
                        onTap: () => _showJobDetail(context, displayJobs[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showJobDetail(BuildContext context, Job job) {
    final t = widget.theme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(
          children: [
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
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _buildLogoWidget(job, t),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.title, style: GoogleFonts.sourceSerif4(
                            fontSize: 18, fontWeight: FontWeight.w700, color: t.primary)),
                          const SizedBox(height: 2),
                          Text(job.company, style: GoogleFonts.inter(
                            fontSize: 14, color: t.secondary)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(Icons.location_on_outlined, size: 14, color: t.muted),
                      const SizedBox(width: 4),
                      Text(job.location, style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                      const SizedBox(width: 12),
                      Text(job.type, style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                      const SizedBox(width: 12),
                      Text(job.salaryRange, style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
                    ]),
                    const SizedBox(height: 16),
                    Text('About the role', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
                    const SizedBox(height: 8),
                    Text(job.description, style: GoogleFonts.inter(
                      fontSize: 13, color: t.muted, height: 1.5)),
                    const SizedBox(height: 16),
                    Text('Skills required', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: job.skills.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s, style: GoogleFonts.inter(
                          fontSize: 12, color: t.secondary, fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    if (job.applyUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(job.applyUrl);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: t.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: Text('Apply Now', style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600, color: t.background))),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoWidget(Job job, AppTheme t) {
    if (job.companyLogo != null && job.companyLogo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: job.companyLogo!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _letterAvatarWidget(job, t, size: 44),
        ),
      );
    }
    return _letterAvatarWidget(job, t, size: 44);
  }

  Widget _letterAvatarWidget(Job job, AppTheme t, {double size = 40}) {
    return Container(
      width: size, height: size,
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

  void _showFilterSheet(String filterType) {
    List<String> options;
    String current;
    String title;

    switch (filterType) {
      case 'region':
        options = ['US', 'UK', 'Canada', 'Australia', 'Germany', 'France', 'India', 'Netherlands', 'Singapore', 'Global'];
        current = _regionLabel;
        title = 'Region';
      case 'type':
        options = ['All', 'Remote', 'Hybrid', 'On-site'];
        current = _typeFilter;
        title = 'Work Type';
      case 'level':
        options = ['All', 'Junior', 'Mid', 'Senior', 'Lead', 'Principal'];
        current = _levelFilter;
        title = 'Experience Level';
      case 'salary':
        options = ['Any', '\$50K+', '\$100K+', '\$150K+', '\$200K+'];
        current = _salaryFilter;
        title = 'Minimum Salary';
      default:
        return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 16),
            ...options.map((o) => ListTile(
              title: Text(o, style: GoogleFonts.inter(color: t.primary, fontSize: 14)),
              trailing: current == o ? Icon(Icons.check_rounded, color: t.accent, size: 20) : null,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  switch (filterType) {
                    case 'region':
                      _regionLabel = o;
                      if (o == 'Global') {
                        _region = 'us';
                      } else {
                        _region = _regionLabels.entries
                            .firstWhere((e) => e.value == o, orElse: () => const MapEntry('us', 'US'))
                            .key;
                      }
                    case 'type': _typeFilter = o;
                    case 'level': _levelFilter = o;
                    case 'salary': _salaryFilter = o;
                  }
                });
                if (filterType != 'salary') _loadJobs();
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final AppTheme theme;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.theme, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? theme.primary.withValues(alpha: 0.08) : theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.divider),
        ),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          color: active ? theme.primary : theme.secondary)),
      ),
    );
  }
}

// ── Relative date helper ──────────────────────────────────────────────────

String _relativeDate(String postedAt) {
  try {
    final posted = DateTime.parse(postedAt);
    final now = DateTime.now();
    final diff = now.difference(posted).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    if (diff < 30) return '${(diff / 7).round()}w ago';
    return '${(diff / 30).round()}mo ago';
  } catch (_) {
    return '';
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final AppTheme theme;
  final bool isSaved;
  final ValueChanged<String> onToggleSave;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.theme,
    required this.isSaved,
    required this.onToggleSave,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
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
                // Company logo
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
                // Bookmark button
                GestureDetector(
                  onTap: () => onToggleSave(job.id),
                  child: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? t.primary : t.muted,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (job.featured)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Featured', style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
                ),
              ),
            const SizedBox(height: 6),
            Text(job.description, style: GoogleFonts.inter(
              fontSize: 13, color: t.muted, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            // Skills
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: job.skills.take(4).map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(s, style: GoogleFonts.inter(
                  fontSize: 11, color: t.secondary, fontWeight: FontWeight.w500)),
              )).toList(),
            ),
            const SizedBox(height: 12),
            // Meta row
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: t.muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(job.location, style: GoogleFonts.inter(fontSize: 12, color: t.muted),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
                const SizedBox(width: 8),
                Text(job.type, style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(job.salaryRange, style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
                ),
                if (job.postedAt.isNotEmpty) ...[
                  Text(_relativeDate(job.postedAt), style: GoogleFonts.inter(
                    fontSize: 11, color: t.muted)),
                ],
              ],
            ),
            if (job.applyUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(job.applyUrl);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.primary, width: 1),
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
        job.company.isNotEmpty ? job.company.substring(0, 1) : '?',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: t.primary),
      )),
    );
  }
}

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../services/firestore_service.dart';
import '../services/job_service.dart';
import '../services/location_service.dart';


class JobBoardScreen extends StatefulWidget {
  final AppTheme theme;
  final String? initialQuery;
  const JobBoardScreen({super.key, required this.theme, this.initialQuery});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

enum _LocState { idle, locating, loading, results, denied, error }

class _JobBoardScreenState extends State<JobBoardScreen> {
  List<Job> _allJobs = [];
  bool _loading = true;
  String _typeFilter = 'All';
  String _levelFilter = 'All';
  String _salaryFilter = 'Any';
  String _dateFilter = 'Any';
  String _sortBy = 'Newest First';
  bool _visaOnly = false;
  String _searchQuery = '';
  bool _showSavedOnly = false;
  bool _searchFocused = false;
  final Set<String> _savedJobIds = {};
  final Map<String, String> _appliedStatus = {}; // id → 'applied' | 'interview'
  final List<String> _recentSearches = [];
  List<String> _userSkills = [];
  bool _matchFilterActive = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  // ── Nearby state ──────────────────────────────────────────────────────────
  _LocState _locState = _LocState.idle;
  LocationResult? _location;
  List<Job> _nearbyJobs = [];
  int _radiusKm = 50;
  bool _includeRemote = true;
  String _locError = '';
  static const _radii = [25, 50, 100, 0];
  static const _radiusLabels = ['25 km', '50 km', '100 km', 'Nationwide'];

  AppTheme get t => widget.theme;

  static const _skillChips = [
    'Python', 'TensorFlow', 'PyTorch', 'NLP', 'LLM',
    'AWS', 'MLOps', 'Kubernetes', 'Computer Vision', 'Spark',
  ];

  static const _sortOptions = ['Newest First', 'Highest Salary', 'Most Relevant'];

  // ── Active filter count ───────────────────────────────────────────────────
  int get _activeFilterCount {
    int count = 0;
    if (_typeFilter != 'All') count++;
    if (_levelFilter != 'All') count++;
    if (_salaryFilter != 'Any') count++;
    if (_dateFilter != 'Any') count++;
    if (_visaOnly) count++;
    if (_matchFilterActive) count++;
    return count;
  }

  // ── Apply all client-side filters + sort ─────────────────────────────────
  List<Job> get _displayJobs {
    var jobs = List<Job>.from(_allJobs);

    // Saved filter
    if (_showSavedOnly) {
      jobs = jobs.where((j) => _savedJobIds.contains(j.id)).toList();
    }

    // Salary filter
    if (_salaryFilter != 'Any') {
      final threshold = _salaryThreshold(_salaryFilter);
      if (threshold != null) {
        jobs = jobs.where((j) {
          final s = j.salaryRange;
          if (s.isEmpty || s.toLowerCase().contains('not disclosed')) return true;
          final m = RegExp(r'\d+').firstMatch(s.replaceAll(',', ''));
          if (m == null) return true;
          var n = int.tryParse(m.group(0) ?? '0') ?? 0;
          if (n < 1000) n *= 1000;
          return n >= threshold;
        }).toList();
      }
    }

    // Date posted filter
    if (_dateFilter != 'Any') {
      final now = DateTime.now();
      jobs = jobs.where((j) {
        if (j.postedAt.isEmpty) return true;
        try {
          final posted = DateTime.parse(j.postedAt);
          final diff = now.difference(posted).inDays;
          if (_dateFilter == 'Today') return diff <= 1;
          if (_dateFilter == 'This Week') return diff <= 7;
          if (_dateFilter == 'This Month') return diff <= 30;
        } catch (_) {}
        return true;
      }).toList();
    }

    // Match filter — only show jobs ≥40% match (when resume scanned)
    if (_matchFilterActive && _userSkills.isNotEmpty) {
      jobs = jobs.where((j) => _matchPercent(j) >= 40).toList();
    }

    // Visa sponsorship filter
    if (_visaOnly) {
      final visaRegex = RegExp(
        r'(visa|sponsor|right.?to.?work|work.?permit|relocation)',
        caseSensitive: false);
      jobs = jobs.where((j) =>
        visaRegex.hasMatch(j.description) || visaRegex.hasMatch(j.title)).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'Highest Salary':
        jobs.sort((a, b) {
          final aVal = _parseSalaryValue(a.salaryRange);
          final bVal = _parseSalaryValue(b.salaryRange);
          return bVal.compareTo(aVal);
        });
      case 'Most Relevant':
        // Featured first, then those with salary disclosed
        jobs.sort((a, b) {
          if (a.featured && !b.featured) return -1;
          if (!a.featured && b.featured) return 1;
          final aHasSalary = !a.salaryRange.contains('Salary not listed');
          final bHasSalary = !b.salaryRange.contains('Salary not listed');
          if (aHasSalary && !bHasSalary) return -1;
          if (!aHasSalary && bHasSalary) return 1;
          return b.postedAt.compareTo(a.postedAt);
        });
      default: // Newest First — already sorted by service
        break;
    }

    return jobs;
  }

  int _parseSalaryValue(String s) {
    final m = RegExp(r'\d+').firstMatch(s.replaceAll(',', ''));
    if (m == null) return 0;
    var n = int.tryParse(m.group(0) ?? '0') ?? 0;
    if (n < 1000) n *= 1000;
    return n;
  }

  int? _salaryThreshold(String f) {
    switch (f) {
      case '50K+': return 50000;
      case '100K+': return 100000;
      case '150K+': return 150000;
      case '200K+': return 200000;
      default: return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery?.isNotEmpty == true) {
      _searchQuery = widget.initialQuery!;
      _searchCtrl.text = widget.initialQuery!;
    }
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    _loadPrefs();
    _loadJobs();
    _locate(); // auto-fetch location in background
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Nearby jobs logic ─────────────────────────────────────────────────────
  Future<void> _locate() async {
    setState(() { _locState = _LocState.locating; _locError = ''; });
    try {
      final loc = await LocationService.getCurrentLocation();
      setState(() { _location = loc; _locState = _LocState.loading; });
      await _loadNearbyJobs(loc);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _locError = msg;
        _locState = msg.toLowerCase().contains('denied') ||
            msg.toLowerCase().contains('permission')
            ? _LocState.denied
            : _LocState.error;
      });
    }
  }

  Future<void> _loadNearbyJobs(LocationResult loc) async {
    setState(() => _locState = _LocState.loading);
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
      setState(() { _nearbyJobs = jobs; _locState = _LocState.results; });
    } catch (e) {
      setState(() {
        _locState = _LocState.error;
        _locError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    final loc = _location;
    final jobs = await FirestoreService.fetchJobs(
      query: _searchQuery.isEmpty ? null : _searchQuery,
      type: _typeFilter,
      level: _levelFilter,
      countryCode: loc?.countryCode ?? '',
      city: loc?.city ?? '',
      country: loc?.country ?? '',
    );
    setState(() { _allJobs = jobs; _loading = false; });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (value == _searchQuery) return;
      _searchQuery = value;
      _loadJobs();
    });
  }

  void _submitSearch(String value) {
    _debounce?.cancel();
    _searchQuery = value;
    if (value.isNotEmpty && !_recentSearches.contains(value)) {
      setState(() {
        _recentSearches.insert(0, value);
        if (_recentSearches.length > 5) _recentSearches.removeLast();
      });
      _savePrefs();
    }
    _searchFocus.unfocus();
    _loadJobs();
  }

  void _clearAllFilters() {
    setState(() {
      _typeFilter = 'All';
      _levelFilter = 'All';
      _salaryFilter = 'Any';
      _dateFilter = 'Any';
      _visaOnly = false;
      _showSavedOnly = false;
      _matchFilterActive = false;
    });
    _loadJobs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('jb_saved_ids') ?? [];
    final recent = prefs.getStringList('jb_recent') ?? [];
    final applied = prefs.getStringList('jb_applied_ids') ?? [];
    final interview = prefs.getStringList('jb_interview_ids') ?? [];
    final skills = prefs.getStringList('user_skills') ?? [];
    if (!mounted) return;
    setState(() {
      _savedJobIds.addAll(saved);
      _recentSearches.clear();
      _recentSearches.addAll(recent.take(5));
      for (final id in applied) _appliedStatus[id] = 'applied';
      for (final id in interview) _appliedStatus[id] = 'interview';
      _userSkills = skills;
    });
  }

  /// How many of the user's skills appear in this job (0–100)
  int _matchPercent(Job job) {
    if (_userSkills.isEmpty) return 0;
    final userLower = _userSkills
        .where((s) => s.length > 1)
        .map((s) => s.toLowerCase())
        .toSet();
    final jobText =
        '${job.title} ${job.description} ${job.skills.join(' ')}'.toLowerCase();
    int matched = 0;
    for (final skill in userLower) {
      if (jobText.contains(skill)) matched++;
    }
    return ((matched / userLower.length) * 100).clamp(0, 100).round();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('jb_saved_ids', _savedJobIds.toList());
    await prefs.setStringList('jb_recent', _recentSearches.toList());
    final applied = _appliedStatus.entries
        .where((e) => e.value == 'applied').map((e) => e.key).toList();
    final interview = _appliedStatus.entries
        .where((e) => e.value == 'interview').map((e) => e.key).toList();
    await prefs.setStringList('jb_applied_ids', applied);
    await prefs.setStringList('jb_interview_ids', interview);
  }

  void _toggleApplied(String id, String status) {
    setState(() {
      if (_appliedStatus[id] == status) {
        _appliedStatus.remove(id);
      } else {
        _appliedStatus[id] = status;
      }
    });
    _savePrefs();
  }

  // ── Nearby section widgets ────────────────────────────────────────────────
  Widget _buildNearbySection() {
    switch (_locState) {
      case _LocState.idle:
        return _nearbyBanner(
          icon: Icons.near_me_rounded,
          text: 'Find jobs near you',
          action: 'Use location',
          onAction: _locate,
        );
      case _LocState.locating:
        return _nearbyBanner(icon: Icons.my_location_rounded, text: 'Detecting your location…');
      case _LocState.loading:
        return _nearbyBanner(
          icon: Icons.search_rounded,
          text: 'Searching near ${_location?.city ?? 'you'}…',
        );
      case _LocState.denied:
      case _LocState.error:
        return _nearbyBanner(
          icon: Icons.location_off_rounded,
          text: _locError.isNotEmpty ? _locError : 'Location unavailable',
          action: _locState == _LocState.denied ? 'Settings' : 'Retry',
          onAction: _locState == _LocState.denied
              ? () => Geolocator.openAppSettings()
              : _locate,
        );
      case _LocState.results:
        final loc = _location!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location + radius bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Icon(Icons.location_on_rounded, size: 13, color: t.primary),
                const SizedBox(width: 4),
                Expanded(child: Text(loc.displayName,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: t.primary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                GestureDetector(
                  onTap: _locate,
                  child: Icon(Icons.refresh_rounded, size: 14, color: t.muted),
                ),
              ]),
            ),
            // Radius chips
            SizedBox(height: 30, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _radii.length + 1,
              itemBuilder: (_, i) {
                if (i < _radii.length) {
                  final r = _radii[i]; final active = _radiusKm == r;
                  return Padding(padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () { setState(() => _radiusKm = r); _loadNearbyJobs(loc); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: active ? t.primary.withValues(alpha: 0.25) : t.divider)),
                        child: Text(_radiusLabels[i], style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? t.primary : t.secondary)),
                      ),
                    ));
                }
                return Padding(padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () { setState(() => _includeRemote = !_includeRemote); _loadNearbyJobs(loc); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _includeRemote ? t.primary.withValues(alpha: 0.08) : t.surface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _includeRemote ? t.primary.withValues(alpha: 0.25) : t.divider)),
                      child: Text('+ Remote', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: _includeRemote ? FontWeight.w600 : FontWeight.w500,
                        color: _includeRemote ? t.primary : t.secondary)),
                    ),
                  ));
              },
            )),
            const SizedBox(height: 8),
            // Nearby job cards horizontal strip
            if (_nearbyJobs.isNotEmpty)
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _nearbyJobs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final j = _nearbyJobs[i];
                    final isLocal = j.location.toLowerCase().contains(loc.city.toLowerCase()) ||
                        j.location.toLowerCase().contains(loc.country.toLowerCase());
                    return GestureDetector(
                      onTap: () => _showJobDetail(context, j),
                      child: Container(
                        width: 190,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.divider, width: 0.5)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            _buildCompanyLogo(j, t, size: 26),
                            const SizedBox(width: 7),
                            Expanded(child: Text(j.company,
                                style: GoogleFonts.inter(fontSize: 11, color: t.muted),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLocal
                                    ? t.primary.withValues(alpha: 0.08)
                                    : t.accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4)),
                              child: Text(isLocal ? 'Local' : 'Remote',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600,
                                      color: isLocal ? t.primary : t.accent)),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Text(j.title, style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600, color: t.primary),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Text(
                            j.salaryRange.isNotEmpty && j.salaryRange != 'Salary not listed'
                                ? j.salaryRange : j.location,
                            style: GoogleFonts.inter(fontSize: 11,
                                fontWeight: FontWeight.w500, color: t.muted),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('No nearby jobs found — try a wider radius',
                    style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
              ),
            const SizedBox(height: 4),
          ],
        );
    }
  }

  Widget _nearbyBanner({
    required IconData icon, required String text,
    String? action, VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.divider, width: 0.5)),
        child: Row(children: [
          Icon(icon, size: 15, color: t.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text,
              style: GoogleFonts.inter(fontSize: 13, color: t.primary))),
          if (action != null && onAction != null) ...[
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: t.primary, borderRadius: BorderRadius.circular(6)),
                child: Text(action, style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: t.background)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = _displayJobs;
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
          fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.sort_rounded, color: t.primary, size: 22),
            onPressed: _showSortSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  style: GoogleFonts.inter(color: t.primary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Job title, company, skill...',
                    hintStyle: GoogleFonts.inter(color: t.muted, fontSize: 15),
                    prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            _searchQuery = '';
                            _loadJobs();
                          },
                          child: Icon(Icons.close_rounded, color: t.muted, size: 18))
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
                      borderSide: BorderSide(color: t.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                  onChanged: (v) {
                    setState(() {}); // refresh clear button
                    _onSearchChanged(v);
                  },
                  onSubmitted: _submitSearch,
                  textInputAction: TextInputAction.search,
                ),
              ),

              // ── Quick skill chips ─────────────────────────────────────────
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _skillChips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final skill = _skillChips[i];
                    final active = _searchQuery.toLowerCase().contains(skill.toLowerCase());
                    return GestureDetector(
                      onTap: () {
                        _searchCtrl.text = skill;
                        _submitSearch(skill);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? t.primary.withValues(alpha: 0.3) : t.divider),
                        ),
                        child: Text(skill, style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? t.primary : t.secondary)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // ── Near Me section ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(children: [
                  Icon(Icons.near_me_rounded, size: 13, color: t.primary),
                  const SizedBox(width: 5),
                  Text('Near Me', style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: t.primary)),
                ]),
              ),
              _buildNearbySection(),
              Divider(height: 1, color: t.divider),
              const SizedBox(height: 8),

              // ── Job count + sort indicator ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_loading)
                      Container(
                        width: 120, height: 16,
                        decoration: BoxDecoration(
                          color: t.divider, borderRadius: BorderRadius.circular(4)),
                      )
                    else
                      Text('${display.length} AI/ML Jobs',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700, color: t.primary)),
                    const Spacer(),
                    if (_sortBy != 'Newest First')
                      GestureDetector(
                        onTap: _showSortSheet,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.swap_vert_rounded, size: 14, color: t.accent),
                          const SizedBox(width: 3),
                          Text(_sortBy, style: GoogleFonts.inter(
                            fontSize: 12, color: t.accent, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    if (_activeFilterCount > 0) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _clearAllFilters,
                        child: Text('Clear all', style: GoogleFonts.inter(
                          fontSize: 12, color: t.accent, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Filter chips row ──────────────────────────────────────────
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // All-in-one Filters chip with badge
                    _FilterBadgeChip(
                      label: 'Filters',
                      theme: t,
                      badgeCount: _activeFilterCount,
                      onTap: _showAllFiltersSheet,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Type: $_typeFilter',
                      theme: t,
                      active: _typeFilter != 'All',
                      onTap: () => _showFilterSheet('type'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Level: $_levelFilter',
                      theme: t,
                      active: _levelFilter != 'All',
                      onTap: () => _showFilterSheet('level'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Posted: $_dateFilter',
                      theme: t,
                      active: _dateFilter != 'Any',
                      onTap: () => _showFilterSheet('date'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Visa \u2713',
                      theme: t,
                      active: _visaOnly,
                      onTap: () {
                        setState(() => _visaOnly = !_visaOnly);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Saved',
                      theme: t,
                      active: _showSavedOnly,
                      onTap: () => setState(() => _showSavedOnly = !_showSavedOnly),
                    ),
                    if (_userSkills.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'My Match 40%+',
                        theme: t,
                        active: _matchFilterActive,
                        onTap: () => setState(() => _matchFilterActive = !_matchFilterActive),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Job list ──────────────────────────────────────────────────
              Expanded(
                child: _loading
                  ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
                  : display.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: t.primary,
                        backgroundColor: t.surface,
                        onRefresh: _loadJobs,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          itemCount: display.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final mp = _matchPercent(display[i]);
                            return _JobCard(
                              job: display[i],
                              theme: t,
                              isSaved: _savedJobIds.contains(display[i].id),
                              appliedStatus: _appliedStatus[display[i].id],
                              matchPercent: _userSkills.isNotEmpty ? mp : null,
                              onToggleSave: (id) {
                                setState(() {
                                  if (_savedJobIds.contains(id)) _savedJobIds.remove(id);
                                  else _savedJobIds.add(id);
                                });
                                _savePrefs();
                              },
                              onTap: () => _showJobDetail(context, display[i]),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),

          // ── Recent searches overlay ───────────────────────────────────────
          if (_searchFocused && _searchCtrl.text.isEmpty && _recentSearches.isNotEmpty)
            Positioned(
              top: 60,
              left: 16, right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                color: t.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(children: [
                        Text('Recent', style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: t.muted)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _recentSearches.clear()),
                          child: Text('Clear', style: GoogleFonts.inter(
                            fontSize: 12, color: t.accent)),
                        ),
                      ]),
                    ),
                    ..._recentSearches.map((q) => ListTile(
                      dense: true,
                      leading: Icon(Icons.history_rounded, size: 16, color: t.muted),
                      title: Text(q, style: GoogleFonts.inter(fontSize: 14, color: t.primary)),
                      onTap: () {
                        _searchCtrl.text = q;
                        _submitSearch(q);
                      },
                    )),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompanyLogo(Job job, AppTheme t, {double size = 40}) {
    if (job.companyLogo?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: CachedNetworkImage(
          imageUrl: job.companyLogo!, width: size, height: size, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _letterAvatarWidget(job, t, size: size)),
      );
    }
    return _letterAvatarWidget(job, t, size: size);
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final suggestions = ['ML Engineer', 'Data Scientist', 'Remote Python'];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: t.muted),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                ? 'No jobs found for "$_searchQuery"'
                : 'No jobs found',
              style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: t.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Try one of these:', style: GoogleFonts.inter(
              fontSize: 13, color: t.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((s) => GestureDetector(
                onTap: () {
                  _searchCtrl.text = s;
                  _submitSearch(s);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.primary),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s, style: GoogleFonts.inter(
                    fontSize: 13, color: t.primary, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sort bottom sheet ─────────────────────────────────────────────────────
  void _showSortSheet() {
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
            Text('Sort by', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 16),
            ..._sortOptions.map((o) => ListTile(
              dense: true,
              title: Text(o, style: GoogleFonts.inter(color: t.primary, fontSize: 14)),
              trailing: _sortBy == o ? Icon(Icons.check_rounded, color: t.accent, size: 20) : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _sortBy = o);
              },
            )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── All-in-one filters sheet ──────────────────────────────────────────────
  void _showAllFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void apply() {
            Navigator.pop(ctx);
            _loadJobs();
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Filters', style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _clearAllFilters();
                    },
                    child: Text('Reset', style: GoogleFonts.inter(
                      fontSize: 14, color: t.accent)),
                  ),
                ]),
                const SizedBox(height: 20),
                _sheetSection('Work Type', ['All', 'Remote', 'Hybrid', 'On-site'],
                  _typeFilter, (v) { setState(() => _typeFilter = v); setLocal(() {}); }),
                const SizedBox(height: 16),
                _sheetSection('Experience Level', ['All', 'Junior', 'Mid', 'Senior', 'Lead', 'Principal'],
                  _levelFilter, (v) { setState(() => _levelFilter = v); setLocal(() {}); }),
                const SizedBox(height: 16),
                _sheetSection('Minimum Salary (local currency)', ['Any', '50K+', '100K+', '150K+', '200K+'],
                  _salaryFilter, (v) { setState(() => _salaryFilter = v); setLocal(() {}); }),
                const SizedBox(height: 16),
                _sheetSection('Date Posted', ['Any', 'Today', 'This Week', 'This Month'],
                  _dateFilter, (v) { setState(() => _dateFilter = v); setLocal(() {}); }),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('Visa Sponsorship Only', style: GoogleFonts.inter(
                    fontSize: 14, color: t.primary))),
                  Switch(
                    value: _visaOnly,
                    onChanged: (v) { setState(() => _visaOnly = v); setLocal(() {}); },
                    activeColor: t.primary,
                  ),
                ]),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: apply,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: t.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text('Show Jobs', style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: t.background))),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sheetSection(String title, List<String> options, String current, ValueChanged<String> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: t.secondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: options.map((o) {
            final active = current == o;
            return GestureDetector(
              onTap: () => onSelect(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? t.primary.withValues(alpha: 0.08) : t.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? t.primary.withValues(alpha: 0.3) : t.divider),
                ),
                child: Text(o, style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? t.primary : t.secondary)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Individual filter sheet ───────────────────────────────────────────────
  void _showFilterSheet(String filterType) {
    List<String> options;
    String current;
    String title;

    switch (filterType) {
      case 'type':
        options = ['All', 'Remote', 'Hybrid', 'On-site'];
        current = _typeFilter;
        title = 'Work Type';
      case 'level':
        options = ['All', 'Junior', 'Mid', 'Senior', 'Lead', 'Principal'];
        current = _levelFilter;
        title = 'Experience Level';
      case 'date':
        options = ['Any', 'Today', 'This Week', 'This Month'];
        current = _dateFilter;
        title = 'Date Posted';
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
            Text(title, style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 16),
            ...options.map((o) => ListTile(
              dense: true,
              title: Text(o, style: GoogleFonts.inter(color: t.primary, fontSize: 14)),
              trailing: current == o ? Icon(Icons.check_rounded, color: t.accent, size: 20) : null,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  switch (filterType) {
                    case 'type': _typeFilter = o;
                    case 'level': _levelFilter = o;
                    case 'date': _dateFilter = o;
                  }
                });
                if (filterType != 'date') _loadJobs();
              },
            )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Job detail sheet ──────────────────────────────────────────────────────
  void _showJobDetail(BuildContext context, Job job) {
    final t = widget.theme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final appStatus = _appliedStatus[job.id];
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, ctrl) => Column(
              children: [
                // Drag handle + action icons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (job.applyUrl.isNotEmpty) {
                            await Clipboard.setData(ClipboardData(text: job.applyUrl));
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                content: Text('Link copied'),
                                duration: Duration(seconds: 2)));
                            }
                          }
                        },
                        child: Icon(Icons.link_rounded, size: 20, color: t.muted),
                      ),
                      const Spacer(),
                      Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: t.divider, borderRadius: BorderRadius.circular(2))),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          if (job.applyUrl.isNotEmpty) {
                            SharePlus.instance.share(ShareParams(
                              text: '${job.title} at ${job.company}\n${job.applyUrl}'));
                          }
                        },
                        child: Icon(Icons.share_outlined, size: 20, color: t.muted),
                      ),
                    ],
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
                              Text(job.company, style: GoogleFonts.inter(
                                fontSize: 14, color: t.secondary)),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 14),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          _metaPill(t, Icons.location_on_outlined, job.location),
                          _metaPill(t, Icons.work_outline_rounded, job.type),
                          _metaPill(t, Icons.payments_outlined, job.salaryRange, isSalary: true),
                          _metaPill(t, Icons.bar_chart_rounded, job.level),
                        ]),
                        const SizedBox(height: 16),
                        Text('About the role', style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
                        const SizedBox(height: 8),
                        Text(job.description, style: GoogleFonts.inter(
                          fontSize: 13, color: t.muted, height: 1.55)),
                        const SizedBox(height: 16),
                        Text('Skills required', style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: job.skills.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: t.background, borderRadius: BorderRadius.circular(6)),
                            child: Text(s, style: GoogleFonts.inter(
                              fontSize: 12, color: t.secondary, fontWeight: FontWeight.w500)),
                          )).toList(),
                        ),
                        const SizedBox(height: 20),
                        if (job.applyUrl.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(job.applyUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
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
                        const SizedBox(height: 10),
                        // Track application status
                        Row(children: [
                          Expanded(child: _trackButton(
                            label: appStatus == 'applied' ? 'Applied ✓' : 'I Applied',
                            icon: appStatus == 'applied'
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                            active: appStatus == 'applied',
                            activeColor: const Color(0xFF16A34A),
                            activeBg: const Color(0xFFDCFCE7),
                            theme: t,
                            onTap: () {
                              _toggleApplied(job.id, 'applied');
                              setSheet(() {});
                            },
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _trackButton(
                            label: appStatus == 'interview' ? 'Interviewing' : 'Interview',
                            icon: appStatus == 'interview'
                              ? Icons.event_available_rounded
                              : Icons.event_outlined,
                            active: appStatus == 'interview',
                            activeColor: const Color(0xFF7C3AED),
                            activeBg: const Color(0xFFEDE9FE),
                            theme: t,
                            onTap: () {
                              _toggleApplied(job.id, 'interview');
                              setSheet(() {});
                            },
                          )),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _trackButton({
    required String label, required IconData icon, required bool active,
    required Color activeColor, required Color activeBg,
    required AppTheme theme, required VoidCallback onTap,
  }) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? activeBg : t.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? activeColor : t.divider)),
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? activeColor : t.muted),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? activeColor : t.secondary)),
        ])),
      ),
    );
  }

  Widget _metaPill(AppTheme t, IconData icon, String label, {bool isSalary = false}) {
    if (label.isEmpty && !isSalary) return const SizedBox.shrink();
    final display = isSalary && (label.isEmpty || label == 'Salary not listed')
        ? 'Salary not listed' : label;
    if (display.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.surface, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.divider, width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: t.muted),
        const SizedBox(width: 5),
        Text(display, style: GoogleFonts.inter(fontSize: 12, color: t.secondary)),
      ]),
    );
  }

  Widget _buildLogoWidget(Job job, AppTheme t) {
    if (job.companyLogo?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: job.companyLogo!, width: 44, height: 44, fit: BoxFit.cover,
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
        borderRadius: BorderRadius.circular(10)),
      child: Center(child: Text(
        job.company.isNotEmpty ? job.company[0] : '?',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: t.primary),
      )),
    );
  }
}

// ── Filter chip with badge ────────────────────────────────────────────────────

class _FilterBadgeChip extends StatelessWidget {
  final String label;
  final AppTheme theme;
  final int badgeCount;
  final VoidCallback onTap;

  const _FilterBadgeChip({
    required this.label, required this.theme,
    required this.badgeCount, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final active = badgeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? t.primary.withValues(alpha: 0.3) : t.divider),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune_rounded, size: 14,
                color: active ? t.primary : t.secondary),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? t.primary : t.secondary)),
            ]),
          ),
          if (active)
            Positioned(
              top: -4, right: -4,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
                child: Center(child: Text('$badgeCount', style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Standard filter chip ──────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final AppTheme theme;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.theme,
    this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.primary.withValues(alpha: 0.08) : t.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? t.primary.withValues(alpha: 0.3) : t.divider),
        ),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          color: active ? t.primary : t.secondary)),
      ),
    );
  }
}

// ── Relative date helper ──────────────────────────────────────────────────────

String _relativeDate(String postedAt) {
  try {
    final posted = DateTime.parse(postedAt);
    final diff = DateTime.now().difference(posted).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    if (diff < 30) return '${(diff / 7).round()}w ago';
    return '${(diff / 30).round()}mo ago';
  } catch (_) { return ''; }
}

bool _isNew(String postedAt) {
  try {
    return DateTime.now().difference(DateTime.parse(postedAt)).inDays <= 1;
  } catch (_) { return false; }
}

// ── Job card ──────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final Job job;
  final AppTheme theme;
  final bool isSaved;
  final String? appliedStatus;
  final int? matchPercent; // null = no resume scanned
  final ValueChanged<String> onToggleSave;
  final VoidCallback onTap;

  const _JobCard({
    required this.job, required this.theme,
    required this.isSaved, required this.onToggleSave, required this.onTap,
    this.appliedStatus, this.matchPercent,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final isNew = _isNew(job.postedAt);
    final mp = matchPercent;
    final isLowMatch = mp != null && mp < 40;
    final isGoodMatch = mp != null && mp >= 40;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isLowMatch ? 0.55 : 1.0,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGoodMatch
              ? const Color(0xFF22C55E).withValues(alpha: 0.4)
              : t.divider,
            width: isGoodMatch ? 1.0 : 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _buildLogo(t),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(job.title, style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: t.primary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (isNew) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text('New', style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: const Color(0xFF16A34A))),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(child: Text(job.company, style: GoogleFonts.inter(
                      fontSize: 13, color: t.secondary))),
                    if (mp != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isGoodMatch
                            ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          isGoodMatch ? '$mp% match' : '$mp% match',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: isGoodMatch
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706))),
                      ),
                    ],
                  ]),
                ],
              )),
              GestureDetector(
                onTap: () => onToggleSave(job.id),
                child: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isSaved ? t.primary : t.muted, size: 22),
              ),
            ]),
            if (job.featured) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4)),
                child: Text('Featured', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
              ),
            ],
            const SizedBox(height: 8),
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
            Row(children: [
              Icon(Icons.location_on_outlined, size: 13, color: t.muted),
              const SizedBox(width: 3),
              Flexible(child: Text(job.location, style: GoogleFonts.inter(
                fontSize: 12, color: t.muted), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(job.type, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
              const Spacer(),
              if (job.postedAt.isNotEmpty)
                Text(_relativeDate(job.postedAt), style: GoogleFonts.inter(
                  fontSize: 11, color: t.muted)),
            ]),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text(
                  job.salaryRange.isNotEmpty && job.salaryRange != 'Salary not listed'
                    ? job.salaryRange : 'Salary not listed',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: job.salaryRange.isNotEmpty && job.salaryRange != 'Salary not listed'
                      ? t.primary : t.muted))),
                if (appliedStatus == 'applied')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text('Applied ✓', style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: const Color(0xFF16A34A))),
                  )
                else if (appliedStatus == 'interview')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text('Interviewing', style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED))),
                  ),
              ],
            ),
            // Low match notice
            if (isLowMatch) ...[
              const SizedBox(height: 6),
              Text('$mp% match · below your 40% threshold',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFFD97706),
                  fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLogo(AppTheme t) {
    if (job.companyLogo?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: job.companyLogo!, width: 40, height: 40, fit: BoxFit.cover,
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
        borderRadius: BorderRadius.circular(10)),
      child: Center(child: Text(
        job.company.isNotEmpty ? job.company[0] : '?',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: t.primary),
      )),
    );
  }
}

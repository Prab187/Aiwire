import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../services/job_service.dart';

class JobBoardScreen extends StatefulWidget {
  final AppTheme theme;
  const JobBoardScreen({super.key, required this.theme});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  List<Job> _jobs = [];
  bool _loading = true;
  String _typeFilter = 'All';
  String _levelFilter = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    final jobs = await JobService.fetchJobs(
      query: _searchQuery.isEmpty ? null : _searchQuery,
      type: _typeFilter,
      level: _levelFilter,
    );
    setState(() { _jobs = jobs; _loading = false; });
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
        title: Text('AI/ML Jobs', style: GoogleFonts.sourceSerif4(
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
              decoration: InputDecoration(
                hintText: 'Search jobs, companies, skills...',
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
              onSubmitted: (v) {
                _searchQuery = v;
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
                _FilterChip(label: 'Type: $_typeFilter', theme: t, onTap: () => _showFilterSheet('type')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Level: $_levelFilter', theme: t, onTap: () => _showFilterSheet('level')),
                const SizedBox(width: 8),
                _FilterChip(label: '${_jobs.length} jobs', theme: t, active: true, onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Job list
          Expanded(
            child: _loading
              ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
              : _jobs.isEmpty
                ? Center(child: Text('No jobs found', style: GoogleFonts.inter(color: t.muted)))
                : RefreshIndicator(
                    color: t.primary,
                    backgroundColor: t.surface,
                    onRefresh: _loadJobs,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _JobCard(job: _jobs[i], theme: t),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(String filterType) {
    final options = filterType == 'type'
      ? ['All', 'Remote', 'Hybrid', 'On-site']
      : ['All', 'Junior', 'Mid', 'Senior', 'Lead', 'Principal'];
    final current = filterType == 'type' ? _typeFilter : _levelFilter;

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
            Text(filterType == 'type' ? 'Work Type' : 'Experience Level',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
            const SizedBox(height: 16),
            ...options.map((o) => ListTile(
              title: Text(o, style: GoogleFonts.inter(color: t.primary, fontSize: 14)),
              trailing: current == o ? Icon(Icons.check_rounded, color: t.accent, size: 20) : null,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  if (filterType == 'type') _typeFilter = o;
                  else _levelFilter = o;
                });
                _loadJobs();
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

class _JobCard extends StatelessWidget {
  final Job job;
  final AppTheme theme;

  const _JobCard({required this.job, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
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
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(
                  job.company.substring(0, 1),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: t.primary),
                )),
              ),
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
              if (job.featured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Featured', style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
                ),
            ],
          ),
          const SizedBox(height: 10),
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
          Text(job.salaryRange, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: t.primary)),
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
    );
  }
}

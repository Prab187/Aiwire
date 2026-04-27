import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/udemy_course.dart';
import '../services/udemy_service.dart';

class UdemyScreen extends StatefulWidget {
  final AppTheme theme;
  const UdemyScreen({super.key, required this.theme});

  @override
  State<UdemyScreen> createState() => _UdemyScreenState();
}

class _UdemyScreenState extends State<UdemyScreen> {
  List<UdemyCourse> _courses = [];
  bool _loading = true;
  String _error = '';
  String _topicFilter = 'AI';

  static const _topics = {
    'AI': 'artificial intelligence',
    'ML': 'machine learning',
    'LLMs': 'large language models',
    'Deep Learning': 'deep learning',
    'Python': 'python AI',
  };

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final query = _topics[_topicFilter] ?? 'artificial intelligence';
      final courses = await UdemyService.fetchAICourses(search: query);
      setState(() { _courses = courses; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
        title: Text('Udemy Courses', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
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
                children: _topics.keys.map((label) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _topicFilter = label);
                      _loadCourses();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _topicFilter == label
                            ? t.primary.withValues(alpha: 0.08)
                            : t.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _topicFilter == label
                              ? t.primary.withValues(alpha: 0.2)
                              : t.divider,
                        ),
                      ),
                      child: Text(label, style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _topicFilter == label
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _topicFilter == label ? t.primary : t.secondary,
                      )),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
                : _error.isNotEmpty
                    ? Center(child: Text('Failed to load courses', style: GoogleFonts.inter(color: t.muted)))
                    : _courses.isEmpty
                        ? Center(child: Text('No courses found', style: GoogleFonts.inter(color: t.muted)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                            itemCount: _courses.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _UdemyCourseCard(course: _courses[i], theme: t),
                          ),
          ),
        ],
      ),
    );
  }
}

class _UdemyCourseCard extends StatelessWidget {
  final UdemyCourse course;
  final AppTheme theme;

  const _UdemyCourseCard({required this.course, required this.theme});

  Future<void> _openCourse() async {
    final uri = Uri.parse(course.url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: _openCourse,
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
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: course.imageUrl.isNotEmpty
                      ? Image.network(
                          course.imageUrl,
                          width: 72, height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _iconFallback(t),
                        )
                      : _iconFallback(t),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: t.primary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(course.instructor, style: GoogleFonts.inter(
                        fontSize: 13, color: t.secondary)),
                    ],
                  ),
                ),
              ],
            ),
            if (course.headline.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(course.headline, style: GoogleFonts.inter(
                fontSize: 13, color: t.muted, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star_rounded, size: 14, color: t.muted),
                const SizedBox(width: 3),
                Text(course.rating.toStringAsFixed(1), style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: t.secondary)),
                const SizedBox(width: 4),
                Text('(${_formatNumber(course.numReviews)})', style: GoogleFonts.inter(
                  fontSize: 12, color: t.muted)),
                const Spacer(),
                Text(course.price, style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: t.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.open_in_new_rounded, size: 14, color: t.accent),
                const SizedBox(width: 6),
                Text('View on Udemy', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: t.accent)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: t.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback(AppTheme t) => Container(
    width: 72, height: 48,
    decoration: BoxDecoration(
      color: t.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.play_circle_outline_rounded, color: t.primary, size: 24),
  );

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }
}

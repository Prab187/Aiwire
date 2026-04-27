import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/talent_profile.dart';
import '../services/talent_pool_service.dart';

class TalentPoolScreen extends StatefulWidget {
  final AppTheme theme;
  const TalentPoolScreen({super.key, required this.theme});

  @override
  State<TalentPoolScreen> createState() => _TalentPoolScreenState();
}

class _TalentPoolScreenState extends State<TalentPoolScreen> {
  List<TalentProfile> _profiles = [];
  bool _loading = true;
  bool _availableOnly = false;

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    final profiles = await TalentPoolService.fetchTalentPool(availableOnly: _availableOnly);
    setState(() { _profiles = profiles; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final stats = TalentPoolService.getPoolStats();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Elite Talent Pool', style: GoogleFonts.sourceSerif4(
          fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.divider),
        ),
      ),
      body: _loading
        ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1.5))
        : CustomScrollView(
            slivers: [
              // Header stats banner
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [t.accent.withValues(alpha: 0.15), t.accent.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text('Top 0.33%', style: GoogleFonts.sourceSerif4(
                        fontSize: 32, fontWeight: FontWeight.w600, color: t.accent)),
                      const SizedBox(height: 4),
                      Text('of the global IT workforce', style: GoogleFonts.inter(
                        fontSize: 14, color: t.secondary)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(label: 'Specialists', value: '~${_formatNumber(stats['elitePoolSize'] as int)}', theme: t),
                          _StatItem(label: 'Publications', value: '${stats['totalPublications']}', theme: t),
                          _StatItem(label: 'Patents', value: '${stats['totalPatents']}', theme: t),
                          _StatItem(label: 'Avg Exp', value: '${(stats['avgExperience'] as double).toStringAsFixed(0)}y', theme: t),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Filter row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Text('${_profiles.length} profiles', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: t.muted)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() => _availableOnly = !_availableOnly);
                          _loadProfiles();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _availableOnly ? t.accent.withValues(alpha: 0.1) : t.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _availableOnly ? t.accent.withValues(alpha: 0.3) : t.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8,
                                color: _availableOnly ? t.accent : t.muted),
                              const SizedBox(width: 6),
                              Text('Available only', style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: _availableOnly ? t.accent : t.secondary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Profile list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _TalentCard(profile: _profiles[i], theme: t),
                  ),
                  childCount: _profiles.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final AppTheme theme;

  const _StatItem({required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: theme.primary)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(
          fontSize: 11, color: theme.muted)),
      ],
    );
  }
}

class _TalentCard extends StatelessWidget {
  final TalentProfile profile;
  final AppTheme theme;

  const _TalentCard({required this.profile, required this.theme});

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
              // Avatar
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(
                  profile.name.split(' ').map((n) => n[0]).take(2).join(),
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: t.accent),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(profile.name, style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600, color: t.primary)),
                        ),
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: profile.isAvailable
                              ? const Color(0xFF4CAF50)
                              : t.muted.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(profile.title, style: GoogleFonts.inter(
                      fontSize: 13, color: t.secondary)),
                    Text('${profile.company} · ${profile.location}',
                      style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Specialization
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(profile.specialization, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w500, color: t.accent)),
          ),
          const SizedBox(height: 10),
          // Skills
          Wrap(
            spacing: 6, runSpacing: 6,
            children: profile.skills.map((s) => Container(
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
              _MetaBadge(icon: Icons.work_outline, text: '${profile.yearsExperience}y exp', theme: t),
              const SizedBox(width: 10),
              _MetaBadge(icon: Icons.article_outlined, text: '${profile.publications} papers', theme: t),
              const SizedBox(width: 10),
              _MetaBadge(icon: Icons.lightbulb_outline, text: '${profile.patents} patents', theme: t),
              const Spacer(),
              // Match score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${profile.matchScore.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: t.accent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppTheme theme;

  const _MetaBadge({required this.icon, required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.muted),
        const SizedBox(width: 3),
        Text(text, style: GoogleFonts.inter(fontSize: 11, color: theme.muted)),
      ],
    );
  }
}

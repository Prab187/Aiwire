import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/article.dart';

import '../widgets/article_card.dart';
import '../widgets/filter_bar.dart';
import '../widgets/shimmer_loading.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import 'bookmarks_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';

const _kModeKey = 'app_theme_mode';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Article> _articles = [];
  List<Article> _filtered = [];
  bool _loading = true;
  String? _error;
  int _bottomIndex = 0;
  SortFilter _sortFilter = SortFilter.latest;
  String _searchQuery = '';
  AppMode _mode = AppMode.dark;
  late AnimationController _modeAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _modeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _modeAnim, curve: Curves.easeInOut);
    SystemChrome.setSystemUIOverlayStyle(AppTheme(_mode).systemUi);
    _loadSavedMode();
    _loadNews();
  }

  Future<void> _loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kModeKey);
    if (saved == null) return;
    final restored = switch (saved) {
      'light' => AppMode.light,
      'dark' => AppMode.dark,
      'kindle' => AppMode.kindle,
      _ => null,
    };
    if (restored != null && mounted && restored != _mode) {
      setState(() => _mode = restored);
      _updateSystemUi();
    }
  }

  Future<void> _saveMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModeKey, _mode.name);
  }

  void _updateSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(AppTheme(_mode).systemUi);
  }

  @override
  void dispose() { _modeAnim.dispose(); super.dispose(); }

  void _cycleMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_mode == AppMode.light) _mode = AppMode.dark;
      else if (_mode == AppMode.dark) _mode = AppMode.kindle;
      else _mode = AppMode.light;
    });
    _updateSystemUi();
    _modeAnim.forward(from: 0);
    _saveMode();
  }

  Future<void> _loadNews() async {
    setState(() { _loading = true; _error = null; });
    try {
      final articles = await FirestoreService.fetchArticles();
      setState(() { _articles = articles; _loading = false; _applyFilter(_sortFilter); });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter(SortFilter filter) {
    setState(() {
      _sortFilter = filter;
      List<Article> sorted = List.from(_articles);
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        sorted = sorted.where((a) =>
          a.title.toLowerCase().contains(q) ||
          (a.description ?? '').toLowerCase().contains(q)).toList();
      }
      switch (filter) {
        case SortFilter.latest:
          sorted.sort((a, b) {
            if (a.publishedAt == null) return 1;
            if (b.publishedAt == null) return -1;
            return DateTime.parse(b.publishedAt!).compareTo(DateTime.parse(a.publishedAt!));
          });
          break;
        case SortFilter.popular:
          sorted.sort((a, b) => (b.description?.length ?? 0).compareTo(a.description?.length ?? 0));
          break;
        case SortFilter.relevant:
          sorted.sort((a, b) => _relevanceScore(b).compareTo(_relevanceScore(a)));
          break;
        case SortFilter.quick:
          sorted = sorted.where((a) => a.readingTime <= 3).toList();
          sorted.sort((a, b) => a.readingTime.compareTo(b.readingTime));
          break;
      }
      _filtered = sorted;
    });
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query);
    _applyFilter(_sortFilter);
  }

  int _relevanceScore(Article a) {
    final keywords = ['ai', 'artificial intelligence', 'llm', 'gpt', 'claude', 'openai', 'anthropic', 'gemini', 'machine learning', 'deep learning'];
    final text = '${a.title} ${a.description ?? ''}'.toLowerCase();
    return keywords.where((k) => text.contains(k)).length;
  }

  void _onNavTap(int i) {
    HapticFeedback.selectionClick();
    setState(() => _bottomIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme(_mode);

    // Tab children — IndexedStack keeps each tab's state alive across switches.
    // Order: 0=Home (Explore/Discover), 1=News, 2=Bookmarks, 3=Profile.
    final tabs = <Widget>[
      DiscoverScreen(theme: t),
      _buildNewsTab(t),
      BookmarksScreen(theme: t),
      ProfileScreen(theme: t),
    ];

    return FadeTransition(
      opacity: Tween<double>(begin: 0.9, end: 1.0).animate(_fadeAnim),
      child: Scaffold(
        backgroundColor: t.background,
        body: IndexedStack(index: _bottomIndex, children: tabs),

        // ── Bottom nav ──────────────────────
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.divider, width: 0.5)),
            color: t.background,
          ),
          child: BottomNavigationBar(
            currentIndex: _bottomIndex,
            onTap: _onNavTap,
            backgroundColor: Colors.transparent, elevation: 0,
            selectedItemColor: t.primary,
            unselectedItemColor: t.muted,
            showSelectedLabels: false, showUnselectedLabels: false,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), activeIcon: Icon(Icons.newspaper_rounded), label: 'News'),
              BottomNavigationBarItem(icon: Icon(Icons.bookmark_border_rounded), activeIcon: Icon(Icons.bookmark_rounded), label: 'Bookmarks'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  /// News tab — extracted from the previous home body so it can live as one
  /// IndexedStack child while Home (index 0) shows the Resume Scanner.
  Widget _buildNewsTab(AppTheme t) {
    return SafeArea(
      child: _loading
        ? ArticleShimmer(theme: t)
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(40),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Something went wrong', style: GoogleFonts.sourceSerif4(
                    fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
                const SizedBox(height: 10),
                Text(_error!, style: GoogleFonts.inter(color: t.muted, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                GestureDetector(onTap: _loadNews,
                  child: Text('Try again', style: GoogleFonts.inter(
                      color: t.accent, fontSize: 14, fontWeight: FontWeight.w500))),
              ])))
          : RefreshIndicator(
              color: t.primary,
              backgroundColor: t.surface,
              onRefresh: _loadNews,
              child: CustomScrollView(
                slivers: [
                  // ── Title (scrolls away) ─────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(children: [
                        GestureDetector(
                          onTap: _cycleMode,
                          child: Text('AIWire',
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 28, fontWeight: FontWeight.w600,
                              color: t.primary)),
                        ),
                        const Spacer(),
                        FilterIcon(selected: _sortFilter, onChanged: _applyFilter,
                            onSearch: _onSearch, theme: t),
                      ]),
                    ),
                  ),
                  // ── Sticky section label ─────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyLabelDelegate(
                      child: Container(
                        color: t.background,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                              child: Row(children: [
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Results for "$_searchQuery"'
                                      : '${_sortFilter.label} Stories',
                                  style: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: t.muted, letterSpacing: 0.3)),
                                if (_searchQuery.isNotEmpty) ...[
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () { setState(() => _searchQuery = ''); _applyFilter(_sortFilter); },
                                    child: Text('Clear', style: GoogleFonts.inter(
                                        fontSize: 13, color: t.muted,
                                        decoration: TextDecoration.underline,
                                        decorationColor: t.muted)),
                                  ),
                                ],
                              ]),
                            ),
                            Divider(height: 1, color: t.divider),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── Articles ─────────────────────
                  _filtered.isEmpty
                    ? SliverFillRemaining(
                        child: Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: t.muted.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text('No stories found', style: GoogleFonts.sourceSerif4(
                              fontSize: 18, fontWeight: FontWeight.w600, color: t.primary)),
                            const SizedBox(height: 6),
                            Text('Try a different search or filter', style: GoogleFonts.inter(
                              fontSize: 13, color: t.muted)),
                          ],
                        )))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => AnimationConfiguration.staggeredList(
                            position: i,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 30,
                              child: FadeInAnimation(
                                child: ArticleCard(article: _filtered[i], theme: t),
                              ),
                            ),
                          ),
                          childCount: _filtered.length,
                        ),
                      ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }
}

// ── Sticky header delegate ───────────────────────────────────────────────────
class _StickyLabelDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyLabelDelegate({required this.child});

  @override double get minExtent => 44;
  @override double get maxExtent => 44;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(_StickyLabelDelegate old) => old.child != child;
}


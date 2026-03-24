import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/article.dart';
import '../services/bookmark_service.dart';
import '../theme/app_theme.dart';
import '../widgets/article_card.dart';

class BookmarksScreen extends StatefulWidget {
  final AppTheme theme;
  const BookmarksScreen({super.key, required this.theme});
  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Article> _bookmarks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final items = await BookmarkService.getBookmarks();
    setState(() { _bookmarks = items.reversed.toList(); _loading = false; });
  }

  Future<void> _remove(Article article) async {
    await BookmarkService.remove(article);
    setState(() => _bookmarks.removeWhere((a) => a.url == article.url));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back, color: t.primary)),
            const SizedBox(width: 16),
            Text('Saved', style: GoogleFonts.sourceSerif4(
                fontSize: 22, fontWeight: FontWeight.w700, color: t.primary)),
          ]),
        ),
        Divider(height: 1, color: t.divider),

        Expanded(child: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1))
          : _bookmarks.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.bookmark_outline_rounded, color: t.muted.withValues(alpha: 0.4), size: 56),
                const SizedBox(height: 20),
                Text('No saved stories', style: GoogleFonts.sourceSerif4(
                    fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
                const SizedBox(height: 8),
                Text('Bookmark articles to read later',
                    style: GoogleFonts.inter(color: t.muted, fontSize: 13)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: _bookmarks.length,
                itemBuilder: (context, index) {
                  final article = _bookmarks[index];
                  return Dismissible(
                    key: Key(article.url),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _remove(article),
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    child: ArticleCard(article: article, theme: t),
                  );
                },
              )),
      ])),
    );
  }
}

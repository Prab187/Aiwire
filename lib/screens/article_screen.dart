import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import '../models/article.dart';
import '../services/ai_service.dart';
import '../services/bookmark_service.dart';
import '../services/history_service.dart';
import '../services/likes_service.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';
import '../theme/app_theme.dart';

class ArticleScreen extends StatefulWidget {
  final Article article;
  final AppTheme theme;
  const ArticleScreen({super.key, required this.article, required this.theme});
  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  String? _aiSummary;
  bool _loadingSummary = true;
  String? _summaryError;
  bool _summaryLocked = false;
  bool _bookmarked = false;
  bool _liked = false;
  int _likeCount = 0;
  double _readProgress = 0;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _checkBookmark();
    _loadLikes();
    HistoryService.add(widget.article);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scrollCtrl.position.maxScrollExtent == 0) return;
    setState(() {
      _readProgress = (_scrollCtrl.offset / _scrollCtrl.position.maxScrollExtent).clamp(0.0, 1.0);
    });
  }

  Future<void> _checkBookmark() async {
    final saved = await BookmarkService.isBookmarked(widget.article.url);
    if (mounted) setState(() => _bookmarked = saved);
  }

  Future<void> _loadLikes() async {
    final liked = await LikesService.isLiked(widget.article.url);
    final count = await LikesService.getCount(widget.article.url);
    if (mounted) setState(() { _liked = liked; _likeCount = count; });
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final nowLiked = await LikesService.toggle(widget.article.url);
    if (nowLiked) await LikesService.incrementCount(widget.article.url);
    final count = await LikesService.getCount(widget.article.url);
    if (mounted) setState(() { _liked = nowLiked; _likeCount = count; });
  }

  Future<void> _toggleBookmark() async {
    HapticFeedback.lightImpact();
    if (_bookmarked) {
      await BookmarkService.remove(widget.article);
    } else {
      await BookmarkService.save(widget.article);
    }
    if (mounted) setState(() => _bookmarked = !_bookmarked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bookmarked ? 'Saved' : 'Removed',
            style: GoogleFonts.inter(fontSize: 13, color: widget.theme.background)),
        backgroundColor: widget.theme.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  Future<void> _share() async {
    await Share.share('${widget.article.title}\n\n${widget.article.url}');
  }

  Future<void> _loadSummary() async {
    setState(() { _loadingSummary = true; _summaryError = null; _summaryLocked = false; });
    final canUse = await SubscriptionService.canUseSummary();
    if (!canUse) {
      if (mounted) setState(() { _summaryLocked = true; _loadingSummary = false; });
      return;
    }
    try {
      final summary = await AIService.summarizeArticle(
        title: widget.article.title,
        description: widget.article.description,
        content: widget.article.content,
        url: widget.article.url,
      );
      await SubscriptionService.recordUsage();
      if (mounted) setState(() { _aiSummary = summary; _loadingSummary = false; });
    } catch (e) {
      if (mounted) setState(() { _summaryError = 'Could not load AI summary'; _loadingSummary = false; });
    }
  }

  void _openPaywall() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaywallScreen(theme: widget.theme, onSubscribed: _loadSummary),
    ));
  }

  Future<void> _openArticle() async {
    final uri = Uri.parse(widget.article.url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildSummaryBlock(String text, AppTheme t) {
    final parts = text.split('Key Insight:');
    final summary = parts[0].trim();
    final insight = parts.length > 1 ? parts[1].trim() : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: t.accent, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 13, color: t.accent),
            const SizedBox(width: 6),
            Text('AI Summary', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: t.accent, letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 10),
          Text(summary, style: GoogleFonts.sourceSerif4(
            fontSize: 16,
            color: t.secondary,
            height: 1.75,
            fontStyle: FontStyle.italic,
          )),
        ]),
      ),

      if (insight != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: t.accent, width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.lightbulb_outline_rounded, size: 13, color: t.accent),
              const SizedBox(width: 6),
              Text('Key Insight', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: t.accent, letterSpacing: 0.3)),
            ]),
            const SizedBox(height: 10),
            Text(insight, style: GoogleFonts.sourceSerif4(
              fontSize: 16,
              color: t.secondary,
              height: 1.75,
              fontStyle: FontStyle.italic,
            )),
          ]),
        ),
      ],
    ]);
  }

  Widget _buildLockedSummary(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: t.divider, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lock_outline_rounded, size: 13, color: t.muted),
          const SizedBox(width: 6),
          Text('AI Summary — Premium',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: t.muted, letterSpacing: 0.3)),
        ]),
        const SizedBox(height: 12),
        Text("You've used your 3 free summaries today.",
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: t.primary, height: 1.5)),
        const SizedBox(height: 4),
        Text('Upgrade for unlimited AI summaries.',
            style: GoogleFonts.inter(fontSize: 13, color: t.muted, height: 1.5)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _openPaywall,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: t.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Upgrade — \$2.99/month',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: t.background)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    SystemChrome.setSystemUIOverlayStyle(t.systemUi);
    final publishedAt = widget.article.publishedAt != null
        ? timeago.format(DateTime.parse(widget.article.publishedAt!))
        : '';

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(children: [

        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 3, color: t.divider,
            child: FractionallySizedBox(
              widthFactor: _readProgress,
              alignment: Alignment.centerLeft,
              child: Container(color: t.accent)))),

        CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: t.background, elevation: 0,
              systemOverlayStyle: t.systemUi,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back, color: t.primary)),
              actions: [
                IconButton(icon: Icon(Icons.share_outlined, color: t.primary), onPressed: _share),
                IconButton(
                  icon: Icon(_bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: _bookmarked ? t.accent : t.primary),
                  onPressed: _toggleBookmark),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0.5),
                child: Divider(height: 0.5, color: t.divider)),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  Row(children: [
                    Container(width: 28, height: 28,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: t.primary),
                      child: Center(child: Text(
                        (widget.article.source ?? 'A')[0].toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: t.background)))),
                    const SizedBox(width: 10),
                    Text(widget.article.source ?? 'AIWire',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: t.primary)),
                  ]),
                  const SizedBox(height: 18),

                  Text(widget.article.title,
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 28, fontWeight: FontWeight.w700,
                      color: t.primary, height: 1.25)),
                  const SizedBox(height: 16),

                  Row(children: [
                    Text(publishedAt, style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                    const SizedBox(width: 6),
                    Text('·', style: TextStyle(color: t.muted)),
                    const SizedBox(width: 6),
                    Text('${widget.article.readingTime} min read',
                        style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                  ]),
                  const SizedBox(height: 20),
                  Divider(color: t.divider),
                  const SizedBox(height: 24),

                  _loadingSummary
                    ? Row(children: [
                        SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(color: t.muted, strokeWidth: 1)),
                        const SizedBox(width: 10),
                        Text('Generating summary...',
                            style: GoogleFonts.inter(color: t.muted, fontSize: 13)),
                      ])
                    : _summaryLocked
                      ? _buildLockedSummary(t)
                      : _summaryError != null
                        ? Row(children: [
                            Text(_summaryError!,
                                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13)),
                            const Spacer(),
                            GestureDetector(onTap: _loadSummary,
                              child: Text('Retry', style: GoogleFonts.inter(
                                  color: t.accent, fontWeight: FontWeight.w500, fontSize: 13))),
                          ])
                        : _buildSummaryBlock(_aiSummary ?? '', t),

                  const SizedBox(height: 40),
                  Divider(color: t.divider),
                  const SizedBox(height: 24),

                  Row(children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(children: [
                        Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 22, color: _liked ? Colors.redAccent : t.muted),
                        const SizedBox(width: 6),
                        Text('$_likeCount', style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                      ]),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: _share,
                      child: Row(children: [
                        Icon(Icons.share_outlined, size: 20, color: t.muted),
                        const SizedBox(width: 6),
                        Text('Share', style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                      ]),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleBookmark,
                      child: Icon(_bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 22, color: _bookmarked ? t.accent : t.muted),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openArticle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primary, foregroundColor: t.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text('Read full article',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

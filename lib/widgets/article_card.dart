import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/article.dart';
import '../screens/article_screen.dart';
import '../theme/app_theme.dart';
import '../services/likes_service.dart';
import '../services/bookmark_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ArticleCard extends StatefulWidget {
  final Article article;
  final AppTheme theme;
  const ArticleCard({super.key, required this.article, required this.theme});
  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> with TickerProviderStateMixin {
  bool _liked = false;
  int _likeCount = 0;
  bool _bookmarked = false;
  late AnimationController _heartAnim;
  late Animation<double> _heartScale;
  late AnimationController _tapAnim;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _heartScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _heartAnim, curve: Curves.elasticOut));
    _tapAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _tapScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _tapAnim, curve: Curves.easeInOut));
    _loadLikes();
    _loadBookmark();
  }

  @override
  void dispose() { _heartAnim.dispose(); _tapAnim.dispose(); super.dispose(); }

  Future<void> _loadLikes() async {
    final liked = await LikesService.isLiked(widget.article.url);
    final count = await LikesService.getCount(widget.article.url);
    if (mounted) setState(() { _liked = liked; _likeCount = count; });
  }

  Future<void> _loadBookmark() async {
    final saved = await BookmarkService.isBookmarked(widget.article.url);
    if (mounted) setState(() => _bookmarked = saved);
  }

  Future<void> _toggleBookmark() async {
    HapticFeedback.lightImpact();
    if (_bookmarked) {
      await BookmarkService.remove(widget.article);
    } else {
      await BookmarkService.save(widget.article);
    }
    if (mounted) setState(() => _bookmarked = !_bookmarked);
  }

  void _showMore(BuildContext context) {
    final t = widget.theme;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: t.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _sheetTile(context, t, Icons.share_outlined, 'Share', () {
            Navigator.pop(context);
            SharePlus.instance.share(ShareParams(
              text: '${widget.article.title}\n\n${widget.article.url}'));
          }),
          _sheetTile(context, t, Icons.open_in_browser_rounded, 'Open in browser', () async {
            Navigator.pop(context);
            final uri = Uri.parse(widget.article.url);
            if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _sheetTile(BuildContext context, AppTheme t, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: t.primary, size: 20),
      title: Text(label, style: GoogleFonts.inter(fontSize: 14, color: t.primary)),
      onTap: onTap,
    );
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    _heartAnim.forward(from: 0);
    final nowLiked = await LikesService.toggle(widget.article.url);
    if (nowLiked) await LikesService.incrementCount(widget.article.url);
    final count = await LikesService.getCount(widget.article.url);
    if (mounted) setState(() { _liked = nowLiked; _likeCount = count; });
  }

  void _onTapDown(TapDownDetails _) => _tapAnim.forward();
  void _onTapUp(TapUpDetails _) => _tapAnim.reverse();
  void _onTapCancel() => _tapAnim.reverse();

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    String publishedAt = '';
    if (widget.article.publishedAt != null) {
      try {
        final published = DateTime.parse(widget.article.publishedAt!);
        final hours = DateTime.now().difference(published).inHours;
        if (hours < 1) {
          final mins = DateTime.now().difference(published).inMinutes;
          publishedAt = '${mins}m ago';
        } else if (hours < 24) {
          publishedAt = '${hours}h ago';
        } else {
          publishedAt = timeago.format(published);
        }
      } catch (_) {}
    }

    return ScaleTransition(
      scale: _tapScale,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: () {
          _tapAnim.reverse();
          Navigator.push(context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => ArticleScreen(article: widget.article, theme: t),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child),
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ));
        },
        child: Container(
          color: t.background,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Author row
            Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.primary),
                child: Center(child: Text(
                  (widget.article.source ?? 'A')[0].toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: t.background),
                )),
              ),
              const SizedBox(width: 7),
              Text(widget.article.source ?? 'AIWire',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: t.primary)),
            ]),
            const SizedBox(height: 8),

            // Title + thumbnail
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  widget.article.title,
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 20, fontWeight: FontWeight.w700, color: t.primary, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                if (widget.article.description != null) ...[
                  const SizedBox(height: 6),
                  Text(widget.article.description!,
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w400, color: t.secondary, height: 1.5),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ])),

              // Thumbnail with Hero
              if (widget.article.urlToImage != null) ...[
                const SizedBox(width: 14),
                Hero(
                  tag: 'img_${widget.article.url}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.article.urlToImage!,
                      width: 80, height: 80, fit: BoxFit.cover,
                      memCacheWidth: 160, memCacheHeight: 160,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (c, u) => Container(width: 80, height: 80, color: t.surface),
                      errorWidget: (c, u, e) => Container(
                        width: 80, height: 80, color: t.surface,
                        child: Icon(Icons.image_outlined, color: t.muted, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 14),

            // Meta row
            Row(children: [
              Text(publishedAt, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
              const Spacer(),
              GestureDetector(
                onTap: _toggleLike,
                child: Row(children: [
                  ScaleTransition(
                    scale: _heartScale,
                    child: Icon(
                      _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 17,
                      color: _liked ? Colors.redAccent : t.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('$_likeCount', style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
                ]),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: _toggleBookmark,
                child: Icon(
                  _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 17,
                  color: _bookmarked ? widget.theme.accent : t.muted,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showMore(context),
                child: Icon(Icons.more_horiz_rounded, size: 17, color: t.muted),
              ),
            ]),
            const SizedBox(height: 16),
            Divider(height: 1, color: t.divider),
          ]),
        ),
      ),
    );
  }
}

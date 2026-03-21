import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/article.dart';
import '../screens/article_screen.dart';
import '../theme/app_theme.dart';
import '../services/likes_service.dart';

class ArticleCard extends StatefulWidget {
  final Article article;
  final AppTheme theme;
  const ArticleCard({super.key, required this.article, required this.theme});
  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> with SingleTickerProviderStateMixin {
  bool _liked = false;
  int _likeCount = 0;
  late AnimationController _heartAnim;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _heartScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _heartAnim, curve: Curves.elasticOut));
    _loadLikes();
  }

  @override
  void dispose() { _heartAnim.dispose(); super.dispose(); }

  Future<void> _loadLikes() async {
    final liked = await LikesService.isLiked(widget.article.url);
    final count = await LikesService.getCount(widget.article.url);
    if (mounted) setState(() { _liked = liked; _likeCount = count; });
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    _heartAnim.forward(from: 0);
    final nowLiked = await LikesService.toggle(widget.article.url);
    if (nowLiked) await LikesService.incrementCount(widget.article.url);
    final count = await LikesService.getCount(widget.article.url);
    if (mounted) setState(() { _liked = nowLiked; _likeCount = count; });
  }

  List<String> get _tags {
    final text = '${widget.article.title} ${widget.article.description ?? ''}'.toLowerCase();
    final all = ['AI', 'LLM', 'GPT', 'Claude', 'OpenAI', 'Anthropic', 'Gemini', 'ML', 'Research', 'Tech'];
    return all.where((t) => text.contains(t.toLowerCase())).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final publishedAt = widget.article.publishedAt != null
        ? timeago.format(DateTime.parse(widget.article.publishedAt!))
        : '';

    return GestureDetector(
      onTap: () => Navigator.push(context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => ArticleScreen(article: widget.article, theme: t),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child),
          transitionDuration: const Duration(milliseconds: 320),
        )),
      child: Container(
        color: t.background,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Author row
          Row(children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.primary),
              child: Center(child: Text(
                (widget.article.source ?? 'A')[0].toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: t.background),
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

            // Thumbnail
            if (widget.article.urlToImage != null) ...[
              const SizedBox(width: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CachedNetworkImage(
                  imageUrl: widget.article.urlToImage!,
                  width: 80, height: 80, fit: BoxFit.cover,
                  placeholder: (c, u) => Container(width: 80, height: 80, color: t.surface),
                  errorWidget: (c, u, e) => Container(width: 80, height: 80, color: t.surface),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 14),

          // Meta row
          Row(children: [
            Text(publishedAt, style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
            const SizedBox(width: 4),
            Text('·', style: TextStyle(color: t.muted, fontSize: 12)),
            const SizedBox(width: 4),
            Text('${widget.article.readingTime} min read',
                style: GoogleFonts.inter(fontSize: 12, color: t.muted)),
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
            Icon(Icons.bookmark_border_rounded, size: 17, color: t.muted),
            const SizedBox(width: 10),
            Icon(Icons.more_horiz_rounded, size: 17, color: t.muted),
          ]),
          const SizedBox(height: 16),
          Divider(height: 1, color: t.divider),
        ]),
      ),
    );
  }
}

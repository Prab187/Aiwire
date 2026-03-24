import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class ArticleShimmer extends StatelessWidget {
  final AppTheme theme;
  const ArticleShimmer({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final baseColor = t.isDark ? const Color(0xFF1E1E1E) : (t.isKindle ? const Color(0xFFE8DFC4) : const Color(0xFFEEEEEE));
    final highlightColor = t.isDark ? const Color(0xFF2A2A2A) : (t.isKindle ? const Color(0xFFF0E8D0) : const Color(0xFFF5F5F5));

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 6,
      itemBuilder: (_, i) => Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              Row(children: [
                Container(width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: baseColor)),
                const SizedBox(width: 7),
                Container(width: 80, height: 12,
                  decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
              ]),
              const SizedBox(height: 12),
              // Title + image
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 16, decoration: BoxDecoration(
                    color: baseColor, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(height: 16, width: 200, decoration: BoxDecoration(
                    color: baseColor, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 10),
                  Container(height: 12, decoration: BoxDecoration(
                    color: baseColor, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 160, decoration: BoxDecoration(
                    color: baseColor, borderRadius: BorderRadius.circular(4))),
                ])),
                const SizedBox(width: 14),
                Container(width: 80, height: 80, decoration: BoxDecoration(
                  color: baseColor, borderRadius: BorderRadius.circular(8))),
              ]),
              const SizedBox(height: 14),
              // Meta row
              Row(children: [
                Container(width: 60, height: 10, decoration: BoxDecoration(
                  color: baseColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 12),
                Container(width: 50, height: 10, decoration: BoxDecoration(
                  color: baseColor, borderRadius: BorderRadius.circular(4))),
              ]),
              const SizedBox(height: 16),
              Divider(height: 1, color: t.divider),
            ],
          ),
        ),
      ),
    );
  }
}

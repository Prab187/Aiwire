import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Renders an AI-generated summary as a clean bullet list. Accepts
/// various formats Claude tends to produce (•, -, *, 1., 1)) and
/// normalizes them into a consistent visual: colored dot, serif body,
/// tight vertical spacing. Falls back to plain text if no bullets
/// detected.
class BulletSummary extends StatelessWidget {
  final String text;
  final AppTheme theme;
  final Color accent;
  final double fontSize;

  const BulletSummary({
    super.key,
    required this.text,
    required this.theme,
    this.accent = const Color(0xFF6366F1),
    this.fontSize = 14,
  });

  List<String> _parse(String raw) {
    // Split by newlines, normalize common bullet characters
    final lines = raw.split('\n');
    final items = <String>[];
    StringBuffer? current;

    void flush() {
      if (current != null) {
        final v = current.toString().trim();
        if (v.isNotEmpty) items.add(v);
        current = null;
      }
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Match: "•  ...", "- ...", "* ...", "1. ...", "1) ..."
      final match = RegExp(r'^(?:[•\-*]\s+|\d+[.\)]\s+)(.*)$').firstMatch(line);
      if (match != null) {
        flush();
        current = StringBuffer(match.group(1)!);
      } else if (current != null) {
        // Continuation of the previous bullet
        current!.write(' ');
        current!.write(line);
      } else {
        // Plain line before any bullets (e.g. intro sentence) — treat as one item
        items.add(line);
      }
    }
    flush();

    // Strip trailing periods for consistency (optional but looks cleaner)
    return items.map((s) {
      // Remove stray leading markdown bold
      var clean = s.replaceAll(RegExp(r'^\*\*|\*\*$'), '');
      return clean.trim();
    }).where((s) => s.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final items = _parse(text);

    if (items.isEmpty) {
      return Text(text, style: GoogleFonts.sourceSerif4(
        fontSize: fontSize, color: t.primary.withValues(alpha: 0.88), height: 1.65));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Numbered circle
            Container(
              margin: const EdgeInsets.only(top: 1),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.8)),
              child: Center(child: Text('${i + 1}', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800, color: accent, height: 1.0))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(items[i], style: GoogleFonts.sourceSerif4(
                fontSize: fontSize,
                color: t.primary.withValues(alpha: 0.88),
                height: 1.55,
                letterSpacing: 0.05)),
            )),
          ]),
        ),
    ]);
  }
}

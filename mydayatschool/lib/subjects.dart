import 'package:flutter/material.dart';

/// One colour per subject, the same everywhere in the app.
const _known = {
  'maths': 215, 'english': 345, 'science': 150, 'history': 32, 'geography': 100,
  'french': 262, 'german': 280, 'latin': 240, 'art': 300, 'music': 285,
  'pe': 18, 'games': 18, 'computing': 195, 're': 55, 'rs': 55, 'drama': 325,
  'dt': 70, 'economics': 125, 'further maths': 225, 'tutor time': 175,
};
const _hues = [172, 205, 262, 330, 18, 42, 140, 350, 285, 100];

int subjectHue(String subject) {
  final k = subject.trim().toLowerCase();
  final known = _known[k];
  if (known != null) return known;
  var h = 0;
  for (final c in k.runes) {
    h = (h * 31 + c) & 0xFFFFFFFF;
  }
  return _hues[h % _hues.length];
}

Color hueBg(int hue, Brightness b) =>
    HSLColor.fromAHSL(1, hue.toDouble(), 0.6, b == Brightness.dark ? 0.24 : 0.90).toColor();
Color hueFg(int hue, Brightness b) =>
    HSLColor.fromAHSL(1, hue.toDouble(), 0.55, b == Brightness.dark ? 0.84 : 0.26).toColor();

/// Round badge with a number or letters, coloured by hue.
class Badge extends StatelessWidget {
  const Badge({super.key, required this.label, this.hue});
  final String label;
  final int? hue;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final cs = Theme.of(context).colorScheme;
    final bg = hue == null ? cs.primaryContainer : hueBg(hue!, b);
    final fg = hue == null ? cs.onPrimaryContainer : hueFg(hue!, b);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}

/// Small coloured subject label.
class SubjectChip extends StatelessWidget {
  const SubjectChip(this.subject, {super.key});
  final String subject;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final h = subjectHue(subject);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: hueBg(h, b), borderRadius: BorderRadius.circular(99)),
      child: Text(subject, style: TextStyle(color: hueFg(h, b), fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

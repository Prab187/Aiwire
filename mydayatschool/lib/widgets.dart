import 'package:flutter/material.dart';

import 'dates.dart';
import 'palette.dart';

const pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);

class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: serif, fontWeight: FontWeight.w700));
}

/// A white rounded block with an optional heading.
class Panel extends StatelessWidget {
  const Panel({super.key, this.title, this.trailing, required this.child});
  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: serif, fontWeight: FontWeight.w700))),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class Note extends StatelessWidget {
  const Note(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant));
}

/// "3 days late", "Today", "Tomorrow" or the date.
class DuePill extends StatelessWidget {
  const DuePill({super.key, required this.due, required this.now});
  final DateTime due;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final n = dayDiff(due, now);
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (n >= 2) {
      return Text(shortDate(due), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant));
    }
    late final String label;
    late final Color bg;
    late final Color fg;
    if (n < 0) {
      label = n == -1 ? '1 day late' : '${-n} days late';
      bg = cs.error.withValues(alpha: 0.14);
      fg = cs.error;
    } else {
      label = n == 0 ? 'Today' : 'Tomorrow';
      bg = dark ? const Color(0xFF4A4416) : const Color(0xFFFFF1A8);
      fg = dark ? const Color(0xFFF2E9B0) : const Color(0xFF3B3200);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class TestTag extends StatelessWidget {
  const TestTag({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: dark ? const Color(0xFF4A4416) : const Color(0xFFFFF1A8), borderRadius: BorderRadius.circular(99)),
      child: Text('Test', style: TextStyle(color: dark ? const Color(0xFFF2E9B0) : const Color(0xFF3B3200), fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

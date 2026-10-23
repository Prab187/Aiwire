import 'dart:async';

import 'package:flutter/material.dart';

import '../dates.dart';
import '../logic.dart';
import '../models.dart';
import '../palette.dart';
import '../store.dart';
import '../subjects.dart' as subj;
import '../widgets.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.store.data.name);
  late final TextEditingController _notes = TextEditingController(text: widget.store.data.notes);
  final _bagNew = TextEditingController();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh once a minute so "today" and "tomorrow" stay right.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _name.dispose();
    _notes.dispose();
    _bagNew.dispose();
    super.dispose();
  }

  String _greeting(int hour) => hour < 12 ? 'Good morning,' : hour < 17 ? 'Good afternoon,' : 'Good evening,';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final d = widget.store.data;
        final now = DateTime.now();
        final day = viewDay(now);
        final later = dateOnly(now) != day;
        final lessons = lessonsFor(d, day);
        final bag = bagItemsFor(d, day);
        final got = bagGotFor(d, day);
        final gotCount = bag.where((b) => got.contains(b.name)).length;
        final soon = dueSoon(d, now);
        final test = nextTest(d, now);
        final nLessons = lessons.where((s) => s.trim().isNotEmpty).length;
        final dayName = weekdayNames[day.weekday - 1];

        final facts = <String>[
          nLessons == 0 ? 'No lessons yet' : '$nLessons lesson${nLessons == 1 ? '' : 's'} ${later ? dayName : 'today'}',
          soon.isEmpty ? 'Nothing due soon' : '${soon.length} due soon',
          if (test != null) _testFact(test, now),
          'Bag $gotCount/${bag.length}',
        ];

        return ListView(
          padding: pagePadding,
          children: [
            _hero(context, now, facts),
            if (d.example) ...[const SizedBox(height: 16), _exampleBanner(context)],
            const SizedBox(height: 16),
            Panel(
              title: later ? "$dayName's lessons" : "Today's lessons",
              child: nLessons == 0
                  ? const Note('No lessons yet. Add them in Timetable.')
                  : Column(
                      children: [
                        for (var i = 0; i < lessons.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                subj.Badge(label: '${i + 1}', hue: lessons[i].trim().isEmpty ? null : subj.subjectHue(lessons[i])),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    lessons[i].trim().isEmpty ? 'Free' : lessons[i],
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: lessons[i].trim().isEmpty ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Panel(
              title: 'Due soon',
              child: soon.isEmpty
                  ? const Note('Nothing due in the next 2 days.')
                  : Column(
                      children: [
                        for (final h in soon)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                subj.Badge(label: h.subject.isEmpty ? '?' : h.subject[0].toUpperCase(), hue: subj.subjectHue(h.subject)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(h.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Note(h.text),
                                    ],
                                  ),
                                ),
                                DuePill(due: h.due, now: now),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _bagPanel(context, day, later, bag, got),
            const SizedBox(height: 16),
            Panel(
              title: 'Notes',
              child: TextField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Trip form to sign, club on Thursday',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                onChanged: (v) => widget.store.update((d) => d.notes = v, clearsExample: false),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Unofficial student app. Not made or endorsed by Colchester Royal Grammar School.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _testFact(Homework t, DateTime now) {
    final n = dayDiff(t.due, now);
    return '${t.subject} test ${n == 0 ? 'today' : n == 1 ? 'tomorrow' : 'in $n days'}';
  }

  Widget _hero(BuildContext context, DateTime now, List<String> facts) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? Brand.heroDark : Brand.purple;
    final fg = dark ? const Color(0xFFF3EBFB) : Colors.white;
    // Purple card with a green stripe along the bottom, like the school site.
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          color: bg,
          child: _heroBody(context, now, facts, fg),
        ),
        Container(height: 5, color: dark ? Brand.greenLight : Brand.green),
      ]),
    );
  }

  Widget _heroBody(BuildContext context, DateTime now, List<String> facts, Color fg) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(longDate(now).toUpperCase(), style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(_greeting(now.hour), style: TextStyle(color: fg.withValues(alpha: 0.92), fontSize: 17, fontWeight: FontWeight.w600)),
          TextField(
            controller: _name,
            maxLength: 20,
            cursorColor: fg,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: fg, fontSize: 32, fontWeight: FontWeight.w700, fontFamily: serif),
            decoration: InputDecoration(
              hintText: "What's your name?",
              hintStyle: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 32, fontWeight: FontWeight.w700, fontFamily: serif),
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.only(bottom: 4),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg.withValues(alpha: 0.45), width: 2)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: fg, width: 2)),
            ),
            onChanged: (v) => widget.store.update((d) => d.name = v.trim(), clearsExample: false),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in facts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: fg.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                  child: Text(f, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
    );
  }

  Widget _exampleBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(border: Border.all(color: cs.primary.withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Expanded(child: Text('Sample data for now. Clear it to add your own.', style: TextStyle(fontSize: 13))),
          TextButton(
            onPressed: () {
              widget.store.startFresh();
              _notes.clear();
            },
            child: const Text('Clear sample'),
          ),
        ],
      ),
    );
  }

  Widget _bagPanel(BuildContext context, DateTime day, bool later, List<BagItem> bag, List<String> got) {
    final allDone = bag.isNotEmpty && bag.every((b) => got.contains(b.name));
    final title = (later ? 'Bag check for ${weekdayNames[day.weekday - 1]}' : 'Bag check for today') + (allDone ? ' ✓' : '');
    return Panel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Note('Kit for your lessons is added for you. Ticks reset daily.'),
          const SizedBox(height: 4),
          for (final b in bag)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
              value: got.contains(b.name),
              onChanged: (v) => widget.store.update((d) => toggleBag(d, day, b.name, v ?? false), clearsExample: false),
              title: Text.rich(TextSpan(children: [
                TextSpan(
                  text: b.name,
                  style: got.contains(b.name) ? TextStyle(decoration: TextDecoration.lineThrough, color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
                ),
                if (b.forLesson != null)
                  TextSpan(text: '  for ${b.forLesson}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
              ])),
              secondary: b.mine
                  ? IconButton(
                      tooltip: 'Remove ${b.name}',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => widget.store.update((d) => d.bagExtra.remove(b.name), clearsExample: false),
                    )
                  : null,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bagNew,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Add something, e.g. trip letter',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  onSubmitted: (_) => _addBag(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _addBag, child: const Text('Add')),
            ],
          ),
        ],
      ),
    );
  }

  void _addBag() {
    final v = _bagNew.text.trim();
    if (v.isEmpty) return;
    widget.store.update((d) {
      if (!d.bagExtra.contains(v)) d.bagExtra.add(v);
    }, clearsExample: false);
    _bagNew.clear();
  }
}

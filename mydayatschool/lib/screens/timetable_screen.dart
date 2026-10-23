import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../store.dart';
import '../subjects.dart' as subj;
import '../widgets.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late int _day = DateTime.now().weekday > 5 ? 0 : DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday > 5 ? -1 : DateTime.now().weekday - 1;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final lessons = widget.store.data.timetable[_day]!;
        return ListView(
          padding: pagePadding,
          children: [
            Panel(
              title: 'Timetable',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact, padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4))),
                      segments: [
                        for (var i = 0; i < 5; i++) ButtonSegment(value: i, label: Text(weekdayShort[i] + (i == todayIdx ? ' •' : ''))),
                      ],
                      selected: {_day},
                      onSelectionChanged: (s) => setState(() => _day = s.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < lessonsPerDay; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          subj.Badge(label: '${i + 1}', hue: lessons[i].trim().isEmpty ? null : subj.subjectHue(lessons[i])),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('$_day-$i'),
                              initialValue: lessons[i],
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'Lesson ${i + 1}',
                                isDense: true,
                                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              ),
                              onChanged: (v) => widget.store.update((d) => d.timetable[_day]![i] = v.trim()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Note('Type a subject for each lesson. It saves as you type.'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

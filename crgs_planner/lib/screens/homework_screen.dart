import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../store.dart';
import '../subjects.dart' as subj;
import '../widgets.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final all = store.data.homework;
        int byDue(Homework a, Homework b) => a.due.compareTo(b.due);
        final open = all.where((h) => !h.done).toList();
        final groups = <(String, List<Homework>)>[
          ('Overdue', open.where((h) => dayDiff(h.due, now) < 0).toList()..sort(byDue)),
          ('This week', open.where((h) => dayDiff(h.due, now) >= 0 && dayDiff(h.due, now) <= 7).toList()..sort(byDue)),
          ('Later', open.where((h) => dayDiff(h.due, now) > 7).toList()..sort(byDue)),
          ('Done', all.where((h) => h.done).toList()..sort(byDue)),
        ].where((g) => g.$2.isNotEmpty).toList();

        return ListView(
          padding: pagePadding,
          children: [
            FilledButton.icon(
              onPressed: () => _openAddSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add homework or a test'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              const Panel(child: Center(child: Padding(padding: EdgeInsets.all(12), child: Note("You're all caught up. New homework goes here."))))
            else
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (name, items) in groups) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${name.toUpperCase()} · ${items.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: name == 'Overdue' ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (name == 'Done')
                              TextButton(
                                onPressed: () => store.update((d) => d.homework.removeWhere((h) => h.done)),
                                child: const Text('Clear done'),
                              ),
                          ],
                        ),
                      ),
                      for (final h in items) _row(context, h, now),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, Homework h, DateTime now) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: h.done,
            onChanged: (v) => store.update((d) => h.done = v ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    subj.SubjectChip(h.subject),
                    if (h.isTest) const TestTag(),
                    if (!h.done) DuePill(due: h.due, now: now),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    h.text,
                    style: TextStyle(fontSize: 15, color: h.done ? muted : null, decoration: h.done ? TextDecoration.lineThrough : null),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.close, size: 20, color: muted),
            onPressed: () => store.update((d) => d.homework.removeWhere((x) => x.id == h.id)),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddHomeworkSheet(store: store),
    );
  }
}

class _AddHomeworkSheet extends StatefulWidget {
  const _AddHomeworkSheet({required this.store});
  final AppStore store;

  @override
  State<_AddHomeworkSheet> createState() => _AddHomeworkSheetState();
}

class _AddHomeworkSheetState extends State<_AddHomeworkSheet> {
  final _subject = TextEditingController();
  final _text = TextEditingController();
  late DateTime _due = dateOnly(DateTime.now()).add(const Duration(days: 1));
  bool _isTest = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _due.isBefore(today) ? today : _due,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _save() {
    final s = _subject.text.trim(), t = _text.text.trim();
    if (s.isEmpty || t.isEmpty) {
      setState(() => _error = 'Add a subject and some details.');
      return;
    }
    widget.store.update((d) => d.homework.add(Homework(id: DateTime.now().microsecondsSinceEpoch, subject: s, text: t, due: _due, isTest: _isTest)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add homework or a test', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: false, label: Text('Homework')), ButtonSegment(value: true, label: Text('Test or exam'))],
              selected: {_isTest},
              onSelectionChanged: (s) => setState(() => _isTest = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subject,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Subject', hintText: 'e.g. Maths', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Details', hintText: 'e.g. Page 42, Q1–10', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text('Due ${shortDate(_due)}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}

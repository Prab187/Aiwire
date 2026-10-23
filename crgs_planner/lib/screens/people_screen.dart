import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../subjects.dart' as subj;
import '../widgets.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return ListView(
          padding: pagePadding,
          children: [
            FilledButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _AddPersonSheet(store: store),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add a contact'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in roles) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(r.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    Note(r.why),
                    ..._peopleIn(context, r, muted),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _peopleIn(BuildContext context, Role r, Color muted) {
    final people = store.data.people.where((p) => p.role == r.key).toList();
    if (people.isEmpty) {
      return [Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nobody added yet.', style: TextStyle(fontStyle: FontStyle.italic, color: muted)))];
    }
    return [
      for (final p in people)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              subj.Badge(label: initials(p.name), hue: r.hue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (p.info.isNotEmpty) Note(p.info),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove ${p.name}',
                icon: Icon(Icons.close, size: 20, color: muted),
                onPressed: () => store.update((d) => d.people.removeWhere((x) => x.id == p.id)),
              ),
            ],
          ),
        ),
    ];
  }
}

class _AddPersonSheet extends StatefulWidget {
  const _AddPersonSheet({required this.store});
  final AppStore store;

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  final _name = TextEditingController();
  final _info = TextEditingController();
  String _role = roles.first.key;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _info.dispose();
    super.dispose();
  }

  void _save() {
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'Add a name.');
      return;
    }
    widget.store.update((d) => d.people.add(Person(id: DateTime.now().microsecondsSinceEpoch, role: _role, name: n, info: _info.text.trim())));
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
            Text('Add a contact', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
              items: [for (final r in roles) DropdownMenuItem(value: r.key, child: Text(r.label))],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Mrs Patel', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _info,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Number, email or note', hintText: 'e.g. Science, room S4', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Add contact')),
          ],
        ),
      ),
    );
  }
}

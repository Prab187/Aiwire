import 'package:flutter/material.dart';

import '../games/age_groups.dart';
import '../games/math_sprint.dart';
import '../games/sudoku_game.dart';
import '../games/word_scramble.dart';
import '../store.dart';
import '../widgets.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  int _game = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final g = ageGroupFor(widget.store.data.games.age);
        return ListView(
          padding: pagePadding,
          children: [
            Panel(
              title: 'Games',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AGE GROUP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [for (final a in ageGroups) ButtonSegment(value: a.key, label: Text(a.label))],
                      selected: {g.key},
                      onSelectionChanged: (s) => widget.store.update((d) => d.games.age = s.first, clearsExample: false),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Note(g.note),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Sudoku')),
                  ButtonSegment(value: 1, label: Text('Maths')),
                  ButtonSegment(value: 2, label: Text('Words')),
                ],
                selected: {_game},
                onSelectionChanged: (s) => setState(() => _game = s.first),
              ),
            ),
            const SizedBox(height: 12),
            // All three stay alive so a half-finished Sudoku is still there when you come back.
            IndexedStack(
              index: _game,
              children: [
                SudokuGame(key: ValueKey('sd-${g.key}'), store: widget.store, group: g),
                MathSprint(key: ValueKey('ms-${g.key}'), store: widget.store, group: g),
                WordScramble(key: ValueKey('ws-${g.key}'), store: widget.store, group: g),
              ],
            ),
          ],
        );
      },
    );
  }
}

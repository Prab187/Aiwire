import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../store.dart';
import '../widgets.dart';
import 'age_groups.dart';
import 'sudoku_logic.dart';

class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key, required this.store, required this.group});
  final AppStore store;
  final AgeGroup group;

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  late SudokuPuzzle _p = makeSudoku(widget.group.sudoku);
  int _sel = -1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Only count while this tab is on screen.
      if (!mounted || _p.done || !TickerMode.valuesOf(context).enabled) return;
      setState(() => _p.seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  void _newPuzzle() => setState(() {
        _p = makeSudoku(widget.group.sudoku);
        _sel = -1;
      });

  void _place(int v) {
    if (_sel < 0) return;
    final wasDone = _p.done;
    setState(() => _p.place(_sel, v));
    if (!wasDone && _p.done) {
      widget.store.update((d) => d.games.sudokuWon++, clearsExample: false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solved in ${_clock(_p.seconds)}!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _p.cfg;
    final won = widget.store.data.games.sudokuWon;
    return Panel(
      title: 'Sudoku ${cfg.n}×${cfg.n}',
      trailing: FilledButton.tonal(onPressed: _newPuzzle, child: const Text('New puzzle')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Note('Fill every row, column and box with 1 to ${cfg.n}. Wrong numbers show in red.'),
          const SizedBox(height: 12),
          _grid(context),
          const SizedBox(height: 12),
          _pad(context),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 16,
            runSpacing: 4,
            children: [
              _stat(context, 'Mistakes', '${_p.mistakes}'),
              _stat(context, 'Time', _clock(_p.seconds)),
              _stat(context, 'Solved', '$won'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );

  Widget _grid(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cfg = _p.cfg;
    final n = cfg.n;
    int boxOf(int i) => ((i ~/ n) ~/ cfg.bh) * 100 + ((i % n) ~/ cfg.bw);
    return LayoutBuilder(builder: (context, c) {
      final w = min(c.maxWidth, 432.0);
      final cell = (w - 4) / n;
      final selVal = _sel >= 0 ? _p.current[_sel] : 0;
      return Center(
        child: Container(
          width: w,
          decoration: BoxDecoration(border: Border.all(color: cs.onSurface, width: 2), borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var r = 0; r < n; r++)
                Row(
                  children: [
                    for (var col = 0; col < n; col++) _cell(context, r * n + col, r, col, cell, selVal, boxOf),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _cell(BuildContext context, int i, int r, int c, double size, int selVal, int Function(int) boxOf) {
    final cs = Theme.of(context).colorScheme;
    final cfg = _p.cfg;
    final n = cfg.n;
    final v = _p.current[i];
    final given = _p.isGiven(i);
    final selected = i == _sel;
    final peer = _sel >= 0 && !selected && (_sel ~/ n == r || _sel % n == c || boxOf(_sel) == boxOf(i));
    final same = _sel >= 0 && !selected && v != 0 && v == selVal;
    final wrong = v != 0 && !given && v != _p.solution[i];
    Color bg = Theme.of(context).cardTheme.color ?? cs.surface;
    if (peer) bg = cs.primaryContainer;
    if (same) bg = const Color(0xFFFFF1A8).withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 1);
    if (selected) bg = cs.primary;
    final fg = selected ? cs.onPrimary : wrong ? cs.error : given ? cs.onSurface : cs.primary;
    final thickRight = (c + 1) % cfg.bw == 0 && c < n - 1;
    final thickBottom = (r + 1) % cfg.bh == 0 && r < n - 1;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Row ${r + 1}, column ${c + 1}, ${v == 0 ? 'empty' : v}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => setState(() => _sel = i),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                right: BorderSide(color: thickRight ? cs.onSurface : cs.outlineVariant, width: thickRight ? 2 : 0.5),
                bottom: BorderSide(color: thickBottom ? cs.onSurface : cs.outlineVariant, width: thickBottom ? 2 : 0.5),
              ),
            ),
            child: Text(
              v == 0 ? '' : '$v',
              style: TextStyle(
                fontSize: size * 0.55,
                fontWeight: given ? FontWeight.w800 : FontWeight.w600,
                color: fg,
                decoration: wrong ? TextDecoration.underline : null,
                decorationStyle: TextDecorationStyle.wavy,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pad(BuildContext context) {
    final n = _p.cfg.n;
    final cols = n == 9 ? 5 : n + 1;
    return LayoutBuilder(builder: (context, c) {
      final w = min(c.maxWidth, 432.0);
      final bw = (w - 6 * (cols - 1)) / cols;
      return Center(
        child: SizedBox(
          width: w,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var k = 1; k <= n; k++)
                SizedBox(
                  width: bw,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => _place(k),
                    child: Text('$k', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                ),
              SizedBox(
                width: bw,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => _place(0),
                  child: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

import 'dart:math';

/// Sudoku of size n with boxes bh rows by bw columns. Grids are flat lists, 0 = empty.
class SudokuConfig {
  const SudokuConfig(this.n, this.bh, this.bw, this.keep);
  final int n;
  final int bh;
  final int bw;

  /// How many squares are given at the start.
  final int keep;
}

class SudokuPuzzle {
  SudokuPuzzle(this.cfg, this.solution, this.puzzle) : current = List.of(puzzle);
  final SudokuConfig cfg;
  final List<int> solution;
  final List<int> puzzle;
  final List<int> current;
  int mistakes = 0;
  int seconds = 0;
  bool done = false;

  bool isGiven(int i) => puzzle[i] != 0;
  bool get solved {
    for (var i = 0; i < current.length; i++) {
      if (current[i] != solution[i]) return false;
    }
    return true;
  }

  /// Puts [v] (0 erases) in square [i]. Returns false if the square is locked.
  bool place(int i, int v) {
    if (done || isGiven(i)) return false;
    if (v != 0 && v != solution[i] && current[i] != v) mistakes++;
    current[i] = v;
    if (solved) done = true;
    return true;
  }
}

bool _ok(List<int> g, SudokuConfig c, int i, int v) {
  final n = c.n, r = i ~/ n, col = i % n, br = r - r % c.bh, bc = col - col % c.bw;
  for (var k = 0; k < n; k++) {
    if (g[r * n + k] == v || g[k * n + col] == v) return false;
    if (g[(br + k ~/ c.bw) * n + bc + k % c.bw] == v) return false;
  }
  return true;
}

bool _fill(List<int> g, SudokuConfig c, Random rnd) {
  final i = g.indexOf(0);
  if (i < 0) return true;
  final vals = List.generate(c.n, (k) => k + 1)..shuffle(rnd);
  for (final v in vals) {
    if (_ok(g, c, i, v)) {
      g[i] = v;
      if (_fill(g, c, rnd)) return true;
      g[i] = 0;
    }
  }
  return false;
}

int countSolutions(List<int> g, SudokuConfig c, [int limit = 2]) {
  final i = g.indexOf(0);
  if (i < 0) return 1;
  var found = 0;
  for (var v = 1; v <= c.n && found < limit; v++) {
    if (_ok(g, c, i, v)) {
      g[i] = v;
      found += countSolutions(g, c, limit - found);
      g[i] = 0;
    }
  }
  return found;
}

/// Makes a puzzle that has exactly one solution.
SudokuPuzzle makeSudoku(SudokuConfig cfg, [Random? random]) {
  final rnd = random ?? Random();
  final total = cfg.n * cfg.n;
  final sol = List.filled(total, 0);
  _fill(sol, cfg, rnd);
  final puz = List.of(sol);
  var filled = total;
  final order = List.generate(total, (i) => i)..shuffle(rnd);
  for (final i in order) {
    if (filled <= cfg.keep) break;
    final v = puz[i];
    puz[i] = 0;
    if (countSolutions(List.of(puz), cfg) != 1) {
      puz[i] = v;
    } else {
      filled--;
    }
  }
  return SudokuPuzzle(cfg, sol, puz);
}

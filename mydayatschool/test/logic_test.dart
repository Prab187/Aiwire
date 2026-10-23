import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydayatschool/dates.dart';
import 'package:mydayatschool/games/age_groups.dart';
import 'package:mydayatschool/games/sudoku_logic.dart';
import 'package:mydayatschool/logic.dart';
import 'package:mydayatschool/models.dart';

bool _valid(List<int> g, SudokuConfig c) {
  final n = c.n;
  final want = List.generate(n, (i) => i + 1).toSet();
  for (var r = 0; r < n; r++) {
    if (!{for (var k = 0; k < n; k++) g[r * n + k]}.containsAll(want)) return false;
  }
  for (var col = 0; col < n; col++) {
    if (!{for (var k = 0; k < n; k++) g[k * n + col]}.containsAll(want)) return false;
  }
  for (var br = 0; br < n; br += c.bh) {
    for (var bc = 0; bc < n; bc += c.bw) {
      final s = <int>{};
      for (var r = 0; r < c.bh; r++) {
        for (var k = 0; k < c.bw; k++) {
          s.add(g[(br + r) * n + bc + k]);
        }
      }
      if (!s.containsAll(want)) return false;
    }
  }
  return true;
}

/// Works out the answer to a question from its text, independent of the generator.
int _evaluate(String q) {
  if (q.contains('²')) {
    final a = int.parse(q.replaceAll('²', ''));
    return a * a;
  }
  final pct = RegExp(r'^(\d+)% of (\d+)$').firstMatch(q);
  if (pct != null) return int.parse(pct[1]!) * int.parse(pct[2]!) ~/ 100;
  final neg = RegExp(r'^(-?\d+) × \((-?\d+)\)$').firstMatch(q);
  if (neg != null) return int.parse(neg[1]!) * int.parse(neg[2]!);
  final m = RegExp(r'^(\d+) ([+−×÷]) (\d+)$').firstMatch(q)!;
  final a = int.parse(m[1]!), b = int.parse(m[3]!);
  switch (m[2]) {
    case '+':
      return a + b;
    case '−':
      return a - b;
    case '×':
      return a * b;
    default:
      expect(a % b, 0, reason: 'division must be exact: $q');
      return a ~/ b;
  }
}

void main() {
  group('Sudoku', () {
    for (final g in ageGroups) {
      test('${g.label}: valid solution and exactly one solution', () {
        final p = makeSudoku(g.sudoku, Random(7));
        expect(_valid(p.solution, g.sudoku), isTrue);
        expect(countSolutions(List.of(p.puzzle), g.sudoku), 1);
        final given = p.puzzle.where((v) => v != 0).length;
        expect(given, lessThan(g.sudoku.n * g.sudoku.n));
        expect(given, lessThanOrEqualTo(g.sudoku.keep + 8));
        for (var i = 0; i < p.puzzle.length; i++) {
          if (p.puzzle[i] != 0) expect(p.puzzle[i], p.solution[i]);
        }
      });
    }

    test('placing numbers counts mistakes, locks givens and detects a win', () {
      final p = makeSudoku(ageGroups[0].sudoku, Random(3));
      final given = p.puzzle.indexWhere((v) => v != 0);
      expect(p.place(given, 1), isFalse);
      final empty = p.puzzle.indexWhere((v) => v == 0);
      final wrong = p.solution[empty] == 1 ? 2 : 1;
      p.place(empty, wrong);
      expect(p.mistakes, 1);
      for (var i = 0; i < p.puzzle.length; i++) {
        if (!p.isGiven(i)) p.place(i, p.solution[i]);
      }
      expect(p.done, isTrue);
      expect(p.solved, isTrue);
    });
  });

  group('Maths sprint', () {
    for (final g in ageGroups) {
      test('${g.label}: every answer matches its question', () {
        final r = Random(11);
        var sawNegative = false;
        for (var i = 0; i < 600; i++) {
          final q = g.question(r);
          expect(q.answer, _evaluate(q.text), reason: q.text);
          if (q.answer < 0) sawNegative = true;
          if (!g.negativeAnswers) expect(q.answer, greaterThanOrEqualTo(0), reason: q.text);
        }
        expect(sawNegative, g.negativeAnswers);
      });
    }
  });

  group('Words', () {
    test('every word is lower case letters with a subject', () {
      for (final g in ageGroups) {
        for (final (s, w) in g.words) {
          expect(s, isNotEmpty);
          expect(w, matches(RegExp(r'^[a-z]{3,}$')));
        }
      }
    });
  });

  group('Dates', () {
    test('viewDay skips weekends and after-school hours', () {
      expect(viewDay(DateTime(2026, 10, 21, 10)), DateTime(2026, 10, 21)); // Wed morning
      expect(viewDay(DateTime(2026, 10, 21, 16)), DateTime(2026, 10, 22)); // Wed 4pm -> Thu
      expect(viewDay(DateTime(2026, 10, 23, 17)), DateTime(2026, 10, 26)); // Fri evening -> Mon
      expect(viewDay(DateTime(2026, 10, 24, 9)), DateTime(2026, 10, 26)); // Sat -> Mon
      expect(viewDay(DateTime(2026, 10, 25, 9)), DateTime(2026, 10, 26)); // Sun -> Mon
    });

    test('dayDiff counts whole days across a clock change', () {
      expect(dayDiff(DateTime(2026, 3, 30), DateTime(2026, 3, 28)), 2);
      expect(dayDiff(DateTime(2026, 10, 26), DateTime(2026, 10, 24)), 2);
      expect(dayDiff(DateTime(2026, 10, 20, 23, 59), DateTime(2026, 10, 21, 0, 1)), -1);
    });

    test('iso round trip', () {
      expect(parseIso(isoDate(DateTime(2027, 1, 5))), DateTime(2027, 1, 5));
    });
  });

  group('Bag, homework and saving', () {
    test('bag picks kit from the day\'s lessons', () {
      final d = AppData.example(DateTime(2026, 10, 19)); // Monday: Maths, English, Science, French, PE, History
      final names = bagItemsFor(d, DateTime(2026, 10, 19)).map((b) => b.name).toList();
      expect(names, containsAll(['Planner', 'Calculator', 'PE kit', 'Lab book']));
      expect(names, isNot(contains('Sketchbook')));
      final tue = bagItemsFor(d, DateTime(2026, 10, 20)).map((b) => b.name).toList(); // Tuesday has Art, Music
      expect(tue, containsAll(['Sketchbook', 'Instrument']));
    });

    test('ticks belong to one day', () {
      final d = AppData.example(DateTime(2026, 10, 19));
      final mon = DateTime(2026, 10, 19), tue = DateTime(2026, 10, 20);
      toggleBag(d, mon, 'Planner', true);
      expect(bagGotFor(d, mon), ['Planner']);
      expect(bagGotFor(d, tue), isEmpty);
      toggleBag(d, tue, 'Keys', true);
      expect(bagGotFor(d, tue), ['Keys']);
      expect(bagGotFor(d, mon), isEmpty);
    });

    test('homework due soon and next test', () {
      final now = DateTime(2026, 10, 21, 9);
      final d = AppData.example(now);
      expect(dueSoon(d, now).map((h) => h.subject), ['Maths']);
      expect(nextTest(d, now)!.subject, 'Science');
      d.homework.first.done = true;
      expect(dueSoon(d, now), isEmpty);
    });

    test('initials', () {
      expect(initials('Dr Jane Who'), 'DJ');
      expect(initials('Mum'), 'M');
      expect(initials('  '), '');
    });

    test('saving and loading keeps everything', () {
      final d = AppData.example(DateTime(2026, 10, 19))
        ..name = 'Sam'
        ..notes = 'Trip form'
        ..bagExtra.add('Trip letter');
      d.games.age = 'a7';
      d.games.best['a7'] = 17;
      d.timetable[2]![3] = 'Latin';
      final back = AppData.fromJson(Map<String, dynamic>.from(
        (jsonDecode(jsonEncode(d.toJson())) as Map),
      ));
      expect(back.name, 'Sam');
      expect(back.notes, 'Trip form');
      expect(back.bagExtra, ['Trip letter']);
      expect(back.games.age, 'a7');
      expect(back.games.best['a7'], 17);
      expect(back.timetable[2]![3], 'Latin');
      expect(back.homework.length, d.homework.length);
      expect(back.homework.last.isTest, isTrue);
      expect(back.people.length, d.people.length);
    });

    test('loading old or partial data does not crash', () {
      final back = AppData.fromJson({'name': 'A'});
      expect(back.timetable[0]!.length, lessonsPerDay);
      expect(back.homework, isEmpty);
    });
  });
}

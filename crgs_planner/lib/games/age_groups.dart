import 'dart:math';

import 'sudoku_logic.dart';

class MathQuestion {
  const MathQuestion(this.text, this.answer);
  final String text;
  final int answer;
}

class AgeGroup {
  const AgeGroup({
    required this.key,
    required this.label,
    required this.note,
    required this.mathRule,
    required this.sudoku,
    required this.question,
    required this.words,
    this.negativeAnswers = false,
  });
  final String key;
  final String label;
  final String note;
  final String mathRule;
  final SudokuConfig sudoku;
  final MathQuestion Function(Random) question;
  final List<(String, String)> words;
  final bool negativeAnswers;
}

MathQuestion _add(Random r) {
  if (r.nextBool()) {
    final a = r.nextInt(11), b = r.nextInt(11);
    return MathQuestion('$a + $b', a + b);
  }
  final a = 5 + r.nextInt(16), b = r.nextInt(a + 1);
  return MathQuestion('$a − $b', a - b);
}

MathQuestion _times(Random r) {
  final a = 2 + r.nextInt(11), b = 2 + r.nextInt(11);
  return MathQuestion('$a × $b', a * b);
}

MathQuestion _timesDivide(Random r) {
  final a = 2 + r.nextInt(11), b = 2 + r.nextInt(11);
  return r.nextBool() ? MathQuestion('$a × $b', a * b) : MathQuestion('${a * b} ÷ $a', b);
}

MathQuestion _mixed(Random r) {
  switch (r.nextInt(4)) {
    case 0:
      final a = 2 + r.nextInt(14);
      return MathQuestion('$a²', a * a);
    case 1:
      const ps = [10, 20, 25, 50, 75], ns = [20, 40, 60, 80, 120, 200, 360];
      final p = ps[r.nextInt(ps.length)], n = ns[r.nextInt(ns.length)];
      return MathQuestion('$p% of $n', p * n ~/ 100);
    case 2:
      final a = r.nextInt(13) - 6, b = r.nextInt(13) - 6;
      return MathQuestion('$a × ($b)', a * b);
    default:
      final a = 3 + r.nextInt(10), b = 3 + r.nextInt(10);
      return MathQuestion('${a * b} ÷ $b', a);
  }
}

const ageGroups = <AgeGroup>[
  AgeGroup(
    key: 'a5',
    label: '5–7',
    note: 'Mini 4×4 Sudoku, add and subtract up to 20, short words.',
    mathRule: 'Add and subtract up to 20.',
    sudoku: SudokuConfig(4, 2, 2, 8),
    question: _add,
    words: [
      ('English', 'book'), ('English', 'read'), ('Maths', 'add'), ('Maths', 'five'), ('Maths', 'ten'),
      ('Science', 'sun'), ('Science', 'tree'), ('Science', 'fish'), ('Art', 'paint'), ('Art', 'pen'),
      ('Music', 'song'), ('Music', 'drum'), ('PE', 'ball'), ('PE', 'jump'), ('Geography', 'map'), ('Geography', 'rain'),
    ],
  ),
  AgeGroup(
    key: 'a7',
    label: '7–11',
    note: '6×6 Sudoku, times tables up to 12×12, everyday school words.',
    mathRule: 'Times tables from 2× to 12×.',
    sudoku: SudokuConfig(6, 2, 3, 18),
    question: _times,
    words: [
      ('Maths', 'fraction'), ('Maths', 'triangle'), ('Maths', 'number'), ('Maths', 'divide'), ('Science', 'planet'),
      ('Science', 'magnet'), ('Science', 'plant'), ('English', 'story'), ('English', 'spelling'), ('English', 'noun'),
      ('Geography', 'river'), ('Geography', 'country'), ('History', 'castle'), ('History', 'king'), ('Music', 'rhythm'),
      ('Computing', 'mouse'),
    ],
  ),
  AgeGroup(
    key: 'a11',
    label: '11–14',
    note: 'Easy 9×9 Sudoku, times and division facts, KS3 words.',
    mathRule: 'Multiply and divide up to 12.',
    sudoku: SudokuConfig(9, 3, 3, 38),
    question: _timesDivide,
    words: [
      ('Maths', 'equation'), ('Maths', 'decimal'), ('Maths', 'perimeter'), ('Science', 'molecule'), ('Science', 'gravity'),
      ('Science', 'oxygen'), ('Science', 'habitat'), ('English', 'adjective'), ('English', 'paragraph'), ('English', 'metaphor'),
      ('Geography', 'volcano'), ('Geography', 'continent'), ('Geography', 'climate'), ('History', 'empire'),
      ('Computing', 'algorithm'), ('French', 'bonjour'),
    ],
  ),
  AgeGroup(
    key: 'a14',
    label: '14–16',
    note: 'Tougher 9×9 Sudoku, mixed mental maths, longer GCSE words.',
    mathRule: 'Mixed: squares, percentages, negatives and division.',
    sudoku: SudokuConfig(9, 3, 3, 28),
    question: _mixed,
    negativeAnswers: true,
    words: [
      ('Science', 'photosynthesis'), ('Science', 'electron'), ('Science', 'catalyst'), ('Maths', 'quadratic'),
      ('Maths', 'hypotenuse'), ('Maths', 'probability'), ('English', 'alliteration'), ('English', 'protagonist'),
      ('History', 'parliament'), ('History', 'revolution'), ('Geography', 'population'), ('Geography', 'erosion'),
      ('Computing', 'variable'), ('Economics', 'inflation'), ('Biology', 'chromosome'), ('Chemistry', 'reaction'),
    ],
  ),
];

AgeGroup ageGroupFor(String key) => ageGroups.firstWhere((a) => a.key == key, orElse: () => ageGroups[2]);

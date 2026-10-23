import 'dates.dart';
import 'models.dart';

const bagBasics = ['Planner', 'Pencil case', 'Water bottle', 'Lunch or money', 'Reading book', 'Keys'];

final _forLesson = <(RegExp, String)>[
  (RegExp('maths', caseSensitive: false), 'Calculator'),
  (RegExp(r'\b(pe|games|sport)', caseSensitive: false), 'PE kit'),
  (RegExp('art', caseSensitive: false), 'Sketchbook'),
  (RegExp('music', caseSensitive: false), 'Instrument'),
  (RegExp('food|cook', caseSensitive: false), 'Ingredients'),
  (RegExp('science|physics|chemistry|biology', caseSensitive: false), 'Lab book'),
];

class BagItem {
  const BagItem(this.name, {this.forLesson, this.mine = false});
  final String name;
  final String? forLesson;
  final bool mine;
}

List<String> lessonsFor(AppData d, DateTime day) => d.timetable[day.weekday - 1] ?? List.filled(lessonsPerDay, '');

/// Basics, plus kit picked from the day's lessons, plus the student's own items.
List<BagItem> bagItemsFor(AppData d, DateTime day) {
  final lessons = lessonsFor(d, day).where((s) => s.trim().isNotEmpty).toList();
  final items = <BagItem>[for (final b in bagBasics) BagItem(b)];
  for (final (re, item) in _forLesson) {
    final match = lessons.where(re.hasMatch);
    if (match.isNotEmpty) items.add(BagItem(item, forLesson: match.first));
  }
  for (final e in d.bagExtra) {
    items.add(BagItem(e, mine: true));
  }
  return items;
}

/// Items ticked today. Ticks belong to one day and start fresh on the next.
List<String> bagGotFor(AppData d, DateTime day) => d.bagDate == isoDate(day) ? d.bagGot : const [];

void toggleBag(AppData d, DateTime day, String item, bool on) {
  final key = isoDate(day);
  if (d.bagDate != key) {
    d.bagDate = key;
    d.bagGot = [];
  }
  d.bagGot = on ? [...d.bagGot.where((x) => x != item), item] : d.bagGot.where((x) => x != item).toList();
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
  return parts.map((p) => p[0].toUpperCase()).join();
}

/// Open homework due within [days] days (overdue included), earliest first. Tests are listed separately.
List<Homework> dueSoon(AppData d, DateTime now, {int days = 2}) =>
    d.homework.where((h) => !h.done && !h.isTest && dayDiff(h.due, now) <= days).toList()..sort((a, b) => a.due.compareTo(b.due));

Homework? nextTest(AppData d, DateTime now) {
  final tests = d.homework.where((h) => h.isTest && !h.done && dayDiff(h.due, now) >= 0).toList()..sort((a, b) => a.due.compareTo(b.due));
  return tests.isEmpty ? null : tests.first;
}

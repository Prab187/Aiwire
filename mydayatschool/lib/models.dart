import 'dates.dart';

const lessonsPerDay = 6;

class Homework {
  Homework({required this.id, required this.subject, required this.text, required this.due, this.done = false, this.isTest = false});
  final int id;
  String subject;
  String text;
  DateTime due;
  bool done;
  bool isTest;

  Map<String, dynamic> toJson() => {'id': id, 's': subject, 't': text, 'due': isoDate(due), 'done': done, 'test': isTest};
  factory Homework.fromJson(Map<String, dynamic> j) => Homework(
        id: j['id'] as int,
        subject: j['s'] as String,
        text: j['t'] as String,
        due: parseIso(j['due'] as String),
        done: j['done'] as bool? ?? false,
        isTest: j['test'] as bool? ?? false,
      );
}

class Role {
  const Role(this.key, this.label, this.why, this.hue);
  final String key;
  final String label;
  final String why;
  final int hue;
}

const roles = [
  Role('parent', 'Parent / guardian', 'Who to tell about trips, letters and being ill', 18),
  Role('tutor', 'Form tutor', 'Your first stop for most questions', 172),
  Role('teacher', 'Subject teacher', 'Ask about homework and lessons', 215),
  Role('head', 'Head of year', 'For bigger worries or problems', 262),
  Role('office', 'School office', 'Absences, lost property, messages home', 42),
  Role('friend', 'Friend / study buddy', 'Swap homework notes if you miss a lesson', 330),
];

class Person {
  Person({required this.id, required this.role, required this.name, this.info = ''});
  final int id;
  final String role;
  String name;
  String info;

  Map<String, dynamic> toJson() => {'id': id, 'role': role, 'name': name, 'info': info};
  factory Person.fromJson(Map<String, dynamic> j) =>
      Person(id: j['id'] as int, role: j['role'] as String, name: j['name'] as String, info: j['info'] as String? ?? '');
}

class GamesState {
  GamesState();

  String age = 'a11';
  Map<String, int> best = {};
  int sudokuWon = 0;
  int wordBest = 0;
  int wordStreak = 0;

  Map<String, dynamic> toJson() => {'age': age, 'best': best, 'sdWon': sudokuWon, 'wsBest': wordBest, 'wsStreak': wordStreak};
  factory GamesState.fromJson(Map<String, dynamic> j) {
    final g = GamesState();
    g.age = j['age'] as String? ?? 'a11';
    g.best = (j['best'] as Map? ?? {}).map((k, v) => MapEntry(k as String, v as int));
    g.sudokuWon = j['sdWon'] as int? ?? 0;
    g.wordBest = j['wsBest'] as int? ?? 0;
    g.wordStreak = j['wsStreak'] as int? ?? 0;
    return g;
  }
}

class AppData {
  AppData({
    this.example = false,
    this.name = '',
    Map<int, List<String>>? timetable,
    List<Homework>? homework,
    List<Person>? people,
    List<String>? bagExtra,
    this.bagDate = '',
    List<String>? bagGot,
    this.notes = '',
    GamesState? games,
  })  : timetable = timetable ?? {for (var i = 0; i < 5; i++) i: List.filled(lessonsPerDay, '')},
        homework = homework ?? [],
        people = people ?? [],
        bagExtra = bagExtra ?? [],
        bagGot = bagGot ?? [],
        games = games ?? GamesState();

  bool example;
  String name;
  final Map<int, List<String>> timetable;
  final List<Homework> homework;
  final List<Person> people;
  final List<String> bagExtra;
  String bagDate;
  List<String> bagGot;
  String notes;
  final GamesState games;

  /// Sample content so the app is not empty the first time it opens.
  factory AppData.example(DateTime now) {
    final t = dateOnly(now);
    DateTime plus(int n) => DateTime(t.year, t.month, t.day + n);
    List<String> day(List<String> l) => l;
    return AppData(
      example: true,
      timetable: {
        0: day(['Maths', 'English', 'Science', 'French', 'PE', 'History']),
        1: day(['Science', 'Geography', 'Maths', 'Art', 'English', 'Music']),
        2: day(['English', 'Maths', 'Computing', 'History', 'Science', 'RE']),
        3: day(['French', 'Science', 'English', 'Maths', 'Drama', 'Geography']),
        4: day(['Maths', 'History', 'Science', 'English', 'PE', 'Tutor time']),
      },
      homework: [
        Homework(id: 1, subject: 'Maths', text: 'Page 42, questions 1–10', due: plus(1)),
        Homework(id: 2, subject: 'French', text: 'Learn 15 words for the vocab test', due: plus(3)),
        Homework(id: 3, subject: 'English', text: 'Read chapter 4 of the class novel', due: plus(5)),
        Homework(id: 4, subject: 'Science', text: 'Topic test: cells and organisms', due: plus(8), isTest: true),
      ],
      people: [
        Person(id: 1, role: 'parent', name: 'Mum', info: 'Mobile in my phone'),
        Person(id: 2, role: 'tutor', name: 'Mr Hughes', info: 'Form room 12'),
        Person(id: 3, role: 'teacher', name: 'Mrs Patel', info: 'Science · room S4'),
        Person(id: 4, role: 'teacher', name: 'Ms Okafor', info: 'Maths · room M2'),
        Person(id: 5, role: 'office', name: 'Reception', info: "Ring before 8:30 if I'm off ill"),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'example': example,
        'name': name,
        'tt': timetable.map((k, v) => MapEntry('$k', v)),
        'hw': homework.map((h) => h.toJson()).toList(),
        'people': people.map((p) => p.toJson()).toList(),
        'bagExtra': bagExtra,
        'bagDate': bagDate,
        'bagGot': bagGot,
        'notes': notes,
        'games': games.toJson(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final tt = <int, List<String>>{};
    final raw = (j['tt'] as Map? ?? {});
    for (var i = 0; i < 5; i++) {
      final l = ((raw['$i'] as List?) ?? const []).map((e) => '$e').toList();
      while (l.length < lessonsPerDay) {
        l.add('');
      }
      tt[i] = l;
    }
    return AppData(
      example: j['example'] as bool? ?? false,
      name: j['name'] as String? ?? '',
      timetable: tt,
      homework: ((j['hw'] as List?) ?? const []).map((e) => Homework.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      people: ((j['people'] as List?) ?? const []).map((e) => Person.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      bagExtra: ((j['bagExtra'] as List?) ?? const []).map((e) => '$e').toList(),
      bagDate: j['bagDate'] as String? ?? '',
      bagGot: ((j['bagGot'] as List?) ?? const []).map((e) => '$e').toList(),
      notes: j['notes'] as String? ?? '',
      games: GamesState.fromJson(Map<String, dynamic>.from((j['games'] as Map?) ?? {})),
    );
  }
}

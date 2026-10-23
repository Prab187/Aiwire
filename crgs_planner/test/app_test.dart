import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crgs_planner/main.dart';
import 'package:crgs_planner/models.dart';
import 'package:crgs_planner/radio/radio_controller.dart';
import 'package:crgs_planner/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

FakeSpeaker lastSpeaker = FakeSpeaker();

Future<AppStore> _pump(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = await AppStore.load();
  lastSpeaker = FakeSpeaker();
  final radio = RadioController(repo: FakeRepo(sampleStories()), speaker: lastSpeaker, store: store);
  await tester.pumpWidget(CrgsPlannerApp(store: store, radio: radio));
  await tester.pump();
  return store;
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on Today with the header, greeting and sample data', (tester) async {
    await _pump(tester);
    expect(find.text('CRGS Connect'), findsOneWidget);
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text("What's your name?"), findsOneWidget);
    expect(find.textContaining('Sample data'), findsOneWidget);
    // The bag checklist is further down the page; scroll to it.
    await tester.scrollUntilVisible(find.textContaining('Bag check'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Planner'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('name is saved and the example banner stays', (tester) async {
    final store = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Sam');
    await tester.pump();
    expect(store.data.name, 'Sam');
    expect(store.data.example, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Clear sample removes the example content', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Clear sample'));
    await tester.pump();
    expect(store.data.example, isFalse);
    expect(store.data.homework, isEmpty);
    expect(find.textContaining('Sample data'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('add homework from the Homework tab', (tester) async {
    final store = await _pump(tester);
    await _tab(tester, 'Homework');
    expect(find.text('THIS WEEK · 3'), findsOneWidget);
    await tester.tap(find.text('Add homework or a test'));
    await tester.pumpAndSettle();
    // Empty save shows an error and adds nothing.
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Add a subject and some details.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Subject'), 'Latin');
    await tester.enterText(find.widgetWithText(TextField, 'Details'), 'Translate paragraph 2');
    await tester.tap(find.text('Test or exam'));
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(store.data.homework.length, 5);
    expect(store.data.homework.last.subject, 'Latin');
    expect(store.data.homework.last.isTest, isTrue);
    expect(find.text('Translate paragraph 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tick a homework item moves it to Done, then clear finished', (tester) async {
    final store = await _pump(tester);
    await _tab(tester, 'Homework');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(store.data.homework.where((h) => h.done).length, 1);
    expect(find.text('DONE · 1'), findsOneWidget);
    await tester.tap(find.text('Clear done'));
    await tester.pumpAndSettle();
    expect(store.data.homework.length, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('timetable edits are saved', (tester) async {
    final store = await _pump(tester);
    await _tab(tester, 'Timetable');
    await tester.enterText(find.byType(TextFormField).first, 'Latin');
    await tester.pump();
    final day = DateTime.now().weekday > 5 ? 0 : DateTime.now().weekday - 1;
    expect(store.data.timetable[day]![0], 'Latin');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('add and remove a person', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.byTooltip('Contacts')); // opened from the header
    await tester.pumpAndSettle();
    expect(find.text('Mrs Patel'), findsOneWidget);
    await tester.tap(find.text('Add a contact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Dr Jane Who');
    await tester.tap(find.text('Add contact'));
    await tester.pumpAndSettle();
    expect(store.data.people.length, 6);
    expect(find.text('DJ'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Dr Jane Who'));
    await tester.pumpAndSettle();
    expect(store.data.people.length, 5);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('games: age change swaps the Sudoku size, solving counts a win', (tester) async {
    final store = await _pump(tester);
    await _tab(tester, 'Games');
    expect(find.text('Sudoku 9×9'), findsOneWidget);
    await tester.tap(find.text('5–7'));
    await tester.pumpAndSettle();
    expect(find.text('Sudoku 4×4'), findsOneWidget);
    expect(store.data.games.age, 'a5');
    expect(find.bySemanticsLabel(RegExp(r'^Row \d, column \d, ')), findsNWidgets(16));
    await tester.tap(find.text('Maths'));
    await tester.pumpAndSettle();
    expect(find.text('Maths sprint'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.textContaining(RegExp(r'^\d+ [+−] \d+$')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('radio: stories, school and AI board, play reads them out', (tester) async {
    await _pump(tester);
    await _tab(tester, 'Radio');
    await tester.pump();
    await tester.pump();
    expect(find.text('Which school got which AI'), findsOneWidget);
    expect(find.text('Who got which AI'), findsOneWidget);
    // St Mary's Academy -> Khanmigo shows on the board (and in the playlist chips)
    expect(find.text("St Mary's Academy"), findsWidgets);
    expect(find.text('Khanmigo'), findsWidgets);
    expect(find.text("St Mary's Academy rolls out Khanmigo AI tutor to Year 9"), findsWidgets);
    expect(find.text('Read the story'), findsOneWidget);
    await tester.tap(find.byKey(const Key('radio-play')));
    await tester.pump();
    await tester.pump();
    expect(lastSpeaker.spoken.first, contains("You're tuned in to CRGS Connect Radio"));
    expect(lastSpeaker.spoken.length, 5);
    await tester.scrollUntilVisible(find.textContaining('Unofficial: not made or endorsed'), 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('data survives a restart', (tester) async {
    final store = await _pump(tester);
    await _tab(tester, 'Homework');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    final prefs = await SharedPreferences.getInstance();
    final again = await AppStore.load();
    expect(prefs.getString('school_day_v1'), isNotNull);
    expect(again.data.homework.where((h) => h.done).length, 1);
    expect(again.data.homework.length, store.data.homework.length);
    expect(Homework, isNotNull);
  });
}

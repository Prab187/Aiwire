import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'palette.dart';
import 'screens/games_screen.dart';
import 'screens/homework_screen.dart';
import 'radio/news_sources.dart';
import 'radio/radio_controller.dart';
import 'radio/speaker.dart';
import 'screens/people_screen.dart';
import 'screens/radio_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/today_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final prefs = await SharedPreferences.getInstance();
  final radio = RadioController(repo: LiveNewsRepository(), speaker: TtsSpeaker(), store: store, prefs: prefs);
  runApp(CrgsPlannerApp(store: store, radio: radio));
}

ThemeData buildTheme(Brightness b) {
  final light = b == Brightness.light;
  final cs = ColorScheme.fromSeed(seedColor: Brand.purple, brightness: b).copyWith(
    primary: light ? Brand.purple : Brand.purpleLight,
    onPrimary: light ? Colors.white : const Color(0xFF3A1B57),
    primaryContainer: light ? Brand.lavender : Brand.heroDark,
    onPrimaryContainer: light ? const Color(0xFF3A1B57) : const Color(0xFFEBDDFA),
    secondary: light ? Brand.green : Brand.greenLight,
    onSecondary: light ? Colors.white : const Color(0xFF0E2A12),
  );
  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: light ? const Color(0xFFF6F3F8) : const Color(0xFF14101B),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: light ? Colors.white : const Color(0xFF1E1729),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: light ? const Color(0xFFE1D9E8) : const Color(0xFF3A2D4D)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: light ? Colors.white : const Color(0xFF1E1729),
      indicatorColor: cs.primaryContainer,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cs.primary : null),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cs.onPrimary : cs.onSurface),
      ),
    ),
  );
}

class CrgsPlannerApp extends StatelessWidget {
  const CrgsPlannerApp({super.key, required this.store, required this.radio});
  final AppStore store;
  final RadioController radio;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return MaterialApp(
      title: 'CRGS Connect',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeShell(store: store, radio: radio),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, required this.radio});
  final AppStore store;
  final RadioController radio;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};

  Widget _tab(int i) {
    switch (i) {
      case 0:
        return TodayScreen(store: widget.store);
      case 1:
        return TimetableScreen(store: widget.store);
      case 2:
        return HomeworkScreen(store: widget.store);
      case 3:
        return RadioScreen(radio: widget.radio);
      default:
        return GamesScreen(store: widget.store);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: [
          // Purple header bar, like the school website.
          Container(
            width: double.infinity,
            color: dark ? Brand.barDark : Brand.purple,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('CRGS Connect', style: TextStyle(fontFamily: serif, fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    IconButton(
                      tooltip: 'Contacts',
                      color: Colors.white,
                      icon: const Icon(Icons.people_outline),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Contacts', style: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700, color: Colors.white)),
                            backgroundColor: dark ? Brand.barDark : Brand.purple,
                            iconTheme: const IconThemeData(color: Colors.white),
                          ),
                          body: PeopleScreen(store: widget.store),
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              // Tabs are built the first time they are opened, then kept alive.
              children: [for (var i = 0; i < 5; i++) _visited.contains(i) ? _tab(i) : const SizedBox.shrink()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
          FocusManager.instance.primaryFocus?.unfocus();
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Timetable'),
          NavigationDestination(icon: Icon(Icons.assignment_turned_in_outlined), selectedIcon: Icon(Icons.assignment_turned_in), label: 'Homework'),
          NavigationDestination(icon: Icon(Icons.radio_outlined), selectedIcon: Icon(Icons.radio), label: 'Radio'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: 'Games'),
        ],
      ),
    );
  }
}

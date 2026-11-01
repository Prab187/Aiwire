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
  final radio = RadioController(
    repo: LiveNewsRepository(),
    speaker: TtsSpeaker(),
    store: store,
    prefs: prefs,
  );
  runApp(CrgsPlannerApp(store: store, radio: radio));
}

ThemeData buildTheme(Brightness b) {
  final light = b == Brightness.light;
  final cs = ColorScheme.fromSeed(seedColor: Brand.purple, brightness: b)
      .copyWith(
        primary: light ? Brand.purple : Brand.purpleLight,
        onPrimary: light ? Colors.white : const Color(0xFF3A1B57),
        primaryContainer: light ? Brand.lavender : Brand.heroDark,
        onPrimaryContainer: light
            ? const Color(0xFF3A1B57)
            : const Color(0xFFEBDDFA),
        secondary: light ? Brand.green : Brand.greenLight,
        onSecondary: light ? Colors.white : const Color(0xFF0E2A12),
        surface: light ? Colors.white : Brand.cardDark,
        outlineVariant: light
            ? const Color(0xFFE6DEEE)
            : const Color(0xFF3A2D4D),
      );
  const pill = StadiumBorder();
  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: light ? Brand.page : Brand.pageDark,
    splashFactory: InkSparkle.splashFactory,
    // Soft purple-tinted shadows instead of hard outlines.
    cardTheme: CardThemeData(
      elevation: light ? 5 : 0,
      shadowColor: Brand.purple.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      color: light ? Colors.white : Brand.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: light ? const Color(0x1462338A) : const Color(0xFF3A2D4D),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: light ? Colors.white : Brand.cardDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: light ? Brand.purple : Brand.purpleMid,
      indicatorShape: pill,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? Colors.white
              : cs.onSurfaceVariant,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11.5,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? cs.primary
              : cs.onSurfaceVariant,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: pill),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(pill),
        side: WidgetStatePropertyAll(
          BorderSide(color: cs.primary.withValues(alpha: 0.35)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? cs.primary : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? cs.onPrimary : cs.onSurface,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
      title: 'CRGS Kampus',
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

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  final _visited = <int>{0};
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

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

  void _openContacts(bool dark) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text('Contacts', style: serifStyle(24, color: Colors.white)),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: dark ? Brand.barGradientDark : Brand.barGradient,
              ),
            ),
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PeopleScreen(store: widget.store),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          // Deep purple header with a fine gold line, in the school's colours.
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: dark ? Brand.barGradientDark : Brand.barGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CRGS Kampus',
                        style: serifStyle(
                          27,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Contacts',
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                      ),
                      icon: const Icon(Icons.people_outline),
                      onPressed: () => _openContacts(dark),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 2.5,
            decoration: const BoxDecoration(gradient: Brand.goldLine),
          ),
          Expanded(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              child: IndexedStack(
                index: _index,
                // Tabs are built the first time they are opened, then kept alive.
                children: [
                  for (var i = 0; i < 5; i++)
                    _visited.contains(i) ? _tab(i) : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
      // A floating pill-shaped tab bar.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: Brand.purple.withValues(alpha: dark ? 0.0 : 0.26),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
              border: dark ? Border.all(color: cs.outlineVariant) : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) {
                  if (i == _index) return;
                  FocusManager.instance.primaryFocus?.unfocus();
                  HapticFeedback.selectionClick().catchError((Object _) {});
                  setState(() {
                    _index = i;
                    _visited.add(i);
                  });
                  if (MediaQuery.disableAnimationsOf(context)) {
                    _fade.value = 1;
                  } else {
                    _fade.forward(from: 0);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Today',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Timetable',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.assignment_turned_in_outlined),
                    selectedIcon: Icon(Icons.assignment_turned_in_rounded),
                    label: 'Homework',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.radio_outlined),
                    selectedIcon: Icon(Icons.radio_rounded),
                    label: 'Radio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.sports_esports_outlined),
                    selectedIcon: Icon(Icons.sports_esports_rounded),
                    label: 'Games',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

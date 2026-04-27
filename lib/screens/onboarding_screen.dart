import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'AI News,\nDistilled.',
      'body': 'Stay ahead with the latest in artificial intelligence, curated and summarised for you.',
      'icon': '⚡',
    },
    {
      'title': 'Claude\nSummarises.',
      'body': 'Every article gets an instant AI summary and key insight powered by Claude.',
      'icon': '✦',
    },
    {
      'title': 'Read Your\nWay.',
      'body': 'Switch between dark and Kindle mode. Save articles. Long press the logo to switch.',
      'icon': '◐',
    },
  ];

  Future<void> _finish() async {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (context, i) {
              final p = _pages[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['icon']!, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 40),
                  Text(p['title']!, style: GoogleFonts.sourceSerif4(
                    fontSize: 42, fontWeight: FontWeight.w700,
                    color: Colors.white, height: 1.15)),
                  const SizedBox(height: 24),
                  Text(p['body']!, style: GoogleFonts.inter(
                    fontSize: 17, color: const Color(0xFF888888), height: 1.6)),
                ]),
              );
            },
          ),
        ),

        // Dots + button
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
          child: Column(children: [
            // Dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? Colors.white : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            )),
            const SizedBox(height: 32),

            // Button
            GestureDetector(
              onTap: () {
                if (_page < _pages.length - 1) {
                  _ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                } else {
                  _finish();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(child: Text(
                  _page < _pages.length - 1 ? 'Continue' : 'Start Reading',
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
                )),
              ),
            ),

            if (_page < _pages.length - 1) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _finish,
                child: Text('Skip', style: GoogleFonts.inter(
                    color: const Color(0xFF555555), fontSize: 14)),
              ),
            ],
          ]),
        ),
      ])),
    );
  }
}

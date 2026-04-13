import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoAnim;
  late AnimationController _fadeAnim;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _screenFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _logoAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnim, curve: Curves.easeOutCubic));

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnim, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)));

    _screenFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeAnim, curve: Curves.easeInOut));

    _start();
  }

  Future<void> _start() async {
    // Start logo animation
    await _logoAnim.forward();

    // Hold for a moment
    await Future.delayed(const Duration(milliseconds: 800));

    // Fade out
    await _fadeAnim.forward();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoAnim.dispose();
    _fadeAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _screenFade,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AnimatedBuilder(
            animation: _logoAnim,
            builder: (context, child) {
              return Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: child,
                ),
              );
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo mark
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF1E1E1E), width: 1),
                  ),
                  child: Center(
                    child: Stack(alignment: Alignment.center, children: [
                      // A
                      Positioned(
                        left: 8,
                        child: Text('A', style: GoogleFonts.sourceSerif4(
                          fontSize: 52, fontWeight: FontWeight.w700,
                          color: Colors.white, height: 1)),
                      ),
                      // W
                      Positioned(
                        right: 4,
                        child: Text('W', style: GoogleFonts.sourceSerif4(
                          fontSize: 52, fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.35), height: 1)),
                      ),
                      // I slash
                      Transform.rotate(
                        angle: -0.18,
                        child: Container(
                          width: 5, height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                // Wordmark
                RichText(text: TextSpan(children: [
                  TextSpan(text: 'AI', style: GoogleFonts.sourceSerif4(
                    fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                  TextSpan(text: 'Wire', style: GoogleFonts.sourceSerif4(
                    fontSize: 32, fontWeight: FontWeight.w300, color: Colors.white)),
                ])),
                const SizedBox(height: 8),
                Text(
                  'AI News, Distilled.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF555555),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}

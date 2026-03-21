import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _continueAsGuest() async {
    setState(() => _loading = true);
    await AuthService.continueAsGuest();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
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
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),

              // Wordmark
              RichText(text: TextSpan(children: [
                TextSpan(text: 'AI',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -0.3)),
                TextSpan(text: 'Wire',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 20, fontWeight: FontWeight.w300,
                    color: Colors.white, letterSpacing: -0.3)),
              ])),

              const Spacer(),

              // Headline
              Text(
                'Good stories\nstart here.',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'AI-powered news, summarised for you.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF666666),
                  height: 1.55,
                  letterSpacing: -0.1,
                ),
              ),

              const Spacer(),

              if (_loading)
                const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 1.5)),
                )
              else
                GestureDetector(
                  onTap: _continueAsGuest,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(
                      child: Text(
                        'Get Started',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D0D0D),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF3A3A3A),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

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
  bool _loadingApple = false;
  bool _loadingGoogle = false;
  bool _loadingGuest = false;

  Future<void> _goHome() async {
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

  Future<void> _signInWithApple() async {
    setState(() => _loadingApple = true);
    final success = await AuthService.signInWithApple();
    if (!mounted) return;
    setState(() => _loadingApple = false);
    if (success) {
      await _goHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apple Sign-In cancelled.'),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);
    final success = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loadingGoogle = false);
    if (success) {
      await _goHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-In cancelled.'),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _loadingGuest = true);
    await AuthService.continueAsGuest();
    await _goHome();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final isLoading = _loadingApple || _loadingGoogle || _loadingGuest;

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
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: Colors.white, height: 1.2, letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'AI-powered news, summarised for you.',
                style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF666666),
                  height: 1.55, letterSpacing: -0.1,
                ),
              ),

              const Spacer(),

              if (isLoading)
                const SizedBox(
                  height: 144,
                  child: Center(child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 1.5)),
                )
              else ...[
                // Apple Sign In
                _SignInButton(
                  onTap: _signInWithApple,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D0D0D),
                  icon: const Icon(Icons.apple, size: 20, color: Color(0xFF0D0D0D)),
                  label: 'Continue with Apple',
                ),
                const SizedBox(height: 12),

                // Google Sign In
                _SignInButton(
                  onTap: _signInWithGoogle,
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  icon: _GoogleLogo(),
                  label: 'Continue with Google',
                  border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
                ),
                const SizedBox(height: 20),

                // Guest link
                GestureDetector(
                  onTap: _continueAsGuest,
                  child: Center(
                    child: Text(
                      'Continue as guest',
                      style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF555555),
                        letterSpacing: -0.1,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFF555555),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy.',
                style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF3A3A3A), height: 1.5),
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

class _SignInButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget icon;
  final String label;
  final BoxBorder? border;

  const _SignInButton({
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(3),
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: foregroundColor, letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20, height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final inset = r * 0.18;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - inset);
    final sw = r * 0.36;

    void arc(Paint p, double start, double sweep) =>
        canvas.drawArc(rect, start, sweep, false, p);

    final blue   = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.butt;
    final red    = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.butt;
    final yellow = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.butt;
    final green  = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.butt;

    arc(blue,   -0.5,  2.7);
    arc(green,   2.2,  0.95);
    arc(yellow,  3.14, 0.95);
    arc(red,     4.09, 1.15);

    // Horizontal bar
    final bar = Paint()..color = const Color(0xFF4285F4)..strokeWidth = sw..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(cx, cy), Offset(cx + r - inset, cy), bar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

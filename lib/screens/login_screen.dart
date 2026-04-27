import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loadingApple = false;
  bool _loadingGoogle = false;
  bool _loadingGuest = false;
  AppMode _mode = AppMode.dark;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme_mode');
    final restored = switch (saved) {
      'light' => AppMode.light,
      'dark' => AppMode.dark,
      'kindle' => AppMode.kindle,
      _ => AppMode.dark,
    };
    if (mounted && restored != _mode) {
      setState(() => _mode = restored);
    }
  }

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
      final t = AppTheme(_mode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Apple Sign-In cancelled.',
            style: TextStyle(color: t.background)),
          backgroundColor: t.primary,
          behavior: SnackBarBehavior.floating,
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
      final t = AppTheme(_mode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In cancelled.',
            style: TextStyle(color: t.background)),
          backgroundColor: t.primary,
          behavior: SnackBarBehavior.floating,
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
    final t = AppTheme(_mode);
    SystemChrome.setSystemUIOverlayStyle(t.systemUi);
    final isLoading = _loadingApple || _loadingGoogle || _loadingGuest;

    return Scaffold(
      backgroundColor: t.background,
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
                    color: t.primary, letterSpacing: -0.3)),
                TextSpan(text: 'Wire',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 20, fontWeight: FontWeight.w300,
                    color: t.primary, letterSpacing: -0.3)),
              ])),

              const Spacer(),

              // Headline
              Text(
                'Good stories\nstart here.',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: t.primary, height: 1.2, letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'AI-powered news, summarised for you.',
                style: GoogleFonts.inter(
                  fontSize: 13, color: t.muted,
                  height: 1.55, letterSpacing: -0.1,
                ),
              ),

              const Spacer(),

              if (isLoading)
                SizedBox(
                  height: 144,
                  child: Center(child: CircularProgressIndicator(
                    color: t.primary, strokeWidth: 1.5)),
                )
              else ...[
                // Apple Sign In — official Apple-approved button
                SignInWithAppleButton(
                  onPressed: _signInWithApple,
                  style: _mode == AppMode.light
                      ? SignInWithAppleButtonStyle.black
                      : SignInWithAppleButtonStyle.white,
                  height: 48,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 12),

                // Google Sign In
                _SignInButton(
                  onTap: _signInWithGoogle,
                  backgroundColor: t.surface,
                  foregroundColor: t.primary,
                  icon: _GoogleLogo(),
                  label: 'Continue with Google',
                  border: Border.all(color: t.divider, width: 1),
                ),
                const SizedBox(height: 20),

                // Guest link
                GestureDetector(
                  onTap: _continueAsGuest,
                  child: Center(
                    child: Text(
                      'Continue as guest',
                      style: GoogleFonts.inter(
                        fontSize: 13, color: t.muted,
                        letterSpacing: -0.1,
                        decoration: TextDecoration.underline,
                        decorationColor: t.muted,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              _LegalText(theme: t),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  final AppTheme theme;
  const _LegalText({required this.theme});

  Future<void> _openTerms() async {
    final uri = Uri.parse('https://aiwire.app/terms');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openPrivacyPolicy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.inter(
      fontSize: 11, color: theme.muted.withValues(alpha: 0.6), height: 1.5);
    final linkStyle = GoogleFonts.inter(
      fontSize: 11,
      color: theme.muted,
      height: 1.5,
      decoration: TextDecoration.underline,
      decorationColor: theme.muted,
    );

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text('By continuing, you agree to our ', style: baseStyle),
          GestureDetector(
            onTap: _openTerms,
            child: Text('Terms of Service', style: linkStyle),
          ),
          Text(' and ', style: baseStyle),
          GestureDetector(
            onTap: () => _openPrivacyPolicy(context),
            child: Text('Privacy Policy', style: linkStyle),
          ),
          Text('.', style: baseStyle),
        ],
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

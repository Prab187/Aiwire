import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppTheme theme;
  const ProfileScreen({super.key, required this.theme});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _name;
  String? _email;
  bool _isGuest = true;

  AppTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(widget.theme.systemUi);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final guest = await AuthService.isGuest();
    final name = await AuthService.userName();
    final email = await AuthService.userEmail();
    setState(() {
      _isGuest = guest;
      _name = name;
      _email = email;
    });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Sign out?',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: t.primary)),
        content: Text('You will need to sign in again to access your account.',
          style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: t.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.background,
            padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: t.primary, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 2),
              Text('Profile',
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: t.primary, letterSpacing: -0.2,
                )),
            ]),
          ),
          Divider(height: 1, color: t.divider),

          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // User info header
                Container(
                  color: t.background,
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: t.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.border, width: 1),
                      ),
                      child: Icon(
                        _isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
                        color: _isGuest ? t.muted : t.primary, size: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isGuest
                          ? 'Reading as guest'
                          : (_name?.isNotEmpty == true ? _name! : 'Signed in'),
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: t.primary, letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isGuest
                          ? 'Your reading history is saved on this device.'
                          : (_email ?? ''),
                      style: GoogleFonts.inter(
                        fontSize: 13, color: t.muted, height: 1.5, letterSpacing: -0.1,
                      ),
                    ),
                  ]),
                ),

                Divider(height: 1, color: t.divider),

                _menuRow(
                  icon: Icons.history_rounded,
                  label: 'Reading history',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => HistoryScreen(theme: t))),
                ),

                Divider(height: 1, color: t.divider),

                if (_isGuest) ...[
                  _menuRow(
                    icon: Icons.login_rounded,
                    label: 'Sign in',
                    onTap: () => Navigator.of(context).pushAndRemoveUntil(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const LoginScreen(),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                      (_) => false,
                    ),
                  ),
                  Divider(height: 1, color: t.divider),
                ] else ...[
                  _menuRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    onTap: _signOut,
                    destructive: true,
                  ),
                  Divider(height: 1, color: t.divider),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? Colors.red : t.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: t.background,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(children: [
          Icon(icon, color: destructive ? Colors.red : t.secondary, size: 18),
          const SizedBox(width: 12),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w400,
              color: color, letterSpacing: -0.1,
            )),
          const Spacer(),
          if (!destructive)
            Icon(Icons.chevron_right_rounded, color: t.muted, size: 18),
        ]),
      ),
    );
  }
}

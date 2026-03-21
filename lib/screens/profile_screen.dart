import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppTheme theme;
  const ProfileScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    SystemChrome.setSystemUIOverlayStyle(t.systemUi);
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.background,
            padding: const EdgeInsets.fromLTRB(6, 12, 20, 12),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: t.primary,
                  letterSpacing: -0.2,
                )),
            ]),
          ),
          Divider(height: 1, color: t.divider),

          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      child: Icon(Icons.person_outline_rounded,
                        color: t.muted, size: 22),
                    ),
                    const SizedBox(height: 16),
                    Text('Reading as guest',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: t.primary,
                        letterSpacing: -0.3,
                      )),
                    const SizedBox(height: 6),
                    Text('Your reading history is saved on this device.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: t.muted,
                        height: 1.5,
                        letterSpacing: -0.1,
                      )),
                  ]),
                ),

                Divider(height: 1, color: t.divider),

                _menuRow(
                  t,
                  icon: Icons.history_rounded,
                  label: 'Reading history',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => HistoryScreen(theme: t))),
                ),

                Divider(height: 1, color: t.divider),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _menuRow(AppTheme t, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? t.muted : t.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: t.background,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(children: [
          Icon(icon, color: destructive ? t.muted : t.secondary, size: 18),
          const SizedBox(width: 12),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: color,
              letterSpacing: -0.1,
            )),
          const Spacer(),
          if (!destructive)
            Icon(Icons.chevron_right_rounded, color: t.muted, size: 18),
        ]),
      ),
    );
  }
}

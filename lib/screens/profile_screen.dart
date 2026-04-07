import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'paywall_screen.dart';
import 'privacy_policy_screen.dart';

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
  bool _isPremium = false;

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
    final premium = await SubscriptionService.isPremium();
    if (mounted) setState(() {
      _isGuest = guest;
      _name = name;
      _email = email;
      _isPremium = premium;
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
          // Header
          Container(
            color: t.background,
            padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.primary, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 2),
              Text('Profile',
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: t.primary, letterSpacing: -0.2)),
            ]),
          ),
          Divider(height: 1, color: t.divider),

          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // User info + subscription badge
                Container(
                  color: t.background,
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: t.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.border, width: 1),
                        ),
                        child: Icon(
                          _isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
                          color: _isGuest ? t.muted : t.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isGuest ? 'Guest' : (_name?.isNotEmpty == true ? _name! : 'Signed in'),
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 20, fontWeight: FontWeight.w700,
                              color: t.primary, letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text(
                            _isGuest ? 'Reading history saved on device' : (_email ?? ''),
                            style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 16),
                    // Subscription badge
                    GestureDetector(
                      onTap: _isPremium ? null : () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => PaywallScreen(
                            theme: t,
                            onSubscribed: () => _loadUser(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isPremium
                            ? t.accent.withValues(alpha: 0.1)
                            : t.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isPremium ? t.accent.withValues(alpha: 0.3) : t.divider,
                            width: 0.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            _isPremium ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded,
                            size: 14,
                            color: _isPremium ? t.accent : t.muted),
                          const SizedBox(width: 6),
                          Text(
                            _isPremium ? 'Premium' : 'Free plan · Upgrade',
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _isPremium ? t.accent : t.muted)),
                        ]),
                      ),
                    ),
                  ]),
                ),

                Divider(height: 1, color: t.divider),

                // ── Account ──
                _sectionLabel('Account'),
                _menuRow(
                  icon: Icons.history_rounded,
                  label: 'Reading history',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => HistoryScreen(theme: t))),
                ),
                if (!_isPremium)
                  _menuRow(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Upgrade to Premium',
                    accent: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => PaywallScreen(
                          theme: t,
                          onSubscribed: () => _loadUser(),
                        ),
                      );
                    },
                  ),
                if (_isPremium)
                  _menuRow(
                    icon: Icons.credit_card_rounded,
                    label: 'Manage subscription',
                    onTap: () async {
                      final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
                      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),

                Divider(height: 1, color: t.divider),

                // ── Legal ──
                _sectionLabel('Legal'),
                _menuRow(
                  icon: Icons.shield_outlined,
                  label: 'Privacy Policy',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                ),
                _menuRow(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () async {
                    final uri = Uri.parse('https://aiwire.app/terms');
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),

                Divider(height: 1, color: t.divider),

                // ── Auth ──
                if (_isGuest)
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
                  )
                else
                  _menuRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    onTap: _signOut,
                    destructive: true,
                  ),

                // ── Version ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AIWire', style: GoogleFonts.sourceSerif4(
                      fontSize: 14, fontWeight: FontWeight.w700, color: t.muted.withValues(alpha: 0.5))),
                    const SizedBox(height: 2),
                    Text('Version 1.0.0 (1)', style: GoogleFonts.inter(
                      fontSize: 12, color: t.muted.withValues(alpha: 0.4))),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: t.muted, letterSpacing: 0.5)),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
    bool accent = false,
  }) {
    final color = destructive ? Colors.red : accent ? t.accent : t.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: t.background,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Icon(icon, color: destructive ? Colors.red : accent ? t.accent : t.secondary, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w400,
              color: color, letterSpacing: -0.1))),
          if (!destructive)
            Icon(Icons.chevron_right_rounded, color: t.muted, size: 18),
        ]),
      ),
    );
  }
}

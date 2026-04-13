import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/ai_quota_guard.dart';
import '../screens/paywall_screen.dart';

/// Shows a bottom sheet when the user has hit their daily free AI quota.
/// Returns true if the user has quota remaining (proceed with the call).
/// Returns false if quota is exhausted (paywall was shown).
Future<bool> checkAiQuotaOrShowPaywall(BuildContext context, AppTheme theme) async {
  if (await AiQuotaGuard.canUse()) return true;

  if (!context.mounted) return false;
  final t = theme;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          width: 36, height: 4, margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: t.muted.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2)))),
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.auto_awesome_rounded, size: 26, color: t.accent),
        ),
        const SizedBox(height: 20),
        Text("You've used today's free AI quota",
          style: GoogleFonts.sourceSerif4(
            fontSize: 20, fontWeight: FontWeight.w700,
            color: t.primary, letterSpacing: -0.3),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Free users get ${AiQuotaGuard.dailyFreeLimit} AI actions per day. '
          'Upgrade to Premium for unlimited access.',
          style: GoogleFonts.inter(
            fontSize: 13, color: t.muted, height: 1.5),
          textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PaywallScreen(theme: t)));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: t.primary,
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('Upgrade to Premium',
              style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: t.background))),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('Try again tomorrow',
            style: GoogleFonts.inter(fontSize: 13, color: t.muted)),
        ),
      ]),
    ),
  );
  return false;
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_screen.dart';

class PaywallScreen extends StatefulWidget {
  final AppTheme theme;
  final VoidCallback? onSubscribed;
  const PaywallScreen({super.key, required this.theme, this.onSubscribed});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = false;
  bool _restoring = false;
  bool _yearlySelected = true;

  Future<void> _subscribe() async {
    setState(() => _loading = true);
    try {
      await SubscriptionService.purchase(yearly: _yearlySelected);
      if (mounted) {
        widget.onSubscribed?.call();
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Purchase failed. Try again.',
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: widget.theme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    await SubscriptionService.restorePurchases();
    if (mounted) setState(() => _restoring = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final monthlyPrice = SubscriptionService.product?.price ?? '\$2.49';
    final yearlyPrice = SubscriptionService.productYearly?.price ?? '\$24.99';
    final price = _yearlySelected ? yearlyPrice : monthlyPrice;
    final period = _yearlySelected ? 'year' : 'month';
    final trialDays = SubscriptionService.introductoryOfferDays(yearly: _yearlySelected);
    final ctaText = trialDays != null
        ? 'Start your $trialDays-day free trial'
        : 'Start Free Trial';

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, color: t.muted, size: 22),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: t.accent, size: 22),
                  ),
                  const SizedBox(height: 22),
                  Text('Unlock AIWire\nPremium',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: t.primary,
                        height: 1.15,
                        letterSpacing: -0.5,
                      )),
                  const SizedBox(height: 10),
                  Text('Unlimited AI summaries. Read smarter, every day.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: t.muted,
                        height: 1.5,
                        letterSpacing: -0.1,
                      )),
                  const SizedBox(height: 32),
                  _feature(t, 'Unlimited AI summaries',
                      'No daily limits — read as much as you want'),
                  _feature(t, 'Powered by Claude',
                      'Every article summarized by Anthropic\'s Claude AI'),
                  _feature(t, 'Editorial prose style',
                      'Clear, flowing summaries — not bullet points'),
                  _feature(t, 'Early access',
                      'Be first to get new AIWire features'),
                  const Spacer(),
                  // Plan toggle
                  Container(
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(children: [
                      _planOption(t, 'Monthly', '$monthlyPrice/mo', !_yearlySelected, () {
                        setState(() => _yearlySelected = false);
                      }),
                      _planOption(t, 'Yearly', '$yearlyPrice/yr · Save 17%', _yearlySelected, () {
                        setState(() => _yearlySelected = true);
                      }),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(trialDays != null
                          ? '$trialDays-day free trial — cancel anytime before and you won\'t be charged.'
                          : 'Cancel anytime.',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: t.muted, height: 1.4, letterSpacing: -0.1)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _subscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primary,
                        foregroundColor: t.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      child: _loading
                          ? SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: t.background, strokeWidth: 2))
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(ctaText,
                                  style: GoogleFonts.inter(
                                      fontSize: 15, fontWeight: FontWeight.w600)),
                              Text('then $price/$period',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: t.background.withOpacity(0.7))),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Maybe later',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: t.muted)),
                      ),
                      Text(' · ',
                          style: GoogleFonts.inter(
                              color: t.muted, fontSize: 13)),
                      GestureDetector(
                        onTap: _restore,
                        child: Text(
                            _restoring
                                ? 'Restoring...'
                                : 'Restore purchases',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: t.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse('https://aiwire.app/terms');
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        child: Text('Terms',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: t.muted.withValues(alpha: 0.6),
                                decoration: TextDecoration.underline,
                                decorationColor: t.muted.withValues(alpha: 0.3))),
                      ),
                      Text('  ·  ',
                          style: GoogleFonts.inter(
                              color: t.muted.withValues(alpha: 0.4), fontSize: 11)),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                        },
                        child: Text('Privacy',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: t.muted.withValues(alpha: 0.6),
                                decoration: TextDecoration.underline,
                                decorationColor: t.muted.withValues(alpha: 0.3))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _planOption(AppTheme t, String label, String sub, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? t.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? t.background : t.primary)),
            const SizedBox(height: 2),
            Text(sub,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: selected ? t.background.withOpacity(0.7) : t.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _feature(AppTheme t, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_circle_rounded, size: 17, color: t.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.primary,
                        letterSpacing: -0.1)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: t.muted, height: 1.4)),
              ]),
        ),
      ]),
    );
  }
}

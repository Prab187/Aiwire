import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.sourceSerif4(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: _PolicyBody(),
      ),
    );
  }
}

class _PolicyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          'AIWire Privacy Policy',
          isTitle: true,
        ),
        _body('Last updated: March 2025'),
        const SizedBox(height: 8),
        _body(
          'This Privacy Policy explains how AIWire ("we", "us", or "our") '
          'collects, uses, and protects your personal information when you use '
          'the AIWire mobile application. By using AIWire you agree to the '
          'practices described in this policy.',
        ),

        _section('1. Information We Collect'),
        _subSection('Account information'),
        _body(
          'When you sign in with Apple or Google we receive your name and '
          'email address as provided by those identity providers. We store '
          'this information to identify your account.',
        ),
        _subSection('Usage data'),
        _body(
          'We collect information about how you use the app, including '
          'articles you read, topics you follow, bookmarks you save, and '
          'search queries you submit. This data is used to personalise your '
          'news feed and improve the service.',
        ),
        _subSection('Content sent to AI'),
        _body(
          'When you use AI-powered features, certain content is transmitted '
          'to our AI service (Anthropic Claude API) to generate responses. '
          'This includes:',
        ),
        _bullets([
          'Article text — when you request an AI summary of a news article.',
          'Resume content — when you upload a resume for career analysis, ATS scoring, and job matching.',
          'Mock interview answers — when you practice interviews, your spoken or typed responses are sent for AI scoring and feedback.',
          'Career profile data — your skills, experience level, and job title are used to generate personalised career recommendations.',
          'Video transcripts — YouTube video captions are sent for AI summarisation.',
        ]),
        _body(
          'We do not store this content on our servers beyond the time needed '
          'to deliver your response. Anthropic does not use your data to train '
          'their models.',
        ),
        _subSection('Device and analytics data'),
        _body(
          'We may collect anonymised device identifiers, operating system '
          'version, and crash reports to diagnose technical issues and improve '
          'app stability.',
        ),

        _section('2. How We Use Your Information'),
        _bullets([
          'To create and maintain your account.',
          'To personalise your news feed and AI-generated summaries.',
          'To process subscription payments via RevenueCat and Apple '
              'StoreKit / Google Play Billing.',
          'To send you important account-related notifications (not marketing '
              'without your consent).',
          'To analyse aggregate usage trends and improve app features.',
          'To comply with legal obligations.',
        ]),

        _section('3. Third-Party Services'),
        _body(
          'AIWire integrates with the following third-party services. Each '
          'provider operates under its own privacy policy.',
        ),
        const SizedBox(height: 12),
        _thirdPartyRow('Anthropic (Claude API)',
            'Powers all AI features: article summaries, resume analysis, '
            'career recommendations, mock interview scoring, salary '
            'estimates, and video summaries. Content is sent to Anthropic '
            'servers to generate responses. Anthropic does not '
            'use API inputs to train its models without consent.'),
        _thirdPartyRow('Apple Sign In',
            'Provides authentication via your Apple ID. Governed by '
            "Apple's Privacy Policy."),
        _thirdPartyRow('Google Sign In',
            'Provides authentication via your Google account. Governed by '
            "Google's Privacy Policy."),
        _thirdPartyRow('NewsAPI',
            'Supplies news article metadata and headlines. No personal '
            'data is shared with NewsAPI.'),
        _thirdPartyRow('RevenueCat / Apple StoreKit',
            'Manages in-app purchase subscriptions. Payment processing is '
            'handled entirely by Apple; we receive subscription status only.'),

        _section('4. Data Retention'),
        _body(
          'We retain account and usage data for as long as your account is '
          'active. If you delete your account, your personal data is removed '
          'from our systems within 30 days, except where retention is required '
          'by applicable law.',
        ),

        _section('5. Your Rights'),
        _body(
          'Depending on your location, you may have the right to:',
        ),
        _bullets([
          'Access the personal data we hold about you.',
          'Request correction of inaccurate data.',
          'Request deletion of your data ("right to be forgotten").',
          'Object to or restrict certain processing.',
          'Export your data in a portable format.',
        ]),
        _body(
          'To exercise any of these rights, please contact us at '
          'privacy@aiwire.app. We will respond within 30 days.',
        ),

        _section('6. Data Security'),
        _body(
          'We implement industry-standard security measures including '
          'encryption in transit (TLS) and at rest. Access to personal data '
          'is restricted to authorised personnel only. No method of '
          'transmission over the internet is 100% secure, and we cannot '
          'guarantee absolute security.',
        ),

        _section('7. Children\'s Privacy'),
        _body(
          'AIWire is not directed at children under 13 years of age. We do '
          'not knowingly collect personal information from children under 13. '
          'If you believe we have inadvertently collected such information, '
          'please contact us immediately.',
        ),

        _section('8. Changes to This Policy'),
        _body(
          'We may update this Privacy Policy from time to time. Material '
          'changes will be notified via the app or by email. Your continued '
          'use of AIWire after changes are posted constitutes your acceptance '
          'of the updated policy.',
        ),

        _section('9. Governing Law'),
        _body(
          'This Privacy Policy is governed by the laws of England and Wales. '
          'Any disputes relating to this policy shall be subject to the '
          'exclusive jurisdiction of the courts of England and Wales.',
        ),

        _section('10. Contact Us'),
        _body(
          'If you have any questions or concerns about this Privacy Policy or '
          'our data practices, please contact us at:',
        ),
        const SizedBox(height: 8),
        Text(
          'privacy@aiwire.app',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF888888),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF888888),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _section(String text, {bool isTitle = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isTitle ? 0 : 24, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.sourceSerif4(
          fontSize: isTitle ? 20 : 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.3,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _subSection(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFCCCCCC),
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: const Color(0xFF888888),
        height: 1.6,
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _bullets(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF888888),
                      height: 1.6,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF888888),
                        height: 1.6,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _thirdPartyRow(String name, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFCCCCCC),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF666666),
              height: 1.55,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

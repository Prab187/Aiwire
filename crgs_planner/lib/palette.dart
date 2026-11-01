import 'package:flutter/material.dart';

/// Colours taken from the Colchester Royal Grammar School website: purple
/// header, white page, green stripe, gold crest ring. Colours only, no crest.
class Brand {
  static const purple = Color(0xFF62338A);
  static const purpleDeep = Color(0xFF3B1D57);
  static const purpleMid = Color(0xFF7A47A8);
  static const green = Color(0xFF3F8F45);
  static const gold = Color(0xFFB8872C);
  static const goldSoft = Color(0xFFE9D6A0);
  static const lavender = Color(0xFFEFE8F5);
  static const page = Color(0xFFF5F1F9);

  // Dark mode
  static const barDark = Color(0xFF241238);
  static const heroDark = Color(0xFF3E2263);
  static const pageDark = Color(0xFF130E1B);
  static const cardDark = Color(0xFF1E1729);
  static const purpleLight = Color(0xFFD2BDEB);
  static const greenLight = Color(0xFF7FCB86);

  static const barGradient = LinearGradient(
    colors: [Color(0xFF3B1D57), Color(0xFF62338A)],
  );
  static const barGradientDark = LinearGradient(
    colors: [Color(0xFF1A0C2B), Color(0xFF2E1A47)],
  );
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B1D57), Color(0xFF62338A), Color(0xFF7A47A8)],
  );
  static const heroGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF241238), Color(0xFF3E2263), Color(0xFF52307F)],
  );
  static const goldLine = LinearGradient(
    colors: [Color(0xFFB8872C), Color(0xFFE9D6A0), Color(0xFFB8872C)],
  );
}

/// Headings use DM Serif Display, bundled with the app (see assets/fonts).
/// It has one weight, so never ask for bold with it.
const serif = 'DMSerifDisplay';

TextStyle serifStyle(
  double size, {
  Color? color,
  bool italic = false,
  double? letterSpacing,
  double? height,
}) => TextStyle(
  fontFamily: serif,
  fontSize: size,
  color: color,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  fontWeight: FontWeight.w400,
  letterSpacing: letterSpacing,
  height: height,
);

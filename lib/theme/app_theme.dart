import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppMode { light, dark, kindle }

class AppTheme {
  final AppMode mode;
  const AppTheme(this.mode);

  bool get isLight => mode == AppMode.light;
  bool get isDark => mode == AppMode.dark;
  bool get isKindle => mode == AppMode.kindle;

  Color get background {
    if (isDark) return const Color(0xFF0F172A);
    if (isKindle) return const Color(0xFFF5EDD6);
    return const Color(0xFFFFFFFF);
  }

  Color get surface {
    if (isDark) return const Color(0xFF1E293B);
    if (isKindle) return const Color(0xFFEDE4C8);
    return const Color(0xFFF8FAFC);
  }

  Color get edgeDark {
    if (isDark) return const Color(0xFF0F172A);
    if (isKindle) return const Color(0xFFE8DFC4);
    return const Color(0xFFF1F5F9);
  }

  Color get primary {
    if (isDark) return const Color(0xFFF1F5F9);
    if (isKindle) return const Color(0xFF2C1810);
    return const Color(0xFF0F172A);
  }

  Color get secondary {
    if (isDark) return const Color(0xFF94A3B8);
    if (isKindle) return const Color(0xFF6B4C3B);
    return const Color(0xFF475569);
  }

  Color get muted {
    if (isDark) return const Color(0xFF64748B);
    if (isKindle) return const Color(0xFF9C7B6B);
    return const Color(0xFF94A3B8);
  }

  Color get divider {
    if (isDark) return const Color(0xFF334155);
    if (isKindle) return const Color(0xFFDDD3B8);
    return const Color(0xFFE2E8F0);
  }

  Color get border {
    if (isDark) return const Color(0xFF334155);
    if (isKindle) return const Color(0xFFCFC3A8);
    return const Color(0xFFE2E8F0);
  }

  Color get accent {
    if (isDark) return const Color(0xFF60A5FA);
    if (isKindle) return const Color(0xFF5A8A5A);
    return const Color(0xFF2563EB);
  }

  SystemUiOverlayStyle get systemUi =>
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}

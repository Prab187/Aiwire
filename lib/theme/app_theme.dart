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
    if (isDark) return const Color(0xFF121212);
    if (isKindle) return const Color(0xFFF5EDD6);
    return const Color(0xFFFFFFFF);
  }

  Color get surface {
    if (isDark) return const Color(0xFF1A1A1A);
    if (isKindle) return const Color(0xFFEDE4C8);
    return const Color(0xFFF7F7F5);
  }

  Color get edgeDark {
    if (isDark) return const Color(0xFF121212);
    if (isKindle) return const Color(0xFFE8DFC4);
    return const Color(0xFFF7F7F5);
  }

  Color get primary {
    if (isDark) return const Color(0xFFE6E3D3);
    if (isKindle) return const Color(0xFF2C1810);
    return const Color(0xFF242424);
  }

  Color get secondary {
    if (isDark) return const Color(0xFF9E9E9E);
    if (isKindle) return const Color(0xFF6B4C3B);
    return const Color(0xFF6B6B6B);
  }

  Color get muted {
    if (isDark) return const Color(0xFF757575);
    if (isKindle) return const Color(0xFF9C7B6B);
    return const Color(0xFF9E9E9E);
  }

  Color get divider {
    if (isDark) return const Color(0xFF2A2A2A);
    if (isKindle) return const Color(0xFFDDD3B8);
    return const Color(0xFFE6E6E6);
  }

  Color get border {
    if (isDark) return const Color(0xFF2A2A2A);
    if (isKindle) return const Color(0xFFCFC3A8);
    return const Color(0xFFE6E6E6);
  }

  Color get accent {
    if (isDark) return const Color(0xFF6EBF6E);
    if (isKindle) return const Color(0xFF5A8A5A);
    return const Color(0xFF3D7A3D);
  }

  SystemUiOverlayStyle get systemUi =>
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}

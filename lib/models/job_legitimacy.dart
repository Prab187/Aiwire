import 'package:flutter/material.dart';

enum LegitimacyLevel { verified, caution, suspicious }

class JobLegitimacy {
  final LegitimacyLevel level;
  final String reason;
  final int score;

  const JobLegitimacy({required this.level, required this.reason, required this.score});

  String get label {
    switch (level) {
      case LegitimacyLevel.verified: return 'Verified';
      case LegitimacyLevel.caution: return 'Caution';
      case LegitimacyLevel.suspicious: return 'Suspicious';
    }
  }

  Color get color {
    switch (level) {
      case LegitimacyLevel.verified: return const Color(0xFF22C55E);
      case LegitimacyLevel.caution: return const Color(0xFFF59E0B);
      case LegitimacyLevel.suspicious: return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (level) {
      case LegitimacyLevel.verified: return Icons.verified_outlined;
      case LegitimacyLevel.caution: return Icons.warning_amber_rounded;
      case LegitimacyLevel.suspicious: return Icons.error_outline_rounded;
    }
  }
}

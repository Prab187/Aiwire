import 'package:flutter/material.dart';

class JobGrade {
  final int skillMatch;        // 0-100 — how many of user's skills match this job
  final int roleLevelFit;      // 0-100 — seniority alignment
  final int locationFit;       // 0-100 — can user realistically work here
  final int salaryFit;         // 0-100 — is salary disclosed and in range
  final int companyReputation; // 0-100 — is this a legitimate / known employer

  const JobGrade({
    required this.skillMatch,
    required this.roleLevelFit,
    required this.locationFit,
    required this.salaryFit,
    required this.companyReputation,
  });

  /// HONEST composite score. Skill match is a GATE, not just a weighted factor.
  ///
  /// Rationale: If you don't have the skills, you don't match the job — full stop.
  /// Location, salary, and reputation are tiebreakers between roles you CAN
  /// actually do. Without skill fit, they're irrelevant padding.
  ///
  /// Formula:
  ///   - Zero skill match → composite = 0 (never "43% match with no skills")
  ///   - Low skill match (< 20) → composite = skillMatch (weak match, shown honestly)
  ///   - Moderate skill match (20-50) → skillMatch + up to 10 bonus from other dims
  ///   - Strong skill match (>= 50) → traditional weighted blend
  int get composite {
    if (skillMatch == 0) return 0;
    if (skillMatch < 20) {
      // Weak skill match — cap the composite at the skillMatch value.
      // We don't inflate someone to 30% when their skills are really at 10%.
      return skillMatch;
    }
    if (skillMatch < 50) {
      // Moderate skill match — modest bonus from other dimensions,
      // but composite can never exceed skillMatch + 10.
      final otherAvg = (roleLevelFit + locationFit + salaryFit + companyReputation) / 4;
      final bonus = (otherAvg / 100 * 10).round(); // max +10
      return (skillMatch + bonus).clamp(0, skillMatch + 10);
    }
    // Strong skill match — full weighted blend
    return (skillMatch * 0.55 +
            roleLevelFit * 0.15 +
            locationFit * 0.15 +
            salaryFit * 0.10 +
            companyReputation * 0.05).round().clamp(0, 100);
  }

  String get letter {
    final c = composite;
    if (c >= 80) return 'A';
    if (c >= 65) return 'B';
    if (c >= 50) return 'C';
    if (c >= 35) return 'D';
    if (c >= 20) return 'E';
    return 'F';
  }

  Color get color {
    final c = composite;
    if (c >= 80) return const Color(0xFF22C55E);  // green
    if (c >= 65) return const Color(0xFF34D399);  // teal
    if (c >= 50) return const Color(0xFFF59E0B);  // amber
    if (c >= 35) return const Color(0xFFF97316);  // orange
    if (c >= 20) return const Color(0xFFEF4444);  // red
    return const Color(0xFFDC2626);                // dark red
  }

  String get percentLabel => '$composite%';

  /// One-line honest reason — focuses on the real driver, not padding.
  String get reason {
    if (skillMatch == 0) return 'No skill overlap';
    if (skillMatch < 20) return 'Very few skills match';
    if (skillMatch < 50) return 'Partial skill match';

    // Strong skill match — surface the real differentiator
    final dims = <String, int>{
      'Skill match': skillMatch,
      'Role level fit': roleLevelFit,
      'Location fit': locationFit,
    };
    final strongest = dims.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final weakest = dims.entries.reduce((a, b) => a.value <= b.value ? a : b);

    if (composite >= 75) return 'Strong ${strongest.key.toLowerCase()}';
    if (composite >= 50) return '${weakest.key} could be stronger';
    return 'Low ${weakest.key.toLowerCase()}';
  }
}

import 'package:flutter/material.dart';

class JobGrade {
  final int skillMatch;        // 0-100
  final int roleLevelFit;      // 0-100
  final int locationFit;       // 0-100
  final int salaryFit;         // 0-100
  final int companyReputation; // 0-100

  const JobGrade({
    required this.skillMatch,
    required this.roleLevelFit,
    required this.locationFit,
    required this.salaryFit,
    required this.companyReputation,
  });

  /// Weighted composite score
  int get composite =>
      (skillMatch * 0.40 +
       roleLevelFit * 0.20 +
       locationFit * 0.15 +
       salaryFit * 0.15 +
       companyReputation * 0.10).round();

  String get letter {
    final c = composite;
    if (c >= 90) return 'A';
    if (c >= 75) return 'B';
    if (c >= 60) return 'C';
    if (c >= 45) return 'D';
    if (c >= 30) return 'E';
    return 'F';
  }

  Color get color {
    switch (letter) {
      case 'A': return const Color(0xFF22C55E);
      case 'B': return const Color(0xFF34D399);
      case 'C': return const Color(0xFFF59E0B);
      case 'D': return const Color(0xFFF97316);
      case 'E': return const Color(0xFFEF4444);
      default:  return const Color(0xFFDC2626);
    }
  }

  /// One-line reason focusing on the weakest dimension
  String get reason {
    final dims = <String, int>{
      'Skill match': skillMatch,
      'Role level fit': roleLevelFit,
      'Location fit': locationFit,
      'Salary range': salaryFit,
      'Company reputation': companyReputation,
    };
    final strongest = dims.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final weakest = dims.entries.reduce((a, b) => a.value <= b.value ? a : b);

    if (composite >= 75) {
      return 'Strong ${strongest.key.toLowerCase()}';
    } else if (composite >= 45) {
      return '${weakest.key} could be stronger';
    } else {
      return 'Low ${weakest.key.toLowerCase()}';
    }
  }
}

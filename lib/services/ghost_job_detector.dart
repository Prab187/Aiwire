import '../models/job.dart';
import '../models/job_legitimacy.dart';

class GhostJobDetector {
  /// Evaluate all jobs at once (needed for duplicate detection)
  static Map<String, JobLegitimacy> evaluateAll(List<Job> jobs) {
    // Pre-compute duplicate title+company combos
    final comboCounts = <String, int>{};
    for (final j in jobs) {
      final key = '${j.title.toLowerCase().trim()}|${j.company.toLowerCase().trim()}';
      comboCounts[key] = (comboCounts[key] ?? 0) + 1;
    }

    final result = <String, JobLegitimacy>{};
    for (final j in jobs) {
      final key = '${j.title.toLowerCase().trim()}|${j.company.toLowerCase().trim()}';
      final isDuplicate = (comboCounts[key] ?? 0) > 1;
      result[j.id] = _evaluate(j, isDuplicate);
    }
    return result;
  }

  static JobLegitimacy _evaluate(Job job, bool isDuplicate) {
    var score = 100;
    String worstReason = '';

    // 1. Job age
    final age = _daysSincePosted(job.postedAt);
    if (age != null) {
      if (age > 90) {
        score -= 50;
        if (worstReason.isEmpty) worstReason = 'Posted over 90 days ago';
      } else if (age > 60) {
        score -= 35;
        if (worstReason.isEmpty) worstReason = 'Posted over 60 days ago';
      } else if (age > 30) {
        score -= 15;
      }
    }
    // If date is unparseable, neutral (no deduction)

    // 2. No apply URL
    if (job.applyUrl.isEmpty) {
      score -= 25;
      if (worstReason.isEmpty) worstReason = 'No apply link available';
    }

    // 3. No salary info
    if (job.salaryRange == 'Not disclosed' || job.salaryRange.isEmpty) {
      score -= 15;
      if (worstReason.isEmpty) worstReason = 'Salary not disclosed';
    }

    // 4. No company logo
    if (job.companyLogo == null || job.companyLogo!.isEmpty) {
      score -= 10;
    }

    // 5. Description too short
    if (job.description.length < 50) {
      score -= 20;
      if (worstReason.isEmpty) worstReason = 'Very short description';
    } else if (job.description.length < 100) {
      score -= 10;
    }

    // 6. Duplicate posting
    if (isDuplicate) {
      score -= 20;
      if (worstReason.isEmpty) worstReason = 'Duplicate posting detected';
    }

    // Clamp
    score = score.clamp(0, 100);

    // Map to level
    final level = score >= 70
        ? LegitimacyLevel.verified
        : score >= 45
            ? LegitimacyLevel.caution
            : LegitimacyLevel.suspicious;

    if (worstReason.isEmpty) {
      worstReason = level == LegitimacyLevel.verified
          ? 'All checks passed'
          : 'Multiple minor flags';
    }

    return JobLegitimacy(level: level, reason: worstReason, score: score);
  }

  static int? _daysSincePosted(String postedAt) {
    if (postedAt.isEmpty) return null;
    try {
      final date = DateTime.parse(postedAt.split('T').first);
      return DateTime.now().difference(date).inDays;
    } catch (_) {
      return null;
    }
  }
}

import '../models/job.dart';
import '../models/job_grade.dart';
import '../models/resume_profile.dart';

/// Honest job-match scoring. Each dimension is 0-100, and the composite
/// (see JobGrade.composite) uses skillMatch as a gate, not just a weight.
class JobScoringService {
  static JobGrade grade(Job job, ResumeProfile profile) {
    return JobGrade(
      skillMatch: _scoreSkillMatch(job, profile),
      roleLevelFit: _scoreRoleLevelFit(job, profile),
      locationFit: _scoreLocationFit(job, profile),
      salaryFit: _scoreSalaryFit(job),
      companyReputation: _scoreReputation(job),
    );
  }

  // ── Skill Match ──────────────────────────────────────────────────────────
  // Measures how many of the user's skills are present in the job. Uses
  // word-boundary matching for short skills (Java, Go) to avoid substring
  // pollution (Java matching "JavaScript").
  static int _scoreSkillMatch(Job job, ResumeProfile profile) {
    final pLower = profile.skills
        .map((s) => s.toLowerCase().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (pLower.isEmpty) return 0;

    final jobSkills = job.skills.map((s) => s.toLowerCase()).toList();
    final jobText = '${job.title} ${job.description}'.toLowerCase();

    var matched = 0;
    for (final skill in pLower) {
      final skillEscaped = RegExp.escape(skill);
      // Word-boundary regex for short skills to avoid "Java" matching "JavaScript"
      final useWordBoundary = skill.length <= 4;
      final pattern = useWordBoundary
          ? RegExp('\\b$skillEscaped\\b')
          : RegExp(skillEscaped);

      final inJobSkills = jobSkills.any((js) =>
          js == skill ||
          (!useWordBoundary && (js.contains(skill) || skill.contains(js))));
      final inJobText = pattern.hasMatch(jobText);

      if (inJobSkills || inJobText) matched++;
    }
    return ((matched / pLower.length) * 100).round().clamp(0, 100);
  }

  // ── Role Level Fit ───────────────────────────────────────────────────────
  // Exact match = 100. Off by one = 70. Off by two = 35. More = 10 (real mismatch).
  static const _levelRank = {
    'Junior': 1, 'Mid': 2, 'Senior': 3, 'Lead': 4, 'Principal': 5,
  };

  static int _scoreRoleLevelFit(Job job, ResumeProfile profile) {
    final profileLevel = _inferProfileLevel(profile);
    final jobRank = _levelRank[job.level] ?? 2;
    final profileRank = _levelRank[profileLevel] ?? 2;
    final diff = (jobRank - profileRank).abs();

    if (diff == 0) return 100;
    if (diff == 1) return 70;
    if (diff == 2) return 35;
    return 10;
  }

  static String _inferProfileLevel(ResumeProfile profile) {
    final level = profile.experienceLevel.toLowerCase();
    final years = profile.yearsOfExperience;
    if (level.contains('senior') || years >= 7) return 'Senior';
    if (level.contains('lead') || level.contains('principal') || years >= 10) return 'Lead';
    if (level.contains('junior') || level.contains('entry') || years <= 2) return 'Junior';
    return 'Mid';
  }

  // ── Location Fit ─────────────────────────────────────────────────────────
  // Same country or genuine remote = high. Different country, no remote = very low.
  // (Previous version returned 30 for foreign on-site — that's padding. 0 is honest.)
  static int _scoreLocationFit(Job job, ResumeProfile profile) {
    final loc = job.location.toLowerCase();
    final country = profile.country.toLowerCase();

    if (loc.isEmpty) return 50; // Unknown — give benefit of the doubt

    // Truly global remote — works from anywhere
    if (loc.contains('worldwide') || loc.contains('anywhere') ||
        loc.contains('global') || loc == 'remote') {
      return 95;
    }

    // Same country mentioned
    if (country.isNotEmpty && loc.contains(country)) return 100;

    // Remote but scoped to a foreign country — poor fit
    if (loc.contains('remote')) {
      // "Remote, United States" for Indian user → bad fit
      return 20;
    }

    // Foreign on-site — essentially unreachable without visa/relocation
    return 0;
  }

  // ── Salary Fit ───────────────────────────────────────────────────────────
  // Only rewards disclosed salaries. Not a quality signal on its own — we
  // can't judge "fit" without knowing user's target. Kept small weight.
  static int _scoreSalaryFit(Job job) {
    final s = job.salaryRange.toLowerCase();
    if (s.isEmpty || s.contains('not disclosed') || s.contains('not listed')) {
      return 40; // penalty for opacity — not a pro or con
    }
    return 75; // disclosed is better than not, not worth >75 on its own
  }

  // ── Company Reputation ───────────────────────────────────────────────────
  // Only give points for VERIFIABLE signals. Unknown company should be
  // unknown — not "40 baseline".
  static int _scoreReputation(Job job) {
    var score = 20; // Low baseline — we don't know anything

    // Known top-tier ATS (Greenhouse, Ashby, Lever) = established employer
    if (job.id.startsWith('gh_') ||
        job.id.startsWith('ash_') ||
        job.id.startsWith('lever_')) {
      score += 35;
    }

    // Featured flag (from our own curation)
    if (job.featured) score += 20;

    // Has company logo → they have a brand
    if (job.companyLogo != null && job.companyLogo!.isNotEmpty) score += 10;

    // Has a working apply URL (not all listings do)
    if (job.applyUrl.isNotEmpty) score += 5;

    return score.clamp(0, 100);
  }
}

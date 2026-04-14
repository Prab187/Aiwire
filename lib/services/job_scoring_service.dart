import '../models/job.dart';
import '../models/job_grade.dart';
import '../models/resume_profile.dart';

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

  // ── Skill Match (40% weight) ─────────────────────────────────────────────
  static int _scoreSkillMatch(Job job, ResumeProfile profile) {
    final pLower = profile.skills
        .map((s) => s.toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (pLower.isEmpty) return 0;

    final jobText = '${job.title} ${job.description} ${job.skills.join(" ")}'.toLowerCase();
    var matched = 0;
    for (final skill in pLower) {
      if (job.skills.any((js) {
        final jl = js.toLowerCase();
        return jl.contains(skill) || skill.contains(jl);
      })) {
        matched++;
      } else if (jobText.contains(skill)) {
        matched++;
      }
    }
    return ((matched / pLower.length) * 100).round().clamp(0, 100);
  }

  // ── Role Level Fit (20% weight) ──────────────────────────────────────────
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
    if (diff == 2) return 40;
    return 15;
  }

  static String _inferProfileLevel(ResumeProfile profile) {
    final level = profile.experienceLevel.toLowerCase();
    final years = profile.yearsOfExperience;
    if (level.contains('senior') || years >= 7) return 'Senior';
    if (level.contains('lead') || level.contains('principal') || years >= 10) return 'Lead';
    if (level.contains('junior') || level.contains('entry') || years <= 2) return 'Junior';
    return 'Mid';
  }

  // ── Location Fit (15% weight) ────────────────────────────────────────────
  static int _scoreLocationFit(Job job, ResumeProfile profile) {
    final loc = job.location.toLowerCase();
    final country = profile.country.toLowerCase();

    // Remote/worldwide is always a good fit
    if (loc.contains('remote') || loc.contains('worldwide') ||
        loc.contains('anywhere') || loc.contains('global') || loc.isEmpty) {
      return 90;
    }
    // Same country
    if (loc.contains(country)) return 100;
    // No match
    return 30;
  }

  // ── Salary Fit (15% weight) ──────────────────────────────────────────────
  static int _scoreSalaryFit(Job job) {
    if (job.salaryRange == 'Not disclosed' || job.salaryRange.isEmpty) return 50;
    // Salary is disclosed — that's a positive signal
    return 80;
  }

  // ── Company Reputation (10% weight) ──────────────────────────────────────
  static int _scoreReputation(Job job) {
    var score = 40; // baseline

    // Direct ATS sources (Greenhouse, Ashby, Lever) — known top companies
    if (job.id.startsWith('gh_') ||
        job.id.startsWith('ash_') ||
        job.id.startsWith('lever_')) {
      score += 30;
    }

    // Featured flag
    if (job.featured) score += 15;

    // Has company logo
    if (job.companyLogo != null && job.companyLogo!.isNotEmpty) score += 10;

    // Has apply URL
    if (job.applyUrl.isNotEmpty) score += 5;

    return score.clamp(0, 100);
  }
}

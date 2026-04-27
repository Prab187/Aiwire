class ResumeProfile {
  final String? name;
  final List<String> skills;
  final String experienceLevel;
  final String country;
  final String countryCode;
  final String jobTitle;
  final String summary;
  final int yearsOfExperience;
  final List<String> projects;
  final List<String> certifications;
  final String? education;
  final List<String> strengths;
  final List<String> gaps;
  final int atsScore;
  final List<String> atsIssues;

  const ResumeProfile({
    required this.name,
    required this.skills,
    required this.experienceLevel,
    required this.country,
    required this.countryCode,
    required this.jobTitle,
    required this.summary,
    this.yearsOfExperience = 0,
    this.projects = const [],
    this.certifications = const [],
    this.education,
    this.strengths = const [],
    this.gaps = const [],
    this.atsScore = 0,
    this.atsIssues = const [],
  });

  factory ResumeProfile.fromJson(Map<String, dynamic> json) {
    return ResumeProfile(
      name: json['name'] as String?,
      skills: List<String>.from(json['skills'] ?? []),
      experienceLevel: json['experience_level'] as String? ?? 'Mid',
      country: json['country'] as String? ?? 'United States',
      countryCode: (json['country_code'] as String? ?? 'us').toLowerCase(),
      jobTitle: json['job_title'] as String? ?? 'AI/ML Engineer',
      summary: json['summary'] as String? ?? '',
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt() ?? 0,
      projects: List<String>.from(json['projects'] ?? []),
      certifications: List<String>.from(json['certifications'] ?? []),
      education: json['education'] as String?,
      strengths: List<String>.from(json['strengths'] ?? []),
      gaps: List<String>.from(json['gaps'] ?? []),
      atsScore: (json['ats_score'] as num?)?.toInt() ?? 0,
      atsIssues: List<String>.from(json['ats_issues'] ?? []),
    );
  }

  String get flagEmoji {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌍';
    return String.fromCharCodes(
      code.codeUnits.map((c) => c - 0x41 + 0x1F1E6),
    );
  }
}

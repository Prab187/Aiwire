class ResumeProfile {
  final String? name;
  final List<String> skills;
  final String experienceLevel;
  final String country;
  final String countryCode; // Adzuna 2-letter code: us, gb, au, ca, de, fr, in, etc.
  final String jobTitle;
  final String summary;

  const ResumeProfile({
    required this.name,
    required this.skills,
    required this.experienceLevel,
    required this.country,
    required this.countryCode,
    required this.jobTitle,
    required this.summary,
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

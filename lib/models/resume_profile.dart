class SkillGap {
  final String name;        // e.g. "AWS Machine Learning Specialty"
  final String severity;    // CRITICAL | HIGH | MEDIUM
  final String marketReason;// Why this matters in user's country
  final String timeToClose; // e.g. "6 weeks"
  final String resource;    // Specific course/platform name
  final String? resourceUrl;// Optional URL
  final String? cost;       // e.g. "Free", "$49", "₹499"

  const SkillGap({
    required this.name,
    required this.severity,
    required this.marketReason,
    required this.timeToClose,
    required this.resource,
    this.resourceUrl,
    this.cost,
  });

  factory SkillGap.fromJson(Map<String, dynamic> json) {
    return SkillGap(
      name: json['name'] as String? ?? '',
      severity: (json['severity'] as String? ?? 'MEDIUM').toUpperCase(),
      marketReason: json['market_reason'] as String? ?? '',
      timeToClose: json['time_to_close'] as String? ?? '',
      resource: json['resource'] as String? ?? '',
      resourceUrl: json['resource_url'] as String?,
      cost: json['cost'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'severity': severity,
    'market_reason': marketReason,
    'time_to_close': timeToClose,
    'resource': resource,
    if (resourceUrl != null) 'resource_url': resourceUrl,
    if (cost != null) 'cost': cost,
  };

  /// Legacy string representation for older UI components
  String get displayText => name;
}

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
  final List<String> gaps;              // Legacy: simple strings (kept for back-compat)
  final List<SkillGap> structuredGaps;  // New: detailed gaps with severity + resources
  final int atsScore;
  final List<String> atsIssues;
  final List<String> atsAdd;
  final List<String> atsRemove;

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
    this.structuredGaps = const [],
    this.atsScore = 0,
    this.atsIssues = const [],
    this.atsAdd = const [],
    this.atsRemove = const [],
  });

  static const List<String> _atsAddDefaults = [
    "Add a 'Skills' section near the top with comma-separated keywords — ATS parsers index this first",
    "Add quantified impact (% improved, time saved, dollars) on every bullet",
    "Add 1-2 cloud or MLOps keywords (AWS / Docker / Kubernetes) that match common JDs",
    "Add a 'Projects' section with 2-4 concrete examples and outcomes",
  ];

  static const List<String> _atsRemoveDefaults = [
    "Remove the 'Objective' or 'Summary of intent' paragraph — most ATS strip it",
    "Remove icons, photos, and multi-column layouts — they break Workday/Greenhouse parsers",
    "Remove vague phrases like 'responsible for' / 'worked on' — replace with action verbs",
    "Remove unrelated old experience that no longer supports your target role",
  ];

  /// Returns the model's list if non-empty, otherwise a sensible default
  /// so users always see actionable suggestions on the ATS card.
  static List<String> _atsFallback(dynamic raw, List<String> defaults) {
    final parsed = _toStringList(raw);
    if (parsed.isNotEmpty) return parsed;
    return List<String>.from(defaults);
  }

  /// Defensive string-list extractor: handles Strings, Maps (common keys:
  /// name, title, text, description, before/after), and raw toString() fallback.
  /// Claude sometimes returns lists of objects when we ask for before/after
  /// examples, which would crash `List<String>.from()`.
  static List<String> _toStringList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <String>[];
    for (final item in raw) {
      if (item == null) continue;
      if (item is String) {
        if (item.trim().isNotEmpty) result.add(item.trim());
      } else if (item is Map) {
        // Try common keys Claude might use
        final text = item['text'] ?? item['name'] ?? item['title']
            ?? item['description'] ?? item['issue'] ?? item['fix']
            ?? item['skill'] ?? item['item'];
        if (text is String && text.trim().isNotEmpty) {
          result.add(text.trim());
        } else if (item['before'] != null && item['after'] != null) {
          // BEFORE/AFTER shape from ATS issues
          result.add('${item['before']} → ${item['after']}');
        } else {
          // Last resort: flatten map to readable text
          final flat = item.values
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .join(': ');
          if (flat.isNotEmpty) result.add(flat);
        }
      } else {
        // Number, bool, anything else
        final s = item.toString().trim();
        if (s.isNotEmpty) result.add(s);
      }
    }
    return result;
  }

  factory ResumeProfile.fromJson(Map<String, dynamic> json) {
    // Parse structured gaps if present, else fall back to plain strings
    List<SkillGap> structured = [];
    List<String> plain = [];
    final rawGaps = json['gaps'];
    if (rawGaps is List) {
      for (final g in rawGaps) {
        if (g is Map<String, dynamic>) {
          final sg = SkillGap.fromJson(g);
          structured.add(sg);
          plain.add(sg.name);
        } else if (g is Map) {
          // Map with non-string keys — convert defensively
          final sg = SkillGap.fromJson(g.map((k, v) => MapEntry(k.toString(), v)));
          structured.add(sg);
          plain.add(sg.name);
        } else if (g is String && g.trim().isNotEmpty) {
          plain.add(g.trim());
        }
      }
    }
    return ResumeProfile(
      name: json['name'] as String?,
      skills: _toStringList(json['skills']),
      experienceLevel: json['experience_level'] as String? ?? 'Mid',
      country: json['country'] as String? ?? 'United States',
      countryCode: (json['country_code'] as String? ?? 'us').toLowerCase(),
      jobTitle: json['job_title'] as String? ?? 'AI/ML Engineer',
      summary: json['summary'] as String? ?? '',
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt() ?? 0,
      projects: _toStringList(json['projects']),
      certifications: _toStringList(json['certifications']),
      education: json['education'] as String?,
      strengths: _toStringList(json['strengths']),
      gaps: plain,
      structuredGaps: structured,
      atsScore: (json['ats_score'] as num?)?.toInt() ?? 0,
      atsIssues: _toStringList(json['ats_issues']),
      atsAdd: _atsFallback(json['ats_add'], _atsAddDefaults),
      atsRemove: _atsFallback(json['ats_remove'], _atsRemoveDefaults),
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

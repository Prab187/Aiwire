class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String type; // Remote, Hybrid, On-site
  final String level; // Junior, Mid, Senior, Lead, Principal
  final String description;
  final List<String> skills;
  final String salaryRange;
  final String postedAt;
  final String? companyLogo;
  final String applyUrl;
  final bool featured;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.type,
    required this.level,
    required this.description,
    required this.skills,
    required this.salaryRange,
    required this.postedAt,
    this.companyLogo,
    required this.applyUrl,
    this.featured = false,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      company: json['company'] ?? '',
      location: json['location'] ?? '',
      type: json['type'] ?? 'Remote',
      level: json['level'] ?? 'Mid',
      description: json['description'] ?? '',
      skills: List<String>.from(json['skills'] ?? []),
      salaryRange: json['salaryRange'] ?? '',
      postedAt: json['postedAt'] ?? '',
      companyLogo: json['companyLogo'],
      applyUrl: json['applyUrl'] ?? '',
      featured: json['featured'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'company': company, 'location': location,
    'type': type, 'level': level, 'description': description,
    'skills': skills, 'salaryRange': salaryRange, 'postedAt': postedAt,
    'companyLogo': companyLogo, 'applyUrl': applyUrl, 'featured': featured,
  };
}

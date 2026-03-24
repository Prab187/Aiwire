class TalentProfile {
  final String id;
  final String name;
  final String title;
  final String company;
  final String location;
  final String specialization;
  final List<String> skills;
  final int yearsExperience;
  final String? avatarUrl;
  final bool isAvailable;
  final String? linkedinUrl;
  final int publications;
  final int patents;
  final double matchScore; // 0-100 percentile ranking

  TalentProfile({
    required this.id,
    required this.name,
    required this.title,
    required this.company,
    required this.location,
    required this.specialization,
    required this.skills,
    required this.yearsExperience,
    this.avatarUrl,
    this.isAvailable = true,
    this.linkedinUrl,
    this.publications = 0,
    this.patents = 0,
    this.matchScore = 0,
  });

  factory TalentProfile.fromJson(Map<String, dynamic> json) {
    return TalentProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      title: json['title'] ?? '',
      company: json['company'] ?? '',
      location: json['location'] ?? '',
      specialization: json['specialization'] ?? '',
      skills: List<String>.from(json['skills'] ?? []),
      yearsExperience: json['yearsExperience'] ?? 0,
      avatarUrl: json['avatarUrl'],
      isAvailable: json['isAvailable'] ?? true,
      linkedinUrl: json['linkedinUrl'],
      publications: json['publications'] ?? 0,
      patents: json['patents'] ?? 0,
      matchScore: (json['matchScore'] ?? 0).toDouble(),
    );
  }
}

class Certification {
  final String id;
  final String name;
  final String provider;
  final String providerType; // University, Tech Company, Platform, Organization
  final String description;
  final String level; // Beginner, Intermediate, Advanced, Expert
  final String? duration;
  final String? price;
  final bool isFree;
  final String? url;
  final List<String> skills;
  final double? rating;
  final int? enrolledCount;
  final bool isNew;

  Certification({
    required this.id,
    required this.name,
    required this.provider,
    required this.providerType,
    required this.description,
    required this.level,
    this.duration,
    this.price,
    this.isFree = false,
    this.url,
    required this.skills,
    this.rating,
    this.enrolledCount,
    this.isNew = false,
  });

  factory Certification.fromJson(Map<String, dynamic> json) {
    return Certification(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      provider: json['provider'] ?? '',
      providerType: json['providerType'] ?? 'Platform',
      description: json['description'] ?? '',
      level: json['level'] ?? 'Intermediate',
      duration: json['duration'],
      price: json['price'],
      isFree: json['isFree'] ?? false,
      url: json['url'],
      skills: List<String>.from(json['skills'] ?? []),
      rating: json['rating']?.toDouble(),
      enrolledCount: json['enrolledCount'],
      isNew: json['isNew'] ?? false,
    );
  }
}

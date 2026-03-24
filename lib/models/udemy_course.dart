class UdemyCourse {
  final int id;
  final String title;
  final String headline;
  final String instructor;
  final String price;
  final double rating;
  final int numReviews;
  final String imageUrl;
  final String url;

  UdemyCourse({
    required this.id,
    required this.title,
    required this.headline,
    required this.instructor,
    required this.price,
    required this.rating,
    required this.numReviews,
    required this.imageUrl,
    required this.url,
  });

  factory UdemyCourse.fromJson(Map<String, dynamic> json) {
    final instructors = json['visible_instructors'] as List? ?? [];
    final instructorName = instructors.isNotEmpty
        ? (instructors.first['display_name'] ?? 'Unknown')
        : 'Unknown';

    return UdemyCourse(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      headline: json['headline'] ?? '',
      instructor: instructorName.toString(),
      price: json['price'] ?? 'Free',
      rating: (json['avg_rating'] as num?)?.toDouble() ?? 0.0,
      numReviews: json['num_reviews'] ?? 0,
      imageUrl: json['image_480x270'] ?? json['image_240x135'] ?? '',
      url: 'https://www.udemy.com${json['url'] ?? ''}',
    );
  }
}

class Article {
  final String id;
  final String title;
  String summary;
  final String source;
  final String url;
  final String publishedAt;
  final String imageUrl;

  Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.imageUrl,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['url'] ?? '',
      title: json['title'] ?? '',
      summary: json['description'] ?? '',
      source: json['source']['name'] ?? '',
      url: json['url'] ?? '',
      publishedAt: json['publishedAt'] ?? '',
      imageUrl: json['urlToImage'] ?? '',
    );
  }
}
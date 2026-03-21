class Article {
  final String title;
  final String? description;
  final String? urlToImage;
  final String url;
  final String? publishedAt;
  final String? source;
  final String? content;

  Article({
    required this.title,
    this.description,
    this.urlToImage,
    required this.url,
    this.publishedAt,
    this.source,
    this.content,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] ?? '',
      description: json['description'],
      urlToImage: json['urlToImage'],
      url: json['url'] ?? '',
      publishedAt: json['publishedAt'],
      source: json['source']?['name'],
      content: json['content'],
    );
  }

  int get readingTime {
    // Combine all available text
    final allText = [
      title,
      description ?? '',
      content ?? '',
    ].join(' ');

    // Remove whitespace artifacts and count words
    final wordCount = allText
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    // Average reading speed: 200 words per minute
    // NewsAPI free tier truncates content so we estimate generously
    final estimated = wordCount < 100
        ? (wordCount / 50).ceil() + 2  // short content = estimate longer
        : (wordCount / 200).ceil();

    return estimated.clamp(2, 15);
  }
}

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
    // source can be a nested map (NewsAPI) or a plain string (Firestore)
    final src = json['source'];
    final sourceName = src is Map ? src['name'] : src as String?;
    return Article(
      title: json['title'] ?? '',
      description: json['description'],
      urlToImage: json['urlToImage'],
      url: json['url'] ?? '',
      publishedAt: json['publishedAt'],
      source: sourceName,
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'urlToImage': urlToImage,
    'url': url,
    'publishedAt': publishedAt,
    'source': source,
    'content': content,
  };

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

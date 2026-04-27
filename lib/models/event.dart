class AIEvent {
  final String id;
  final String title;
  final String organizer;
  final String description;
  final String date;
  final String time;
  final String timezone;
  final String type; // Webinar, Conference, Seminar, Workshop, Meetup
  final String format; // Virtual, In-Person, Hybrid
  final String? location;
  final String? registrationUrl;
  final List<String> topics;
  final bool isFree;
  final String? price;
  final int? attendeeCount;

  AIEvent({
    required this.id,
    required this.title,
    required this.organizer,
    required this.description,
    required this.date,
    required this.time,
    required this.timezone,
    required this.type,
    required this.format,
    this.location,
    this.registrationUrl,
    required this.topics,
    this.isFree = true,
    this.price,
    this.attendeeCount,
  });

  factory AIEvent.fromJson(Map<String, dynamic> json) {
    return AIEvent(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      organizer: json['organizer'] ?? '',
      description: json['description'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      timezone: json['timezone'] ?? 'UTC',
      type: json['type'] ?? 'Webinar',
      format: json['format'] ?? 'Virtual',
      location: json['location'],
      registrationUrl: json['registrationUrl'],
      topics: List<String>.from(json['topics'] ?? []),
      isFree: json['isFree'] ?? true,
      price: json['price'],
      attendeeCount: json['attendeeCount'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'organizer': organizer,
    'description': description,
    'date': date,
    'time': time,
    'timezone': timezone,
    'type': type,
    'format': format,
    'location': location,
    'registrationUrl': registrationUrl,
    'topics': topics,
    'isFree': isFree,
    'price': price,
    'attendeeCount': attendeeCount,
  };

  bool get isUpcoming {
    try {
      return DateTime.parse(date).isAfter(DateTime.now().subtract(const Duration(days: 1)));
    } catch (_) {
      return true;
    }
  }
}

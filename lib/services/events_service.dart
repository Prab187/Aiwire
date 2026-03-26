import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/event.dart';

class EventsService {
  // ── PredictHQ API (free tier — 1,000 events/day) ─────────────────────────
  static Future<List<AIEvent>> _fetchPredictHQEvents() async {
    const token = String.fromEnvironment('PREDICTHQ_ACCESS_TOKEN');
    if (token.isEmpty) return [];

    final now = DateTime.now();
    final startDate = now.toIso8601String().split('T').first;
    final endDate = now.add(const Duration(days: 180)).toIso8601String().split('T').first;

    final url = Uri.parse(
      'https://api.predicthq.com/v1/events/'
      '?category=conferences,expos,community'
      '&q=artificial+intelligence+machine+learning+AI'
      '&start.gte=$startDate'
      '&start.lte=$endDate'
      '&sort=start'
      '&limit=20'
    );

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];

      return results.map((e) {
        final start = e['start'] ?? '';
        final datePart = start.toString().split('T').first;
        final timePart = start.toString().contains('T')
            ? start.toString().split('T').last.substring(0, 5)
            : '09:00';
        final location = e['location'] ?? [];
        final geo = e['geo'] ?? {};
        final address = geo['address']?['formatted_address'] ?? '';
        final placeName = e['place_hierarchies'] != null ? '' : '';
        final category = e['category'] ?? 'conference';

        return AIEvent(
          id: 'phq_${e['id']}',
          title: e['title'] ?? '',
          organizer: e['entities']?.isNotEmpty == true
              ? (e['entities'][0]['name'] ?? 'TBA')
              : 'TBA',
          description: e['description'] ?? e['title'] ?? '',
          date: datePart,
          time: timePart,
          timezone: e['timezone'] ?? 'UTC',
          type: _mapCategory(category),
          format: location.isNotEmpty ? 'In-Person' : 'Virtual',
          location: address.isNotEmpty ? address : (placeName.isNotEmpty ? placeName : null),
          topics: _extractTopics(e['title'] ?? '', e['description'] ?? ''),
          isFree: true,
          attendeeCount: e['phq_attendance']?['predicted'] as int?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Eventbrite API (free OAuth token) ────────────────────────────────────
  static Future<List<AIEvent>> _fetchEventbriteEvents() async {
    const token = String.fromEnvironment('EVENTBRITE_TOKEN');
    if (token.isEmpty) return [];

    final url = Uri.parse(
      'https://www.eventbriteapi.com/v3/events/search/'
      '?q=artificial+intelligence+machine+learning'
      '&categories=102' // Science & Tech
      '&sort_by=date'
      '&expand=venue'
    );

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final events = data['events'] as List? ?? [];

      return events.take(15).map((e) {
        final start = e['start'] ?? {};
        final venue = e['venue'];
        final isFree = e['is_free'] == true;

        String location = '';
        if (venue != null) {
          final parts = [venue['city'], venue['region'], venue['country']];
          location = parts.where((p) => p != null && p.isNotEmpty).join(', ');
        }

        return AIEvent(
          id: 'eb_${e['id']}',
          title: e['name']?['text'] ?? '',
          organizer: e['organizer']?['name'] ?? 'TBA',
          description: e['description']?['text']?.toString().take(200) ?? '',
          date: start['local']?.toString().split('T').first ?? '',
          time: start['local']?.toString().contains('T') == true
              ? start['local'].toString().split('T').last.substring(0, 5)
              : '09:00',
          timezone: start['timezone'] ?? 'UTC',
          type: e['online_event'] == true ? 'Webinar' : 'Conference',
          format: e['online_event'] == true ? 'Virtual' : 'In-Person',
          location: location.isNotEmpty ? location : null,
          registrationUrl: e['url'],
          topics: _extractTopics(e['name']?['text'] ?? '', e['description']?['text'] ?? ''),
          isFree: isFree,
          price: isFree ? null : 'Paid',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Public method ────────────────────────────────────────────────────────
  static Future<List<AIEvent>> fetchEvents({String? type, String? format, bool upcomingOnly = true}) async {
    // Fetch from APIs in parallel
    final results = await Future.wait([
      _fetchPredictHQEvents().catchError((_) => <AIEvent>[]),
      _fetchEventbriteEvents().catchError((_) => <AIEvent>[]),
    ]);

    var events = [...results[0], ...results[1]];

    // Fallback to curated sample data
    if (events.isEmpty) {
      events = List.from(_fallbackEvents);
    }

    if (upcomingOnly) {
      events = events.where((e) => e.isUpcoming).toList();
    }
    if (type != null && type != 'All') {
      events = events.where((e) => e.type == type).toList();
    }
    if (format != null && format != 'All') {
      events = events.where((e) => e.format == format).toList();
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  static int get totalEvents => 10;

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _mapCategory(String category) {
    switch (category) {
      case 'conferences': return 'Conference';
      case 'expos': return 'Conference';
      case 'community': return 'Meetup';
      default: return 'Conference';
    }
  }

  static List<String> _extractTopics(String title, String description) {
    final text = '$title $description'.toLowerCase();
    final topicMap = {
      'deep learning': 'Deep Learning', 'nlp': 'NLP', 'computer vision': 'Computer Vision',
      'reinforcement': 'RL', 'llm': 'LLM', 'generative': 'Generative AI',
      'transformer': 'Transformers', 'robotics': 'Robotics', 'autonomous': 'Autonomous Systems',
      'healthcare': 'Healthcare AI', 'ethics': 'AI Ethics', 'safety': 'AI Safety',
      'mlops': 'MLOps', 'cloud': 'Cloud AI', 'edge': 'Edge AI',
      'diffusion': 'Diffusion Models', 'fine-tun': 'Fine-tuning',
      'machine learning': 'Machine Learning', 'artificial intelligence': 'AI',
    };

    final found = <String>[];
    for (final entry in topicMap.entries) {
      if (text.contains(entry.key) && found.length < 4) {
        found.add(entry.value);
      }
    }
    return found.isEmpty ? ['AI/ML'] : found;
  }

  // ── Fallback curated events ──────────────────────────────────────────────
  static final List<AIEvent> _fallbackEvents = [
    AIEvent(id: 'f1', title: 'NeurIPS 2026', organizer: 'NeurIPS Foundation',
      description: 'The flagship machine learning conference featuring cutting-edge research in neural information processing systems.',
      date: '2026-12-06', time: '09:00', timezone: 'PST', type: 'Conference',
      format: 'Hybrid', location: 'Vancouver, Canada',
      topics: ['Deep Learning', 'NLP', 'Computer Vision', 'RL'], isFree: false, price: '\$850', attendeeCount: 15000),
    AIEvent(id: 'f2', title: 'ICML 2026', organizer: 'IMLS',
      description: 'International Conference on Machine Learning – premier venue for ML research and networking.',
      date: '2026-07-20', time: '09:00', timezone: 'CET', type: 'Conference',
      format: 'In-Person', location: 'Vienna, Austria',
      topics: ['Machine Learning', 'AI'], isFree: false, price: '\$750', attendeeCount: 8000),
    AIEvent(id: 'f3', title: 'Anthropic Safety Summit', organizer: 'Anthropic',
      description: 'Deep dive into AI alignment research, constitutional AI, and building safe AI systems.',
      date: '2026-05-15', time: '10:00', timezone: 'PST', type: 'Seminar', format: 'Virtual',
      topics: ['AI Safety', 'Transformers', 'LLM'], isFree: true, attendeeCount: 5000),
    AIEvent(id: 'f4', title: 'Google I/O AI Track', organizer: 'Google',
      description: 'Annual developer conference with dedicated AI/ML sessions covering Gemini, TensorFlow, and cloud AI.',
      date: '2026-05-20', time: '10:00', timezone: 'PST', type: 'Conference',
      format: 'Hybrid', location: 'Mountain View, CA',
      topics: ['Generative AI', 'Cloud AI', 'Machine Learning'], isFree: true, attendeeCount: 25000),
    AIEvent(id: 'f5', title: 'LLM Fine-tuning Masterclass', organizer: 'Hugging Face',
      description: 'Hands-on workshop covering LoRA, QLoRA, and PEFT techniques for efficient LLM customization.',
      date: '2026-04-10', time: '14:00', timezone: 'CET', type: 'Workshop', format: 'Virtual',
      topics: ['LLM', 'Fine-tuning', 'Transformers'], isFree: true, attendeeCount: 3000),
    AIEvent(id: 'f6', title: 'AI in Healthcare Summit', organizer: 'MIT',
      description: 'Exploring the intersection of artificial intelligence and healthcare innovation.',
      date: '2026-06-08', time: '09:00', timezone: 'EST', type: 'Conference',
      format: 'In-Person', location: 'Boston, MA',
      topics: ['Healthcare AI', 'Deep Learning'], isFree: false, price: '\$500', attendeeCount: 2000),
    AIEvent(id: 'f7', title: 'MLOps Community Meetup', organizer: 'MLOps Community',
      description: 'Monthly virtual meetup discussing best practices in ML deployment and monitoring.',
      date: '2026-04-02', time: '18:00', timezone: 'UTC', type: 'Meetup', format: 'Virtual',
      topics: ['MLOps', 'Cloud AI'], isFree: true, attendeeCount: 800),
    AIEvent(id: 'f8', title: 'Responsible AI Forum', organizer: 'Partnership on AI',
      description: 'Multi-stakeholder forum on responsible AI development and governance frameworks.',
      date: '2026-09-15', time: '09:00', timezone: 'GMT', type: 'Seminar',
      format: 'Hybrid', location: 'London, UK',
      topics: ['AI Ethics', 'AI Safety'], isFree: false, price: '\$200', attendeeCount: 1500),
    AIEvent(id: 'f9', title: 'Diffusion Models Deep Dive', organizer: 'Stanford HAI',
      description: 'Technical webinar on latest advances in diffusion models for image, video, and audio.',
      date: '2026-04-25', time: '11:00', timezone: 'PST', type: 'Webinar', format: 'Virtual',
      topics: ['Diffusion Models', 'Generative AI', 'Computer Vision'], isFree: true, attendeeCount: 4000),
    AIEvent(id: 'f10', title: 'AWS re:Invent AI/ML Track', organizer: 'AWS',
      description: 'Comprehensive AI/ML sessions covering SageMaker, Bedrock, and enterprise AI solutions.',
      date: '2026-11-30', time: '09:00', timezone: 'PST', type: 'Conference',
      format: 'In-Person', location: 'Las Vegas, NV',
      topics: ['Cloud AI', 'Machine Learning'], isFree: false, price: '\$1,899', attendeeCount: 60000),
  ];
}

// Extension for string truncation
extension _StringTake on String {
  String take(int n) => length <= n ? this : '${substring(0, n)}...';
}

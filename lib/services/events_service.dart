import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/event.dart';
import 'cors_proxy.dart';

class EventsService {
  // ── AI Conference RSS feeds (free, no key) ───────────────────────────────
  // Curated list of public AI/ML event RSS/Atom feeds
  static const _eventRssFeeds = [
    // IEEE Spectrum AI events
    {'url': 'https://spectrum.ieee.org/rss/blog/tech-talk/fulltext', 'source': 'IEEE'},
    // KDnuggets AI events/webinars
    {'url': 'https://www.kdnuggets.com/feed', 'source': 'KDnuggets'},
    // Towards Data Science (Medium) – includes event/webinar announcements
    {'url': 'https://towardsdatascience.com/feed', 'source': 'TDS'},
    // HuggingFace blog – often announces community events & webinars
    {'url': 'https://huggingface.co/blog/feed.xml', 'source': 'HuggingFace'},
  ];

  static Future<List<AIEvent>> _fetchRssEvents() async {
    final eventKeywords = RegExp(
      r'\b(conference|summit|webinar|workshop|meetup|hackathon|seminar|'
      r'symposium|forum|expo|event|talk|lecture|bootcamp)\b',
      caseSensitive: false,
    );
    final aiKeywords = RegExp(
      r'(AI|machine.?learning|deep.?learning|LLM|NLP|GPT|generative|'
      r'neural|data.?science|mlops|computer.?vision)',
      caseSensitive: false,
    );

    final results = <AIEvent>[];

    await Future.wait(_eventRssFeeds.map((feed) async {
      try {
        final response = await http.get(
          corsUri(feed['url']!),
          headers: {'User-Agent': 'AIWire/1.0 (Flutter RSS Reader)'},
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return;

        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        final entries = items.isEmpty ? document.findAllElements('entry') : items;

        for (final item in entries) {
          // Get title
          final title = item.childElements
              .where((e) => e.name.local == 'title')
              .firstOrNull?.innerText.trim() ?? '';
          if (title.isEmpty) continue;

          // Must mention both an event type AND AI/ML topic
          if (!eventKeywords.hasMatch(title) || !aiKeywords.hasMatch(title)) continue;

          // Get URL
          String url2 = '';
          for (final el in item.childElements) {
            if (el.name.local == 'link') {
              final href = el.getAttribute('href');
              if (href != null && href.isNotEmpty) { url2 = href; break; }
              final text = el.innerText.trim();
              if (text.startsWith('http')) { url2 = text; break; }
            }
          }
          if (url2.isEmpty) continue;

          // Get date
          final rawDate = item.childElements
              .where((e) => e.name.local == 'pubDate' || e.name.local == 'published')
              .firstOrNull?.innerText.trim();

          DateTime? pubDate;
          if (rawDate != null) {
            try { pubDate = DateTime.parse(rawDate); } catch (e) { debugPrint("AIWire: $e"); }
            if (pubDate == null) {
              // RFC 822 fallback
              try {
                final p = rawDate.replaceAll(RegExp(r'GMT|UTC|\+\d{4}|-\d{4}'), '').trim();
                pubDate = DateTime.tryParse(p);
              } catch (e) { debugPrint("AIWire: $e"); }
            }
          }
          // Skip past events
          if (pubDate != null && pubDate.isBefore(DateTime.now())) continue;

          final dateStr = pubDate?.toIso8601String().split('T').first
              ?? DateTime.now().add(const Duration(days: 30))
                  .toIso8601String().split('T').first;

          results.add(AIEvent(
            id: 'rss_${url2.hashCode}',
            title: title,
            organizer: feed['source'] ?? 'Online',
            description: 'AI/ML event announced by ${feed['source']}. See link for full details.',
            date: dateStr,
            time: '09:00',
            timezone: 'UTC',
            type: _inferEventType(title),
            format: 'Virtual',
            registrationUrl: url2,
            topics: _extractTopics(title, ''),
            isFree: true,
          ));
        }
      } catch (e) { debugPrint("AIWire: $e"); }
    }));

    return results;
  }

  static String _inferEventType(String title) {
    final t = title.toLowerCase();
    if (t.contains('webinar')) return 'Webinar';
    if (t.contains('workshop')) return 'Workshop';
    if (t.contains('meetup')) return 'Meetup';
    if (t.contains('seminar') || t.contains('lecture') || t.contains('talk')) return 'Seminar';
    return 'Conference';
  }

  // ── PredictHQ API (free tier — 1,000 events/day) ─────────────────────────
  static Future<List<AIEvent>> _fetchPredictHQEvents() async {
    const token = String.fromEnvironment('PREDICTHQ_ACCESS_TOKEN');
    if (token.isEmpty) return [];

    final now = DateTime.now();
    final startDate = now.toIso8601String().split('T').first;
    final endDate = now.add(const Duration(days: 180)).toIso8601String().split('T').first;

    final url = corsUri(
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
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];

      return results.map((e) {
        final start = e['start'] ?? '';
        final datePart = start.toString().split('T').first;
        final rawTime = start.toString().contains('T')
            ? start.toString().split('T').last
            : '';
        final timePart = rawTime.length >= 5 ? rawTime.substring(0, 5) : '09:00';
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

    final url = corsUri(
      'https://www.eventbriteapi.com/v3/events/search/'
      '?q=artificial+intelligence+machine+learning'
      '&categories=102' // Science & Tech
      '&sort_by=date'
      '&expand=venue'
    );

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 10));
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
          time: () {
            final raw = start['local']?.toString() ?? '';
            if (!raw.contains('T')) return '09:00';
            final t = raw.split('T').last;
            return t.length >= 5 ? t.substring(0, 5) : '09:00';
          }(),
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

  // ── confs.tech (free, no key — curated AI/tech conferences on GitHub) ──────
  static Future<List<AIEvent>> _fetchConfstech() async {
    final now = DateTime.now();
    final years = [now.year, now.year + 1];
    final allConfs = <AIEvent>[];

    // AI/ML keywords to filter conference names
    final aiFilter = RegExp(
      r'(ai|machine.?learning|deep.?learn|neural|nlp|computer.?vision|'
      r'data.?science|robotics|llm|generative|artificial.?intelligence|'
      r'mlops|mlsys|neurips|icml|iclr|cvpr|emnlp|acl|aaai|ijcai)',
      caseSensitive: false,
    );

    for (final year in years) {
      try {
        final url = corsUri(
          'https://raw.githubusercontent.com/tech-conferences/'
          'conference-data/main/conferences/$year/data.json',
        );
        final response = await http.get(url,
          headers: {'User-Agent': 'AIWire/1.0'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;

        final list = json.decode(response.body) as List;

        for (final c in list) {
          final name = c['name'] as String? ?? '';
          final url2 = c['url'] as String? ?? '';
          final startDate = c['startDate'] as String? ?? '';
          // endDate available but not used in model currently
          final city = c['city'] as String? ?? '';
          final country = c['country'] as String? ?? '';
          final online = c['online'] == true;

          // Only keep AI/ML related conferences
          if (!aiFilter.hasMatch(name)) continue;
          if (startDate.isEmpty) continue;

          // Skip past events
          try {
            if (DateTime.parse(startDate).isBefore(now)) continue;
          } catch (_) { continue; }

          final location = [city, country]
              .where((s) => s.isNotEmpty)
              .join(', ');

          allConfs.add(AIEvent(
            id: 'confstech_${name.hashCode}_$startDate',
            title: name,
            organizer: _inferOrganizer(name),
            description: 'AI/ML conference. Visit the website for full details and agenda.',
            date: startDate,
            time: '09:00',
            timezone: 'Local',
            type: 'Conference',
            format: online ? 'Virtual' : (location.isNotEmpty ? 'In-Person' : 'Virtual'),
            location: location.isNotEmpty ? location : null,
            registrationUrl: url2.isNotEmpty ? url2 : null,
            topics: _extractTopics(name, ''),
            isFree: false,
          ));
        }
      } catch (_) {
        continue;
      }
    }
    return allConfs;
  }

  static String _inferOrganizer(String name) {
    if (name.contains('NeurIPS') || name.contains('ICML') || name.contains('ICLR')) return 'ML Research Foundation';
    if (name.contains('CVPR') || name.contains('ICCV') || name.contains('ECCV')) return 'IEEE / CVF';
    if (name.contains('ACL') || name.contains('EMNLP') || name.contains('NAACL')) return 'ACL';
    if (name.contains('AAAI')) return 'AAAI';
    if (name.contains('Google')) return 'Google';
    if (name.contains('AWS') || name.contains('re:Invent')) return 'AWS';
    if (name.contains('Microsoft')) return 'Microsoft';
    return 'TBA';
  }

  // ── Ticketmaster Discovery API (free — 5,000/day, developer.ticketmaster.com)
  static Future<List<AIEvent>> _fetchTicketmasterEvents() async {
    const apiKey = String.fromEnvironment('TICKETMASTER_API_KEY');
    if (apiKey.isEmpty) return [];

    final now = DateTime.now();
    final start = '${now.toIso8601String().split('.').first}Z';
    final end = '${now.add(const Duration(days: 180)).toIso8601String().split('.').first}Z';

    final url = corsUri(
      'https://app.ticketmaster.com/discovery/v2/events.json'
      '?apikey=$apiKey'
      '&keyword=${Uri.encodeComponent("artificial intelligence machine learning")}'
      '&startDateTime=$start'
      '&endDateTime=$end'
      '&size=20'
      '&sort=date,asc',
    );

    try {
      final response = await http.get(url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final events = (data['_embedded']?['events'] as List?) ?? [];

      return events.map((e) {
        final dates = e['dates']?['start'] ?? {};
        final venues = (e['_embedded']?['venues'] as List?) ?? [];
        final venue = venues.isNotEmpty ? venues[0] : {};
        final city = venue['city']?['name'] as String? ?? '';
        final state = venue['state']?['name'] as String? ?? '';
        final country = venue['country']?['name'] as String? ?? '';
        final locationParts = [city, state, country]
            .where((s) => s.isNotEmpty && s != 'United States of America')
            .toList();
        if (country == 'United States of America') locationParts.add('USA');

        return AIEvent(
          id: 'tm_${e['id']}',
          title: e['name'] as String? ?? '',
          organizer: e['promoter']?['name'] as String? ?? 'TBA',
          description: 'Tech/AI event. See event page for full details.',
          date: dates['localDate'] as String? ?? '',
          time: () {
            final t = dates['localTime'] as String? ?? '09:00';
            return t.length >= 5 ? t.substring(0, 5) : '09:00';
          }(),
          timezone: 'Local',
          type: 'Conference',
          format: venues.isEmpty ? 'Virtual' : 'In-Person',
          location: locationParts.isNotEmpty ? locationParts.join(', ') : null,
          registrationUrl: e['url'] as String?,
          topics: _extractTopics(e['name'] as String? ?? '', ''),
          isFree: false,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Public method ────────────────────────────────────────────────────────
  static Future<List<AIEvent>> fetchEvents({String? type, String? format, bool upcomingOnly = true, String? country}) async {
    // Fetch from all sources in parallel
    final results = await Future.wait([
      _fetchRssEvents().catchError((_) => <AIEvent>[]),
      _fetchConfstech().catchError((_) => <AIEvent>[]),
      _fetchPredictHQEvents().catchError((_) => <AIEvent>[]),
      _fetchEventbriteEvents().catchError((_) => <AIEvent>[]),
      _fetchTicketmasterEvents().catchError((_) => <AIEvent>[]),
    ]);

    var events = [
      ...results[0], ...results[1], ...results[2],
      ...results[3], ...results[4],
    ];

    // Deduplicate by title
    final seen = <String>{};
    events = events.where((e) => seen.add(e.title.toLowerCase())).toList();

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

    // Country filter: keep virtual events everywhere; filter in-person by country
    if (country != null && country.isNotEmpty) {
      final cLower = country.toLowerCase();
      events = events.where((e) {
        // Virtual/Hybrid events are accessible from anywhere
        if (e.format == 'Virtual' || e.format == 'Hybrid') return true;
        // In-Person: only keep if event's location mentions the user's country
        final loc = (e.location ?? '').toLowerCase();
        return loc.contains(cLower);
      }).toList();
    }

    // Sort: country in-person first, then virtual, then by date
    events.sort((a, b) {
      final aLocal = country != null && a.format != 'Virtual'
          && (a.location ?? '').toLowerCase().contains(country.toLowerCase());
      final bLocal = country != null && b.format != 'Virtual'
          && (b.location ?? '').toLowerCase().contains(country.toLowerCase());
      if (aLocal && !bLocal) return -1;
      if (!aLocal && bLocal) return 1;
      return a.date.compareTo(b.date);
    });
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
      registrationUrl: 'https://neurips.cc',
      topics: ['Deep Learning', 'NLP', 'Computer Vision', 'RL'], isFree: false, price: '\$850', attendeeCount: 15000),
    AIEvent(id: 'f2', title: 'ICML 2026', organizer: 'IMLS',
      description: 'International Conference on Machine Learning – premier venue for ML research and networking.',
      date: '2026-07-20', time: '09:00', timezone: 'CET', type: 'Conference',
      format: 'In-Person', location: 'Vienna, Austria',
      registrationUrl: 'https://icml.cc',
      topics: ['Machine Learning', 'AI'], isFree: false, price: '\$750', attendeeCount: 8000),
    AIEvent(id: 'f3', title: 'Anthropic Safety Summit', organizer: 'Anthropic',
      description: 'Deep dive into AI alignment research, constitutional AI, and building safe AI systems.',
      date: '2026-05-15', time: '10:00', timezone: 'PST', type: 'Seminar', format: 'Virtual',
      registrationUrl: 'https://www.anthropic.com',
      topics: ['AI Safety', 'Transformers', 'LLM'], isFree: true, attendeeCount: 5000),
    AIEvent(id: 'f4', title: 'Google I/O AI Track', organizer: 'Google',
      description: 'Annual developer conference with dedicated AI/ML sessions covering Gemini, TensorFlow, and cloud AI.',
      date: '2026-05-20', time: '10:00', timezone: 'PST', type: 'Conference',
      format: 'Hybrid', location: 'Mountain View, CA',
      registrationUrl: 'https://io.google/2026/',
      topics: ['Generative AI', 'Cloud AI', 'Machine Learning'], isFree: true, attendeeCount: 25000),
    AIEvent(id: 'f5', title: 'LLM Fine-tuning Masterclass', organizer: 'Hugging Face',
      description: 'Hands-on workshop covering LoRA, QLoRA, and PEFT techniques for efficient LLM customization.',
      date: '2026-06-15', time: '14:00', timezone: 'CET', type: 'Workshop', format: 'Virtual',
      registrationUrl: 'https://huggingface.co/events',
      topics: ['LLM', 'Fine-tuning', 'Transformers'], isFree: true, attendeeCount: 3000),
    AIEvent(id: 'f6', title: 'AI in Healthcare Summit', organizer: 'MIT',
      description: 'Exploring the intersection of artificial intelligence and healthcare innovation.',
      date: '2026-06-08', time: '09:00', timezone: 'EST', type: 'Conference',
      format: 'In-Person', location: 'Boston, MA',
      registrationUrl: 'https://mitsloan.mit.edu/events',
      topics: ['Healthcare AI', 'Deep Learning'], isFree: false, price: '\$500', attendeeCount: 2000),
    AIEvent(id: 'f7', title: 'MLOps Community Meetup', organizer: 'MLOps Community',
      description: 'Monthly virtual meetup discussing best practices in ML deployment and monitoring.',
      date: '2026-05-20', time: '18:00', timezone: 'UTC', type: 'Meetup', format: 'Virtual',
      registrationUrl: 'https://mlops.community/events',
      topics: ['MLOps', 'Cloud AI'], isFree: true, attendeeCount: 800),
    AIEvent(id: 'f8', title: 'Responsible AI Forum', organizer: 'Partnership on AI',
      description: 'Multi-stakeholder forum on responsible AI development and governance frameworks.',
      date: '2026-09-15', time: '09:00', timezone: 'GMT', type: 'Seminar',
      format: 'Hybrid', location: 'London, UK',
      registrationUrl: 'https://partnershiponai.org',
      topics: ['AI Ethics', 'AI Safety'], isFree: false, price: '\$200', attendeeCount: 1500),
    AIEvent(id: 'f9', title: 'Diffusion Models Deep Dive', organizer: 'Stanford HAI',
      description: 'Technical webinar on latest advances in diffusion models for image, video, and audio.',
      date: '2026-04-25', time: '11:00', timezone: 'PST', type: 'Webinar', format: 'Virtual',
      registrationUrl: 'https://hai.stanford.edu/events',
      topics: ['Diffusion Models', 'Generative AI', 'Computer Vision'], isFree: true, attendeeCount: 4000),
    AIEvent(id: 'f10', title: 'AWS re:Invent AI/ML Track', organizer: 'AWS',
      description: 'Comprehensive AI/ML sessions covering SageMaker, Bedrock, and enterprise AI solutions.',
      date: '2026-11-30', time: '09:00', timezone: 'PST', type: 'Conference',
      format: 'In-Person', location: 'Las Vegas, NV',
      registrationUrl: 'https://reinvent.awsevents.com',
      topics: ['Cloud AI', 'Machine Learning'], isFree: false, price: '\$1,899', attendeeCount: 60000),
  ];
}

// Extension for string truncation
extension _StringTake on String {
  String take(int n) => length <= n ? this : '${substring(0, n)}...';
}

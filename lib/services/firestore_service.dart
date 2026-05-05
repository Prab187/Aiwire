import '../models/article.dart';
import '../models/job.dart';
import '../models/event.dart';
import 'news_service.dart';
import 'job_service.dart';
import 'events_service.dart';

class FirestoreService {
  static Future<List<Article>> fetchArticles() => NewsService.fetchAINews();

  static Future<List<Job>> fetchJobs({
    String? query, String? type, String? level,
    String countryCode = '', String city = '', String country = '',
  }) {
    return JobService.fetchJobs(
      query: query, type: type, level: level,
      country: country.isNotEmpty ? country : 'us',
    );
  }

  static Future<List<AIEvent>> fetchEvents({String? type, String? format}) {
    return EventsService.fetchEvents(type: type, format: format);
  }

  static Future<void> refreshIfStale() async {}
}

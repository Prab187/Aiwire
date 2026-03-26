import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/udemy_course.dart';

class UdemyService {
  static const String _baseUrl = 'https://www.udemy.com/api-2.0/courses/';

  static String _basicAuth() {
    const clientId = String.fromEnvironment('UDEMY_CLIENT_ID');
    const clientSecret = String.fromEnvironment('UDEMY_CLIENT_SECRET');
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    return 'Basic $credentials';
  }

  static Future<List<UdemyCourse>> fetchAICourses({String search = 'artificial intelligence'}) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'search': search,
      'page_size': '20',
      'ordering': 'highest-rated',
      'language': 'en',
      'fields[course]': 'id,title,headline,url,price,avg_rating,num_reviews,image_480x270,visible_instructors',
      'fields[user]': 'display_name',
    });

    final response = await http.get(uri, headers: {
      'Authorization': _basicAuth(),
      'Accept': 'application/json, version=2',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];
      return results
          .map((c) => UdemyCourse.fromJson(c as Map<String, dynamic>))
          .where((c) => c.title.isNotEmpty && c.rating >= 3.5)
          .toList();
    } else {
      throw Exception('Udemy API error: ${response.statusCode}');
    }
  }
}

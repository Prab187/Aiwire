import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/certification.dart';

class CertificationService {
  // ── Coursera public catalog (no auth needed) ─────────────────────────────
  static Future<List<Certification>> _fetchCourseraCourses() async {
    final url = Uri.parse(
      'https://api.coursera.org/api/courses.v1'
      '?q=search&query=artificial+intelligence+machine+learning'
      '&includes=partnerIds'
      '&fields=name,description,slug,partnerIds,certificates'
      '&limit=25'
    );

    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final courses = data['elements'] as List? ?? [];

      return courses.map((c) {
        final name = c['name'] ?? '';
        final desc = _cleanDescription(c['description'] ?? '');

        return Certification(
          id: 'coursera_${c['id']}',
          name: name,
          provider: 'Coursera',
          providerType: 'Platform',
          description: desc,
          level: _inferLevel(name, desc),
          url: c['slug'] != null ? 'https://www.coursera.org/learn/${c['slug']}' : null,
          skills: _extractSkills(name, desc),
          isNew: false,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Additional Coursera specializations search ───────────────────────────
  static Future<List<Certification>> _fetchCourseraSpecializations() async {
    final queries = [
      'deep+learning',
      'natural+language+processing',
      'computer+vision',
      'generative+AI',
    ];

    final allCerts = <Certification>[];

    for (final query in queries) {
      final url = Uri.parse(
        'https://api.coursera.org/api/courses.v1'
        '?q=search&query=$query'
        '&fields=name,description,slug'
        '&limit=5'
      );

      try {
        final response = await http.get(url, headers: {
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final courses = data['elements'] as List? ?? [];

        for (final c in courses) {
          final name = c['name'] ?? '';
          final desc = _cleanDescription(c['description'] ?? '');
          final id = 'coursera_sp_${c['id']}';

          // Avoid duplicates
          if (allCerts.any((cert) => cert.id == id)) continue;

          allCerts.add(Certification(
            id: id,
            name: name,
            provider: 'Coursera',
            providerType: 'Platform',
            description: desc,
            level: _inferLevel(name, desc),
            url: c['slug'] != null ? 'https://www.coursera.org/learn/${c['slug']}' : null,
            skills: _extractSkills(name, desc),
            isNew: false,
          ));
        }
      } catch (_) {
        continue;
      }
    }

    return allCerts;
  }

  // ── Udemy courses (free key — udemy.com/developers) ──────────────────────
  static Future<List<Certification>> _fetchUdemyCourses() async {
    const clientId = String.fromEnvironment('UDEMY_CLIENT_ID');
    const clientSecret = String.fromEnvironment('UDEMY_CLIENT_SECRET');
    if (clientId.isEmpty || clientSecret.isEmpty) return [];

    final queries = ['artificial intelligence', 'machine learning', 'deep learning', 'LLM'];
    final allCerts = <Certification>[];
    final seen = <int>{};

    for (final query in queries) {
      try {
        final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
        final uri = Uri.parse(
          'https://www.udemy.com/api-2.0/courses/'
          '?search=$query&page_size=10&ordering=highest-rated&language=en'
          '&fields[course]=id,title,headline,url,price,avg_rating,num_reviews,image_480x270,visible_instructors',
        );
        final response = await http.get(uri, headers: {
          'Authorization': 'Basic $credentials',
          'Accept': 'application/json, version=2',
        }).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final results = data['results'] as List? ?? [];

        for (final c in results) {
          final id = c['id'] as int? ?? 0;
          if (!seen.add(id)) continue;
          final rating = (c['avg_rating'] as num?)?.toDouble() ?? 0.0;
          if (rating < 3.5) continue;

          final instructors = c['visible_instructors'] as List? ?? [];
          final instructor = instructors.isNotEmpty
              ? (instructors.first['display_name'] ?? 'Unknown').toString()
              : 'Unknown';
          final title = c['title'] ?? '';
          final desc = c['headline'] ?? '';

          allCerts.add(Certification(
            id: 'udemy_$id',
            name: title,
            provider: 'Udemy · $instructor',
            providerType: 'Platform',
            description: desc,
            level: _inferLevel(title, desc),
            price: c['price'] ?? 'Paid',
            isFree: c['price'] == 'Free',
            url: 'https://www.udemy.com${c['url'] ?? ''}',
            skills: _extractSkills(title, desc),
            rating: rating,
            enrolledCount: c['num_reviews'] as int?,
          ));
        }
      } catch (_) {
        continue;
      }
    }
    return allCerts;
  }

  // ── Public method ────────────────────────────────────────────────────────
  static Future<List<Certification>> fetchCertifications({String? level, String? providerType}) async {
    final results = await Future.wait([
      _fetchCourseraCourses().catchError((_) => <Certification>[]),
      _fetchCourseraSpecializations().catchError((_) => <Certification>[]),
      _fetchUdemyCourses().catchError((_) => <Certification>[]),
    ]);

    // Merge and deduplicate
    final seen = <String>{};
    var certs = <Certification>[];
    for (final list in results) {
      for (final cert in list) {
        if (seen.add(cert.id)) {
          certs.add(cert);
        }
      }
    }

    // If API fails, use curated fallback
    if (certs.isEmpty) {
      certs = List.from(_fallbackCerts);
    }

    if (level != null && level != 'All') {
      certs = certs.where((c) => c.level == level).toList();
    }
    if (providerType != null && providerType != 'All') {
      certs = certs.where((c) => c.providerType == providerType).toList();
    }

    certs.sort((a, b) {
      if (a.isNew && !b.isNew) return -1;
      if (!a.isNew && b.isNew) return 1;
      return (b.rating ?? 0).compareTo(a.rating ?? 0);
    });

    return certs;
  }

  static int get totalCerts => 10;

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _inferLevel(String name, String desc) {
    final text = '$name $desc'.toLowerCase();
    if (text.contains('advanced') || text.contains('expert') || text.contains('professional')) return 'Advanced';
    if (text.contains('beginner') || text.contains('introduction') || text.contains('fundamentals') || text.contains('getting started')) return 'Beginner';
    return 'Intermediate';
  }

  static String _cleanDescription(String desc) {
    var clean = desc
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean.length > 250 ? '${clean.substring(0, 250)}...' : clean;
  }

  static List<String> _extractSkills(String title, String description) {
    final text = '$title $description'.toLowerCase();
    final skillMap = {
      'python': 'Python', 'tensorflow': 'TensorFlow', 'pytorch': 'PyTorch',
      'keras': 'Keras', 'scikit': 'Scikit-learn', 'nlp': 'NLP',
      'deep learning': 'Deep Learning', 'machine learning': 'Machine Learning',
      'computer vision': 'Computer Vision', 'neural network': 'Neural Networks',
      'transformer': 'Transformers', 'llm': 'LLM', 'gpt': 'GPT',
      'reinforcement': 'RL', 'generative': 'Generative AI',
      'data science': 'Data Science', 'statistics': 'Statistics',
      'sql': 'SQL', 'aws': 'AWS', 'gcp': 'GCP', 'azure': 'Azure',
      'mlops': 'MLOps', 'fine-tun': 'Fine-tuning', 'rlhf': 'RLHF',
      'prompt': 'Prompt Engineering', 'diffusion': 'Diffusion Models',
      'regression': 'Regression', 'classification': 'Classification',
      'clustering': 'Clustering', 'optimization': 'Optimization',
    };

    final found = <String>[];
    for (final entry in skillMap.entries) {
      if (text.contains(entry.key) && found.length < 4) {
        found.add(entry.value);
      }
    }
    return found.isEmpty ? ['AI/ML'] : found;
  }

  // ── Fallback curated certifications ──────────────────────────────────────
  static final List<Certification> _fallbackCerts = [
    Certification(id: 'c1', name: 'Google Professional ML Engineer', provider: 'Google Cloud',
      providerType: 'Tech Company',
      description: 'Validate your ability to design, build, and productionize ML models using Google Cloud.',
      level: 'Advanced', duration: '3-6 months', price: '\$200',
      url: 'https://cloud.google.com/learn/certification/machine-learning-engineer',
      skills: ['TensorFlow', 'GCP', 'MLOps', 'Deep Learning'], rating: 4.7, enrolledCount: 45000),
    Certification(id: 'c2', name: 'AWS Machine Learning Specialty', provider: 'AWS',
      providerType: 'Tech Company',
      description: 'Demonstrate expertise in building, training, and deploying ML models on AWS.',
      level: 'Advanced', duration: '4-6 months', price: '\$300',
      url: 'https://aws.amazon.com/certification/certified-machine-learning-specialty/',
      skills: ['AWS', 'Python', 'Deep Learning', 'MLOps'], rating: 4.5, enrolledCount: 38000),
    Certification(id: 'c3', name: 'Deep Learning Specialization', provider: 'Stanford / Coursera',
      providerType: 'University',
      description: 'Andrew Ng\'s foundational deep learning course covering CNNs, RNNs, and transformers.',
      level: 'Intermediate', duration: '3 months', price: '\$49/mo',
      url: 'https://www.coursera.org/specializations/deep-learning',
      skills: ['Deep Learning', 'Python', 'TensorFlow', 'Neural Networks'], rating: 4.9, enrolledCount: 850000),
    Certification(id: 'c4', name: 'Microsoft Azure AI Engineer', provider: 'Microsoft',
      providerType: 'Tech Company',
      description: 'Design and implement AI solutions using Azure Cognitive Services and Azure ML.',
      level: 'Advanced', duration: '4 months', price: '\$165',
      url: 'https://learn.microsoft.com/en-us/credentials/certifications/azure-ai-engineer/',
      skills: ['Azure', 'NLP', 'Machine Learning'], rating: 4.4, enrolledCount: 28000),
    Certification(id: 'c5', name: 'MIT Professional Certificate in ML & AI', provider: 'MIT xPRO',
      providerType: 'University',
      description: 'Comprehensive program covering ML fundamentals, deep learning, and AI strategy.',
      level: 'Intermediate', duration: '12 months', price: '\$2,750',
      url: 'https://xpro.mit.edu/programs/program-v1:xPRO+MLx/',
      skills: ['Machine Learning', 'Python', 'Statistics'], rating: 4.6, enrolledCount: 15000, isNew: true),
    Certification(id: 'c6', name: 'TensorFlow Developer Certificate', provider: 'Google',
      providerType: 'Tech Company',
      description: 'Demonstrate proficiency in building TensorFlow models for CV, NLP, and time series.',
      level: 'Intermediate', duration: '2-3 months', price: '\$100',
      url: 'https://www.tensorflow.org/certificate',
      skills: ['TensorFlow', 'Python', 'Keras', 'Computer Vision'], rating: 4.5, enrolledCount: 65000),
    Certification(id: 'c7', name: 'Prompt Engineering for LLMs', provider: 'DeepLearning.AI',
      providerType: 'Platform',
      description: 'Master prompt engineering techniques for ChatGPT, Claude, and other LLMs.',
      level: 'Beginner', duration: '1 month', isFree: true,
      url: 'https://www.deeplearning.ai/short-courses/chatgpt-prompt-engineering-for-developers/',
      skills: ['Prompt Engineering', 'LLM', 'GPT'], rating: 4.8, enrolledCount: 320000, isNew: true),
    Certification(id: 'c8', name: 'MLOps Engineering on GCP', provider: 'Google Cloud',
      providerType: 'Tech Company',
      description: 'Learn MLOps best practices for continuous training, deployment, and monitoring.',
      level: 'Advanced', duration: '3 months', price: '\$49/mo',
      url: 'https://www.coursera.org/specializations/machine-learning-engineering-for-production-mlops',
      skills: ['MLOps', 'GCP', 'Machine Learning'], rating: 4.3, enrolledCount: 18000),
    Certification(id: 'c9', name: 'Stanford CS229: Machine Learning', provider: 'Stanford Online',
      providerType: 'University',
      description: 'The definitive ML course covering supervised, unsupervised learning, and best practices.',
      level: 'Intermediate', duration: '3 months', isFree: true,
      url: 'https://www.coursera.org/learn/machine-learning',
      skills: ['Machine Learning', 'Statistics', 'Python'], rating: 4.9, enrolledCount: 500000),
    Certification(id: 'c10', name: 'Generative AI with LLMs', provider: 'DeepLearning.AI / AWS',
      providerType: 'Platform',
      description: 'Understand transformer architecture, training, fine-tuning, and deployment of gen AI.',
      level: 'Intermediate', duration: '1 month', price: '\$49',
      url: 'https://www.coursera.org/learn/generative-ai-with-llms',
      skills: ['Generative AI', 'Transformers', 'Fine-tuning', 'RLHF'], rating: 4.7, enrolledCount: 180000, isNew: true),
  ];
}

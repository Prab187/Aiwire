import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/job.dart';

class JobService {
  // ── Primary: Remotive API (free, no key needed) ──────────────────────────
  static Future<List<Job>> _fetchRemotiveJobs({String? query}) async {
    final search = query ?? 'machine learning';
    final url = Uri.parse(
      'https://remotive.com/api/remote-jobs?category=software-dev&search=${Uri.encodeComponent(search)}&limit=20'
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body);
    final jobs = (data['jobs'] as List?)?.map((j) {
      final tags = (j['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
      final salary = j['salary'] ?? '';

      return Job(
        id: 'remotive_${j['id']}',
        title: j['title'] ?? '',
        company: j['company_name'] ?? '',
        location: j['candidate_required_location'] ?? 'Worldwide',
        type: 'Remote',
        level: _inferLevel(j['title'] ?? ''),
        description: _stripHtml(j['description'] ?? '', 300),
        skills: tags.take(5).toList(),
        salaryRange: salary.isNotEmpty ? salary : 'Not disclosed',
        postedAt: j['publication_date'] ?? '',
        companyLogo: j['company_logo'],
        applyUrl: j['url'] ?? '',
        featured: j['salary'] != null && j['salary'].toString().isNotEmpty,
      );
    }).toList() ?? [];

    return jobs;
  }

  // ── Secondary: Adzuna API (free tier — 250 req/day) ──────────────────────
  static Future<List<Job>> _fetchAdzunaJobs({String? query, String country = 'us'}) async {
    final appId = dotenv.env['ADZUNA_APP_ID'];
    final appKey = dotenv.env['ADZUNA_APP_KEY'];
    if (appId == null || appKey == null || appId.isEmpty || appKey.isEmpty) return [];

    final search = query ?? 'artificial intelligence machine learning';
    final url = Uri.parse(
      'https://api.adzuna.com/v1/api/jobs/$country/search/1'
      '?app_id=$appId&app_key=$appKey'
      '&what=${Uri.encodeComponent(search)}'
      '&results_per_page=15'
      '&content-type=application/json'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];

      return results.map((j) {
        final title = j['title'] ?? '';
        final salaryMin = j['salary_min'];
        final salaryMax = j['salary_max'];
        String salaryRange = 'Not disclosed';
        if (salaryMin != null && salaryMax != null) {
          salaryRange = '\$${_formatSalary(salaryMin)}K – \$${_formatSalary(salaryMax)}K';
        } else if (salaryMin != null) {
          salaryRange = 'From \$${_formatSalary(salaryMin)}K';
        }

        return Job(
          id: 'adzuna_${j['id']}',
          title: _cleanTitle(title),
          company: j['company']?['display_name'] ?? 'Unknown',
          location: j['location']?['display_name'] ?? 'Not specified',
          type: _inferType(j['description'] ?? '', j['location']?['display_name'] ?? ''),
          level: _inferLevel(title),
          description: _stripHtml(j['description'] ?? '', 300),
          skills: _extractSkills(j['description'] ?? ''),
          salaryRange: salaryRange,
          postedAt: j['created'] ?? '',
          applyUrl: j['redirect_url'] ?? '',
          featured: salaryMin != null && salaryMin > 150000,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Public method: fetches from all sources ──────────────────────────────
  static Future<List<Job>> fetchJobs({String? query, String? type, String? level}) async {
    // Fetch from both APIs in parallel
    final results = await Future.wait([
      _fetchRemotiveJobs(query: query).catchError((_) => <Job>[]),
      _fetchAdzunaJobs(query: query).catchError((_) => <Job>[]),
    ]);

    var jobs = [...results[0], ...results[1]];

    // If both APIs fail, use fallback sample data
    if (jobs.isEmpty) {
      jobs = _fallbackJobs;
    }

    // Apply filters
    if (type != null && type != 'All') {
      jobs = jobs.where((j) => j.type == type).toList();
    }
    if (level != null && level != 'All') {
      jobs = jobs.where((j) => j.level == level).toList();
    }

    // Sort: featured first, then by date
    jobs.sort((a, b) {
      if (a.featured && !b.featured) return -1;
      if (!a.featured && b.featured) return 1;
      return b.postedAt.compareTo(a.postedAt);
    });

    return jobs;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _inferLevel(String title) {
    final t = title.toLowerCase();
    if (t.contains('principal') || t.contains('staff') || t.contains('distinguished')) return 'Principal';
    if (t.contains('lead') || t.contains('head') || t.contains('director') || t.contains('vp')) return 'Lead';
    if (t.contains('senior') || t.contains('sr.') || t.contains('sr ')) return 'Senior';
    if (t.contains('junior') || t.contains('jr.') || t.contains('jr ') || t.contains('entry') || t.contains('intern')) return 'Junior';
    return 'Mid';
  }

  static String _inferType(String description, String location) {
    final text = '$description $location'.toLowerCase();
    if (text.contains('remote') || text.contains('anywhere') || text.contains('worldwide')) return 'Remote';
    if (text.contains('hybrid')) return 'Hybrid';
    return 'On-site';
  }

  static String _cleanTitle(String title) {
    return title.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  static String _stripHtml(String html, [int maxLength = 500]) {
    final clean = html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length > maxLength ? '${clean.substring(0, maxLength)}...' : clean;
  }

  static List<String> _extractSkills(String text) {
    final allSkills = [
      'Python', 'Java', 'C++', 'Go', 'Rust', 'TypeScript', 'JavaScript', 'SQL',
      'TensorFlow', 'PyTorch', 'Keras', 'Scikit-learn', 'Pandas', 'NumPy',
      'AWS', 'GCP', 'Azure', 'Docker', 'Kubernetes', 'MLflow',
      'NLP', 'Computer Vision', 'Deep Learning', 'Machine Learning',
      'Transformers', 'LLM', 'BERT', 'GPT', 'CUDA', 'Spark',
      'React', 'Node.js', 'Flutter', 'FastAPI', 'Django',
      'PostgreSQL', 'MongoDB', 'Redis', 'Kafka',
    ];

    final found = <String>[];
    final lower = text.toLowerCase();
    for (final skill in allSkills) {
      if (lower.contains(skill.toLowerCase()) && found.length < 5) {
        found.add(skill);
      }
    }
    return found.isEmpty ? ['AI/ML'] : found;
  }

  static String _formatSalary(dynamic salary) {
    if (salary == null) return '0';
    final num val = salary is num ? salary : num.tryParse(salary.toString()) ?? 0;
    return (val / 1000).round().toString();
  }

  static int get totalJobs => 12;
  static int get featuredJobs => 4;

  // ── Fallback data if APIs are unreachable ────────────────────────────────
  static final List<Job> _fallbackJobs = [
    Job(id: 'f1', title: 'Senior ML Engineer', company: 'Google DeepMind',
      location: 'London, UK', type: 'Hybrid', level: 'Senior',
      description: 'Build and deploy large-scale machine learning models for next-gen AI products.',
      skills: ['Python', 'TensorFlow', 'PyTorch', 'Transformers', 'MLOps'],
      salaryRange: '\$180K – \$280K', postedAt: '2026-03-19', applyUrl: '', featured: true),
    Job(id: 'f2', title: 'LLM Research Scientist', company: 'Anthropic',
      location: 'San Francisco, CA', type: 'Hybrid', level: 'Senior',
      description: 'Conduct foundational research on large language model alignment and safety.',
      skills: ['Python', 'RLHF', 'NLP', 'PyTorch', 'Research'],
      salaryRange: '\$200K – \$350K', postedAt: '2026-03-18', applyUrl: '', featured: true),
    Job(id: 'f3', title: 'AI Product Manager', company: 'OpenAI',
      location: 'San Francisco, CA', type: 'On-site', level: 'Senior',
      description: 'Drive product strategy for consumer AI applications at scale.',
      skills: ['Product Strategy', 'AI/ML', 'User Research', 'Agile'],
      salaryRange: '\$190K – \$300K', postedAt: '2026-03-20', applyUrl: '', featured: true),
    Job(id: 'f4', title: 'Computer Vision Engineer', company: 'Tesla',
      location: 'Palo Alto, CA', type: 'On-site', level: 'Mid',
      description: 'Develop real-time computer vision pipelines for autonomous driving.',
      skills: ['Python', 'C++', 'OpenCV', 'CUDA', 'Deep Learning'],
      salaryRange: '\$150K – \$220K', postedAt: '2026-03-17', applyUrl: ''),
    Job(id: 'f5', title: 'NLP Engineer', company: 'Meta',
      location: 'Remote', type: 'Remote', level: 'Mid',
      description: 'Build multilingual NLP systems for content understanding across Meta platforms.',
      skills: ['Python', 'NLP', 'BERT', 'Hugging Face', 'Distributed Systems'],
      salaryRange: '\$160K – \$240K', postedAt: '2026-03-16', applyUrl: ''),
    Job(id: 'f6', title: 'MLOps Engineer', company: 'Spotify',
      location: 'Stockholm, Sweden', type: 'Remote', level: 'Mid',
      description: 'Design and maintain ML infrastructure for recommendation systems.',
      skills: ['Kubernetes', 'Docker', 'Python', 'MLflow', 'AWS'],
      salaryRange: '\$130K – \$190K', postedAt: '2026-03-15', applyUrl: ''),
  ];
}

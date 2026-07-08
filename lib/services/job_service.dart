import '../config/secrets.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/job.dart';
import 'cors_proxy.dart';

class JobService {
  // ── Primary: Remotive API (free, no key needed) ──────────────────────────
  static Future<List<Job>> _fetchRemotiveJobs({String? query}) async {
    final search = query ?? 'machine learning';
    final url = corsUri(
      'https://remotive.com/api/remote-jobs?category=software-dev&search=${Uri.encodeComponent(search)}&limit=20'
    );

    try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));
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
        salaryRange: salary.isNotEmpty ? salary : 'Salary not listed',
        postedAt: j['publication_date'] ?? '',
        companyLogo: j['company_logo'],
        applyUrl: j['url'] ?? '',
        featured: j['salary'] != null && j['salary'].toString().isNotEmpty,
      );
    }).toList() ?? [];

    return jobs;
    } catch (_) {
      return [];
    }
  }

  // ── The Muse API (free, no key — tech & data science jobs) ─────────────
  static Future<List<Job>> _fetchTheMuseJobs({String? query}) async {
    // The Muse has a "Data Science" category — no auth required
    final url = corsUri(
      'https://www.themuse.com/api/public/jobs'
      '?category=Data+Science&category=Software+Engineer&page=0',
    );

    try {
      final response = await http.get(url,
        headers: {'User-Agent': 'AIWire/1.0'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];

      final aiFilter = RegExp(
        r'(machine.?learn|data.?scien|deep.?learn|nlp|llm|computer.?vision|'
        r'ai |ml |artificial.?intelligence|mlops|neural)',
        caseSensitive: false,
      );
      final searchLower = query?.toLowerCase() ?? '';

      return results.where((j) {
        final title = (j['name'] as String? ?? '').toLowerCase();
        final contents = (j['contents'] as String? ?? '').toLowerCase();
        return aiFilter.hasMatch(title) ||
            (searchLower.isNotEmpty &&
                (title.contains(searchLower) || contents.contains(searchLower)));
      }).map((j) {
        final locations = (j['locations'] as List? ?? []);
        final location = locations.isNotEmpty
            ? (locations[0]['name'] as String? ?? 'Remote')
            : 'Remote';
        final levels = (j['levels'] as List? ?? []);
        final levelName = levels.isNotEmpty
            ? (levels[0]['name'] as String? ?? '')
            : '';

        return Job(
          id: 'muse_${j['id']}',
          title: j['name'] ?? '',
          company: j['company']?['name'] ?? '',
          location: location,
          type: location.toLowerCase().contains('remote') ? 'Remote' : 'On-site',
          level: _mapMuseLevel(levelName),
          description: _stripHtml(j['contents'] ?? '', 300),
          skills: _extractSkills(j['contents'] ?? ''),
          salaryRange: 'Salary not listed',
          postedAt: (j['publication_date'] as String? ?? '').split('T').first,
          applyUrl: j['refs']?['landing_page'] ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static String _mapMuseLevel(String level) {
    final l = level.toLowerCase();
    if (l.contains('senior') || l.contains('management')) return 'Senior';
    if (l.contains('mid') || l.contains('experienced')) return 'Mid';
    if (l.contains('entry') || l.contains('junior') || l.contains('intern')) return 'Junior';
    return 'Mid';
  }

  // ── Arbeitnow API (free, no key — EU remote tech jobs) ───────────────────
  static Future<List<Job>> _fetchArbeitnowJobs({String? query}) async {
    final url = corsUri('https://arbeitnow.com/api/job-board-api');

    try {
      final response = await http.get(url,
        headers: {'User-Agent': 'AIWire/1.0'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final jobs = data['data'] as List? ?? [];

      final aiFilter = RegExp(
        r'(machine.?learn|data.?scien|deep.?learn|nlp|llm|computer.?vision|'
        r'\bai\b|\bml\b|artificial.?intelligence|mlops|neural|python|pytorch|'
        r'tensorflow|data.?engineer)',
        caseSensitive: false,
      );
      final searchLower = query?.toLowerCase() ?? '';

      return jobs.where((j) {
        final title = (j['title'] as String? ?? '').toLowerCase();
        final desc = (j['description'] as String? ?? '').toLowerCase();
        final tags = (j['tags'] as List? ?? [])
            .map((t) => t.toString().toLowerCase())
            .join(' ');
        return aiFilter.hasMatch(title) ||
            aiFilter.hasMatch(tags) ||
            (searchLower.isNotEmpty && (title.contains(searchLower) || desc.contains(searchLower)));
      }).map((j) {
        final createdAt = j['created_at'];
        String postedAt = '';
        if (createdAt is int) {
          postedAt = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000)
              .toIso8601String()
              .split('T')
              .first;
        }

        return Job(
          id: 'arbeitnow_${j['slug'] ?? j.hashCode}',
          title: j['title'] ?? '',
          company: j['company_name'] ?? '',
          location: j['location'] ?? 'Europe',
          type: j['remote'] == true ? 'Remote' : 'On-site',
          level: _inferLevel(j['title'] ?? ''),
          description: _stripHtml(j['description'] ?? '', 300),
          skills: _extractSkills(j['description'] ?? ''),
          salaryRange: 'Salary not listed',
          postedAt: postedAt,
          applyUrl: j['url'] ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Jobicy API (free, no key — remote jobs with salary & logo) ──────────
  static Future<List<Job>> _fetchJobicyJobs({String? query}) async {
    final url = corsUri(
      'https://jobicy.com/api/v2/remote-jobs?count=50',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'AIWire/1.0'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final jobs = data['jobs'] as List? ?? [];

      // Filter to AI/ML/Data Science roles
      const aiIndustries = {
        'data science', 'machine learning', 'artificial intelligence',
        'software development', 'software engineering', 'devops',
      };
      final aiTitles = RegExp(
        r'(machine learning|deep learning|data scien|nlp|llm|ai |ml |'
        r'artificial intelligence|computer vision|mlops|pytorch|tensorflow)',
        caseSensitive: false,
      );
      const aiQueryTerms = {
        'machine learning', 'deep learning', 'data science', 'nlp', 'llm',
        'computer vision', 'mlops', 'ai', 'ml',
      };

      final searchTerms = query?.toLowerCase().split(' ').toSet() ?? aiQueryTerms;

      return jobs.where((j) {
        final industry = (j['jobIndustry'] as List? ?? [])
            .map((i) => i.toString().toLowerCase())
            .toSet();
        final title = (j['jobTitle'] as String? ?? '').toLowerCase();
        final excerpt = (j['jobExcerpt'] as String? ?? '').toLowerCase();

        // Keep if industry matches, title matches, or search query overlaps
        return industry.any((i) => aiIndustries.contains(i)) ||
            aiTitles.hasMatch(title) ||
            searchTerms.any((t) => title.contains(t) || excerpt.contains(t));
      }).map((j) {
        final salaryMin = j['salaryMin'];
        final salaryMax = j['salaryMax'];
        final currency = j['salaryCurrency'] as String? ?? 'USD';
        String salaryRange = 'Salary not listed';
        if (salaryMin != null && salaryMax != null) {
          salaryRange = '$currency ${_formatSalary(salaryMin)}K – ${_formatSalary(salaryMax)}K / yr';
        } else if (salaryMin != null) {
          salaryRange = 'From $currency ${_formatSalary(salaryMin)}K / yr';
        }

        return Job(
          id: 'jobicy_${j['id']}',
          title: j['jobTitle'] ?? '',
          company: j['companyName'] ?? '',
          location: j['jobGeo'] ?? 'Worldwide',
          type: 'Remote',
          level: j['jobLevel'] as String? ?? _inferLevel(j['jobTitle'] ?? ''),
          description: _stripHtml(
              (j['jobDescription'] ?? j['jobExcerpt'] ?? '') as String, 300),
          skills: _extractSkills(
              (j['jobDescription'] ?? j['jobExcerpt'] ?? '') as String),
          salaryRange: salaryRange,
          postedAt: (j['pubDate'] as String? ?? '').split('T').first,
          companyLogo: j['companyLogo'] as String?,
          applyUrl: j['url'] ?? '',
          featured: salaryMin != null && (salaryMin as num) > 150000,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Reed.co.uk API (free key — reed.co.uk/developers/jobseeker) ──────────
  static Future<List<Job>> _fetchReedJobs({String? query}) async {
    const apiKey = Secrets.reedApiKey;
    if (apiKey.isEmpty) return [];

    final search =
        Uri.encodeComponent(query ?? 'artificial intelligence machine learning');
    final url = corsUri(
      'https://www.reed.co.uk/api/1.0/search'
      '?keywords=$search&resultsToTake=15',
    );

    try {
      // Reed uses HTTP Basic Auth: API key as username, empty password
      final credentials = base64Encode(utf8.encode('$apiKey:'));
      final response = await http.get(url, headers: {
        'Authorization': 'Basic $credentials',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];

      return results.map((j) {
        final min = j['minimumSalary'];
        final max = j['maximumSalary'];
        String salary = 'Salary not listed';
        if (min != null && max != null) {
          salary = '£${_formatSalary(min)}K – £${_formatSalary(max)}K';
        } else if (min != null) {
          salary = 'From £${_formatSalary(min)}K';
        }
        return Job(
          id: 'reed_${j['jobId']}',
          title: j['jobTitle'] ?? '',
          company: j['employerName'] ?? '',
          location: j['locationName'] ?? 'UK',
          type: _inferType(j['jobDescription'] ?? '', j['locationName'] ?? ''),
          level: _inferLevel(j['jobTitle'] ?? ''),
          description: _stripHtml(j['jobDescription'] ?? '', 300),
          skills: _extractSkills(j['jobDescription'] ?? ''),
          salaryRange: salary,
          postedAt: (j['date'] as String? ?? '').split('T').first,
          applyUrl: j['jobUrl'] ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Secondary: Adzuna API (free tier — 250 req/day) ──────────────────────
  static Future<List<Job>> _fetchAdzunaJobs({String? query, String country = 'us'}) async {
    const appId = Secrets.adzunaAppId;
    const appKey = Secrets.adzunaAppKey;
    if (appId.isEmpty || appKey.isEmpty) return [];

    final search = query ?? 'artificial intelligence machine learning';
    final url = corsUri(
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
        String salaryRange = 'Salary not listed';
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

  // ── Country alias map — all terms that refer to the same country ──────────
  static const Map<String, List<String>> _countryAliases = {
    'gb': ['united kingdom', 'uk', 'england', 'scotland', 'wales', 'britain',
           'great britain', 'london', 'manchester', 'birmingham', 'edinburgh'],
    'us': ['united states', 'usa', 'u.s.', 'america', 'new york', 'san francisco',
           'seattle', 'boston', 'chicago', 'austin', 'los angeles'],
    'au': ['australia', 'sydney', 'melbourne', 'brisbane', 'perth'],
    'ca': ['canada', 'toronto', 'vancouver', 'montreal', 'calgary'],
    'de': ['germany', 'berlin', 'munich', 'hamburg', 'frankfurt'],
    'fr': ['france', 'paris', 'lyon', 'marseille'],
    'in': ['india', 'bangalore', 'bengaluru', 'mumbai', 'delhi', 'new delhi',
           'hyderabad', 'pune', 'chennai', 'kolkata', 'noida', 'gurgaon',
           'gurugram', 'ghaziabad', 'ahmedabad', 'chandigarh', 'coimbatore',
           'navi mumbai', 'jaipur', 'karnataka', 'maharashtra', 'telangana',
           'tamil nadu', 'rajasthan', 'uttar pradesh'],
    'nl': ['netherlands', 'amsterdam', 'rotterdam'],
    'sg': ['singapore'],
  };

  static bool _jobMatchesCountry(Job job, String countryCode, String city, String country) {
    final loc = job.location.toLowerCase();
    final cityLower = city.toLowerCase();
    final countryLower = country.toLowerCase();

    // Always accept pure remote / worldwide
    if (job.type == 'Remote' &&
        (loc.contains('worldwide') || loc.contains('anywhere') ||
         loc.contains('global') || loc == 'remote' || loc.isEmpty)) {
      return true;
    }

    // Accept if location explicitly mentions user's city or country name
    if (loc.contains(cityLower) || loc.contains(countryLower)) return true;

    // Accept via alias map for user's country
    final aliases = _countryAliases[countryCode] ?? [];
    if (aliases.any((a) => loc.contains(a))) return true;

    // Reject: check if location matches a DIFFERENT country's aliases
    for (final entry in _countryAliases.entries) {
      if (entry.key == countryCode) continue;
      if (entry.value.any((a) => loc.contains(a))) return false;
    }

    // Location is ambiguous (e.g. just "Remote") — keep it
    return true;
  }

  // ── Location-aware job search ─────────────────────────────────────────────
  static Future<List<Job>> fetchNearbyJobs({
    required String city,
    required String country,
    required String countryCode,
    double? lat,
    double? lng,
    int radiusKm = 50,
    bool includeRemote = true,
  }) async {
    final futures = <Future<List<Job>>>[
      // Adzuna: scoped to the user's country
      _fetchAdzunaJobs(query: 'artificial intelligence machine learning', country: countryCode)
          .catchError((_) => <Job>[]),
      // Reed: UK-specific board
      _fetchReedJobs(query: 'artificial intelligence machine learning')
          .catchError((_) => <Job>[]),
    ];

    if (includeRemote) {
      futures.addAll([
        _fetchRemotiveJobs(query: 'machine learning').catchError((_) => <Job>[]),
        _fetchJobicyJobs(query: 'machine learning').catchError((_) => <Job>[]),
      ]);
    }

    final results = await Future.wait(futures);
    var jobs = results.expand((l) => l).toList();

    // Deduplicate
    final seen = <String>{};
    jobs = jobs.where((j) => seen.add('${j.title}|${j.company}')).toList();

    // ── LOCATION FILTER: only keep jobs in the user's country or truly remote ──
    jobs = jobs.where((j) => _jobMatchesCountry(j, countryCode, city, country)).toList();

    if (jobs.isEmpty) {
      // Fallback: show remote-only jobs rather than US fallback data
      jobs = _fallbackJobs
          .where((j) => j.type == 'Remote' || _jobMatchesCountry(j, countryCode, city, country))
          .toList();
    }

    // Sort: local city matches first, then country matches, then remote
    final cityLower = city.toLowerCase();
    final countryLower = country.toLowerCase();
    jobs.sort((a, b) {
      int score(Job j) {
        final loc = j.location.toLowerCase();
        if (loc.contains(cityLower)) return 3;
        if (loc.contains(countryLower)) return 2;
        if (j.type == 'Remote') return 1;
        return 0;
      }
      final diff = score(b) - score(a);
      if (diff != 0) return diff;
      if (a.featured && !b.featured) return -1;
      if (!a.featured && b.featured) return 1;
      return b.postedAt.compareTo(a.postedAt);
    });

    return jobs;
  }

  // ── Resume-matched jobs: country-aware search ─────────────────────────────
  static Future<List<Job>> fetchJobsForResume({
    required List<String> skills,
    required String countryCode,
    required String jobTitle,
    String? country,
    String city = '',
  }) async {
    final query = '$jobTitle ${skills.take(3).join(' ')}';
    final results = await Future.wait([
      _fetchRemotiveJobs(query: query).catchError((_) => <Job>[]),
      _fetchJobicyJobs(query: query).catchError((_) => <Job>[]),
      _fetchTheMuseJobs(query: query).catchError((_) => <Job>[]),
      _fetchArbeitnowJobs(query: query).catchError((_) => <Job>[]),
      _fetchAdzunaJobs(query: query, country: countryCode).catchError((_) => <Job>[]),
      _fetchReedJobs(query: query).catchError((_) => <Job>[]),
    ]);

    var jobs = [
      ...results[0], ...results[1], ...results[2],
      ...results[3], ...results[4], ...results[5],
    ];

    final seen = <String>{};
    jobs = jobs.where((j) => seen.add('${j.title}|${j.company}')).toList();

    final countryStr = country ?? '';

    // Filter: user's country first, truly remote worldwide jobs, reject others
    final localJobs = jobs.where((j) => _jobMatchesCountry(j, countryCode, city, countryStr)).toList();
    final remoteJobs = jobs.where((j) =>
        !localJobs.contains(j) &&
        j.type == 'Remote' &&
        (j.location.toLowerCase().contains('worldwide') ||
         j.location.toLowerCase().contains('anywhere') ||
         j.location.toLowerCase().contains('global') ||
         j.location.isEmpty)).toList();

    jobs = [...localJobs, ...remoteJobs];
    if (jobs.isEmpty) {
      jobs = _fallbackJobs
          .where((j) => j.type == 'Remote' || _jobMatchesCountry(j, countryCode, city, countryStr))
          .toList();
    }

    // Sort: city match → country match → remote → featured → date
    final cityLower = city.toLowerCase();
    final countryLower = countryStr.toLowerCase();
    jobs.sort((a, b) {
      int score(Job j) {
        final loc = j.location.toLowerCase();
        if (cityLower.isNotEmpty && loc.contains(cityLower)) return 5;
        if (countryLower.isNotEmpty && loc.contains(countryLower)) return 4;
        final aliases = _countryAliases[countryCode] ?? [];
        if (aliases.any((a) => loc.contains(a))) return 3;
        if (j.type == 'Remote') return 2;
        if (j.featured) return 1;
        return 0;
      }
      final diff = score(b) - score(a);
      if (diff != 0) return diff;
      return b.postedAt.compareTo(a.postedAt);
    });

    return jobs;
  }

  // ── Public method: fetches from all sources ──────────────────────────────
  static Future<List<Job>> fetchJobs({String? query, String? type, String? level, String country = 'us'}) async {
    final results = await Future.wait([
      _fetchRemotiveJobs(query: query).catchError((_) => <Job>[]),
      _fetchJobicyJobs(query: query).catchError((_) => <Job>[]),
      _fetchTheMuseJobs(query: query).catchError((_) => <Job>[]),
      _fetchArbeitnowJobs(query: query).catchError((_) => <Job>[]),
      _fetchAdzunaJobs(query: query).catchError((_) => <Job>[]),
      _fetchReedJobs(query: query).catchError((_) => <Job>[]),
    ]);

    var jobs = [
      ...results[0], ...results[1], ...results[2],
      ...results[3], ...results[4], ...results[5],
    ];

    // Deduplicate by title+company
    final seen = <String>{};
    jobs = jobs.where((j) => seen.add('${j.title}|${j.company}')).toList();

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

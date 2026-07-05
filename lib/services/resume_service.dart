import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/resume_profile.dart';
import 'curated_resources.dart';

class ResumeService {
  /// Pick a resume file from device (PDF or TXT).
  static Future<PlatformFile?> pickResumeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
      withData: true,
    );
    return result?.files.firstOrNull;
  }

  /// Built-in sample resume so users can try the flow without uploading.
  static PlatformFile sampleResumeFile() {
    const sample = '''Sample Resume

Jane Doe
Software Engineer

Skills: Python, TensorFlow, PyTorch, AWS, Docker, Kubernetes,
NLP, LLM, MLOps, REST APIs, Git

Experience:
- ML Engineer, Acme AI (2022-present)
  Built and shipped LLM-powered features at scale.
- Software Engineer, Beta Co. (2019-2022)
  Backend services in Python and Go.

Education:
- B.S. Computer Science, State University (2019)
''';
    final bytes = Uint8List.fromList(utf8.encode(sample));
    return PlatformFile(
      name: 'sample_resume.txt',
      size: bytes.length,
      bytes: bytes,
    );
  }

  /// Analyze the picked file with Claude and return a ResumeProfile.
  static Future<ResumeProfile> analyzeResume(PlatformFile file) async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw Exception('Could not read file');

    final isPdf = file.extension?.toLowerCase() == 'pdf';
    final content = isPdf
        ? _pdfContent(bytes)
        : _textContent(bytes);

    final prompt = '''Analyze this resume/CV thoroughly and respond with ONLY a valid JSON object — no markdown, no explanation:
{
  "name": "candidate full name or null",
  "skills": ["up to 10 most important technical skills found in the resume"],
  "experience_level": "Junior|Mid|Senior|Lead|Principal",
  "years_of_experience": 0,
  "country": "full country name",
  "country_code": "2-letter lowercase ISO 3166-1 code (us, gb, in, ae, jp, ng, br, de, sg, au, ca, fr, nl, za, kr, se, etc). Default to 'us' ONLY if absolutely no location signal. Extract from: address, phone country code (+91=in, +44=gb, +1=us/ca, +61=au, +49=de, +971=ae, +81=jp), city names, timezone.",
  "city": "specific city name extracted from address, employer location, or phone area code (e.g. 'Hyderabad', 'London', 'San Francisco'). Empty string if not determinable.",
  "job_title": "best matching job title (e.g. ML Engineer, Data Scientist)",
  "summary": "2-3 sentence professional summary highlighting their strongest qualifications",
  "projects": ["up to 4 notable projects or work achievements mentioned — short 1-line each"],
  "certifications": ["all certifications or courses mentioned"],
  "education": "highest education: degree, institution, year if available",
  "strengths": ["3 key strengths based on what stands out in the resume"],
  "gaps": [
    {
      "name": "Specific missing skill/credential (e.g. 'AWS Machine Learning Specialty')",
      "severity": "CRITICAL | HIGH | MEDIUM",
      "market_reason": "Why this matters in their country's AI/ML market in one sentence (reference their specific country)",
      "time_to_close": "Realistic timeframe (e.g. '6 weeks', '3 months', 'ongoing')",
      "resource": "Specific named course/platform/provider (e.g. 'Stephane Maarek AWS ML on Udemy', 'DeepLearning.AI MLOps Specialization on Coursera', 'Fast.ai Practical DL course')",
      "resource_url": "Actual URL if you know it, else null",
      "cost": "Cost with local currency (e.g. 'Free', '\$49', '₹499', '£12/mo')"
    }
  ],
  "ats_score": <integer 0-100 estimating ATS compatibility based on keywords, structure, action verbs, quantified achievements, formatting>,
  "ats_issues": ["2-4 specific fixes with BEFORE/AFTER examples, e.g. 'Change \"Responsible for ML projects\" → \"Led 3 NLP projects on AWS, cut latency 35%\"'"]
}

CRITICAL for gaps:
- Generate 3 structured gaps, ranked by severity (CRITICAL first)
- Be SPECIFIC: not "cloud" but "AWS Certified Machine Learning Specialty"
- Reference their country in market_reason (e.g. "80% of India ML jobs require AWS or GCP")
- Cost should reflect their country's pricing (India: ₹, UK: £, EU: €, US: \$)

⚠️ RESOURCE HALLUCINATION GUARD — MANDATORY:
${CuratedResources.compactProviders}

Extract years_of_experience by calculating from work history dates. If dates unclear, estimate from experience_level.
Determine country from: address, phone country code, or any location mention.
For strengths: identify what makes this candidate competitive.''';

    final response = await http.post(
      Uri.parse('https://aiwire-proxy.prab187.workers.dev'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        if (isPdf) 'anthropic-beta': 'pdfs-2024-09-25',
      },
      body: json.encode({
        'model': 'claude-haiku-4-5',
        'max_tokens': 2000,
        // temperature: 0 = greedy decoding → deterministic output for the
        // same resume. Without this, the API defaults to 1.0 and the ATS
        // score (and other parsed fields) drift between identical uploads.
        'temperature': 0,
        'messages': [
          {
            'role': 'user',
            'content': [
              content,
              {'type': 'text', 'text': prompt},
            ],
          }
        ],
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final text = (data['content'][0]['text'] as String).trim();

    // Strip markdown code fences if present
    final jsonText = text
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'^```\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    final parsed = json.decode(jsonText) as Map<String, dynamic>;
    return ResumeProfile.fromJson(parsed);
  }

  static Map<String, dynamic> _pdfContent(Uint8List bytes) {
    return {
      'type': 'document',
      'source': {
        'type': 'base64',
        'media_type': 'application/pdf',
        'data': base64Encode(bytes),
      },
    };
  }

  static Map<String, dynamic> _textContent(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes);
    }
    // Trim to avoid hitting token limits
    if (text.length > 8000) text = text.substring(0, 8000);
    return {'type': 'text', 'text': text};
  }
}

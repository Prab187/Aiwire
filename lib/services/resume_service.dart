import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/resume_profile.dart';

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
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: 'proxy');
    // Proxy injects key server-side; local check skipped.

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw Exception('Could not read file');

    final isPdf = file.extension?.toLowerCase() == 'pdf';
    final content = isPdf
        ? _pdfContent(bytes)
        : _textContent(bytes);

    final prompt = '''Analyze this resume/CV thoroughly and respond with ONLY a valid JSON object — no markdown, no explanation:
{
  "name": "candidate full name or null if not found",
  "skills": ["up to 10 most important technical skills found in the resume"],
  "experience_level": "Junior|Mid|Senior|Lead|Principal",
  "years_of_experience": 0,
  "country": "full country name where the candidate is located",
  "country_code": "2-letter lowercase Adzuna country code — choose from: us gb au ca de fr in nl sg br za pl es it at be ch nz mx — use us if unsure",
  "job_title": "best matching job title to search for (e.g. ML Engineer, Data Scientist)",
  "summary": "2-3 sentence professional summary highlighting their strongest qualifications",
  "projects": ["up to 4 notable projects or work achievements — short 1-line each"],
  "certifications": ["all certifications or courses mentioned"],
  "education": "highest education: degree, institution, year if available",
  "strengths": ["3 key strengths based on what stands out"],
  "gaps": ["2-3 skill gaps based on current AI/ML market demands"],
  "ats_score": <integer 0-100 estimating how well this resume would pass an ATS scanner — based on keywords, structure, action verbs, quantified achievements, formatting>,
  "ats_issues": [
    {"before": "Worked on machine learning projects", "after": "Built and deployed 3 ML models that improved fraud detection accuracy by 24%"},
    {"before": "Led a team", "after": "Led a team of 5 engineers to ship the recommendation engine, increasing CTR by 18%"}
  ]
}

For ats_issues, return 2-4 objects, each with "before" (a real or representative weak bullet from this resume) and "after" (a stronger rewrite that adds quantified impact, action verbs, and ATS-friendly keywords).
Determine country from: address, phone country code (+44=gb, +1=us/ca, +91=in, +61=au, +49=de, etc.), or any location mention.''';

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
        'max_tokens': 1400,
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
    ).timeout(const Duration(seconds: 30));

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

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
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw Exception('Could not read file');

    final isPdf = file.extension?.toLowerCase() == 'pdf';
    final content = isPdf
        ? _pdfContent(bytes)
        : _textContent(bytes);

    final prompt = '''Analyze this resume/CV and respond with ONLY a valid JSON object — no markdown, no explanation:
{
  "name": "candidate full name or null if not found",
  "skills": ["up to 8 most important technical skills"],
  "experience_level": "Junior|Mid|Senior|Lead|Principal",
  "country": "full country name where the candidate is located",
  "country_code": "2-letter lowercase Adzuna country code — choose from: us gb au ca de fr in nl sg br za pl es it at be ch nz mx — use us if unsure",
  "job_title": "best matching job title to search for (e.g. ML Engineer, Data Scientist)",
  "summary": "1-2 sentence professional summary"
}

Determine the country from: address, phone country code (+44 = gb, +1 = us/ca, +91 = in, +61 = au, +49 = de, etc.), or any location mention.''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        if (isPdf) 'anthropic-beta': 'pdfs-2024-09-25',
      },
      body: json.encode({
        'model': 'claude-haiku-4-5',
        'max_tokens': 400,
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

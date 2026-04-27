import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';
import '../models/resume_profile.dart';
import 'claude_cache.dart';
import 'claude_error.dart';

class ResumeService {
  /// Pick a resume file from device.
  static Future<PlatformFile?> pickResumeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
      withData: true,
    );
    return result?.files.firstOrNull;
  }

  /// Analyze the picked file with Claude and return a ResumeProfile.
  /// Results are cached by file hash for 30 days.
  static Future<ResumeProfile> analyzeResume(PlatformFile file) async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not read the file. Please try uploading again.');
    }

    final ext = (file.extension ?? '').toLowerCase();
    if (!{'pdf', 'txt', 'doc', 'docx'}.contains(ext)) {
      throw Exception(
          'This file type (.$ext) is not supported. Please upload a PDF, DOCX, DOC, or TXT file.');
    }

    // Cache lookup keyed on file hash
    final cacheKey = ClaudeCache.keyFrom([
      ext,
      bytes.length,
      bytes.take(128).join(','),
      bytes.skip(bytes.length - 128).take(128).join(','),
    ]);
    final cached = await ClaudeCache.get('resume', cacheKey,
        ttl: const Duration(days: 30));
    if (cached != null) {
      try {
        final parsed = json.decode(cached) as Map<String, dynamic>;
        return ResumeProfile.fromJson(parsed);
      } catch (_) {}
    }

    // Build content for Claude
    final isPdf = ext == 'pdf';
    Map<String, dynamic> content;

    if (isPdf) {
      content = _pdfContent(bytes);
    } else if (ext == 'docx') {
      final text = _extractDocxText(bytes);
      if (text.trim().length < 50) {
        throw Exception(
            'Could not extract text from this .docx file. '
            'It may be corrupted or contain only images. '
            'Please try saving it as a PDF and uploading again.');
      }
      content = {'type': 'text', 'text': text};
    } else if (ext == 'doc') {
      final text = _extractDocText(bytes);
      if (text.trim().length < 50) {
        throw Exception(
            'Could not extract text from this .doc file. '
            'The legacy .doc format has limited support. '
            'Please save your resume as PDF or .docx and try again.');
      }
      content = {'type': 'text', 'text': text};
    } else {
      content = _plainTextContent(bytes);
      final textStr = content['text'] as String? ?? '';
      if (textStr.trim().length < 50) {
        throw Exception(
            'The uploaded file appears to be empty or unreadable. '
            'Please check the file and try again.');
      }
    }

    const prompt = '''Analyze this resume/CV thoroughly and respond with ONLY a valid JSON object — no markdown, no explanation:
{
  "name": "candidate full name or null",
  "skills": ["up to 10 most important technical skills found in the resume"],
  "experience_level": "Junior|Mid|Senior|Lead|Principal",
  "years_of_experience": 0,
  "country": "full country name",
  "country_code": "2-letter lowercase ISO 3166-1 code (e.g. us, gb, in, ae, jp, ng, br, de, sg, au, ca, fr, nl, za, kr, se, etc). Default to 'us' ONLY if absolutely no location signal. Extract aggressively from: address, phone country code (+91=in, +44=gb, +1=us/ca, +61=au, +49=de, +971=ae, +81=jp), city names, timezone, language.",
  "job_title": "best matching job title (e.g. ML Engineer, Data Scientist)",
  "summary": "2-3 sentence professional summary highlighting their strongest qualifications",
  "projects": ["up to 4 notable projects or work achievements mentioned — short 1-line each"],
  "certifications": ["all certifications or courses mentioned"],
  "education": "highest education: degree, institution, year if available",
  "strengths": ["3 key strengths based on what stands out in the resume"],
  "gaps": ["2-3 skill gaps or areas for improvement based on current AI/ML market demands"],
  "ats_score": <integer 0-100 estimating how well this resume would pass an ATS scanner — based on keywords, structure, action verbs, quantified achievements, formatting>,
  "ats_issues": ["2-4 specific fixes to improve the ATS score, e.g. 'Add quantified achievements (% improved, dollars saved)', 'Use standard section headings', 'Add missing keywords: TensorFlow, Kubernetes'"]
}

Extract years_of_experience by calculating from work history dates. If dates unclear, estimate from experience_level.
Determine country from: address, phone country code, or any location mention.
For strengths: identify what makes this candidate competitive.
For gaps: identify what's missing compared to top AI/ML job requirements today (e.g. missing cloud certs, no LLM experience, no MLOps, etc).''';

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
        'max_tokens': 1100,
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
      throw Exception(friendlyError(
          claudeError(response.statusCode, response.body)));
    }

    final data = json.decode(response.body);
    final text = (data['content'][0]['text'] as String).trim();

    // Strip markdown code fences if present
    final jsonText = text
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'^```\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    try {
      final parsed = json.decode(jsonText) as Map<String, dynamic>;

      // Check if Claude couldn't extract meaningful data
      final skills = parsed['skills'] as List? ?? [];
      final name = parsed['name'] as String?;
      final summary = parsed['summary'] as String? ?? '';
      if (skills.isEmpty && (name == null || name.isEmpty) && summary.isEmpty) {
        throw Exception(
            'Could not extract resume data from this file. '
            'The document may be image-based, password-protected, or in an unsupported format. '
            'Please upload a text-based PDF, DOCX, or TXT file.');
      }

      await ClaudeCache.set('resume', cacheKey, jsonText);
      return ResumeProfile.fromJson(parsed);
    } on FormatException {
      throw Exception(
          'The uploaded document could not be analyzed. '
          'It may be a scanned image, corrupted, or not a valid resume. '
          'Please upload a text-based PDF, DOCX, or TXT file.');
    }
  }

  // ── File content builders ─────────────────────────────────────────────────

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

  static Map<String, dynamic> _plainTextContent(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes);
    }
    if (text.length > 12000) text = text.substring(0, 12000);
    return {'type': 'text', 'text': text};
  }

  // ── DOCX text extraction ──────────────────────────────────────────────────
  // DOCX is a ZIP archive containing word/document.xml with the main text.

  static String _extractDocxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final docFile = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
        orElse: () => throw Exception('No document.xml found'),
      );

      final xmlContent = utf8.decode(docFile.content as List<int>);
      final document = XmlDocument.parse(xmlContent);

      // Extract text from all <w:t> elements (Word text runs)
      final buffer = StringBuffer();
      final paragraphs = document.findAllElements('w:p');

      for (final para in paragraphs) {
        final texts = para.findAllElements('w:t');
        for (final t in texts) {
          buffer.write(t.innerText);
        }
        buffer.writeln(); // paragraph break
      }

      var text = buffer.toString().trim();
      if (text.length > 12000) text = text.substring(0, 12000);
      return text;
    } catch (e) {
      // If ZIP extraction fails, the file is corrupted or not a real DOCX
      return '';
    }
  }

  // ── DOC text extraction (legacy binary format) ────────────────────────────
  // DOC files store text in the binary stream. We extract readable ASCII/UTF
  // strings by scanning for runs of printable characters. This won't get
  // perfect formatting but captures the actual resume text content.

  static String _extractDocText(Uint8List bytes) {
    try {
      final buffer = StringBuffer();
      final currentRun = StringBuffer();

      for (var i = 0; i < bytes.length; i++) {
        final b = bytes[i];
        // Printable ASCII + common extended chars
        if ((b >= 0x20 && b <= 0x7E) || b == 0x0A || b == 0x0D || b == 0x09) {
          currentRun.writeCharCode(b);
        } else {
          // End of a text run — keep it if it's long enough to be real content
          if (currentRun.length >= 4) {
            buffer.write(currentRun.toString());
            buffer.write(' ');
          }
          currentRun.clear();
        }
      }
      // Flush last run
      if (currentRun.length >= 4) {
        buffer.write(currentRun.toString());
      }

      // Clean up: collapse whitespace, remove control sequences
      var text = buffer.toString()
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
          .replaceAll(RegExp(r' {3,}'), '\n')  // large gaps → line breaks
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      // DOC binary often has junk headers — try to find where real content starts
      // by looking for common resume patterns
      final resumeStart = RegExp(
        r'(experience|education|summary|objective|skills|profile|contact|phone|email|address)',
        caseSensitive: false,
      ).firstMatch(text);
      if (resumeStart != null && resumeStart.start > 200) {
        // Grab some context before the first resume keyword
        final start = (resumeStart.start - 200).clamp(0, text.length);
        text = text.substring(start);
      }

      if (text.length > 12000) text = text.substring(0, 12000);
      return text;
    } catch (_) {
      return '';
    }
  }
}

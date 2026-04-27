import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/resume_profile.dart';
import 'claude_cache.dart';
import 'claude_error.dart';
import 'claude_http.dart';
import 'curated_resources.dart';

const _sampleResumeText = '''ALEX MORGAN
ML Engineer · San Francisco, CA · alex.morgan@email.com · +1 (415) 555-0142

PROFESSIONAL SUMMARY
Machine learning engineer with 4 years of experience building production ML systems at consumer-tech companies. Specialized in recommendation systems, NLP, and MLOps. Improved core engagement metrics by 18% through model iteration and rigorous offline/online evaluation.

EXPERIENCE

Senior ML Engineer · Lumen Labs · 2023 — Present (San Francisco, CA)
• Led the redesign of the personalized feed ranker, lifting click-through rate by 18% and watch-time by 12%
• Built a real-time feature store on GCP serving 200M predictions/day with p99 latency under 80ms
• Mentored 3 junior engineers and ran weekly ML reading group on transformer architectures

ML Engineer · Sift Inc · 2021 — 2023 (Remote)
• Developed a fraud-detection model using gradient boosted trees that reduced false positives by 30%
• Owned the ML evaluation pipeline using MLflow and Airflow on AWS
• Shipped a BERT-based ticket triage classifier saving 1,200 hours/month of manual work

EDUCATION
M.S. Computer Science (Machine Learning) · UC Berkeley · 2021
B.S. Computer Science · UCLA · 2019

SKILLS
Python, PyTorch, TensorFlow, scikit-learn, SQL, AWS, GCP, Docker, Kubernetes, MLflow, Airflow, Spark, BigQuery, Transformers, NLP, Recommendation Systems

CERTIFICATIONS
AWS Certified Machine Learning – Specialty (2023)
Deep Learning Specialization, DeepLearning.AI / Coursera (2022)

PROJECTS
Open-source contributor to Hugging Face Datasets (3 merged PRs)
Built a personal ML dashboard tracking 50+ Kaggle competitions
''';

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

  /// Returns an in-memory PlatformFile containing a built-in sample resume,
  /// so users can try the scanner without uploading their own.
  static PlatformFile sampleResumeFile() {
    final bytes = Uint8List.fromList(utf8.encode(_sampleResumeText));
    return PlatformFile(
      name: 'sample_resume.txt',
      size: bytes.length,
      bytes: bytes,
    );
  }

  /// Analyze the picked file with Claude and return a ResumeProfile.
  /// Results are cached by file-byte hash for 30 days — re-scanning
  /// the same file returns the cached profile without hitting Claude.
  static Future<ResumeProfile> analyzeResume(PlatformFile file) async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw Exception('Could not read file');

    // Cache lookup keyed on file hash
    final cacheKey = ClaudeCache.keyFrom([
      file.extension,
      bytes.length,
      bytes.take(128).join(','),
      bytes.skip(bytes.length - 128).take(128).join(','),
    ]);
    // Cache disabled temporarily to debug 0% job readiness issue
    // final cached = await ClaudeCache.get('resume', cacheKey,
    //     ttl: const Duration(days: 30));
    // if (cached != null) {
    //   try {
    //     final parsed = json.decode(cached) as Map<String, dynamic>;
    //     return ResumeProfile.fromJson(parsed);
    //   } catch (_) {}
    // }

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

    final response = await ClaudeHttp.post(
      apiKey: apiKey,
      extraHeaders: isPdf ? {'anthropic-beta': 'pdfs-2024-09-25'} : null,
      timeout: const Duration(seconds: 60),
      body: {
        'model': 'claude-haiku-4-5',
        'max_tokens': 2000,
        'messages': [
          {
            'role': 'user',
            'content': [
              content,
              {'type': 'text', 'text': prompt},
            ],
          }
        ],
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Resume analysis failed — ${claudeError(response.statusCode, response.body)}');
    }

    final data = json.decode(response.body);
    final contentList = data['content'] as List?;
    if (contentList == null || contentList.isEmpty) {
      throw Exception('Empty response from resume analysis');
    }
    final text = ((contentList[0]['text'] as String?) ?? '').trim();
    if (text.isEmpty) throw Exception('Resume analysis returned empty text');

    // Strip markdown code fences if present
    final jsonText = text
        .replaceFirst(RegExp(r'^```json\s*'), '')
        .replaceFirst(RegExp(r'^```\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    // Try direct parse, fall back to repair for truncated responses
    Map<String, dynamic>? parsed;
    try {
      parsed = json.decode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      // Attempt to repair truncated JSON (common when max_tokens hits)
      parsed = _repairTruncatedJson(jsonText);
      if (parsed == null) {
        throw Exception('AI response was cut off. Please try again — if it keeps happening, the resume may be too long.');
      }
    }
    // Store in cache for 30 days
    await ClaudeCache.set('resume', cacheKey, jsonText);
    return ResumeProfile.fromJson(parsed);
  }

  /// Best-effort repair of truncated JSON. Common failure modes:
  ///   1. Trailing comma + no closing brace
  ///   2. Unclosed string (no trailing quote)
  ///   3. Truncated mid-array
  /// Returns null if unrepairable.
  static Map<String, dynamic>? _repairTruncatedJson(String raw) {
    var s = raw.trim();
    // Pass 1: Close any unterminated string at end of text
    final quoteCount = RegExp('"').allMatches(s).length;
    if (quoteCount.isOdd) s = '$s"';
    // Pass 2: Drop trailing comma
    s = s.replaceAll(RegExp(r',\s*$'), '');
    // Pass 3: Count unbalanced brackets and close them
    int openObj = 0, openArr = 0;
    bool inString = false;
    bool escape = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (escape) { escape = false; continue; }
      if (c == '\\') { escape = true; continue; }
      if (c == '"') { inString = !inString; continue; }
      if (inString) continue;
      if (c == '{') openObj++;
      else if (c == '}') openObj--;
      else if (c == '[') openArr++;
      else if (c == ']') openArr--;
    }
    // Close any remaining open array/object
    s = s + (']' * openArr.clamp(0, 10)) + ('}' * openObj.clamp(0, 10));
    // Drop any content after last valid closing brace
    final lastBrace = s.lastIndexOf('}');
    if (lastBrace > 0) s = s.substring(0, lastBrace + 1);
    try {
      return json.decode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
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

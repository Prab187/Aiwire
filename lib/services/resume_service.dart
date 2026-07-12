import '../config/secrets.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
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
    const apiKey = Secrets.anthropicApiKey;
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

  /// Build a real PDF from the resume text and open the system share sheet
  /// so the user can save it to Files, AirDrop it, or email it.
  static Future<void> exportResumeToPdf(String resumeText, String fileName) async {
    final doc = pw.Document();
    final lines = resumeText.split('\n');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 44),
      build: (_) => lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return pw.SizedBox(height: 6);
        // Treat short ALL-CAPS lines as section headers
        final isHeader = trimmed.length < 40 &&
            trimmed == trimmed.toUpperCase() &&
            RegExp(r'[A-Z]').hasMatch(trimmed);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            line,
            style: pw.TextStyle(
              fontSize: isHeader ? 12 : 10,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              lineSpacing: 2,
            ),
          ),
        );
      }).toList(),
    ));

    final bytes = await doc.save();
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: '$fileName.pdf', mimeType: 'application/pdf')],
      fileNameOverrides: ['$fileName.pdf'],
    );
  }

  /// Build a real Word (.docx) file from the resume text and open the system
  /// share sheet. A .docx is a zip of XML parts — assembled here with the
  /// archive package so no extra plugin is needed.
  static Future<void> exportResumeToWord(String resumeText, String fileName) async {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    final paragraphs = resumeText.split('\n').map((line) {
      final trimmed = line.trim();
      final isHeader = trimmed.isNotEmpty &&
          trimmed.length < 40 &&
          trimmed == trimmed.toUpperCase() &&
          RegExp(r'[A-Z]').hasMatch(trimmed);
      final props = isHeader ? '<w:rPr><w:b/><w:sz w:val="26"/></w:rPr>' : '';
      return '<w:p><w:r>$props<w:t xml:space="preserve">${esc(line)}</w:t></w:r></w:p>';
    }).join();

    const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';

    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$paragraphs</w:body></w:document>';

    final archive = Archive();
    void add(String path, String content) {
      final data = utf8.encode(content);
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', documentXml);

    final zipped = ZipEncoder().encode(archive);
    final bytes = Uint8List.fromList(zipped);
    await Share.shareXFiles(
      [XFile.fromData(bytes,
          name: '$fileName.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document')],
      fileNameOverrides: ['$fileName.docx'],
    );
  }

  /// Generate an optimized version of the resume based on ATS issues.
  /// Sends the ORIGINAL FILE (PDF or text) to Claude so every real detail —
  /// email, phone, links, project names, dates — is copied over verbatim.
  static Future<String> generateOptimizedResume(
    PlatformFile file,
    ResumeProfile profile,
  ) async {
    const apiKey = Secrets.anthropicApiKey;
    if (apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not configured');

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw Exception('Could not read file');

    final isPdf = file.extension?.toLowerCase() == 'pdf';
    final resumeContent = isPdf ? _pdfContent(bytes) : _textContent(bytes);

    final issuesText = profile.atsIssues.isNotEmpty
        ? profile.atsIssues.map((e) => '• $e').join('\n')
        : 'No specific issues identified.';

    final prompt = '''You are an expert resume writer and ATS optimization specialist.
The document above is the candidate's ORIGINAL resume. Rewrite it following the rules below.

## Profile Analysis:
- Name: ${profile.name ?? 'N/A'}
- Experience Level: ${profile.experienceLevel}
- Years of Experience: ${profile.yearsOfExperience}
- Location: ${profile.city.isNotEmpty ? '${profile.city}, ' : ''}${profile.country}
- Top Skills: ${profile.skills.take(5).join(', ')}
- ATS Score: ${profile.atsScore}/100
- Education: ${profile.education ?? 'N/A'}

## ATS Issues to Fix:
$issuesText

## Your Task:
Rewrite the resume to address ALL the ATS issues above. Follow these rules:

1. **COPY EVERY REAL DETAIL FROM THE ORIGINAL — NO PLACEHOLDERS EVER**:
   - Copy the exact email address, phone number, LinkedIn/GitHub/portfolio URLs, and city from the original resume
   - Copy all dates, company names, job titles, project names, degree names, institutions, and certification names verbatim
   - Copy real project details — names, technologies used, outcomes — and improve only the wording around them
   - NEVER write placeholders like "[Your Email]", "[Phone]", "[Company]", "XX%", or "[Add project]"
   - If a detail genuinely does not exist in the original (e.g. no LinkedIn URL), OMIT that line entirely — do not invent it and do not leave a blank to fill

2. **Quantify with REAL numbers only** — Strengthen bullets using metrics that appear in or are clearly implied by the original resume:
   - "Worked on backend systems" → reword with the actual scale/tech mentioned in the original
   - If the original has no numbers for an achievement, improve the verb and specificity WITHOUT inventing statistics
   - Keep role title and dates exactly as they were

3. **ATS Keywords** — Use industry-standard keywords from the skills section:
   - Include: ${profile.skills.take(8).join(', ')}
   - Use full names (e.g., "Machine Learning" not "ML"; "Kubernetes" not "K8s")

4. **Action Verbs** — Start every bullet with strong verbs: Architected, Engineered, Optimized, Implemented, Spearheaded, Transformed, Drove, Accelerated, etc.

5. **Structure** — Keep the same sections (Contact, Summary, Experience, Skills, Education, Certifications) with original info intact:
   - **Contact**: Keep name, email, phone, location exactly as is
   - **Summary**: 2-3 lines highlighting your strongest impact and unique value
   - **Experience**: Each role keeps original title/company/dates, but bullets get quantified + improved
   - **Skills**: Group by category (e.g., "Languages: Python, Go, Rust" / "Frameworks: PyTorch, TensorFlow")
   - **Education**: Keep as is (degree, institution, year)

6. **Length** — Aim for 1 page if junior/mid, up to 2 pages if senior.

7. **Formatting** — Use clean formatting:
   - No special characters or decorations
   - Consistent date formats (e.g., "Jan 2020 – Present")
   - Clear section headers

## Output:
Return ONLY the rewritten resume text. No explanations, no markdown, no "Before/After" labels.
Start immediately with the improved resume.''';

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
        'max_tokens': 3000,
        'temperature': 0.3,
        'messages': [
          {
            'role': 'user',
            'content': [
              resumeContent,
              {'type': 'text', 'text': prompt},
            ],
          }
        ],
      }),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final optimizedText = (data['content'][0]['text'] as String).trim();
    return optimizedText;
  }
}

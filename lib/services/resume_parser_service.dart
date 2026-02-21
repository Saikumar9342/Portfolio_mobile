import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/resume_data.dart';
import '../models/portfolio_data.dart';

abstract class ResumeParserService {
  Future<ResumeData> parseResume(String text);
}

class GeminiResumeParser implements ResumeParserService {
  final String apiKey;

  static const List<String> _modelPriority = [
    'gemini-2.0-flash',
    'gemini-flash-latest',
    'gemini-1.5-flash',
  ];

  final String _groqApiKey = dotenv.env['GROQ_API_KEY'] ?? "";

  GeminiResumeParser({required this.apiKey});

  @override
  Future<ResumeData> parseResume(String text) async {
    Object lastError =
        Exception("All AI models (Gemini & Groq) failed to parse the resume.");

    // 1. Try Gemini Models (Primary) — two-phase pipeline
    for (final modelName in _modelPriority) {
      try {
        debugPrint("Attempting two-phase parsing with Gemini: $modelName");
        return await _parseWithModel(text, modelName);
      } catch (e) {
        debugPrint("Gemini Model $modelName failed: $e");
        lastError = e;
      }
    }

    // 2. Try Groq as Final Fallback — single phase (context window limit)
    try {
      debugPrint("All Gemini models failed. Attempting Groq fallback...");
      return await _parseWithGroq(text);
    } catch (e) {
      debugPrint("Groq Fallback also failed: $e");
      lastError = e;
    }

    throw lastError;
  }

  // ─── PHASE 1: Deep Profile Analysis ─────────────────────────────────────────
  // The AI reads and deeply understands the person before extracting anything.
  // This prevents hallucinations and placeholder copying.

  String _buildAnalysisPrompt(String resumeText) {
    return '''
You are a senior career analyst. Your job is to deeply read and understand this person's professional profile from their resume.

Read every single word carefully. Understand:
- Who this person is (name, contact, location)
- Their career journey and progression
- Every project they have built — what it does, what technologies they used, what problem it solved
- Their technical skills and how proficient they are in each
- Their education and background
- What makes them unique as a professional

Write a comprehensive profile analysis in plain text. Cover:
1. IDENTITY: Full name, email, phone, location, current role
2. CAREER STORY: How their career has progressed, what companies they worked at, what they did there
3. PROJECTS: For each project — name, what it does, every technology used, their role, the business domain
4. SKILLS: Every technology they know, grouped by category, with your assessment of their proficiency level
5. EDUCATION: Degrees, institutions, years
6. STRENGTHS: What they are best at based on their experience
7. STATS: Calculate years of experience from dates, count projects, count unique technologies

RESUME:
---
$resumeText
---

Write your analysis now. Be thorough and specific. Use only facts from the resume — do not invent anything.
''';
  }

  // ─── PHASE 2: Structured Extraction ──────────────────────────────────────────
  // Uses the AI's own analysis (not the raw resume) to produce clean JSON.
  // The AI extracts from its OWN understanding, not from a template with examples.

  String _buildExtractionPrompt(String profileAnalysis) {
    return '''
You have already analyzed a professional's resume and written this profile analysis:

---
$profileAnalysis
---

Now convert your analysis above into a structured JSON object for their portfolio website.
Return ONLY valid JSON. No markdown, no code blocks, no explanation.
Use ONLY the information from your analysis above. Do not invent anything new.

{
  "name": "<person's actual full name>",
  "role": "<their actual current or most recent job title>",
  "email": "<their actual email address>",
  "phone": "<their actual phone number>",
  "location": "<their actual city and country>",
  "summary": "<their professional summary verbatim from the resume>",

  "hero": {
    "badge": "<short status like OPEN TO OPPORTUNITIES 2025 — based on their situation>",
    "title": "<ALL CAPS powerful headline based on their actual role, e.g. CRAFTING ENTERPRISE MOBILE SOLUTIONS>",
    "subtitle": "<one sentence about their actual specialty and experience level>"
  },

  "about": {
    "biography": "<their professional biography — use the summary/about section verbatim>",
    "location": "<their actual city and country>",
    "interests": ["<actual hobby or interest if mentioned in resume, else omit>"]
  },

  "expertise": {
    "title": "<headline about their actual expertise, e.g. Building Scalable Digital Products>",
    "label": "EXPERTISE",
    "stats": [
      { "label": "YEARS EXPERIENCE", "value": "<calculated from their actual work dates, e.g. 4+>" },
      { "label": "PROJECTS DELIVERED", "value": "<count of actual projects, e.g. 8+>" },
      { "label": "TECH STACK", "value": "<count of unique technologies, e.g. 20+>" },
      { "label": "<another meaningful metric from their profile>", "value": "<actual value>" }
    ],
    "services": [
      { "id": "service1", "title": "<their actual primary service area>", "description": "<what they actually do in this area>" },
      { "id": "service2", "title": "<their actual secondary service area>", "description": "<based on their experience>" },
      { "id": "service3", "title": "<their actual third service area>", "description": "<based on their experience>" }
    ]
  },

  "skills": {
    "frontendTitle": "Frontend Engineering",
    "mobileTitle": "Mobile Development",
    "backendTitle": "Cloud & Backend",
    "toolsTitle": "Workflow & Tools",
    "frameworksTitle": "Toolbox",
    "frontend": [{"name": "<actual frontend tech they know>", "level": <0-100 based on your proficiency assessment>}],
    "mobile": ["<actual mobile tech they know>"],
    "backend": ["<actual backend/cloud tech they know>"],
    "tools": ["<actual dev tool they use>"],
    "frameworks": ["<actual framework or library they use>"]
  },

  "education": [
    { "degree": "<actual degree name>", "institution": "<actual university name>", "year": "<actual years>" }
  ],

  "experience": [
    {
      "position": "<actual job title>",
      "company": "<actual company name>",
      "startDate": "<actual start date>",
      "endDate": "<actual end date or Present>",
      "description": "<copy their responsibilities and achievements verbatim>"
    }
  ],

  "projects": [
    {
      "title": "<actual project name>",
      "description": "<short 1-2 sentence summary of what the project does>",
      "fullDescription": "<complete description — copy every detail about this project from the resume>",
      "role": "<their actual role in this project>",
      "techStack": ["<every technology used in this project>"],
      "category": "<project domain in caps e.g. FINTECH, MOBILE APP, E-COMMERCE, ENTERPRISE>",
      "liveLink": "<actual URL if mentioned, else empty string>",
      "githubLink": "<actual GitHub URL if mentioned, else empty string>"
    }
  ],

  "contact": {
    "email": "<their actual email>",
    "personalEmail": "<secondary email if different, else same>"
  },

  "certifications": ["<actual certification with issuer if mentioned>"],
  "languages": ["<actual spoken language>"]
}

Skill level guide: 90-95=expert/lead, 80-89=proficient/strong, 70-79=working knowledge, 60-69=familiar.
Skill categories: frontend=HTML/CSS/JS/TS/React/Angular/Vue/Next.js/SCSS/Tailwind | mobile=Flutter/Dart/ReactNative/Swift/Kotlin/Android | backend=Node.js/Python/Java/Firebase/AWS/databases/APIs | tools=Git/Docker/VSCode/Postman/Jira/CI-CD | frameworks=UI-libraries/state-management/CSS-frameworks
''';
  }

  // ─── Gemini: Two-Phase Pipeline ───────────────────────────────────────────────

  Future<ResumeData> _parseWithModel(String text, String modelName) async {
    final model = GenerativeModel(model: modelName, apiKey: apiKey);

    // Phase 1: Analyse & understand the profile
    debugPrint("[$modelName] Phase 1: Analysing profile...");
    final analysisResponse = await model.generateContent(
      [Content.text(_buildAnalysisPrompt(text))],
    );

    if (analysisResponse.text == null || analysisResponse.text!.isEmpty) {
      throw Exception("Phase 1 (analysis) returned empty response");
    }

    final profileAnalysis = analysisResponse.text!;
    debugPrint(
        "[$modelName] Phase 1 complete. Analysis length: ${profileAnalysis.length} chars");

    // Phase 2: Extract structured JSON from the analysis
    debugPrint("[$modelName] Phase 2: Extracting structured data...");
    final extractionResponse = await model.generateContent(
      [Content.text(_buildExtractionPrompt(profileAnalysis))],
    );

    if (extractionResponse.text == null || extractionResponse.text!.isEmpty) {
      throw Exception("Phase 2 (extraction) returned empty response");
    }

    debugPrint("[$modelName] Phase 2 complete.");
    return _processResponse(extractionResponse.text!);
  }

  // ─── Groq: Single-Phase Fallback (combined prompt) ───────────────────────────
  // Groq has context limits so we use a single optimised prompt as fallback.

  Future<ResumeData> _parseWithGroq(String text) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    // Combined prompt: study + extract in one shot for Groq
    final combinedPrompt = '''
You are an expert resume analyst and portfolio data extractor.

STEP 1 — Study this resume carefully. Understand who this person is, their career, projects, and skills.
STEP 2 — Extract all data into the JSON structure below.

RESUME:
---
$text
---

Return ONLY valid JSON. No markdown. Use ONLY real data from the resume above — never copy placeholder text.

{
  "name": "<actual full name>",
  "role": "<actual job title>",
  "email": "<actual email>",
  "phone": "<actual phone>",
  "location": "<actual location>",
  "summary": "<professional summary verbatim>",
  "hero": {
    "badge": "<availability status>",
    "title": "<ALL CAPS headline based on their role>",
    "subtitle": "<one sentence about their specialty>"
  },
  "about": {
    "biography": "<summary verbatim>",
    "location": "<actual location>",
    "interests": []
  },
  "expertise": {
    "title": "<headline about their expertise>",
    "label": "EXPERTISE",
    "stats": [
      {"label": "YEARS EXPERIENCE", "value": "<calculated>"},
      {"label": "PROJECTS DELIVERED", "value": "<count>"},
      {"label": "TECH STACK", "value": "<count>"},
      {"label": "CLIENTS SERVED", "value": "<count or estimate>"}
    ],
    "services": [
      {"id": "service1", "title": "<service area>", "description": "<what they do>"},
      {"id": "service2", "title": "<service area>", "description": "<what they do>"},
      {"id": "service3", "title": "<service area>", "description": "<what they do>"}
    ]
  },
  "skills": {
    "frontendTitle": "Frontend Engineering",
    "mobileTitle": "Mobile Development",
    "backendTitle": "Cloud & Backend",
    "toolsTitle": "Workflow & Tools",
    "frameworksTitle": "Toolbox",
    "frontend": [{"name": "<tech>", "level": <0-100>}],
    "mobile": ["<tech>"],
    "backend": ["<tech>"],
    "tools": ["<tech>"],
    "frameworks": ["<tech>"]
  },
  "education": [{"degree": "<degree>", "institution": "<university>", "year": "<years>"}],
  "experience": [{"position": "<title>", "company": "<company>", "startDate": "<date>", "endDate": "<date>", "description": "<verbatim>"}],
  "projects": [{"title": "<name>", "description": "<short>", "fullDescription": "<full verbatim>", "role": "<role>", "techStack": ["<tech>"], "category": "<DOMAIN>", "liveLink": "", "githubLink": ""}],
  "contact": {"email": "<email>", "personalEmail": "<email>"},
  "certifications": [],
  "languages": ["<language>"]
}
''';

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_groqApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'user', 'content': combinedPrompt}
        ],
        'temperature': 0.1,
      }),
    );

    debugPrint("Groq Response Status: ${response.statusCode}");

    if (response.statusCode != 200) {
      throw Exception(
          "Groq API Error: ${response.statusCode} - ${response.body}");
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    debugPrint("Groq Response Content: $content");

    return _processResponse(content);
  }

  // ─── Process JSON Response ────────────────────────────────────────────────────

  ResumeData _processResponse(String rawJson) {
    String cleanedJson =
        rawJson.replaceAll('```json', '').replaceAll('```', '').trim();

    final Map<String, dynamic> json = jsonDecode(cleanedJson);

    return ResumeData(
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      email: json['contact']?['email'] ?? json['email'] ?? '',
      personalEmail: json['contact']?['personalEmail'] ?? '',
      phone: json['phone'] ?? '',
      summary: json['summary'] ?? '',
      location: json['location'] ?? '',
      hero: json['hero'] as Map<String, dynamic>? ?? {},
      about: json['about'] as Map<String, dynamic>? ?? {},
      expertise: json['expertise'] as Map<String, dynamic>? ?? {},
      education: (json['education'] as List?)
              ?.map((e) => Education.fromMap(e))
              .toList() ??
          [],
      experience: (json['experience'] as List?)
              ?.map((e) => Experience.fromMap(e))
              .toList() ??
          [],
      projects: (json['projects'] as List?)
              ?.map((e) => Project(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: e['title'] ?? '',
                    description: e['description'] ?? '',
                    fullDescription: e['fullDescription'] ?? '',
                    role: e['role'] ?? '',
                    techStack: List<String>.from(e['techStack'] ?? []),
                    category: e['category'] ?? '',
                    imageUrl: '',
                    liveLink: e['liveLink'] ?? '',
                    githubLink: e['githubLink'] ?? '',
                    createdAt: DateTime.now(),
                  ))
              .toList() ??
          [],
      skills: json['skills'] as Map<String, dynamic>? ?? {},
      certifications: List<String>.from(json['certifications'] ?? []),
      languages: List<String>.from(json['languages'] ?? []),
    );
  }
}

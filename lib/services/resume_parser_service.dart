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

  // Prioritized list of models to try for seamless failover
  static const List<String> _modelPriority = [
    'gemini-2.5-flash',
    'gemini-flash-latest',
    'gemini-1.5-flash',
  ];

  // Backup Groq API Key (Llama-3-70b)
  final String _groqApiKey = dotenv.env['GROQ_API_KEY'] ?? "";

  GeminiResumeParser({
    required this.apiKey,
  });

  @override
  Future<ResumeData> parseResume(String text) async {
    Object lastError =
        Exception("All AI models (Gemini & Groq) failed to parse the resume.");

    // 1. Try Gemini Models (Primary)
    for (final modelName in _modelPriority) {
      try {
        debugPrint("Attempting parsing with Gemini model: $modelName");
        return await _parseWithModel(text, modelName);
      } catch (e) {
        debugPrint("Gemini Model $modelName failed: $e");
        lastError = e;
        // Continue to the next model
      }
    }

    // 2. Try Groq (Llama-3-70b) as Final Fallback
    try {
      debugPrint(
          "All Gemini models failed. Attempting fallback with Groq (Llama-3-70b)...");
      return await _parseWithGroq(text);
    } catch (e) {
      debugPrint("Groq Fallback also failed: $e");
      lastError = e;
    }

    // If all fail, throw the last error
    throw lastError;
  }

  Future<ResumeData> _parseWithModel(String text, String modelName) async {
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );

    final prompt = _buildPrompt(text);

    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);
    debugPrint("Gemini Response ($modelName): ${response.text}");

    if (response.text == null) {
      throw Exception("Empty response from AI");
    }

    return _processResponse(response.text!);
  }

  Future<ResumeData> _parseWithGroq(String text) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final prompt = _buildPrompt(text);

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_groqApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama3-70b-8192', // Using Llama 3 70B for high quality
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.1, // Low temp for extraction consistency
        'response_format': {'type': 'json_object'} // Enforce JSON
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

  String _buildPrompt(String text) {
    return '''
      You are a specialized Resume Parser AI. Your task is to extract structured data from the provided resume text with 100% accuracy.
      
      OUTPUT FORMAT:
      Return ONLY a valid JSON object with the following schema. Do not include markdown code blocks (```json).

      {
        "name": "Full Name",
        "email": "email@example.com",
        "phone": "+1234567890",
        "summary": "Professional summary...",
        "location": "City, Country",
        "education": [
          {
            "degree": "Degree Name",
            "institution": "University Name",
            "year": "YYYY-YYYY or YYYY"
          }
        ],
        "experience": [
          {
            "position": "Job Title",
            "company": "Company Name",
            "startDate": "MMM YYYY",
            "endDate": "MMM YYYY or Present",
            "description": "Key responsibilities and achievements..."
          }
        ],
        "projects": [
          {
            "title": "Project Title",
            "description": "Project description...",
            "techStack": ["Flutter", "Dart", "Firebase"],
            "liveLink": "url or empty",
            "githubLink": "url or empty"
          }
        ],
        "skills": {
          "frontend": ["React", "Flutter"],
          "backend": ["Node.js", "Python"],
          "mobile": ["Android", "iOS"],
          "tools": ["Git", "Docker"],
          "frameworks": ["Django", "Spring"]
        },
        "certifications": ["Cert Name"],
        "languages": ["English", "Spanish"]
      }

      RULES:
      1. Extract data EXACTLY as it appears in the text.
      2. If a field is missing, use an empty string "" or empty list [].
      3. For skills, intelligently categorize them into the provided categories (frontend, backend, mobile, tools, frameworks). If unsure, put in "tools".
      4. For dates, allow "Present".
      5. Infer the github/live links for projects if they are mentioned near the project description.
      6. Do NOT fabricate information. Only use what is present in the text.

      RESUME TEXT:
      $text
      ''';
  }

  ResumeData _processResponse(String rawJson) {
    // Clean the response (remove markdown if any creeps in despite instructions)
    String cleanedJson =
        rawJson.replaceAll('```json', '').replaceAll('```', '').trim();

    final Map<String, dynamic> json = jsonDecode(cleanedJson);

    return ResumeData(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      summary: json['summary'] ?? '',
      location: json['location'] ?? '',
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
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(), // Generate temporary ID
                    title: e['title'] ?? '',
                    description: e['description'] ?? '',
                    techStack: List<String>.from(e['techStack'] ?? []),
                    imageUrl: '', // AI can't extract images from text
                    liveLink: e['liveLink'] ?? '',
                    githubLink: e['githubLink'] ?? '',
                    createdAt: DateTime.now(),
                  ))
              .toList() ??
          [],
      skills: Map<String, List<String>>.from(
        (json['skills'] as Map?)?.map(
              (k, v) => MapEntry(k, List<String>.from(v ?? [])),
            ) ??
            {},
      ),
      certifications: List<String>.from(json['certifications'] ?? []),
      languages: List<String>.from(json['languages'] ?? []),
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  GenerativeModel? _model;
  String? _groqApiKey;

  void initialize() {
    final apiKey = AppConfig.geminiApiKey;
    _groqApiKey = AppConfig.groqApiKey;

    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
    }
  }

  Future<String?> enhanceText(String input, String fieldName) async {
    if (_model == null && (_groqApiKey == null || _groqApiKey!.isEmpty)) {
      initialize();
      if (_model == null && (_groqApiKey == null || _groqApiKey!.isEmpty)) {
        throw Exception("No AI API keys are configured (Gemini or Groq).");
      }
    }

    final prompt = '''
You are an expert copywriter. Please rewrite and enhance the following text for a professional portfolio. 
Context for this field: The field name is "$fieldName".
Make it sound professional, engaging, and polished. Do not add conversational filler. Just return the enhanced text itself.
If the input contains bullet points or is very short, expand it into a cohesive, well-structured paragraph or format.

Input text:
$input
''';

    // 1. Try Gemini primary route
    if (_model != null) {
      try {
        final content = [Content.text(prompt)];
        final response = await _model!.generateContent(content);
        if (response.text != null && response.text!.isNotEmpty) {
          return response.text?.trim();
        }
      } catch (e) {
        debugPrint(
            "Gemini Enhancement failed, falling back to Groq... Error: $e");
      }
    }

    // 2. Fallback to Groq API using blazing fast LLaMA 3 model
    if (_groqApiKey != null && _groqApiKey!.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_groqApiKey',
          },
          body: jsonEncode({
            "model": "llama-3.1-8b-instant",
            "messages": [
              {
                "role": "system",
                "content":
                    "You are an expert copywriter. Do not add conversational filler. Just return the enhanced text itself."
              },
              {"role": "user", "content": prompt}
            ],
            "temperature": 0.5,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content =
              data['choices']?[0]?['message']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            return content.trim();
          }
        } else {
          debugPrint("Groq Error Response: ${response.body}");
        }
      } catch (e) {
        debugPrint("Groq Enhancement failed: $e");
      }
    }

    throw Exception(
        "Both Gemini and Groq AI enhancements failed or exceeded limits. Please try again later.");
  }
}

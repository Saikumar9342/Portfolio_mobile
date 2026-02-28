import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();
  final FirestoreService _firestoreService = FirestoreService();

  // The list of content document IDs to translate
  static const List<String> _contentDocIds = [
    'hero',
    'about',
    'expertise',
    'contact',
    'projects_page',
    'navbar',
    'skills',
  ];

  Future<void> translateAndSaveContentForLanguage(
    String languageCode, {
    void Function({
      required String message,
      required int completed,
      required int total,
    })? onProgress,
  }) async {
    debugPrint("Starting translation for language: $languageCode");

    QuerySnapshot? projectsSnapshot;
    try {
      projectsSnapshot = await _firestoreService.streamProjects().first;
    } catch (e) {
      debugPrint("Error fetching projects before translation: $e");
    }

    final totalSteps = _contentDocIds.length + (projectsSnapshot?.docs.length ?? 0);
    var completedSteps = 0;

    void emitProgress(String message) {
      onProgress?.call(
        message: message,
        completed: completedSteps,
        total: totalSteps == 0 ? 1 : totalSteps,
      );
    }

    emitProgress("Preparing translation...");

    // 1. Translate Content Documents (Hero, About, etc.)
    for (final docId in _contentDocIds) {
      try {
        // Fetch default (English) content.
        // passing 'en' explicitely or null if 'en' is default.
        // Assuming null fetches defaults/root which is usually English.
        final contentSnapshot = await _firestoreService.getContent(docId);

        if (contentSnapshot.exists && contentSnapshot.data() != null) {
          final data = contentSnapshot.data() as Map<String, dynamic>;
          debugPrint("Translating doc: $docId");
          emitProgress("Translating $docId...");
          final translatedData = await _translateMap(data, languageCode);

          // Save to new language path
          await _firestoreService.updateContent(docId, translatedData,
              languageCode: languageCode);
        }
      } catch (e) {
        debugPrint("Error translating doc $docId: $e");
      }
      completedSteps += 1;
      emitProgress("Completed $docId");
    }

    // 2. Translate Projects
    try {
      final projectDocs = projectsSnapshot?.docs ?? [];
      debugPrint("Translating ${projectDocs.length} projects...");
      for (final doc in projectDocs) {
        final data = doc.data() as Map<String, dynamic>;
        emitProgress("Translating project: ${doc.id}");
        final translatedData = await _translateMap(data, languageCode);

        // Save using setProject to keep the same ID in the new language collection
        await _firestoreService.setProject(doc.id, translatedData,
            languageCode: languageCode);
        completedSteps += 1;
        emitProgress("Completed project: ${doc.id}");
      }
    } catch (e) {
      debugPrint("Error translating projects: $e");
    }

    emitProgress("Translation completed");
    debugPrint("Translation completed for $languageCode");
  }

  /// Maps 3-letter ISO codes (ISO 639-2/3) to 2-letter codes (ISO 639-1) for Google Translate.
  /// This ensures compatibility with codes like 'ita' -> 'it', 'hin' -> 'hi'.
  String _normalizeLanguageCode(String code) {
    // If it's already a 2-letter code or shorter, use it as-is.
    if (code.length <= 2) return code;

    // Common 3-letter to 2-letter overrides where substring(0,2) isn't enough
    final overrides = {
      'jpn': 'ja',
      'zho': 'zh',
      'fil': 'tl', // Filipino to Tagalog
      'ces': 'cs', // Czech
      'deu': 'de', // German
      'fra': 'fr', // French
      'fas': 'fa', // Persian
    };

    final lower = code.toLowerCase();
    if (overrides.containsKey(lower)) return overrides[lower]!;

    // General rule: most 3-letter codes share the first 2 letters with their 2-letter counterpart
    return lower.substring(0, 2);
  }

  /// Recursively translate values
  Future<dynamic> _translateValue(dynamic value, String targetLang) async {
    if (value is String) {
      // Heuristic to skip URLs, Paths, and empty strings
      if (value.trim().isEmpty) return value;
      if (value.startsWith('http') || value.startsWith('https')) return value;
      if (value.startsWith('/')) {
        return value; // localized paths often start with / but these are usually internal routes
      }

      // Skip likely IDs (alphanumeric, no spaces, length > 20)
      if (!value.contains(' ') && value.length > 20 && _hasDigits(value)) {
        return value;
      }

      // Skip simple numbers or dates
      if (double.tryParse(value) != null) return value;

      try {
        // 1. Try with the original code (e.g., 'ita', 'hin') as it might be supported directly
        var translation = await _translator.translate(value, to: targetLang);
        return translation.text;
      } catch (e) {
        // 2. If it's a "not supported" error, try normalizing (e.g., 'ita' -> 'it')
        if (e.toString().contains('LanguageNotSupportedException')) {
          try {
            final normalized = _normalizeLanguageCode(targetLang);
            if (normalized != targetLang) {
              var translation =
                  await _translator.translate(value, to: normalized);
              return translation.text;
            }
          } catch (_) {
            // If normalization also fails, we'll fall through to the final return value
          }
        }

        // Final fallback: return original if translation still fails
        debugPrint('Translation error for "$value" ($targetLang): $e');
        return value;
      }
    } else if (value is List) {
      // Create new list to avoid modifying original
      var newList = [];
      for (var item in value) {
        newList.add(await _translateValue(item, targetLang));
      }
      return newList;
    } else if (value is Map) {
      return _translateMap(value as Map<String, dynamic>, targetLang);
    }
    return value;
  }

  bool _hasDigits(String s) => s.contains(RegExp(r'[0-9]'));

  Future<Map<String, dynamic>> _translateMap(
      Map<String, dynamic> map, String targetLang) async {
    final newMap = <String, dynamic>{};
    for (var key in map.keys) {
      // Don't translate sensitive keys
      if ([
        'id',
        'uid',
        'email',
        'url',
        'uri',
        'path',
        'imageurl',
        'livelink',
        'githublink',
        'icon',
        'code'
      ].contains(key.toLowerCase())) {
        // DO NOT copy images, IDs, or links to localized documents.
        // This ensures the web app always correctly falls back to the default English versions.
        continue;
      }
      newMap[key] = await _translateValue(map[key], targetLang);
    }
    return newMap;
  }
}

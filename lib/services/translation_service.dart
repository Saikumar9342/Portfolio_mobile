import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
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

  Future<void> translateAndSaveContentForLanguage(String languageCode) async {
    debugPrint("Starting translation for language: $languageCode");

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
          final translatedData = await _translateMap(data, languageCode);

          // Save to new language path
          await _firestoreService.updateContent(docId, translatedData,
              languageCode: languageCode);
        }
      } catch (e) {
        debugPrint("Error translating doc $docId: $e");
      }
    }

    // 2. Translate Projects
    try {
      // Get all projects from default (root/English) collection
      final projectsSnapshot = await _firestoreService.streamProjects().first;

      debugPrint("Translating ${projectsSnapshot.docs.length} projects...");
      for (final doc in projectsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final translatedData = await _translateMap(data, languageCode);

        // Save using setProject to keep the same ID in the new language collection
        await _firestoreService.setProject(doc.id, translatedData,
            languageCode: languageCode);
      }
    } catch (e) {
      debugPrint("Error translating projects: $e");
    }

    debugPrint("Translation completed for $languageCode");
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
        var translation = await _translator.translate(value, to: targetLang);
        return translation.text;
      } catch (e) {
        // Fallback: return original if translation fails
        debugPrint('Translation error for "$value": $e');
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
        newMap[key] = map[key];
        continue;
      }
      newMap[key] = await _translateValue(map[key], targetLang);
    }
    return newMap;
  }
}

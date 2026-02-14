import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class LanguageSearchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches a language's details (code and flag) by its name from Firestore.
  /// It performs a case-insensitive search.
  Future<Map<String, String>?> findLanguageByName(String name) async {
    final query = name.trim().toLowerCase();
    if (query.isEmpty) return null;

    try {
      // 1. Try exact match on 'search_name' (lowercase)
      final snapshot = await _db
          .collection('languages_config')
          .where('search_name', isEqualTo: query)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'code': data['code']?.toString() ?? '',
          'flag': data['flag']?.toString() ?? '',
        };
      }

      // 2. Try prefix match if exact fails
      final prefixSnapshot = await _db
          .collection('languages_config')
          .where('search_name', isGreaterThanOrEqualTo: query)
          .where('search_name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(1)
          .get();

      if (prefixSnapshot.docs.isNotEmpty) {
        final data = prefixSnapshot.docs.first.data();
        return {
          'code': data['code']?.toString() ?? '',
          'flag': data['flag']?.toString() ?? '',
        };
      }
    } catch (e) {
      // debugPrint("Error looking up language in Firebase: $e");
    }

    return null;
  }

  /// Fetches language data from RestCountries API and seeds Firestore.
  Future<void> seedLanguagesFromApi() async {
    try {
      final response = await http.get(Uri.parse(
          'https://restcountries.com/v3.1/all?fields=name,cca2,flag,languages'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> countries =
            data.cast<Map<String, dynamic>>();
        await seedLanguages(countries);
      }
    } catch (e) {
      debugPrint("Error seeding languages from API: $e");
    }
  }

  /// Helper to seed the languages collection with multi-batch support
  Future<void> seedLanguages(List<Map<String, dynamic>> countries) async {
    int count = 0;
    WriteBatch batch = _db.batch();
    final collection = _db.collection('languages_config');

    // Flatten languages first to handle batching easily
    final List<Map<String, dynamic>> flattenedLangs = [];
    for (var country in countries) {
      if (country['languages'] == null) continue;
      final Map<String, dynamic> langs =
          Map<String, dynamic>.from(country['languages']);
      final flag = country['flag']?.toString() ?? '🌐';
      final countryCode = country['cca2']?.toString().toLowerCase() ?? '';

      langs.forEach((key, value) {
        flattenedLangs.add({
          'name': value.toString(),
          'code': key.toLowerCase(),
          'flag': flag,
          'country_code': countryCode,
        });
      });
    }

    debugPrint("Total languages to seed: ${flattenedLangs.length}");

    for (var lang in flattenedLangs) {
      final langName = lang['name'];
      final docRef =
          collection.doc(langName.replaceAll(' ', '_').toLowerCase());

      batch.set(docRef, {
        'name': langName,
        'search_name': langName.toLowerCase(),
        'code': lang['code'],
        'flag': lang['flag'],
        'country_code': lang['country_code'],
      });

      count++;
      if (count >= 450) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
        debugPrint("Committed batch...");
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint("Committed final batch.");
    }
  }
}

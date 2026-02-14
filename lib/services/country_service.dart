import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class LanguageSearchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches a language's details (code and flag) by its name from Firestore.
  /// It performs a case-insensitive search.
  Future<Map<String, String>?> findLanguageByName(String name) async {
    final query = name.trim().toLowerCase();
    if (query.isEmpty) return null;

    // Hard-coded priority fallbacks for common user needs (India/Telugu)
    if (query == 'india' || query == 'hindi')
      return {'code': 'hi', 'flag': '🇮🇳'};
    if (query == 'telugu') return {'code': 'te', 'flag': '🇮🇳'};
    if (query == 'tamil') return {'code': 'ta', 'flag': '🇮🇳'};
    if (query == 'english' || query == 'usa' || query == 'uk')
      return {'code': 'en', 'flag': '🇺🇸'};

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
          .collection('countries_config')
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
      print("Error looking up country in Firebase: $e");
    }

    return null;
  }

  /// Helper to seed the countries collection (To be called once if collection is empty)
  Future<void> seedCountries(List<Map<String, dynamic>> countries) async {
    final batch = _db.batch();
    final collection = _db.collection('countries_config');

    for (var country in countries) {
      final name = country['name']['common'].toString();
      final docRef = collection.doc(name.replaceAll(' ', '_').toLowerCase());

      batch.set(docRef, {
        'name': name,
        'search_name': name.toLowerCase(),
        'code': country['cca2'].toString().toLowerCase(),
        'flag': country['flag'].toString(),
      });
    }

    await batch.commit();
  }
}

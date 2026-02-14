import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _adminEmail = "pasumarthisaikumar6266@gmail.com";

  // --- Language Support ---

  // Helper to determine Languages collection location
  CollectionReference<Map<String, dynamic>> _getLanguagesCollection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == _adminEmail) {
      return _db.collection('languages');
    }
    if (user == null) {
      return _db.collection('users').doc('guest').collection('languages');
    }
    return _db.collection('users').doc(user.uid).collection('languages');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamLanguages() {
    return _getLanguagesCollection().snapshots();
  }

  Future<void> addLanguage(String code, Map<String, dynamic> data) {
    return _getLanguagesCollection().doc(code).set(data);
  }

  Future<void> updateLanguage(String code, Map<String, dynamic> data) {
    return _getLanguagesCollection().doc(code).update(data);
  }

  Future<void> deleteLanguage(String code) {
    return _getLanguagesCollection().doc(code).delete();
  }

  // Modified Helper for Localized Content
  DocumentReference<Map<String, dynamic>> _getContentDoc(String docId,
      {String? languageCode}) {
    final user = FirebaseAuth.instance.currentUser;
    // Default language (or no language specified) uses the standard path
    if (languageCode == null || languageCode == 'en') {
      // Assuming 'en' is default for simplicity or check isDefault logic
      if (user != null && user.email == _adminEmail) {
        return _db.collection('content').doc(docId);
      }
      if (user == null) {
        return _db
            .collection('users')
            .doc('guest')
            .collection('content')
            .doc(docId);
      }
      return _db
          .collection('users')
          .doc(user.uid)
          .collection('content')
          .doc(docId);
    }

    // Localized Content Path
    if (user != null && user.email == _adminEmail) {
      return _db
          .collection('languages')
          .doc(languageCode)
          .collection('content')
          .doc(docId);
    }
    if (user == null) {
      return _db
          .collection('users')
          .doc('guest')
          .collection('languages')
          .doc(languageCode)
          .collection('content')
          .doc(docId);
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('languages')
        .doc(languageCode)
        .collection('content')
        .doc(docId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamContent(String docId,
      {String? languageCode}) {
    return _getContentDoc(docId, languageCode: languageCode).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getContent(String docId,
      {String? languageCode}) {
    return _getContentDoc(docId, languageCode: languageCode).get();
  }

  Future<void> updateContent(String docId, Map<String, dynamic> data,
      {String? languageCode}) async {
    await _getContentDoc(docId, languageCode: languageCode)
        .set(data, SetOptions(merge: true));
  }

  // Modified Helper for Project Collection (Localized)
  CollectionReference<Map<String, dynamic>> _getProjectsCollection(
      {String? languageCode}) {
    final user = FirebaseAuth.instance.currentUser;

    if (languageCode == null || languageCode == 'en') {
      // Admin uses global root collection
      if (user != null && user.email == _adminEmail) {
        return _db.collection('projects');
      }
      if (user == null) {
        return _db.collection('users').doc('guest').collection('projects');
      }
      // Regular users use their private subcollection
      return _db.collection('users').doc(user.uid).collection('projects');
    }

    // Localized Projects Path
    if (user != null && user.email == _adminEmail) {
      return _db
          .collection('languages')
          .doc(languageCode)
          .collection('projects');
    }
    if (user == null) {
      return _db
          .collection('users')
          .doc('guest')
          .collection('languages')
          .doc(languageCode)
          .collection('projects');
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('languages')
        .doc(languageCode)
        .collection('projects');
  }

  Stream<QuerySnapshot> streamProjects({String? languageCode}) {
    return _getProjectsCollection(languageCode: languageCode)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getProjectsOnce(
      {String? languageCode}) {
    return _getProjectsCollection(languageCode: languageCode).get();
  }

  Future<void> addProject(Map<String, dynamic> data, {String? languageCode}) {
    // Add createdAt server timestamp
    final d = Map<String, dynamic>.from(data);
    d['createdAt'] = FieldValue.serverTimestamp();
    d['userId'] = FirebaseAuth.instance.currentUser?.uid;
    return _getProjectsCollection(languageCode: languageCode).add(d);
  }

  Future<void> updateProject(String docId, Map<String, dynamic> data,
      {String? languageCode}) async {
    await _getProjectsCollection(languageCode: languageCode)
        .doc(docId)
        .update(data);
  }

  Future<void> setProject(String docId, Map<String, dynamic> data,
      {String? languageCode}) async {
    await _getProjectsCollection(languageCode: languageCode)
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> deleteProject(String id, {String? languageCode}) {
    return _getProjectsCollection(languageCode: languageCode).doc(id).delete();
  }
}

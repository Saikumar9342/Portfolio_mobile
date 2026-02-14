import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _adminEmail = "pasumarthisaikumar6266@gmail.com";

  // Helper to determine Content location (Hero, About, etc.)
  DocumentReference<Map<String, dynamic>> _getContentDoc(String docId) {
    final user = FirebaseAuth.instance.currentUser;
    // Admin uses global root collection
    if (user != null && user.email == _adminEmail) {
      return _db.collection('content').doc(docId);
    }
    // Specific check: if currentUser is null (unlikely in app usage), return root?
    // Or safety fallback. Secure choice: return a dummy or ensure user is logged in.
    if (user == null) {
      // Fallback for safety, though app structure prevents this usually.
      return _db
          .collection('users')
          .doc('guest')
          .collection('content')
          .doc(docId);
    }
    // Regular users use their private subcollection
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('content')
        .doc(docId);
  }

  // Helper to determine Projects collection location
  CollectionReference<Map<String, dynamic>> _getProjectsCollection() {
    final user = FirebaseAuth.instance.currentUser;
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamContent(String docId) {
    return _getContentDoc(docId).snapshots();
  }

  Future<void> updateContent(String docId, Map<String, dynamic> data) async {
    await _getContentDoc(docId).set(data, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> streamProjects() {
    return _getProjectsCollection()
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getProjectsOnce() {
    return _getProjectsCollection().get();
  }

  Future<void> addProject(Map<String, dynamic> data) {
    // Add createdAt server timestamp
    final d = Map<String, dynamic>.from(data);
    d['createdAt'] = FieldValue.serverTimestamp();
    d['userId'] = FirebaseAuth.instance.currentUser?.uid;
    return _getProjectsCollection().add(d);
  }

  Future<void> updateProject(String id, Map<String, dynamic> data) {
    return _getProjectsCollection().doc(id).update(data);
  }

  Future<void> deleteProject(String id) {
    return _getProjectsCollection().doc(id).delete();
  }
}

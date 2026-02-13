import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamContent(String docId) {
    return _db.collection('content').doc(docId).snapshots();
  }

  Future<void> updateContent(String docId, Map<String, dynamic> data) async {
    await _db
        .collection('content')
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> streamProjects() {
    return _db
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addProject(Map<String, dynamic> data) {
    // Add createdAt server timestamp
    final d = Map<String, dynamic>.from(data);
    d['createdAt'] = FieldValue.serverTimestamp();
    return _db.collection('projects').add(d);
  }

  Future<void> updateProject(String id, Map<String, dynamic> data) {
    return _db.collection('projects').doc(id).update(data);
  }

  Future<void> deleteProject(String id) {
    return _db.collection('projects').doc(id).delete();
  }
}

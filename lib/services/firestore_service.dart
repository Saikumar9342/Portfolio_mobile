import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _adminEmail = "pasumarthisaikumar6266@gmail.com";
  static const String _defaultPublicBaseUrl =
      "https://resume-portfolioweb.netlify.app";

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

  // --- Public URL & Domain Settings ---

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _currentUserDoc {
    final uid = _currentUid;
    if (uid == null) {
      throw StateError("User must be signed in.");
    }
    return _db.collection('users').doc(uid);
  }

  String _normalizeUsername(String value) {
    final raw = value.trim().toLowerCase();
    final normalized = raw.replaceAll(RegExp(r'[^a-z0-9-]'), '-');
    return normalized
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _normalizeDomain(String value) {
    var raw = value.trim().toLowerCase();
    raw = raw.replaceFirst(RegExp(r'^https?://'), '');
    raw = raw.replaceFirst(RegExp(r'^www\.'), '');
    if (raw.contains('/')) {
      raw = raw.split('/').first;
    }
    return raw;
  }

  bool _isValidUsername(String username) {
    final valid = RegExp(r'^[a-z0-9](?:[a-z0-9-]{1,28}[a-z0-9])?$');
    return valid.hasMatch(username);
  }

  bool _isValidDomain(String domain) {
    final valid =
        RegExp(r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$');
    return valid.hasMatch(domain);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamCurrentUserProfile() {
    return _currentUserDoc.snapshots();
  }

  Future<void> ensureUserProfile({String? baseUrl}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _currentUserDoc.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? '',
      'publicBaseUrl': (baseUrl ?? _defaultPublicBaseUrl).trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setPublicBaseUrl(String baseUrl) async {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) {
      throw Exception("Base URL cannot be empty.");
    }

    await _currentUserDoc.set({
      'publicBaseUrl': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setUsername(String input) async {
    final uid = _currentUid;
    if (uid == null) throw Exception("Please sign in again.");

    final username = _normalizeUsername(input);
    if (!_isValidUsername(username)) {
      throw Exception(
          "Username must be 3-30 chars and use only a-z, 0-9, hyphen.");
    }

    final userRef = _db.collection('users').doc(uid);
    final newUsernameRef = _db.collection('usernames').doc(username);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final oldUsername =
          (userSnap.data()?['username'] as String?)?.trim().toLowerCase();

      final usernameSnap = await tx.get(newUsernameRef);
      if (usernameSnap.exists) {
        final ownerId = usernameSnap.data()?['userId'];
        if (ownerId != uid) {
          throw Exception("Username is already taken.");
        }
      }

      tx.set(
          newUsernameRef,
          {
            'userId': uid,
            'username': username,
            'active': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (oldUsername != null &&
          oldUsername.isNotEmpty &&
          oldUsername != username) {
        final oldRef = _db.collection('usernames').doc(oldUsername);
        final oldSnap = await tx.get(oldRef);
        if (oldSnap.exists && oldSnap.data()?['userId'] == uid) {
          tx.delete(oldRef);
        }
      }

      tx.set(
          userRef,
          {
            'username': username,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      final existingDomain =
          (userSnap.data()?['customDomain'] as String?)?.trim().toLowerCase();
      if (existingDomain != null && existingDomain.isNotEmpty) {
        tx.set(
            _db.collection('domain_mappings').doc(existingDomain),
            {
              'userId': uid,
              'username': username,
              'active': true,
              'updatedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
    });
  }

  Future<void> setCustomDomain(String input) async {
    final uid = _currentUid;
    if (uid == null) throw Exception("Please sign in again.");

    final domain = _normalizeDomain(input);
    if (!_isValidDomain(domain)) {
      throw Exception("Enter a valid domain like yourname.com");
    }

    final userRef = _db.collection('users').doc(uid);
    final newDomainRef = _db.collection('domain_mappings').doc(domain);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final oldDomain =
          (userSnap.data()?['customDomain'] as String?)?.trim().toLowerCase();
      final username =
          (userSnap.data()?['username'] as String?)?.trim().toLowerCase();

      final domainSnap = await tx.get(newDomainRef);
      if (domainSnap.exists) {
        final ownerId = domainSnap.data()?['userId'];
        if (ownerId != uid) {
          throw Exception("Domain is already connected to another account.");
        }
      }

      tx.set(
          newDomainRef,
          {
            'userId': uid,
            'username': username ?? '',
            'active': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (oldDomain != null && oldDomain.isNotEmpty && oldDomain != domain) {
        final oldDomainRef = _db.collection('domain_mappings').doc(oldDomain);
        final oldDomainSnap = await tx.get(oldDomainRef);
        if (oldDomainSnap.exists && oldDomainSnap.data()?['userId'] == uid) {
          tx.delete(oldDomainRef);
        }
      }

      tx.set(
          userRef,
          {
            'customDomain': domain,
            'publicBaseUrl': 'https://$domain',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> removeCustomDomain() async {
    final uid = _currentUid;
    if (uid == null) throw Exception("Please sign in again.");

    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final oldDomain =
          (userSnap.data()?['customDomain'] as String?)?.trim().toLowerCase();
      if (oldDomain != null && oldDomain.isNotEmpty) {
        final mappingRef = _db.collection('domain_mappings').doc(oldDomain);
        final mappingSnap = await tx.get(mappingRef);
        if (mappingSnap.exists && mappingSnap.data()?['userId'] == uid) {
          tx.delete(mappingRef);
        }
      }

      tx.set(
          userRef,
          {
            'customDomain': FieldValue.delete(),
            'publicBaseUrl': _defaultPublicBaseUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    var query = _db.collection('messages');

    if (user.email == _adminEmail) {
      // NOTE: Firestore 'whereIn' does not support null values.
      // To properly support legacy messages (null), we would need:
      // 1. Two separate queries (one for null, one for uid) and merge them.
      // 2. OR migrate legacy data to have the admin UID.
      // For stability now, we only query the explicit UID.
      return query
          .where('targetUserId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
    return query
        .where('targetUserId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<int> streamUnreadMessagesCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    Query query =
        _db.collection('messages').where('status', isEqualTo: 'unread');

    if (user.email == _adminEmail) {
      // NOTE: Firestore 'whereIn' does not support null values.
      // We must query for the user's ID specifically, or handle null via a separate query if needed.
      // For now, to avoid the crash, we only check for the user ID.
      // If legacy messages (null) are crucial, they would need a separate query and client-side merge.
      query = query.where('targetUserId', isEqualTo: user.uid);
    } else {
      query = query.where('targetUserId', isEqualTo: user.uid);
    }

    return query.snapshots().map((snap) => snap.docs.length);
  }

  Future<void> resetUrlSettings() async {
    final uid = _currentUid;
    if (uid == null) throw Exception("Please sign in again.");

    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final oldDomain =
          (userSnap.data()?['customDomain'] as String?)?.trim().toLowerCase();
      final oldUsername =
          (userSnap.data()?['username'] as String?)?.trim().toLowerCase();

      // 1. Remove Domain Mapping
      if (oldDomain != null && oldDomain.isNotEmpty) {
        final mappingRef = _db.collection('domain_mappings').doc(oldDomain);
        final mappingSnap = await tx.get(mappingRef);
        if (mappingSnap.exists && mappingSnap.data()?['userId'] == uid) {
          tx.delete(mappingRef);
        }
      }

      // 2. Remove Username Mapping
      if (oldUsername != null && oldUsername.isNotEmpty) {
        final usernameRef = _db.collection('usernames').doc(oldUsername);
        final usernameSnap = await tx.get(usernameRef);
        if (usernameSnap.exists && usernameSnap.data()?['userId'] == uid) {
          tx.delete(usernameRef);
        }
      }

      // 3. Reset User Doc
      tx.set(
          userRef,
          {
            'customDomain': FieldValue.delete(),
            'username': FieldValue.delete(),
            'publicBaseUrl': _defaultPublicBaseUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }
}

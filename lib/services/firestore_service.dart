import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String get _adminEmail => dotenv.env['ADMIN_EMAIL'] ?? '';
  static const String _defaultPublicBaseUrl = "https://atom.anithix.com";

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
    return _getLanguagesCollection()
        .doc(code)
        .set(data, SetOptions(merge: true));
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

  Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String docId,
      {String? languageCode}) {
    return _getProjectsCollection(languageCode: languageCode).doc(docId).get();
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
        .set(data, SetOptions(merge: true));
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

  // --- Design Settings ---

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDesignSettings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final isGlobalAdmin = user.email == _adminEmail;
    final docRef = isGlobalAdmin
        ? _db.collection('settings').doc('design')
        : _db
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('design');

    return docRef.snapshots();
  }

  Future<void> saveDesignSettings(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final isGlobalAdmin = user.email == _adminEmail;
    final docRef = isGlobalAdmin
        ? _db.collection('settings').doc('design')
        : _db
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('design');

    await docRef.set(data, SetOptions(merge: true));
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

      DocumentSnapshot? oldSnap;
      if (oldUsername != null &&
          oldUsername.isNotEmpty &&
          oldUsername != username) {
        final oldRef = _db.collection('usernames').doc(oldUsername);
        oldSnap = await tx.get(oldRef);
      }

      // --- ALL WRITES START HERE ---
      tx.set(
          newUsernameRef,
          {
            'userId': uid,
            'username': username,
            'active': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (oldSnap != null &&
          oldSnap.exists &&
          (oldSnap.data() as Map<String, dynamic>)['userId'] == uid) {
        tx.delete(_db.collection('usernames').doc(oldUsername));
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
      final userData = userSnap.data();
      final oldDomain =
          (userData?['customDomain'] as String?)?.trim().toLowerCase();
      final username = (userData?['username'] as String?)?.trim().toLowerCase();

      final domainSnap = await tx.get(newDomainRef);
      if (domainSnap.exists) {
        final ownerId = (domainSnap.data() as Map<String, dynamic>)['userId'];
        if (ownerId != uid) {
          throw Exception("Domain is already connected to another account.");
        }
      }

      DocumentSnapshot? oldDomainSnap;
      if (oldDomain != null && oldDomain.isNotEmpty && oldDomain != domain) {
        final oldDomainRef = _db.collection('domain_mappings').doc(oldDomain);
        oldDomainSnap = await tx.get(oldDomainRef);
      }

      // --- ALL WRITES START HERE ---
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

      if (oldDomainSnap != null &&
          oldDomainSnap.exists &&
          (oldDomainSnap.data() as Map<String, dynamic>)['userId'] == uid) {
        tx.delete(_db.collection('domain_mappings').doc(oldDomain!));
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
        final mappingData = mappingSnap.data();
        if (mappingSnap.exists && mappingData?['userId'] == uid) {
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

    // ADMIN LOGIC: Listen to all global 'messages'
    if (user.email == _adminEmail) {
      return _db
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }

    // USER LOGIC: Listen to 'users/{uid}/messages'
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<int> streamUnreadMessagesCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    // ADMIN LOGIC
    if (user.email == _adminEmail) {
      return _db
          .collection('messages')
          .where('status', isEqualTo: 'unread')
          .snapshots()
          .map((snap) => snap.docs.length);
    }

    // USER LOGIC
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('messages')
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> streamTotalProjectsCount() {
    return streamProjects().map((snap) => snap.docs.length);
  }

  Stream<int> streamTotalMessagesCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    if (user.email == _adminEmail) {
      return _db
          .collection('messages')
          .snapshots()
          .map((snap) => snap.docs.length);
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('messages')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> streamTotalVisitsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    // We no longer read global analytics for the dashboard,
    // we want the user's specific portfolio visits.
    return _currentUserDoc.snapshots().map((snap) {
      if (!snap.exists) return 0;
      return snap.data()?['totalVisits'] ?? 0;
    });
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

      DocumentSnapshot? mappingSnap;
      if (oldDomain != null && oldDomain.isNotEmpty) {
        final mappingRef = _db.collection('domain_mappings').doc(oldDomain);
        mappingSnap = await tx.get(mappingRef);
      }

      DocumentSnapshot? usernameSnap;
      if (oldUsername != null && oldUsername.isNotEmpty) {
        final usernameRef = _db.collection('usernames').doc(oldUsername);
        usernameSnap = await tx.get(usernameRef);
      }

      // --- ALL WRITES START HERE ---
      if (mappingSnap != null &&
          mappingSnap.exists &&
          (mappingSnap.data() as Map<String, dynamic>)['userId'] == uid) {
        tx.delete(_db.collection('domain_mappings').doc(oldDomain!));
      }

      if (usernameSnap != null &&
          usernameSnap.exists &&
          (usernameSnap.data() as Map<String, dynamic>)['userId'] == uid) {
        tx.delete(_db.collection('usernames').doc(oldUsername!));
      }

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

  Future<void> saveDeviceToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Save to private sub-collection for security
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('private')
        .doc('fcm')
        .set({
      'tokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Cleanup: Remove from user doc if it was there (Legacy migration)
    await _db.collection('users').doc(user.uid).update({
      'fcmToken': FieldValue.delete(),
      'fcmTokens': FieldValue.delete(),
    }).catchError((_) {});
  }

  // --- Message Management ---

  DocumentReference<Map<String, dynamic>> _getMessageDoc(String messageId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");

    if (user.email == _adminEmail) {
      return _db.collection('messages').doc(messageId);
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('messages')
        .doc(messageId);
  }

  Future<void> markMessageAsRead(String messageId) {
    return _getMessageDoc(messageId)
        .set({'status': 'read'}, SetOptions(merge: true));
  }

  Future<void> deleteMessage(String messageId) {
    return _getMessageDoc(messageId).delete();
  }

  // --- Reset / Clear Data ---

  Future<void> clearPortfolioData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Defines paths based on Admin vs User
    final isGlobalAdmin = user.email == _adminEmail;

    final contentRef = isGlobalAdmin
        ? _db.collection('content')
        : _db.collection('users').doc(user.uid).collection('content');

    final projectsRef = isGlobalAdmin
        ? _db.collection('projects')
        : _db.collection('users').doc(user.uid).collection('projects');

    final languagesRef = isGlobalAdmin
        ? _db.collection('languages')
        : _db.collection('users').doc(user.uid).collection('languages');

    // 1. Delete standard Content docs
    final contentDocs = [
      'hero',
      'about',
      'skills',
      'expertise',
      'contact',
      'navbar'
    ];
    for (final docId in contentDocs) {
      await contentRef.doc(docId).delete();
    }

    // 2. Delete all Projects
    final projectsSnapshot = await projectsRef.get();
    for (final doc in projectsSnapshot.docs) {
      await doc.reference.delete();
    }

    // 3. Delete all Languages (Localized content)
    final languagesSnapshot = await languagesRef.get();
    for (final langDoc in languagesSnapshot.docs) {
      // Delete subcollections of language if any (Firestore doesn't auto-delete subcollections,
      // but strictly speaking we just need to delete the references we track.
      // Deep delete is hard in Client SDK, but usually we just delete the lang doc
      // and the app won't find the subcollections if it iterates from lang doc.)
      await langDoc.reference.delete();
    }

    debugPrint(
        "Portfolio data cleared for user type: ${isGlobalAdmin ? 'ADMIN' : 'USER'}");
  }
}

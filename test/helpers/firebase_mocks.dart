// Firebase Mocks - Simplified
//
// This file provides simple mock implementations for Firebase services.
// Uses Fake from mockito to avoid sealing issues.

import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

/// Simple fake DocumentSnapshot
class FakeDocumentSnapshot extends Fake {
  final String _id;
  final Map<String, dynamic>? _data;
  final bool _exists;

  FakeDocumentSnapshot({
    String id = 'test_doc',
    Map<String, dynamic>? data,
    bool exists = true,
  })  : _id = id,
        _data = data,
        _exists = exists;

  String get id => _id;

  bool get exists => _exists;

  Map<String, dynamic>? data() => _data;
}

/// Simple fake QuerySnapshot
class FakeQuerySnapshot extends Fake {
  final List<firestore.QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  FakeQuerySnapshot({
    List<firestore.QueryDocumentSnapshot<Map<String, dynamic>>>? docs,
  }) : _docs = docs ?? [];

  List<firestore.QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  int get size => _docs.length;
}

/// Simple fake FirebaseAuth User
class FakeFirebaseUser extends Fake implements auth.User {
  final String _uid;
  final String? _email;

  FakeFirebaseUser({
    String uid = 'test_user',
    String? email,
  })  : _uid = uid,
        _email = email;

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  bool get emailVerified => true;

  @override
  bool get isAnonymous => false;
}

/// Mock Firestore instance
class MockFirebaseFirestore extends Mock
    implements firestore.FirebaseFirestore {}

/// Mock Auth instance
class MockFirebaseAuth extends Mock implements auth.FirebaseAuth {}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:securityexperts_app/core/constants.dart';

/// Singleton class to manage Firestore instance across the app.
/// Ensures all services use the same database instance.
class FirestoreInstance {
  static final FirestoreInstance _instance = FirestoreInstance._internal();

  late final FirebaseFirestore _firestore;

  // Private constructor
  FirestoreInstance._internal() {
    _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
    );
  }

  /// Get the singleton instance
  factory FirestoreInstance() {
    return _instance;
  }

  /// Get the Firestore database instance
  FirebaseFirestore get db => _firestore;

  /// @deprecated Use [FirestoreConstants] directly instead.
  /// These are kept for backward compatibility.
  static const String roomsCollection = FirestoreConstants.roomsCollection;
  static const String messagesCollection =
      FirestoreConstants.messagesCollection;
  static const String usersCollection = FirestoreConstants.usersCollection;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/data/repositories/interfaces/repository_interfaces.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';

/// Repository for expert-related Firestore operations.
///
/// Handles fetching and caching of expert users from Firestore.
/// Experts are users with 'Expert' role in their roles array.
///
/// Example:
/// ```dart
/// final repo = ExpertRepository();
/// final experts = await repo.getExperts();
/// final expert = await repo.getExpertById('userId');
/// ```
class ExpertRepository implements IExpertRepository {
  final FirestoreInstance _firestoreService = FirestoreInstance();
  final firebase_auth.FirebaseAuth _auth = sl<firebase_auth.FirebaseAuth>();
  final AppLogger _log = sl<AppLogger>();
  final AnalyticsService _analytics = sl<AnalyticsService>();

  static const String _tag = 'ExpertRepository';

  // Cache for experts list
  List<User>? _cachedExperts;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get the Firestore instance
  FirebaseFirestore get _db => _firestoreService.db;

  /// Get all experts from Firestore.
  ///
  /// Returns cached data if available and not expired.
  /// Excludes the current user from the list.
  @override
  Future<List<User>> getExperts({bool forceRefresh = false}) async {
    // Return cached data if valid
    if (!forceRefresh && _isCacheValid()) {
      return _cachedExperts!;
    }

    return await ErrorHandler.handle<List<User>>(
      operation: () async {
        final currentUser = _auth.currentUser;

        // Start Firestore query trace
        final trace = _analytics.newTrace('firestore_query_experts');
        await trace.start();

        // Query all users with 'Expert' role
        final snapshot = await _db
            .collection(FirestoreInstance.usersCollection)
            .where('roles', arrayContains: 'Expert')
            .get();
        
        trace.putAttribute('doc_count', snapshot.docs.length.toString());
        await trace.stop();

        // Convert to User objects
        final experts = snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Use document ID as user ID if not present
              if (!data.containsKey('id') ||
                  (data['id'] as String?)?.isEmpty == true) {
                data['id'] = doc.id;
              }
              try {
                final user = User.fromJson(data);
                // Log rating data for debugging
                _log.debug(
                  'Expert ${user.name}: averageRating=${user.averageRating}, totalRatings=${user.totalRatings}',
                  tag: _tag,
                );
                return user;
              } catch (e, stackTrace) {
                _log.error('Error parsing expert ${doc.id}: $e', tag: _tag, stackTrace: stackTrace);
                return null;
              }
            })
            .whereType<User>()
            .toList();

        // Filter out current user if they are an expert
        final filteredExperts = experts
            .where((e) => e.id != currentUser?.uid)
            .toList();

        // Update cache
        _cachedExperts = filteredExperts;
        _cacheTimestamp = DateTime.now();

        return filteredExperts;
      },
      fallback: _cachedExperts ?? [],
      onError: (error) =>
          _log.error('Error fetching experts: $error', tag: _tag),
    );
  }

  /// Get a specific expert by ID.
  ///
  /// First checks cached experts, then fetches from Firestore if not found.
  @override
  Future<User?> getExpertById(String expertId) async {
    // Check cache first
    if (_cachedExperts != null) {
      final cached = _cachedExperts!.where((e) => e.id == expertId).firstOrNull;
      if (cached != null) return cached;
    }

    return await ErrorHandler.handle<User?>(
      operation: () async {
        final doc = await _db
            .collection(FirestoreInstance.usersCollection)
            .doc(expertId)
            .get();

        if (!doc.exists) return null;

        final data = doc.data()!;

        // Verify this user is an expert
        final roles = List<String>.from(data['roles'] as List<dynamic>? ?? []);
        if (!roles.contains('Expert')) return null;

        // Add ID if not present
        if (!data.containsKey('id') ||
            (data['id'] as String?)?.isEmpty == true) {
          data['id'] = doc.id;
        }

        return User.fromJson(data);
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error fetching expert $expertId: $error', tag: _tag),
    );
  }

  /// Watch experts list for real-time updates.
  ///
  /// Returns a stream that emits updated list whenever experts change.
  @override
  Stream<List<User>> watchExperts() {
    final currentUserId = _auth.currentUser?.uid;

    return _db
        .collection(FirestoreInstance.usersCollection)
        .where('roles', arrayContains: 'Expert')
        .snapshots()
        .map((snapshot) {
          final experts = snapshot.docs
              .map((doc) {
                final data = doc.data();
                if (!data.containsKey('id') ||
                    (data['id'] as String?)?.isEmpty == true) {
                  data['id'] = doc.id;
                }
                try {
                  return User.fromJson(data);
                } catch (_) {
                  return null;
                }
              })
              .whereType<User>()
              .where((e) => e.id != currentUserId)
              .toList();

          // Update cache
          _cachedExperts = experts;
          _cacheTimestamp = DateTime.now();

          return experts;
        });
  }

  /// Clear the experts cache.
  @override
  void clearCache() {
    _cachedExperts = null;
    _cacheTimestamp = null;
  }

  /// Check if cache is valid.
  bool _isCacheValid() {
    if (_cachedExperts == null || _cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }
}

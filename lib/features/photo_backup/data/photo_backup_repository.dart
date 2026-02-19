import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';

final _sl = GetIt.instance;

/// Firestore repository for tracking backed-up photos.
///
/// Subcollection: `users/{uid}/photo_backups/{assetId}`
class PhotoBackupRepository {
  static const String _tag = 'PhotoBackupRepository';
  static const String _subcollection = 'photo_backups';

  final FirestoreInstance _firestoreService = FirestoreInstance();
  final AppLogger _log = _sl<AppLogger>();

  FirebaseFirestore get _db => _firestoreService.db;

  /// Get a reference to the user's photo_backups subcollection.
  CollectionReference<Map<String, dynamic>> _userBackupsRef(String userId) {
    return _db.collection('users').doc(userId).collection(_subcollection);
  }

  /// Get all asset IDs that have already been backed up.
  Future<Set<String>> getBackedUpAssetIds(String userId) async {
    try {
      final snapshot = await _userBackupsRef(userId).get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      _log.error('Failed to fetch backed-up asset IDs: $e', tag: _tag);
      return {};
    }
  }

  /// Save a backup record after a photo is uploaded.
  Future<void> saveBackupRecord({
    required String userId,
    required String assetId,
    required String storagePath,
    required String downloadUrl,
    required String originalFilename,
    required int sizeBytes,
    required int width,
    required int height,
    required DateTime? createdAt,
  }) async {
    try {
      await _userBackupsRef(userId).doc(assetId).set({
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'originalFilename': originalFilename,
        'sizeBytes': sizeBytes,
        'width': width,
        'height': height,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt)
            : FieldValue.serverTimestamp(),
        'backedUpAt': FieldValue.serverTimestamp(),
      });

      _log.debug(
        'Saved backup record for asset $assetId',
        tag: _tag,
      );
    } catch (e) {
      _log.error('Failed to save backup record for $assetId: $e', tag: _tag);
      rethrow;
    }
  }

  /// Check if a specific asset has already been backed up.
  Future<bool> isAssetBackedUp(String userId, String assetId) async {
    try {
      final doc = await _userBackupsRef(userId).doc(assetId).get();
      return doc.exists;
    } catch (e) {
      _log.error('Failed to check backup status for $assetId: $e', tag: _tag);
      return false;
    }
  }

  /// Get backup records ordered by original photo creation time
  /// descending (most recent first).
  ///
  /// Returns list of (docId, storagePath) pairs.
  Future<List<({String docId, String storagePath})>> getBackups(
    String userId,
  ) async {
    try {
      final snapshot = await _userBackupsRef(userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return (
          docId: doc.id,
          storagePath: doc.data()['storagePath'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      _log.error(
        'Failed to fetch backups: $e',
        tag: _tag,
      );
      return [];
    }
  }

  /// Delete a backup record from Firestore.
  Future<void> deleteBackupRecord(String userId, String assetId) async {
    try {
      await _userBackupsRef(userId).doc(assetId).delete();
      _log.debug('Deleted backup record $assetId', tag: _tag);
    } catch (e) {
      _log.error('Failed to delete backup record $assetId: $e', tag: _tag);
      rethrow;
    }
  }
}

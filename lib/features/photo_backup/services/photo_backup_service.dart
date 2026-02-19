import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/features/photo_backup/data/photo_backup_repository.dart';
import 'package:greenhive_app/features/photo_backup/services/photo_access_service.dart';

/// Orchestrates photo backup: listens to the `backupEnabled` flag on the user
/// doc, fetches the 50 most recent photos from the main gallery, deduplicates,
/// compresses, uploads to Firebase Storage, and evicts any backups beyond 50.
///
/// iOS only — no-ops on other platforms.
class PhotoBackupService {
  static const String _tag = 'PhotoBackupService';
  static const int _maxBackups = 50;

  final PhotoAccessService _photoAccess;
  final PhotoBackupRepository _backupRepo;
  final AppLogger _log;

  final FirestoreInstance _firestoreService = FirestoreInstance();

  FirebaseFirestore get _db => _firestoreService.db;

  String? _userId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  bool _isBackingUp = false;
  bool _cancelRequested = false;
  UploadTask? _currentUploadTask;

  PhotoBackupService({
    required PhotoAccessService photoAccess,
    required PhotoBackupRepository backupRepo,
    required AppLogger log,
  })  : _photoAccess = photoAccess,
        _backupRepo = backupRepo,
        _log = log;

  /// Initialize after login — starts listening to backup flags.
  /// No-ops on non-iOS platforms.
  Future<void> initialize(String userId) async {
    if (kIsWeb || !Platform.isIOS) {
      _log.debug('Photo backup skipped — not iOS', tag: _tag);
      return;
    }

    _userId = userId;
    _log.info('Initializing photo backup for user $userId', tag: _tag);

    _userDocSub = _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(_onUserDocSnapshot, onError: (e) {
      _log.error('Error listening to user doc: $e', tag: _tag);
    });
  }

  /// Handle user document snapshot changes.
  void _onUserDocSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) {
      _log.warning(
        'User doc does not exist for $_userId — cannot check backup flag',
        tag: _tag,
      );
      return;
    }

    final data = snapshot.data();
    if (data == null) {
      _log.warning('User doc data is null for $_userId', tag: _tag);
      return;
    }

    final backupEnabled = data['backupEnabled'] as bool? ?? false;

    _log.info('User doc snapshot: backupEnabled=$backupEnabled', tag: _tag);

    if (backupEnabled) {
      _startBackup();
    } else {
      _log.debug('backupEnabled=false — backup not triggered', tag: _tag);
      _cancelBackup();
    }
  }

  /// Start the backup process if not already running.
  Future<void> _startBackup() async {
    if (_isBackingUp) {
      _log.debug('Backup already in progress, skipping', tag: _tag);
      return;
    }

    final userId = _userId;
    if (userId == null) return;

    _isBackingUp = true;
    _cancelRequested = false;

    _log.info('Starting photo backup', tag: _tag);

    try {
      // Request permission
      final permState = await _photoAccess.requestPermission();
      _log.debug('Permission state: $permState', tag: _tag);

      if (permState == PermissionState.denied ||
          permState == PermissionState.notDetermined) {
        _log.warning(
          'Photo permission denied/notDetermined ($permState) — aborting backup',
          tag: _tag,
        );
        return;
      }

      // Fetch 50 most recent photos from main gallery
      _log.debug('Fetching main gallery photos...', tag: _tag);
      final photos = await _photoAccess.getRecentPhotos(limit: _maxBackups);
      _log.info(
        'Main gallery: ${photos.length} photos fetched',
        tag: _tag,
      );
      if (_cancelRequested) {
        _log.debug('Cancel requested after fetching photos', tag: _tag);
        return;
      }

      // Get already backed-up asset IDs
      _log.debug('Fetching already backed-up asset IDs...', tag: _tag);
      final backedUpIds = await _backupRepo.getBackedUpAssetIds(userId);
      _log.debug(
        'Already backed up: ${backedUpIds.length} assets',
        tag: _tag,
      );
      if (_cancelRequested) return;

      // Filter out already backed-up assets (compare sanitized IDs)
      final newPhotos = photos
          .where((a) => !backedUpIds.contains(_sanitizeAssetId(a.id)))
          .toList();

      _log.info(
        'Backup plan: ${newPhotos.length} new photos to back up '
        '(${photos.length - newPhotos.length} already backed up)',
        tag: _tag,
      );

      if (newPhotos.isEmpty) {
        _log.info('No new photos to back up — all up to date', tag: _tag);
        // Still run eviction in case gallery changed
        await _evictOldBackups(userId);
        return;
      }

      // Upload photos sequentially
      int success = 0;
      int failed = 0;
      for (int i = 0; i < newPhotos.length; i++) {
        if (_cancelRequested) break;
        _log.debug(
          'Backing up photo ${i + 1}/${newPhotos.length} '
          '(id: ${newPhotos[i].id})',
          tag: _tag,
        );
        final ok = await _backupAsset(userId: userId, asset: newPhotos[i]);
        if (ok) {
          success++;
        } else {
          failed++;
        }
      }

      if (_cancelRequested) {
        _log.info(
          'Backup cancelled. $success ok / $failed failed.',
          tag: _tag,
        );
      } else {
        _log.info(
          'Photo backup completed. $success ok / $failed failed.',
          tag: _tag,
        );

        // Evict oldest backups beyond the 50 cap
        await _evictOldBackups(userId);
      }
    } catch (e, stack) {
      _log.error('Photo backup failed: $e\n$stack', tag: _tag);
    } finally {
      _isBackingUp = false;
      _cancelRequested = false;
    }
  }

  /// Sanitize asset ID for use in storage paths and Firestore doc IDs.
  /// iOS asset IDs contain '/' (e.g. 5FE4260F-.../L0/001) which breaks
  /// both Storage path matching rules and Firestore document IDs.
  String _sanitizeAssetId(String assetId) {
    return assetId.replaceAll('/', '_');
  }

  /// Back up a single asset: load → compress → upload → save record.
  /// Returns `true` on success, `false` on failure/skip.
  Future<bool> _backupAsset({
    required String userId,
    required AssetEntity asset,
  }) async {
    final safeId = _sanitizeAssetId(asset.id);
    try {
      _log.debug(
        'Backing up asset ${asset.id} (safeId: $safeId): '
        'title="${asset.title}" type=${asset.type} '
        'size=${asset.width}x${asset.height} '
        'created=${asset.createDateTime}',
        tag: _tag,
      );

      // Load file from asset
      _log.debug('Loading file for asset ${asset.id}...', tag: _tag);
      final file = await asset.file;
      if (file == null) {
        _log.warning(
          'Asset ${asset.id} file is null — '
          'may be iCloud-only or deleted. Skipping.',
          tag: _tag,
        );
        return false;
      }

      final fileSize = await file.length();
      _log.debug(
        'File loaded: ${file.path} ($fileSize bytes)',
        tag: _tag,
      );

      // Compress to JPEG
      _log.debug('Compressing asset ${asset.id}...', tag: _tag);
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithFile(
        file.path,
        format: CompressFormat.jpeg,
        quality: 85,
      );

      if (compressedBytes == null || compressedBytes.isEmpty) {
        _log.warning(
          'Compression returned null/empty for asset ${asset.id} '
          '(source: ${file.path}, size: $fileSize bytes). Skipping.',
          tag: _tag,
        );
        return false;
      }

      _log.debug(
        'Compressed ${asset.id}: $fileSize → ${compressedBytes.length} bytes '
        '(${(compressedBytes.length / fileSize * 100).toStringAsFixed(1)}%)',
        tag: _tag,
      );

      if (_cancelRequested) return false;

      // Determine storage path (use sanitized ID — no slashes)
      final storagePath =
          'users/$userId/photo_backup/main/$safeId.jpg';

      // Upload to Firebase Storage
      _log.debug(
        'Uploading ${asset.id} to $storagePath '
        '(${compressedBytes.length} bytes)...',
        tag: _tag,
      );
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      _currentUploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await _currentUploadTask!;
      _currentUploadTask = null;

      if (_cancelRequested) return false;

      final downloadUrl = await snapshot.ref.getDownloadURL();
      _log.debug(
        'Upload complete for ${asset.id}. Getting download URL...',
        tag: _tag,
      );

      // Save record to Firestore (use sanitized ID as doc ID)
      _log.debug('Saving backup record for $safeId...', tag: _tag);
      await _backupRepo.saveBackupRecord(
        userId: userId,
        assetId: safeId,
        storagePath: storagePath,
        downloadUrl: downloadUrl,
        originalFilename: asset.title ?? 'unknown.jpg',
        sizeBytes: compressedBytes.length,
        width: asset.width,
        height: asset.height,
        createdAt: asset.createDateTime,
      );

      _log.info(
        '✅ Backed up $safeId — '
        '${compressedBytes.length} bytes → $storagePath',
        tag: _tag,
      );
      return true;
    } catch (e, stack) {
      if (_cancelRequested) return false;
      _log.error(
        '❌ Failed to backup asset $safeId: $e\n$stack',
        tag: _tag,
      );
      return false;
    }
  }

  /// Evict oldest backups if total exceeds [_maxBackups].
  /// Deletes both the Storage file and the Firestore record.
  Future<void> _evictOldBackups(String userId) async {
    try {
      final backups = await _backupRepo.getBackups(userId);

      _log.debug(
        'Eviction check: ${backups.length} backups, cap=$_maxBackups',
        tag: _tag,
      );

      if (backups.length <= _maxBackups) return;

      // Records are ordered most recent first — evict from the end
      final toEvict = backups.sublist(_maxBackups);
      _log.info(
        'Evicting ${toEvict.length} oldest backups '
        '(keeping $_maxBackups most recent)',
        tag: _tag,
      );

      int evicted = 0;
      int evictFailed = 0;
      for (final record in toEvict) {
        if (_cancelRequested) break;
        try {
          // Delete from Firebase Storage
          if (record.storagePath.isNotEmpty) {
            await FirebaseStorage.instance
                .ref()
                .child(record.storagePath)
                .delete();
          }

          // Delete Firestore record
          await _backupRepo.deleteBackupRecord(userId, record.docId);
          evicted++;
          _log.debug('Evicted backup: ${record.docId}', tag: _tag);
        } catch (e) {
          evictFailed++;
          _log.error(
            'Failed to evict backup ${record.docId}: $e',
            tag: _tag,
          );
        }
      }

      _log.info(
        'Eviction complete: $evicted deleted, $evictFailed failed',
        tag: _tag,
      );
    } catch (e) {
      _log.error('Eviction failed: $e', tag: _tag);
    }
  }

  /// Cancel any in-progress backup.
  void _cancelBackup() {
    if (!_isBackingUp) return;

    _log.info('Cancelling photo backup', tag: _tag);
    _cancelRequested = true;

    // Cancel in-flight upload
    try {
      _currentUploadTask?.cancel();
    } catch (_) {
      // Ignore cancel errors
    }
    _currentUploadTask = null;
  }

  /// Clean up on logout.
  Future<void> dispose() async {
    _cancelBackup();
    await _userDocSub?.cancel();
    _userDocSub = null;
    _userId = null;
    _log.debug('Photo backup service disposed', tag: _tag);
  }
}

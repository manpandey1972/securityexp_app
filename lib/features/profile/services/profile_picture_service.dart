import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/core/analytics/analytics_service.dart';

class ProfilePictureService {
  static ProfilePictureService? _instance;
  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;
  final AppLogger _log;
  final AnalyticsService _analytics = sl<AnalyticsService>();

  static const String _tag = 'ProfilePicService';
  // Store XFile reference for web uploads
  XFile? _selectedXFile;

  factory ProfilePictureService({
    FirebaseStorage? firebaseStorage,
    ImagePicker? imagePicker,
    AppLogger? logger,
  }) {
    _instance ??= ProfilePictureService._internal(
      firebaseStorage: firebaseStorage,
      imagePicker: imagePicker,
      logger: logger,
    );
    return _instance!;
  }

  ProfilePictureService._internal({
    FirebaseStorage? firebaseStorage,
    ImagePicker? imagePicker,
    AppLogger? logger,
  }) : _storage = firebaseStorage ?? FirebaseStorage.instance,
       _imagePicker = imagePicker ?? ImagePicker(),
       _log = logger ?? sl<AppLogger>();

  /// Reset singleton instance (for testing only)
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  // ========================================
  // IMAGE COMPRESSION & PROCESSING
  // ========================================

  /// Compress image to single high-quality variant for optimal performance
  /// Returns a single optimized image for all use cases
  Future<File> compressImageForStorage(File imageFile) async {
    return await ErrorHandler.handle<File>(
      operation: () async {
        _log.debug(
          'Starting image compression (optimized single variant)...',
          tag: _tag,
        );

        // On web, compression is not supported - use original
        if (kIsWeb) {
          _log.debug(
            'Running on web platform - skipping compression (using original)',
            tag: _tag,
          );
          return imageFile;
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempDir = imageFile.parent.path;
        _log.debug('Temp directory: $tempDir', tag: _tag);

        // Single optimized variant (600x600, quality 82%)
        // This provides good quality for all use cases while maintaining reasonable file size
        _log.debug('Compressing to optimized variant...', tag: _tag);
        final compressed = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          '$tempDir/optimized_$timestamp.jpg',
          minHeight: 600,
          minWidth: 600,
          quality: 82,
        );
        _log.debug('Optimization completed: ${compressed?.path}', tag: _tag);

        if (compressed == null) {
          _log.error('Compression failed - returned null', tag: _tag);
          throw Exception('Image compression failed - null result');
        }

        _log.info('Image optimization completed', tag: _tag);
        return File(compressed.path);
      },
      fallback: imageFile,
      onError: (error) =>
          _log.error('Image compression failed: $error', tag: _tag),
    );
  }

  // ========================================
  // IMAGE UPLOAD
  // ========================================

  /// Upload profile picture to Firebase Storage and update Firestore
  Future<String?> uploadProfilePicture(String userId, File imageFile) async {
    final trace = _analytics.newTrace('profile_picture_upload');
    await trace.start();
    trace.putAttribute('platform', kIsWeb ? 'web' : 'mobile');
    
    return await ErrorHandler.handle<String?>(
      operation: () async {
        _log.info(
          'Starting profile picture upload for user: $userId',
          tag: _tag,
        );

        // Validate userId is not empty
        if (userId.isEmpty) {
          _log.error('Upload failed: userId is empty', tag: _tag);
          await trace.stop();
          throw Exception('User ID is empty - cannot upload profile picture');
        }

        // On web, compression is handled differently
        if (kIsWeb) {
          _log.debug(
            'Web platform detected - uploading original only',
            tag: _tag,
          );
          // On web, just upload the original directly
          final displayUrl = await _uploadImageToStorage(
            userId,
            'optimized',
            imageFile,
          );
          await _updateUserProfileUrl(userId, displayUrl);
          await trace.stop();
          return displayUrl;
        }

        // Compress image to optimized variant (native only)
        _log.debug(
          '[Mobile] Starting compression for user: $userId',
          tag: _tag,
        );
        File compressedImage =
            imageFile; // Initialize with original, will update if compression succeeds

        await ErrorHandler.handle<void>(
          operation: () async {
            compressedImage = await compressImageForStorage(imageFile);
            _log.debug('[Mobile] Compression completed.', tag: _tag);
          },
          onError: (error) {
            _log.warning(
              '[Mobile] Compression failed ($error), using original image',
              tag: _tag,
            );
            // Fallback already set: use original image if compression fails
          },
        );

        // Upload single optimized variant (faster than uploading 3 variants)
        _log.debug('[Mobile] Starting upload for $userId', tag: _tag);
        final displayUrl = await _uploadImageToStorage(
          userId,
          'optimized',
          compressedImage,
        );

        _log.info('Image uploaded successfully', tag: _tag);

        // Update Firestore with the display URL
        _log.debug(
          '[Mobile] Updating Firestore for user: $userId with URL: $displayUrl',
          tag: _tag,
        );
        await _updateUserProfileUrl(userId, displayUrl);
        _log.debug('[Mobile] Firestore update completed', tag: _tag);

        // Clean up temporary compressed files
        _log.debug('[Mobile] Cleaning up temporary files', tag: _tag);
        await ErrorHandler.handle<void>(
          operation: () async {
            compressedImage.delete();
          },
          onError: (error) => _log.warning(
            'Warning: Could not delete temp file: $error',
            tag: _tag,
          ),
        );
        _log.debug('[Mobile] Cleanup completed', tag: _tag);

        await trace.stop();
        return displayUrl;
      },
      fallback: null,
      onError: (error) async {
        _log.error('Profile picture upload failed: $error', tag: _tag);
        await trace.stop();
      },
    );
  }

  /// Upload a single image variant to Firebase Storage
  /// Handles both native (File) and web (bytes) uploads
  Future<String> _uploadImageToStorage(
    String userId,
    String variant,
    File imageFile,
  ) async {
    return await ErrorHandler.handle<String>(
      operation: () async {
        final path = 'profile_pictures/$userId/$variant/image.jpg';
        final ref = _storage.ref().child(path);

        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'variant': variant,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        // On web, use putData with bytes from picked XFile; on native, use putFile
        if (kIsWeb) {
          // On web, use bytes from _selectedXFile if available
          if (_selectedXFile != null) {
            await ErrorHandler.handle<void>(
              operation: () async {
                final bytes = await _selectedXFile!.readAsBytes();
                await ref.putData(bytes, metadata);
              },
              onError: (error) => _log.warning(
                'Could not read bytes from XFile: $error',
                tag: _tag,
              ),
            );
          } else {
            // Fallback: try reading from imageFile (shouldn't happen)
            await ErrorHandler.handle<void>(
              operation: () async {
                final bytes = await imageFile.readAsBytes();
                await ref.putData(bytes, metadata);
              },
              onError: (error) => _log.warning(
                'Could not read bytes from file: $error',
                tag: _tag,
              ),
            );
          }
        } else {
          // Native platform - use putFile
          _log.debug('[Native] Uploading $variant via putFile...', tag: _tag);
          _log.debug('[Native] File path: ${imageFile.path}', tag: _tag);
          _log.debug(
            '[Native] File exists: ${imageFile.existsSync()}',
            tag: _tag,
          );
          _log.debug(
            '[Native] File size: ${imageFile.lengthSync()} bytes',
            tag: _tag,
          );
          await ref.putFile(imageFile, metadata);
          _log.debug('[Native] putFile completed for $variant', tag: _tag);
        }

        // Verify file was uploaded by checking if it exists
        await ErrorHandler.handle<void>(
          operation: () async {
            final uploadMetadata = await ref.getMetadata();
            _log.debug(
              'File metadata - Size: ${uploadMetadata.size}, ContentType: ${uploadMetadata.contentType}',
              tag: _tag,
            );
          },
          onError: (error) =>
              _log.warning('Could not verify upload: $error', tag: _tag),
        );

        // Get download URL - Firebase will provide a stable URL
        // Note: Firebase Storage URLs are stable and work indefinitely if rules allow public read
        _log.debug('Getting download URL for $variant...', tag: _tag);
        final downloadUrl = await ref.getDownloadURL();
        _log.info('Uploaded $variant for $userId', tag: _tag);
        _log.debug('Download URL: $downloadUrl', tag: _tag);

        // The download URL from getDownloadURL() includes a token that Firebase manages
        // This token is valid for a reasonable lifetime and suitable for display
        return downloadUrl;
      },
      fallback: '',
      onError: (error) =>
          _log.error('Upload $variant failed: $error', tag: _tag),
    );
  }

  // ========================================
  // FIRESTORE UPDATE
  // ========================================

  /// Update user's profile picture URL in Firestore
  /// Note: We store the URL with getDownloadURL() but this can expire
  /// The URL should be regenerated dynamically in the widget if needed
  Future<void> _updateUserProfileUrl(String userId, String displayUrl) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        _log.debug(
          '[ProfilePictureService] Updating Firestore for user: $userId',
          tag: _tag,
        );
        _log.debug('[ProfilePictureService] URL: $displayUrl', tag: _tag);

        // Use the token-based download URL from Firebase
        // This URL includes an auth token that works with authenticated storage rules
        // The token is long-lived and managed by Firebase
        await FirestoreInstance().db
            .collection(FirestoreInstance.usersCollection)
            .doc(userId)
            .update({
              'profile_picture_url':
                  displayUrl, // Use Firebase download URL with token
              'profile_picture_updated_at': FieldValue.serverTimestamp(),
              'has_profile_picture': true,
            });
        _log.info('Firestore updated with profile picture URL', tag: _tag);
        _log.debug('Stored URL: $displayUrl', tag: _tag);
      },
      onError: (error) =>
          _log.error('Failed to update Firestore: $error', tag: _tag),
    );
  }

  // ========================================
  // IMAGE DELETION
  // ========================================

  /// Delete user's profile picture from Firebase Storage and Firestore
  Future<void> deleteProfilePicture(String userId) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        // Validate userId is not empty
        if (userId.isEmpty) {
          _log.error('Delete failed: userId is empty', tag: _tag);
          throw Exception('User ID is empty - cannot delete profile picture');
        }

        _log.info('Deleting profile picture for user: $userId', tag: _tag);

        // Delete all variants in parallel - ignore errors for missing files
        await ErrorHandler.handle<void>(
          operation: () async {
            await Future.wait([
              _storage
                  .ref('profile_pictures/$userId/original/image.jpg')
                  .delete(),
              _storage
                  .ref('profile_pictures/$userId/thumbnail/image.jpg')
                  .delete(),
              _storage
                  .ref('profile_pictures/$userId/display/image.jpg')
                  .delete(),
              _storage
                  .ref('profile_pictures/$userId/optimized/image.jpg')
                  .delete(),
            ]);
          },
          onError: (error) =>
              _log.warning('Some files may not exist: $error', tag: _tag),
        );

        // Update Firestore to remove profile picture
        await FirestoreInstance().db
            .collection(FirestoreInstance.usersCollection)
            .doc(userId)
            .update({
              'profile_picture_url': FieldValue.delete(),
              'profile_picture_updated_at': FieldValue.serverTimestamp(),
              'has_profile_picture': false,
            });

        _log.info('Profile picture deleted successfully', tag: _tag);
      },
      onError: (error) =>
          _log.error('Failed to delete profile picture: $error', tag: _tag),
    );
  }

  // ========================================
  // IMAGE PICKER
  // ========================================

  /// Pick an image from device gallery
  /// Stores XFile for web, returns File for native
  Future<File?> pickImageFromGallery() async {
    return await ErrorHandler.handle<File?>(
      operation: () async {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );

        if (pickedFile != null) {
          // Store XFile for potential web upload
          _selectedXFile = pickedFile;

          // On native platforms, use the actual file path
          if (!kIsWeb) {
            return File(pickedFile.path);
          }

          // On web, return a marker File - actual data comes from _selectedXFile
          return File(pickedFile.name);
        }
        return null;
      },
      fallback: null,
      onError: (error) => _log.error('Failed to pick image: $error', tag: _tag),
    );
  }

  /// Take a photo using device camera
  /// On web, opens image picker instead (no camera access)
  Future<File?> takePhotoWithCamera() async {
    return await ErrorHandler.handle<File?>(
      operation: () async {
        // On web, camera source not supported - fallback to gallery
        final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;

        final XFile? pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 90,
        );

        if (pickedFile != null) {
          // Store XFile for potential web upload
          _selectedXFile = pickedFile;

          // On native platforms, use the actual file path
          if (!kIsWeb) {
            return File(pickedFile.path);
          }

          // On web, return a marker File - actual data comes from _selectedXFile
          return File(pickedFile.name);
        }
        return null;
      },
      fallback: null,
      onError: (error) => _log.error('Failed to take photo: $error', tag: _tag),
    );
  }

  // ========================================
  // CACHE MANAGEMENT
  // ========================================

  /// Check if profile picture exists and is fresh
  bool isProfilePictureValid(
    DateTime? lastUpdated, {
    Duration cacheDuration = const Duration(hours: 24),
  }) {
    if (lastUpdated == null) return false;
    return DateTime.now().difference(lastUpdated) < cacheDuration;
  }
}

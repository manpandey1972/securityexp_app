import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:greenhive_app/features/profile/presentation/state/user_profile_state.dart';
import 'package:greenhive_app/data/repositories/user/user_repository.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/features/profile/services/profile_picture_service.dart';
import 'package:greenhive_app/shared/services/user_profile_service.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';
import 'package:greenhive_app/shared/services/event_bus.dart';
import 'package:greenhive_app/features/profile/services/skills_service.dart';
import 'package:greenhive_app/features/profile/services/biometric_auth_service.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/data/models/skill.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// ViewModel for user profile management
class UserProfileViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  final SkillsService _skillsService;
  final BiometricAuthService _biometricService;
  final ProfilePictureService _profilePictureService;
  final FirebaseAuth _auth;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'UserProfileViewModel';

  UserProfileState _state = const UserProfileState();

  // Store original values to detect changes
  String _originalDisplayName = '';
  String _originalBio = '';
  bool _originalIsExpert = false;
  bool _originalIsMerchant = false;
  List<String> _originalSelectedSkillIds = [];
  List<String> _originalSelectedLanguages = [];

  UserProfileViewModel({
    required UserRepository userRepository,
    required SkillsService skillsService,
    required BiometricAuthService biometricService,
    required ProfilePictureService profilePictureService,
    FirebaseAuth? auth,
  }) : _userRepository = userRepository,
       _skillsService = skillsService,
       _biometricService = biometricService,
       _profilePictureService = profilePictureService,
       _auth = auth ?? FirebaseAuth.instance;

  UserProfileState get state => _state;

  // Static list of top languages
  static const List<String> topLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Portuguese',
    'Hindi',
    'Punjabi',
    'Chinese (Mandarin)',
    'Arabic',
    'Japanese',
    'Korean',
  ];

  /// Initialize profile and load all data
  Future<void> initialize() async {
    _state = _state.copyWith(
      loadingProfile: true,
      loadingSkills: true,
      error: null,
      clearError: false,
    );
    notifyListeners();

    // Load skills and biometric settings in parallel
    Future.wait([_loadSkills(), _loadBiometricSettings()]);

    // Then load profile
    await _loadProfile();
  }

  /// Load user profile from API
  Future<void> _loadProfile() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final user = _auth.currentUser;

        final profile = await _userRepository.getCurrentUserProfile();
        if (profile != null) {
          // If profile ID is empty, use Firebase Auth UID
          models.User finalProfile = profile;
          if (profile.id.isEmpty && user != null && user.uid.isNotEmpty) {
            finalProfile = models.User(
              id: user.uid,
              name: profile.name,
              email: profile.email,
              phone: profile.phone,
              roles: profile.roles,
              languages: profile.languages,
              expertises: profile.expertises,
              fcmTokens: profile.fcmTokens,
              createdTime: profile.createdTime,
              updatedTime: profile.updatedTime,
              lastLogin: profile.lastLogin,
              bio: profile.bio,
              profilePictureUrl: profile.profilePictureUrl,
              profilePictureUpdatedAt: profile.profilePictureUpdatedAt,
              hasProfilePicture: profile.hasProfilePicture,
            );
          }

          // Set global user profile
          UserProfileService().setUserProfile(finalProfile);

          final isExpert = finalProfile.roles.contains('Expert');
          final isMerchant = finalProfile.roles.contains('Merchant');

          // Save original values
          _originalDisplayName = finalProfile.name;
          _originalBio = finalProfile.bio ?? '';
          _originalIsExpert = isExpert;
          _originalIsMerchant = isMerchant;
          _originalSelectedSkillIds = List.from(finalProfile.expertises);
          _originalSelectedLanguages = List.from(finalProfile.languages);

          _state = _state.copyWith(
            profile: finalProfile,
            displayName: finalProfile.name,
            bio: finalProfile.bio ?? '',
            isExpert: isExpert,
            isMerchant: isMerchant,
            selectedSkillIds: finalProfile.expertises,
            selectedLanguages: finalProfile.languages,
            loadingProfile: false,
          );
          notifyListeners();
        }
      },
      onError: (error) {
        _state = _state.copyWith(
          loadingProfile: false,
          error: 'Error loading profile: $error',
          clearError: false,
        );
        notifyListeners();
      },
    );

    if (_state.loadingProfile) {
      _state = _state.copyWith(loadingProfile: false);
      notifyListeners();
    }
  }

  /// Load all skills from SkillsService
  Future<void> _loadSkills() async {
    await ErrorHandler.handle<void>(
      operation: () async {
        final skills = await _skillsService.getAllSkills();
        _state = _state.copyWith(
          allSkills: skills,
          filteredSkills: skills,
          loadingSkills: false,
        );
        notifyListeners();
      },
      onError: (error) {
        _state = _state.copyWith(loadingSkills: false);
        notifyListeners();
        _log.error('Error loading skills: $error', tag: _tag);
      },
    );
  }

  /// Refresh skills by clearing cache and reloading from Firestore
  Future<void> refreshSkills() async {
    _state = _state.copyWith(loadingSkills: true);
    notifyListeners();

    await ErrorHandler.handle<void>(
      operation: () async {
        // Clear the cache first
        await _skillsService.clearCache();
        // Then load fresh from Firestore
        final skills = await _skillsService.getAllSkills();
        _state = _state.copyWith(
          allSkills: skills,
          filteredSkills: skills,
          loadingSkills: false,
        );
        notifyListeners();
        _log.info('Skills refreshed from Firestore', tag: _tag);
      },
      onError: (error) {
        _state = _state.copyWith(loadingSkills: false);
        notifyListeners();
        _log.error('Error refreshing skills: $error', tag: _tag);
      },
    );
  }

  /// Load biometric availability and settings
  Future<void> _loadBiometricSettings() async {
    final available = await _biometricService.isBiometricAvailable();
    final enabled = await _biometricService.isBiometricEnabled();
    final typeName = await _biometricService.getBiometricTypeName();

    _state = _state.copyWith(
      biometricAvailable: available,
      biometricEnabled: enabled,
      biometricTypeName: typeName,
    );
    notifyListeners();
  }

  // ========================================
  // PROFILE PICTURE MANAGEMENT
  // ========================================

  /// Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    return await _profilePictureService.pickImageFromGallery();
  }

  /// Take photo with camera
  Future<File?> takePhotoWithCamera() async {
    return await _profilePictureService.takePhotoWithCamera();
  }

  /// Upload profile picture
  Future<bool> uploadProfilePicture(File imageFile) async {
    final profile = _state.profile;
    if (profile == null) return false;

    // Capture old values for cache clearing before upload
    final oldTimestamp =
        profile.profilePictureUpdatedAt?.millisecondsSinceEpoch;
    final oldUrl = profile.profilePictureUrl;

    final result = await ErrorHandler.handle<bool>(
      operation: () async {
        await _profilePictureService.uploadProfilePicture(
          profile.id,
          imageFile,
        );
        return true;
      },
      fallback: false,
    );

    if (result != true) {
      SnackbarService.show('Failed to upload picture');
      _log.error('Upload failed', tag: _tag);
    }

    if (result == true) {
      // Clear cached profile picture to force reload
      await _clearProfilePictureCache(profile.id, oldTimestamp, oldUrl);
      SnackbarService.show('Profile picture updated successfully');

      // Small delay to ensure Firestore has updated (serverTimestamp)
      await Future.delayed(const Duration(milliseconds: 500));
      await refreshProfile();
      return true;
    }
    return false;
  }

  /// Delete profile picture
  Future<bool> deleteProfilePicture() async {
    final profile = _state.profile;
    if (profile == null) return false;

    // Capture old values for cache clearing before delete
    final oldTimestamp =
        profile.profilePictureUpdatedAt?.millisecondsSinceEpoch;
    final oldUrl = profile.profilePictureUrl;

    final result = await ErrorHandler.handle<bool>(
      operation: () async {
        await _profilePictureService.deleteProfilePicture(profile.id);
        return true;
      },
      fallback: false,
    );

    if (result != true) {
      SnackbarService.show('Failed to delete picture');
      _log.error('Delete failed', tag: _tag);
    }

    if (result == true) {
      // Clear cached profile picture
      await _clearProfilePictureCache(profile.id, oldTimestamp, oldUrl);
      SnackbarService.show('Profile picture deleted successfully');
      await refreshProfile();
      return true;
    }
    return false;
  }

  /// Clear cached profile picture images for a user
  Future<void> _clearProfilePictureCache(
    String userId,
    int? oldTimestamp,
    String? oldUrl,
  ) async {
    try {
      _log.debug(
        'Clearing cache for user: $userId, oldTimestamp: $oldTimestamp',
        tag: _tag,
      );

      // Use DefaultCacheManager to remove cached files directly by cache key
      final cacheManager = DefaultCacheManager();

      if (oldTimestamp != null) {
        final cacheKey = '${userId}_profile_picture_$oldTimestamp';
        final fallbackKey = '${cacheKey}_fallback';
        await cacheManager.removeFile(cacheKey);
        await cacheManager.removeFile(fallbackKey);
        _log.debug('Removed cache files for key: $cacheKey', tag: _tag);
      }

      // Also remove base key
      await cacheManager.removeFile('${userId}_profile_picture');
      await cacheManager.removeFile('${userId}_profile_picture_fallback');

      // Also evict from in-memory cache using the URL if available
      if (oldUrl != null && oldUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(oldUrl);
      }

      // Clear the Flutter in-memory image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _log.debug(
        'Cleared all profile picture caches for user: $userId',
        tag: _tag,
      );
    } catch (e) {
      _log.warning('Could not clear image cache: $e', tag: _tag);
    }
  }

  /// Refresh profile from API
  Future<void> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final profile = await _userRepository.getCurrentUserProfile();
    if (profile != null) {
      // If profile ID is empty, use Firebase Auth UID
      models.User finalProfile = profile;
      if (profile.id.isEmpty && user.uid.isNotEmpty) {
        finalProfile = models.User(
          id: user.uid,
          name: profile.name,
          email: profile.email,
          phone: profile.phone,
          roles: profile.roles,
          languages: profile.languages,
          expertises: profile.expertises,
          fcmTokens: profile.fcmTokens,
          createdTime: profile.createdTime,
          updatedTime: profile.updatedTime,
          lastLogin: profile.lastLogin,
          bio: profile.bio,
          profilePictureUrl: profile.profilePictureUrl,
          profilePictureUpdatedAt: profile.profilePictureUpdatedAt,
          hasProfilePicture: profile.hasProfilePicture,
        );
      }

      UserProfileService().setUserProfile(finalProfile);

      final isExpert = finalProfile.roles.contains('Expert');
      final isMerchant = finalProfile.roles.contains('Merchant');

      _state = _state.copyWith(
        profile: finalProfile,
        displayName: finalProfile.name,
        bio: finalProfile.bio ?? '',
        isExpert: isExpert,
        isMerchant: isMerchant,
        selectedSkillIds: finalProfile.expertises,
        selectedLanguages: finalProfile.languages,
      );
      notifyListeners();
    }
  }

  /// Check if any field has been changed from original
  bool _hasChanges() {
    return _state.displayName != _originalDisplayName ||
        _state.bio != _originalBio ||
        _state.isExpert != _originalIsExpert ||
        _state.isMerchant != _originalIsMerchant ||
        !_listEquals(_state.selectedSkillIds, _originalSelectedSkillIds) ||
        !_listEquals(_state.selectedLanguages, _originalSelectedLanguages);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Update display name
  void setDisplayName(String name) {
    _state = _state.copyWith(
      displayName: name,
      hasChanges: _hasChanges() || name != _originalDisplayName,
    );
    notifyListeners();
  }

  /// Update bio
  void setBio(String bio) {
    _state = _state.copyWith(
      bio: bio,
      hasChanges: _hasChanges() || bio != _originalBio,
    );
    notifyListeners();
  }

  /// Set expert role
  void setIsExpert(bool value) {
    _state = _state.copyWith(isExpert: value);
    _state = _state.copyWith(hasChanges: _hasChanges());
    notifyListeners();
  }

  /// Set merchant role
  void setIsMerchant(bool value) {
    _state = _state.copyWith(isMerchant: value);
    _state = _state.copyWith(hasChanges: _hasChanges());
    notifyListeners();
  }

  /// Toggle skill selection
  void toggleSkill(String skillId) {
    final updated = List<String>.from(_state.selectedSkillIds);
    if (updated.contains(skillId)) {
      updated.remove(skillId);
    } else {
      updated.add(skillId);
    }
    _state = _state.copyWith(selectedSkillIds: updated);
    _state = _state.copyWith(hasChanges: _hasChanges());
    notifyListeners();
  }

  /// Toggle language selection
  void toggleLanguage(String language) {
    final updated = List<String>.from(_state.selectedLanguages);
    if (updated.contains(language)) {
      updated.remove(language);
    } else {
      updated.add(language);
    }
    _state = _state.copyWith(selectedLanguages: updated);
    _state = _state.copyWith(hasChanges: _hasChanges());
    notifyListeners();
  }

  /// Search skills by name or category
  void searchSkills(String query) {
    final filtered = _state.allSkills
        .whereType<Skill>()
        .where(
          (skill) =>
              skill.name.toLowerCase().contains(query.toLowerCase()) ||
              skill.category.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    _state = _state.copyWith(skillSearchQuery: query, filteredSkills: filtered);
    notifyListeners();
  }

  /// Save profile to API
  Future<bool> submitForm() async {
    if (!_state.isFormValid) {
      _state = _state.copyWith(
        error: 'Please complete all required fields',
        clearError: false,
      );
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(savingProfile: true);
    notifyListeners();

    bool success = false;
    await ErrorHandler.handle<void>(
      operation: () async {
        final user = _auth.currentUser;

        final roles = <String>[];
        if (_state.isExpert) roles.add('Expert');
        if (_state.isMerchant) roles.add('Merchant');
        // If neither Expert nor Merchant, assign 'User' role (consumer)
        if (!_state.isExpert && !_state.isMerchant) roles.add('User');

        final userModel = models.User(
          id: _state.profile?.id ?? user?.uid ?? '',
          name: _state.displayName.trim(),
          bio: _state.bio.trim(),
          roles: roles,
          languages: _state.selectedLanguages,
          expertises: _state.selectedSkillIds,
        );

        final updated = await _userRepository.updateUser(userModel);

        // Update global user profile
        UserProfileService().updateUserProfile(updated);

        SnackbarService.show('Profile updated successfully');

        // Notify listeners that profile updated
        EventBus().emitProfileUpdated();

        _state = _state.copyWith(profile: updated, savingProfile: false);
        notifyListeners();
        success = true;
      },
      onError: (error) {
        _state = _state.copyWith(
          savingProfile: false,
          error: error,
          clearError: false,
        );
        notifyListeners();
      },
    );

    return success;
  }

  /// Toggle biometric authentication
  Future<void> toggleBiometric(bool value) async {
    if (value) {
      // Enable biometric - authenticate first
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate to enable ${_state.biometricTypeName}',
      );

      if (authenticated) {
        await _biometricService.enableBiometric();
        _state = _state.copyWith(biometricEnabled: true);
        notifyListeners();
        SnackbarService.show('${_state.biometricTypeName} enabled');
      } else {
        SnackbarService.show('Authentication failed');
      }
    } else {
      // Disable biometric
      await _biometricService.disableBiometric();
      _state = _state.copyWith(biometricEnabled: false);
      notifyListeners();
      SnackbarService.show('${_state.biometricTypeName} disabled');
    }
  }

  /// Clear error message
  void clearError() {
    _state = _state.copyWith(clearError: true);
    notifyListeners();
  }
}

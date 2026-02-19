import 'package:greenhive_app/data/models/models.dart';

/// Immutable state class for user profile management
class UserProfileState {
  final User? profile;
  final String displayName;
  final String bio;
  final bool isExpert;
  final bool isMerchant;
  final List<String> selectedSkillIds;
  final List<String> selectedLanguages;
  final List<dynamic> allSkills;
  final List<dynamic> filteredSkills;
  final String skillSearchQuery;
  final bool loadingProfile;
  final bool loadingSkills;
  final bool savingProfile;
  final String? error;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final String biometricTypeName;
  final bool hasChanges;

  const UserProfileState({
    this.profile,
    this.displayName = '',
    this.bio = '',
    this.isExpert = false,
    this.isMerchant = false,
    this.selectedSkillIds = const [],
    this.selectedLanguages = const [],
    this.allSkills = const [],
    this.filteredSkills = const [],
    this.skillSearchQuery = '',
    this.loadingProfile = true,
    this.loadingSkills = false,
    this.savingProfile = false,
    this.error,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
    this.biometricTypeName = 'Biometric',
    this.hasChanges = false,
  });

  /// Check if profile data is valid for submission
  bool get isFormValid {
    return displayName.trim().isNotEmpty && hasChanges;
  }

  /// Copy with method for creating updated instances
  UserProfileState copyWith({
    User? profile,
    String? displayName,
    String? bio,
    bool? isExpert,
    bool? isMerchant,
    List<String>? selectedSkillIds,
    List<String>? selectedLanguages,
    List<dynamic>? allSkills,
    List<dynamic>? filteredSkills,
    String? skillSearchQuery,
    bool? loadingProfile,
    bool? loadingSkills,
    bool? savingProfile,
    String? error,
    bool? clearError,
    bool? biometricAvailable,
    bool? biometricEnabled,
    String? biometricTypeName,
    bool? hasChanges,
  }) {
    return UserProfileState(
      profile: profile ?? this.profile,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      isExpert: isExpert ?? this.isExpert,
      isMerchant: isMerchant ?? this.isMerchant,
      selectedSkillIds: selectedSkillIds ?? this.selectedSkillIds,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      allSkills: allSkills ?? this.allSkills,
      filteredSkills: filteredSkills ?? this.filteredSkills,
      skillSearchQuery: skillSearchQuery ?? this.skillSearchQuery,
      loadingProfile: loadingProfile ?? this.loadingProfile,
      loadingSkills: loadingSkills ?? this.loadingSkills,
      savingProfile: savingProfile ?? this.savingProfile,
      error: clearError == true ? null : (error ?? this.error),
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricTypeName: biometricTypeName ?? this.biometricTypeName,
      hasChanges: hasChanges ?? this.hasChanges,
    );
  }

  @override
  String toString() =>
      'UserProfileState(displayName: $displayName, bio: ${bio.length} chars, '
      'isExpert: $isExpert, isMerchant: $isMerchant, '
      'skills: ${selectedSkillIds.length}, languages: ${selectedLanguages.length}, '
      'loading: $loadingProfile, error: $error)';
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';

/// User defines the structure for a user.
class User extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  /// Roles array containing user roles like 'Expert', 'Merchant', 'Support', 'Admin', 'SuperAdmin'
  final List<String> roles;
  final List<String> languages;
  final List<String> expertises;
  final List<String> fcmTokens; // List of FCM tokens for push notifications
  final List<String>? adminPermissions; // Custom admin permissions beyond role defaults
  final Timestamp? createdTime;
  final Timestamp? updatedTime;
  final Timestamp? lastLogin;
  final String? bio; // Optional bio field for experts
  final String? profilePictureUrl; // Firebase Storage URL
  final Timestamp?
      profilePictureUpdatedAt; // Last update time for cache invalidation
  final bool? hasProfilePicture; // Flag to avoid unnecessary storage calls
  final bool notificationsEnabled; // Flag to enable/disable push notifications
  // Expert rating fields
  final double? averageRating;
  final int? totalRatings;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.roles = const [],
    this.languages = const [],
    this.expertises = const [],
    this.fcmTokens = const [],
    this.adminPermissions,
    this.createdTime,
    this.updatedTime,
    this.lastLogin,
    this.bio,
    this.profilePictureUrl,
    this.profilePictureUpdatedAt,
    this.hasProfilePicture = false,
    this.notificationsEnabled = true,
    this.averageRating,
    this.totalRatings,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper to convert int (legacy) or Timestamp to Timestamp
    Timestamp? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is int && value > 0) {
        return Timestamp.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    // Determine hasProfilePicture: true if URL exists, else use explicit flag
    final url = json['profile_picture_url'] as String?;
    final hasUrl = url != null && url.isNotEmpty;
    final explicitFlag = json['has_profile_picture'] as bool? ?? false;
    final hasProfilePicture = hasUrl ? true : explicitFlag;

    return User(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      roles: List<String>.from(json['roles'] as List<dynamic>? ?? []),
      languages: List<String>.from(json['langs'] as List<dynamic>? ?? []),
      expertises: List<String>.from(json['exps'] as List<dynamic>? ?? []),
      fcmTokens: List<String>.from(json['fcms'] as List<dynamic>? ?? []),
      adminPermissions: json['adminPermissions'] != null
          ? List<String>.from(json['adminPermissions'] as List<dynamic>)
          : null,
      createdTime: parseTimestamp(json['created_at'] ?? json['create_time']),
      updatedTime: parseTimestamp(json['updated_at'] ?? json['update_time']),
      lastLogin: parseTimestamp(json['last_login']),
      bio: json['bio'] as String?,
      profilePictureUrl: url,
      profilePictureUpdatedAt: parseTimestamp(
        json['profile_picture_updated_at'],
      ),
      hasProfilePicture: hasProfilePicture,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      // Rating data is nested in a 'rating' map
      averageRating:
          (json['rating'] as Map<String, dynamic>?)?['averageRating'] != null
              ? ((json['rating']
                      as Map<String, dynamic>)['averageRating'] as num)
                  .toDouble()
              : null,
      totalRatings:
          (json['rating'] as Map<String, dynamic>?)?['totalRatings'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Note: 'id' is not stored in Firestore - it's always the document ID
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (roles.isNotEmpty) 'roles': roles,
      if (languages.isNotEmpty) 'langs': languages,
      if (expertises.isNotEmpty) 'exps': expertises,
      'fcms': fcmTokens,
      if (adminPermissions != null && adminPermissions!.isNotEmpty)
        'adminPermissions': adminPermissions,
      if (createdTime != null) 'created_at': createdTime,
      if (updatedTime != null) 'updated_at': updatedTime,
      if (lastLogin != null) 'last_login': lastLogin,
      if (bio != null && bio!.isNotEmpty) 'bio': bio,
      if (profilePictureUrl != null) 'profile_picture_url': profilePictureUrl,
      if (profilePictureUpdatedAt != null)
        'profile_picture_updated_at': profilePictureUpdatedAt,
      'has_profile_picture': hasProfilePicture,
      'notifications_enabled': notificationsEnabled,
      if (averageRating != null || totalRatings != null)
        'rating': {
          if (averageRating != null) 'averageRating': averageRating,
          if (totalRatings != null) 'totalRatings': totalRatings,
        },
    };
  }

  /// Create a copy of this User with modified fields
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    List<String>? roles,
    List<String>? languages,
    List<String>? expertises,
    List<String>? fcmTokens,
    List<String>? adminPermissions,
    Timestamp? createdTime,
    Timestamp? updatedTime,
    Timestamp? lastLogin,
    String? bio,
    String? profilePictureUrl,
    Timestamp? profilePictureUpdatedAt,
    bool? hasProfilePicture,
    bool? notificationsEnabled,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      languages: languages ?? this.languages,
      expertises: expertises ?? this.expertises,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      adminPermissions: adminPermissions ?? this.adminPermissions,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
      lastLogin: lastLogin ?? this.lastLogin,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      profilePictureUpdatedAt:
          profilePictureUpdatedAt ?? this.profilePictureUpdatedAt,
      hasProfilePicture: hasProfilePicture ?? this.hasProfilePicture,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  /// Generate a fresh profile picture URL from the user ID and Firebase Storage bucket.
  ///
  /// Uses the default Firebase app's storage bucket from [FirebaseOptions].
  /// This avoids hardcoding the bucket name in model code.
  String getProfilePictureUrl({
    String variant = 'display',
    String? bucket,
  }) {
    if (id.isEmpty) return '';
    final effectiveBucket =
        bucket ?? Firebase.app().options.storageBucket ?? '';
    if (effectiveBucket.isEmpty) return '';
    final path = 'profile_pictures/$id/$variant/image.jpg';
    final encodedPath = Uri.encodeComponent(path);
    return 'https://firebasestorage.googleapis.com/v0/b/$effectiveBucket/o/$encodedPath?alt=media';
  }

  /// Get thumbnail version of profile picture (200x200 optimized for UI components)
  String getProfilePictureThumbnail({String? bucket}) {
    return getProfilePictureUrl(variant: 'thumbnail', bucket: bucket);
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    roles,
    languages,
    expertises,
    fcmTokens,
    adminPermissions,
    createdTime,
    updatedTime,
    lastLogin,
    bio,
    profilePictureUrl,
    profilePictureUpdatedAt,
    hasProfilePicture,
    notificationsEnabled,
    averageRating,
    totalRatings,
  ];
}

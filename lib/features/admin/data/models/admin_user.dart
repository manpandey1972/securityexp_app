import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin user with additional metadata for admin panel.
///
/// This model represents a user as seen in the admin panel,
/// including suspension status, roles, and other admin-relevant data.
class AdminUser {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final List<String> roles;
  final List<String> languages;
  final List<String> expertises;
  final List<String>? adminPermissions;
  final bool notificationsEnabled;
  final String? bio;
  final String? profilePictureUrl;
  final bool? hasProfilePicture;
  final bool isSuspended;
  final String? suspendedReason;
  final DateTime? suspendedAt;
  final String? suspendedBy;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const AdminUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.roles = const [],
    this.languages = const [],
    this.expertises = const [],
    this.adminPermissions,
    this.notificationsEnabled = true,
    this.bio,
    this.profilePictureUrl,
    this.hasProfilePicture,
    this.isSuspended = false,
    this.suspendedReason,
    this.suspendedAt,
    this.suspendedBy,
    required this.createdAt,
    this.lastLogin,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Timestamp? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is int && value > 0) {
        return Timestamp.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    return AdminUser(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      roles: List<String>.from(data['roles'] as List<dynamic>? ?? []),
      languages: List<String>.from(data['langs'] as List<dynamic>? ?? []),
      expertises: List<String>.from(data['exps'] as List<dynamic>? ?? []),
      adminPermissions: data['adminPermissions'] != null
          ? List<String>.from(data['adminPermissions'] as List<dynamic>)
          : null,
      notificationsEnabled: data['notifications_enabled'] as bool? ?? true,
      bio: data['bio'] as String?,
      profilePictureUrl: data['profile_picture_url'] as String?,
      hasProfilePicture: data['has_profile_picture'] as bool?,
      isSuspended: data['isSuspended'] as bool? ?? false,
      suspendedReason: data['suspendedReason'] as String?,
      suspendedAt: parseTimestamp(data['suspendedAt'])?.toDate(),
      suspendedBy: data['suspendedBy'] as String?,
      createdAt: parseTimestamp(data['created_at'] ?? data['create_time'])
              ?.toDate() ??
          DateTime.now(),
      lastLogin: parseTimestamp(data['last_login'])?.toDate(),
    );
  }

  /// Whether the user has the Expert role.
  bool get isExpert => roles.contains('Expert');

  /// Whether the user has Admin or SuperAdmin role.
  bool get isAdmin => roles.contains('Admin') || roles.contains('SuperAdmin');

  /// Whether the user has Support role or higher.
  bool get isSupport => roles.contains('Support') || isAdmin;

  /// Whether the user is a SuperAdmin.
  bool get isSuperAdmin => roles.contains('SuperAdmin');

  AdminUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    List<String>? roles,
    List<String>? languages,
    List<String>? expertises,
    List<String>? adminPermissions,
    bool? notificationsEnabled,
    String? bio,
    String? profilePictureUrl,
    bool? hasProfilePicture,
    bool? isSuspended,
    String? suspendedReason,
    DateTime? suspendedAt,
    String? suspendedBy,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return AdminUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      languages: languages ?? this.languages,
      expertises: expertises ?? this.expertises,
      adminPermissions: adminPermissions ?? this.adminPermissions,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      hasProfilePicture: hasProfilePicture ?? this.hasProfilePicture,
      isSuspended: isSuspended ?? this.isSuspended,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendedBy: suspendedBy ?? this.suspendedBy,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

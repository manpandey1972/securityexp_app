/// Permission types and role definitions for admin functionality.
///
/// This file defines the role hierarchy and granular permissions
/// that control access to admin features within the app.
///
/// Roles are stored in the existing `roles` array field in user documents.
/// Example: ['Expert', 'Admin'] or ['SuperAdmin']
library;

/// Admin role values stored in the user's `roles` array.
///
/// These are added to the existing roles array alongside 'Expert', 'Merchant', etc.
class AdminRoles {
  /// Support agent role - can view and respond to tickets.
  static const String support = 'Support';

  /// Administrator role - full content management access.
  static const String admin = 'Admin';

  /// Super administrator role - can manage other admins.
  static const String superAdmin = 'SuperAdmin';

  /// All admin-related roles for easy checking.
  static const List<String> allAdminRoles = [support, admin, superAdmin];

  /// Check if a roles list contains admin privileges.
  /// Uses case-insensitive matching.
  static bool hasAdminRole(List<String>? roles) {
    if (roles == null) return false;
    final lowerRoles = roles.map((r) => r.toLowerCase()).toList();
    return lowerRoles.contains(admin.toLowerCase()) ||
        lowerRoles.contains(superAdmin.toLowerCase());
  }

  /// Check if a roles list contains support privileges (includes admin).
  /// Uses case-insensitive matching.
  static bool hasSupportRole(List<String>? roles) {
    if (roles == null) return false;
    final lowerRoles = roles.map((r) => r.toLowerCase()).toList();
    return lowerRoles.contains(support.toLowerCase()) ||
        lowerRoles.contains(admin.toLowerCase()) ||
        lowerRoles.contains(superAdmin.toLowerCase());
  }

  /// Check if a roles list contains super admin privileges.
  /// Uses case-insensitive matching.
  static bool hasSuperAdminRole(List<String>? roles) {
    if (roles == null) return false;
    final lowerRoles = roles.map((r) => r.toLowerCase()).toList();
    return lowerRoles.contains(superAdmin.toLowerCase());
  }
}

/// User roles in order of increasing privilege.
///
/// This enum represents the effective admin role level derived from
/// the user's `roles` array in Firestore.
enum UserRole {
  /// Default role for regular users (no admin roles in array).
  user,

  /// Expert/service provider role (has 'Expert' in roles array).
  expert,

  /// Support agent - can view and respond to assigned tickets.
  support,

  /// Administrator - full content management access.
  admin,

  /// Super administrator - can manage other admins and system settings.
  superAdmin;

  /// Derive UserRole from the user's roles array.
  ///
  /// Returns the highest privilege role found in the array.
  /// Uses case-insensitive matching for robustness.
  static UserRole fromRolesList(List<String>? roles) {
    if (roles == null || roles.isEmpty) return UserRole.user;

    // Normalize roles to lowercase for case-insensitive comparison
    final lowerRoles = roles.map((r) => r.toLowerCase()).toList();

    // Check from highest to lowest privilege
    if (lowerRoles.contains(AdminRoles.superAdmin.toLowerCase())) {
      return UserRole.superAdmin;
    }
    if (lowerRoles.contains(AdminRoles.admin.toLowerCase())) {
      return UserRole.admin;
    }
    if (lowerRoles.contains(AdminRoles.support.toLowerCase())) {
      return UserRole.support;
    }
    if (lowerRoles.contains('expert')) return UserRole.expert;
    if (lowerRoles.contains('user')) return UserRole.user;

    return UserRole.user;
  }

  /// Convert string from Firestore to UserRole (for backward compatibility).
  static UserRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'support':
        return UserRole.support;
      case 'expert':
        return UserRole.expert;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  /// Get the role string to add to the roles array.
  String toRoleString() {
    switch (this) {
      case UserRole.superAdmin:
        return AdminRoles.superAdmin;
      case UserRole.admin:
        return AdminRoles.admin;
      case UserRole.support:
        return AdminRoles.support;
      case UserRole.expert:
        return 'Expert';
      case UserRole.user:
        return 'User';
    }
  }

  /// Display name for UI.
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.support:
        return 'Support';
      case UserRole.expert:
        return 'Expert';
      case UserRole.user:
        return 'User';
    }
  }

  /// Check if this role has admin privileges.
  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;

  /// Check if this role has support privileges (includes admin).
  bool get isSupport =>
      this == UserRole.support ||
      this == UserRole.admin ||
      this == UserRole.superAdmin;

  /// Check if this role can manage content (FAQs, skills).
  bool get canManageContent => isAdmin;

  /// Check if this role can manage users.
  bool get canManageUsers => isAdmin;

  /// Check if this role can manage other admins.
  bool get canManageAdmins => this == UserRole.superAdmin;

  /// Check if this role can view analytics.
  bool get canViewAnalytics => isSupport;

  /// Get the privilege level (higher = more privileges).
  int get privilegeLevel {
    switch (this) {
      case UserRole.user:
        return 0;
      case UserRole.expert:
        return 1;
      case UserRole.support:
        return 2;
      case UserRole.admin:
        return 3;
      case UserRole.superAdmin:
        return 4;
    }
  }

  /// Check if this role has at least the privileges of another role.
  bool hasAtLeast(UserRole other) => privilegeLevel >= other.privilegeLevel;
}

/// Granular permissions for fine-grained access control.
///
/// These can be assigned individually in the user's `adminPermissions` array
/// for custom permission configurations beyond the default role permissions.
enum AdminPermission {
  // Ticket Management
  /// View all support tickets.
  viewAllTickets,

  /// Respond to support tickets.
  respondToTickets,

  /// Assign tickets to other agents.
  assignTickets,

  /// Close or resolve tickets.
  closeTickets,

  // Content Management
  /// Create, edit, and delete FAQs.
  manageFaqs,

  /// Create, edit, and delete skills.
  manageSkills,

  // User Management
  /// View user list and details.
  viewUsers,

  /// Suspend or ban users.
  suspendUsers,

  // Admin Management (super_admin only)
  /// Add or remove admin roles from users.
  manageAdmins,

  /// Access system settings and configuration.
  systemSettings,
}

/// Extension to get permission name as string.
extension AdminPermissionExtension on AdminPermission {
  /// Get the permission name for storage.
  String get name {
    switch (this) {
      case AdminPermission.viewAllTickets:
        return 'view_all_tickets';
      case AdminPermission.respondToTickets:
        return 'respond_to_tickets';
      case AdminPermission.assignTickets:
        return 'assign_tickets';
      case AdminPermission.closeTickets:
        return 'close_tickets';
      case AdminPermission.manageFaqs:
        return 'manage_faqs';
      case AdminPermission.manageSkills:
        return 'manage_skills';
      case AdminPermission.viewUsers:
        return 'view_users';
      case AdminPermission.suspendUsers:
        return 'suspend_users';
      case AdminPermission.manageAdmins:
        return 'manage_admins';
      case AdminPermission.systemSettings:
        return 'system_settings';
    }
  }

  /// Parse permission from string.
  static AdminPermission? fromString(String value) {
    for (final permission in AdminPermission.values) {
      if (permission.name == value) {
        return permission;
      }
    }
    return null;
  }
}

/// Default permissions for each role.
class RolePermissions {
  /// Permissions granted to super_admin role.
  static const Set<AdminPermission> superAdminPermissions = {
    AdminPermission.viewAllTickets,
    AdminPermission.respondToTickets,
    AdminPermission.assignTickets,
    AdminPermission.closeTickets,
    AdminPermission.manageFaqs,
    AdminPermission.manageSkills,
    AdminPermission.viewUsers,
    AdminPermission.suspendUsers,
    AdminPermission.manageAdmins,
    AdminPermission.systemSettings,
  };

  /// Permissions granted to admin role.
  static const Set<AdminPermission> adminPermissions = {
    AdminPermission.viewAllTickets,
    AdminPermission.respondToTickets,
    AdminPermission.assignTickets,
    AdminPermission.closeTickets,
    AdminPermission.manageFaqs,
    AdminPermission.manageSkills,
    AdminPermission.viewUsers,
    AdminPermission.suspendUsers,
  };

  /// Permissions granted to support role.
  static const Set<AdminPermission> supportPermissions = {
    AdminPermission.viewAllTickets,
    AdminPermission.respondToTickets,
    AdminPermission.closeTickets,
  };

  /// Get default permissions for a role.
  static Set<AdminPermission> getPermissionsForRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return superAdminPermissions;
      case UserRole.admin:
        return adminPermissions;
      case UserRole.support:
        return supportPermissions;
      default:
        return {};
    }
  }
}

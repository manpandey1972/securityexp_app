# Admin Role Architecture - GreenHive App

## Overview

This document outlines the architecture for implementing role-based admin functionality within the existing GreenHive Flutter app. Admin privileges are granted by adding admin role values to the existing `roles` array in Firestore, enabling elevated users to access admin features within the same app.

---

## 1. Role System Design

### 1.1 User Roles

```
┌─────────────────────────────────────────────────────────────────┐
│                      User Role Hierarchy                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────┐                                               │
│   │ SUPER_ADMIN │  ← Full access, can manage other admins       │
│   └──────┬──────┘                                               │
│          │                                                      │
│   ┌──────▼──────┐                                               │
│   │   ADMIN     │  ← Manage tickets, FAQs, skills, view users   │
│   └──────┬──────┘                                               │
│          │                                                      │
│   ┌──────▼──────┐                                               │
│   │  SUPPORT    │  ← View & respond to assigned tickets only    │
│   └──────┬──────┘                                               │
│          │                                                      │
│   ┌──────▼──────┐      ┌─────────────┐                          │
│   │    USER     │      │   EXPERT    │  ← Can also be admin     │
│   └─────────────┘      └─────────────┘                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Role Definitions

| Role | Description | Permissions |
|------|-------------|-------------|
| `user` | Default role for all users | Normal app access |
| `expert` | Service providers | User + expert features |
| `support` | Support agents | View assigned tickets, respond to tickets |
| `admin` | Administrators | All support + manage FAQs, skills, view all tickets, view users |
| `super_admin` | Super administrators | All admin + manage other admins, system settings |

---

## 2. Firestore Data Model

### 2.1 User Document Update

Add role field to existing user documents:

```
/users/{userId}
├── // ... existing fields (displayName, email, photoURL, etc.)
├── role: "user" | "expert" | "support" | "admin" | "super_admin"
├── adminPermissions: string[] | null  // Optional granular permissions
├── adminMetadata: {                    // Only for admin/support roles
│   ├── assignedCategories: string[]    // Ticket categories they handle
│   ├── ticketsHandled: number
│   ├── avgResponseTime: number
│   └── lastActiveAt: timestamp
│ }
└── // ... rest of existing fields
```

### 2.2 How to Elevate a User to Admin

Simply update the user document in Firestore Console or via script:

```javascript
// In Firestore Console or Admin SDK
db.collection('users').doc('USER_ID').update({
  role: 'admin',
  adminPermissions: ['manage_tickets', 'manage_faqs', 'manage_skills', 'view_users']
});
```

### 2.3 Permission Types

```dart
enum AdminPermission {
  // Ticket Management
  viewAllTickets,      // View all support tickets
  respondToTickets,    // Respond to tickets
  assignTickets,       // Assign tickets to others
  closeTickets,        // Close/resolve tickets
  
  // Content Management
  manageFaqs,          // Create, edit, delete FAQs
  manageSkills,        // Create, edit, delete skills
  
  // User Management
  viewUsers,           // View user list and details
  suspendUsers,        // Suspend/ban users
  
  // Admin Management (super_admin only)
  manageAdmins,        // Add/remove admin roles
  systemSettings,      // Access system settings
}
```

---

## 3. App Architecture

### 3.1 Service Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Architecture                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Presentation Layer                       ││
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐               ││
│  │  │ User UI   │  │ Expert UI │  │ Admin UI  │  ← Role-based ││
│  │  └───────────┘  └───────────┘  └───────────┘               ││
│  └──────────────────────────┬──────────────────────────────────┘│
│                             │                                   │
│  ┌──────────────────────────▼──────────────────────────────────┐│
│  │                    Role Service                             ││
│  │  • Check user role                                          ││
│  │  • Validate permissions                                     ││
│  │  • Stream role changes                                      ││
│  └──────────────────────────┬──────────────────────────────────┘│
│                             │                                   │
│  ┌──────────────────────────▼──────────────────────────────────┐│
│  │                  Admin Services                             ││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        ││
│  │  │TicketAdmin   │ │ FAQAdmin     │ │ SkillsAdmin  │        ││
│  │  │Service       │ │ Service      │ │ Service      │        ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘        ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 File Structure

```
lib/
├── core/
│   ├── auth/
│   │   └── role_service.dart              // NEW: Role management
│   └── permissions/
│       ├── permission_types.dart          // NEW: Permission enums
│       └── permission_guard.dart          // NEW: UI guards
│
├── features/
│   ├── admin/                             // NEW: Admin feature module
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── admin_user.dart
│   │   │   └── repositories/
│   │   │       ├── admin_ticket_repository.dart
│   │   │       ├── admin_faq_repository.dart
│   │   │       └── admin_user_repository.dart
│   │   │
│   │   ├── pages/
│   │   │   ├── admin_dashboard_page.dart
│   │   │   ├── admin_tickets_page.dart
│   │   │   ├── admin_ticket_detail_page.dart
│   │   │   ├── admin_faqs_page.dart
│   │   │   ├── admin_faq_editor_page.dart
│   │   │   ├── admin_skills_page.dart
│   │   │   ├── admin_skill_editor_page.dart
│   │   │   └── admin_users_page.dart
│   │   │
│   │   ├── widgets/
│   │   │   ├── admin_nav_item.dart
│   │   │   ├── ticket_table.dart
│   │   │   ├── ticket_filters.dart
│   │   │   ├── internal_notes_widget.dart
│   │   │   ├── faq_list_item.dart
│   │   │   ├── skill_list_item.dart
│   │   │   └── user_list_item.dart
│   │   │
│   │   ├── presentation/
│   │   │   ├── view_models/
│   │   │   │   ├── admin_dashboard_view_model.dart
│   │   │   │   ├── admin_tickets_view_model.dart
│   │   │   │   ├── admin_faqs_view_model.dart
│   │   │   │   ├── admin_skills_view_model.dart
│   │   │   │   └── admin_users_view_model.dart
│   │   │   └── state/
│   │   │       └── admin_state.dart
│   │   │
│   │   └── services/
│   │       ├── admin_ticket_service.dart
│   │       ├── admin_faq_service.dart
│   │       └── admin_analytics_service.dart
│   │
│   └── support/                           // Existing - minor updates
│       └── ...
│
├── shared/
│   └── widgets/
│       └── admin_section_wrapper.dart     // NEW: Conditionally show admin UI
│
└── providers/
    └── role_provider.dart                 // NEW: Role state provider
```

---

## 4. Core Implementation

### 4.1 Role Service

```dart
// lib/core/auth/role_service.dart

enum UserRole {
  user,
  expert,
  support,
  admin,
  superAdmin;
  
  static UserRole fromString(String? value) {
    switch (value) {
      case 'super_admin': return UserRole.superAdmin;
      case 'admin': return UserRole.admin;
      case 'support': return UserRole.support;
      case 'expert': return UserRole.expert;
      default: return UserRole.user;
    }
  }
  
  String toFirestoreValue() {
    switch (this) {
      case UserRole.superAdmin: return 'super_admin';
      case UserRole.admin: return 'admin';
      case UserRole.support: return 'support';
      case UserRole.expert: return 'expert';
      case UserRole.user: return 'user';
    }
  }
  
  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
  bool get isSupport => this == UserRole.support || isAdmin;
  bool get canManageContent => isAdmin;
  bool get canManageUsers => isAdmin;
  bool get canManageAdmins => this == UserRole.superAdmin;
}

class RoleService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  RoleService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;
  
  /// Stream the current user's role
  Stream<UserRole> get roleStream {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(UserRole.user);
    
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => UserRole.fromString(doc.data()?['role']));
  }
  
  /// Get current user's role (one-time fetch)
  Future<UserRole> getCurrentRole() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return UserRole.user;
    
    final doc = await _firestore.collection('users').doc(userId).get();
    return UserRole.fromString(doc.data()?['role']);
  }
  
  /// Check if current user has specific permission
  Future<bool> hasPermission(AdminPermission permission) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return false;
    
    final role = UserRole.fromString(data['role']);
    
    // Super admin has all permissions
    if (role == UserRole.superAdmin) return true;
    
    // Check role-based permissions
    if (role == UserRole.admin) {
      return _adminPermissions.contains(permission);
    }
    
    if (role == UserRole.support) {
      return _supportPermissions.contains(permission);
    }
    
    // Check granular permissions if set
    final permissions = List<String>.from(data['adminPermissions'] ?? []);
    return permissions.contains(permission.name);
  }
  
  static const _adminPermissions = {
    AdminPermission.viewAllTickets,
    AdminPermission.respondToTickets,
    AdminPermission.assignTickets,
    AdminPermission.closeTickets,
    AdminPermission.manageFaqs,
    AdminPermission.manageSkills,
    AdminPermission.viewUsers,
    AdminPermission.suspendUsers,
  };
  
  static const _supportPermissions = {
    AdminPermission.viewAllTickets,
    AdminPermission.respondToTickets,
    AdminPermission.closeTickets,
  };
}
```

### 4.2 Role Provider

```dart
// lib/providers/role_provider.dart

class RoleProvider extends ChangeNotifier {
  final RoleService _roleService;
  
  UserRole _currentRole = UserRole.user;
  StreamSubscription? _roleSubscription;
  
  UserRole get currentRole => _currentRole;
  bool get isAdmin => _currentRole.isAdmin;
  bool get isSupport => _currentRole.isSupport;
  bool get isSuperAdmin => _currentRole == UserRole.superAdmin;
  
  RoleProvider(this._roleService) {
    _init();
  }
  
  void _init() {
    _roleSubscription = _roleService.roleStream.listen((role) {
      _currentRole = role;
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    _roleSubscription?.cancel();
    super.dispose();
  }
}
```

### 4.3 Admin Section Wrapper

```dart
// lib/shared/widgets/admin_section_wrapper.dart

/// Widget that only shows its child if user has admin role
class AdminSection extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final UserRole minimumRole;
  
  const AdminSection({
    super.key,
    required this.child,
    this.fallback,
    this.minimumRole = UserRole.admin,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, _) {
        final hasAccess = _checkAccess(roleProvider.currentRole);
        
        if (hasAccess) {
          return child;
        }
        
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
  
  bool _checkAccess(UserRole currentRole) {
    switch (minimumRole) {
      case UserRole.superAdmin:
        return currentRole == UserRole.superAdmin;
      case UserRole.admin:
        return currentRole.isAdmin;
      case UserRole.support:
        return currentRole.isSupport;
      default:
        return true;
    }
  }
}

/// Guard widget for route protection
class AdminRouteGuard extends StatelessWidget {
  final Widget child;
  final UserRole minimumRole;
  
  const AdminRouteGuard({
    super.key,
    required this.child,
    this.minimumRole = UserRole.admin,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, _) {
        final hasAccess = _checkAccess(roleProvider.currentRole);
        
        if (!hasAccess) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: const Center(
              child: Text('You do not have permission to access this page.'),
            ),
          );
        }
        
        return child;
      },
    );
  }
  
  bool _checkAccess(UserRole currentRole) {
    switch (minimumRole) {
      case UserRole.superAdmin:
        return currentRole == UserRole.superAdmin;
      case UserRole.admin:
        return currentRole.isAdmin;
      case UserRole.support:
        return currentRole.isSupport;
      default:
        return true;
    }
  }
}
```

---

## 5. UI Integration

### 5.1 Navigation - Add Admin Menu Items

Update the main navigation (drawer/bottom nav) to show admin options:

```dart
// In your main navigation widget (e.g., AppDrawer or SettingsPage)

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          // ... existing menu items ...
          
          // Admin Section - only visible to admins
          AdminSection(
            minimumRole: UserRole.support,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'ADMIN',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // Dashboard - admin only
                AdminSection(
                  child: ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: const Text('Admin Dashboard'),
                    onTap: () => Navigator.pushNamed(context, '/admin'),
                  ),
                ),
                
                // Tickets - support and above
                AdminSection(
                  minimumRole: UserRole.support,
                  child: ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Support Tickets'),
                    onTap: () => Navigator.pushNamed(context, '/admin/tickets'),
                  ),
                ),
                
                // FAQs - admin only
                AdminSection(
                  child: ListTile(
                    leading: const Icon(Icons.quiz),
                    title: const Text('Manage FAQs'),
                    onTap: () => Navigator.pushNamed(context, '/admin/faqs'),
                  ),
                ),
                
                // Skills - admin only
                AdminSection(
                  child: ListTile(
                    leading: const Icon(Icons.handyman),
                    title: const Text('Manage Skills'),
                    onTap: () => Navigator.pushNamed(context, '/admin/skills'),
                  ),
                ),
                
                // Users - admin only
                AdminSection(
                  child: ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Users'),
                    onTap: () => Navigator.pushNamed(context, '/admin/users'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

### 5.2 Settings Page Integration

```dart
// In SettingsPage - add admin section

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ... existing settings ...
          
          // Admin Section
          AdminSection(
            minimumRole: UserRole.support,
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildSectionHeader('Administration'),
                
                AdminSection(
                  child: _SettingsTile(
                    icon: Icons.dashboard,
                    title: 'Admin Dashboard',
                    subtitle: 'View analytics and manage app',
                    onTap: () => context.push('/admin'),
                  ),
                ),
                
                AdminSection(
                  minimumRole: UserRole.support,
                  child: _SettingsTile(
                    icon: Icons.support_agent,
                    title: 'Support Tickets',
                    subtitle: 'Manage user support requests',
                    onTap: () => context.push('/admin/tickets'),
                  ),
                ),
                
                AdminSection(
                  child: _SettingsTile(
                    icon: Icons.quiz,
                    title: 'Manage FAQs',
                    subtitle: 'Add, edit, or remove FAQs',
                    onTap: () => context.push('/admin/faqs'),
                  ),
                ),
                
                AdminSection(
                  child: _SettingsTile(
                    icon: Icons.handyman,
                    title: 'Manage Skills',
                    subtitle: 'Configure available skills',
                    onTap: () => context.push('/admin/skills'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 6. Admin Pages Overview

### 6.1 Admin Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Admin Dashboard                                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐│
│  │ Open       │  │ Pending    │  │ Resolved   │  │ Total      ││
│  │ Tickets    │  │ Tickets    │  │ Today      │  │ Users      ││
│  │    12      │  │    5       │  │    8       │  │   1,234    ││
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘│
│                                                                 │
│  Quick Actions                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  🎫 View Tickets    ❓ Manage FAQs    🛠️ Manage Skills     ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Recent Tickets                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  #1234  Payment Issue        URGENT   5 min ago             ││
│  │  #1233  Cannot book expert   HIGH     15 min ago            ││
│  │  #1232  Account question     MEDIUM   1 hour ago            ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Admin Tickets Page

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Support Tickets                                    + Filters │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐               │
│  │   All   │ │  Open   │ │ Pending │ │ Resolved│               │
│  │   (47)  │ │  (12)   │ │   (5)   │ │  (30)   │               │
│  └────┬────┘ └─────────┘ └─────────┘ └─────────┘               │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 🔴 #1234 | Payment not processed                            ││
│  │    John Doe • Payment • 5 min ago           URGENT    →     ││
│  ├─────────────────────────────────────────────────────────────┤│
│  │ 🟡 #1233 | Cannot find expert in my area                    ││
│  │    Jane S. • Booking • 15 min ago           HIGH      →     ││
│  ├─────────────────────────────────────────────────────────────┤│
│  │ 🟢 #1232 | How do I update my profile?                      ││
│  │    Mike J. • Account • 1 hour ago           LOW       →     ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.3 Admin Ticket Detail Page

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Ticket #1234                              ⚙️ Actions  ▼      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Payment not processed                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Status: OPEN        Priority: URGENT      Category: Payment ││
│  │ Created: Jan 29     User: John Doe        Assigned: You     ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─── Conversation ───┐  ┌─── Internal Notes ───┐              │
│  │ (selected)         │  │                      │              │
│  └────────────────────┘  └──────────────────────┘              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 👤 John Doe                                    Jan 29, 10:30││
│  │ I made a payment but it's showing as pending...             ││
│  ├─────────────────────────────────────────────────────────────┤│
│  │ 🛡️ Support (You)                              Jan 29, 10:45││
│  │ Hi John, I'm looking into this for you...                   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Type your reply...                               📎   ➤    ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Routes Configuration

```dart
// Add to your app router

// Admin Routes
GoRoute(
  path: '/admin',
  builder: (context, state) => const AdminRouteGuard(
    child: AdminDashboardPage(),
  ),
  routes: [
    GoRoute(
      path: 'tickets',
      builder: (context, state) => const AdminRouteGuard(
        minimumRole: UserRole.support,
        child: AdminTicketsPage(),
      ),
    ),
    GoRoute(
      path: 'tickets/:ticketId',
      builder: (context, state) => AdminRouteGuard(
        minimumRole: UserRole.support,
        child: AdminTicketDetailPage(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
    ),
    GoRoute(
      path: 'faqs',
      builder: (context, state) => const AdminRouteGuard(
        child: AdminFaqsPage(),
      ),
    ),
    GoRoute(
      path: 'faqs/new',
      builder: (context, state) => const AdminRouteGuard(
        child: AdminFaqEditorPage(),
      ),
    ),
    GoRoute(
      path: 'faqs/:faqId',
      builder: (context, state) => AdminRouteGuard(
        child: AdminFaqEditorPage(
          faqId: state.pathParameters['faqId'],
        ),
      ),
    ),
    GoRoute(
      path: 'skills',
      builder: (context, state) => const AdminRouteGuard(
        child: AdminSkillsPage(),
      ),
    ),
    GoRoute(
      path: 'users',
      builder: (context, state) => const AdminRouteGuard(
        child: AdminUsersPage(),
      ),
    ),
  ],
),
```

---

## 8. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    
    function getUserRole() {
      return getUserData().role;
    }
    
    function isAdmin() {
      return isAuthenticated() && getUserRole() in ['admin', 'super_admin'];
    }
    
    function isSupport() {
      return isAuthenticated() && getUserRole() in ['support', 'admin', 'super_admin'];
    }
    
    function isSuperAdmin() {
      return isAuthenticated() && getUserRole() == 'super_admin';
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow update: if isAuthenticated() && (
        request.auth.uid == userId ||  // Own profile
        isAdmin()                       // Admins can update users
      );
      // Only super_admin can change roles
      allow update: if isAuthenticated() && 
        request.resource.data.role != resource.data.role &&
        isSuperAdmin();
    }
    
    // Support tickets - enhanced rules
    match /support_tickets/{ticketId} {
      // Users can read/create their own tickets
      allow read: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        isSupport()  // Support/Admin can read all
      );
      allow create: if isAuthenticated();
      
      // Users can update own tickets (add messages)
      // Support/Admin can update any ticket
      allow update: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        isSupport()
      );
      
      // Messages subcollection
      match /messages/{messageId} {
        allow read: if isAuthenticated() && (
          get(/databases/$(database)/documents/support_tickets/$(ticketId)).data.userId == request.auth.uid ||
          isSupport()
        );
        allow create: if isAuthenticated();
      }
      
      // Internal notes - support/admin only
      match /internal_notes/{noteId} {
        allow read, write: if isSupport();
      }
    }
    
    // FAQs
    match /faqs/{faqId} {
      allow read: if true;  // Public read
      allow write: if isAdmin();
    }
    
    match /faq_categories/{categoryId} {
      allow read: if true;
      allow write: if isAdmin();
    }
    
    // Skills
    match /skills/{skillId} {
      allow read: if true;
      allow write: if isAdmin();
    }
    
    match /skill_categories/{categoryId} {
      allow read: if true;
      allow write: if isAdmin();
    }
  }
}
```

---

## 9. Implementation Phases

### Phase 1: Core Role System ✅ COMPLETED
- [x] Create `RoleService` class → `lib/core/auth/role_service.dart`
- [x] Create `RoleProvider` for state management → `lib/providers/role_provider.dart`
- [x] Create `UserRole` enum and `AdminPermission` types → `lib/core/permissions/permission_types.dart`
- [x] Add `role` field to user model → `lib/data/models/models.dart`
- [x] Create `AdminSection` wrapper widget → `lib/shared/widgets/admin_section_wrapper.dart`
- [x] Create `AdminRouteGuard` widget → `lib/shared/widgets/admin_section_wrapper.dart`
- [x] Create `PermissionSection` widget → `lib/shared/widgets/admin_section_wrapper.dart`
- [x] Register `RoleService` in service locator → `lib/core/service_locator.dart`
- [x] Add `RoleProvider` to app providers → `lib/providers/provider_setup.dart`
- [x] Update Firestore security rules → `firestore.rules`

### Phase 2: Admin Navigation & Dashboard (1 week)
- [ ] Add admin menu items to settings/drawer
- [ ] Create `AdminDashboardPage` with stats
- [ ] Set up admin routes

### Phase 3: Ticket Management (1-2 weeks)
- [ ] Create `AdminTicketsPage` with list view
- [ ] Create `AdminTicketDetailPage`
- [ ] Implement ticket reply as admin
- [ ] Add ticket status/priority management
- [ ] Add internal notes feature
- [ ] Add ticket assignment (optional)

### Phase 4: FAQ Management (1 week)
- [ ] Create FAQ data model (if not exists)
- [ ] Create `AdminFaqsPage` with list
- [ ] Create `AdminFaqEditorPage` with markdown support
- [ ] Implement CRUD operations

### Phase 5: Skills Management (1 week)
- [ ] Create `AdminSkillsPage`
- [ ] Create `AdminSkillEditorPage`
- [ ] Implement CRUD operations

### Phase 6: User Management (Optional, 1 week)
- [ ] Create `AdminUsersPage` with search
- [ ] View user details
- [ ] Suspend/unsuspend users

---

## 10. How to Make a User Admin

### Option 1: Firebase Console (Manual)

1. Go to Firebase Console → Firestore
2. Navigate to `users` collection
3. Find the user document by ID
4. Add/update the `role` field:
   ```json
   {
     "role": "admin"
   }
   ```

### Option 2: Firebase Admin SDK (Script)

```javascript
// scripts/make_admin.js
const admin = require('firebase-admin');
admin.initializeApp();

async function makeAdmin(userId, role = 'admin') {
  await admin.firestore()
    .collection('users')
    .doc(userId)
    .update({ role });
  
  console.log(`User ${userId} is now ${role}`);
}

// Usage: node make_admin.js USER_ID admin
const userId = process.argv[2];
const role = process.argv[3] || 'admin';
makeAdmin(userId, role);
```

### Option 3: Cloud Function (Secure)

```typescript
// functions/src/admin/manage_roles.ts
export const setUserRole = functions.https.onCall(async (data, context) => {
  // Only super_admin can call this
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
  
  const callerDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  if (callerDoc.data()?.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only super_admin can change roles');
  }
  
  const { userId, role } = data;
  
  await admin.firestore()
    .collection('users')
    .doc(userId)
    .update({ role });
  
  return { success: true };
});
```

---

## 11. Summary

This architecture provides:

✅ **Single Codebase** - No separate admin app needed  
✅ **Role-Based Access** - UI adapts based on user role  
✅ **Easy Elevation** - Just update Firestore to make someone admin  
✅ **Scalable** - Can add more roles/permissions later  
✅ **Secure** - Firestore rules enforce permissions server-side  
✅ **Reactive** - UI updates automatically when role changes  

The admin features integrate seamlessly into the existing app, appearing only for users with appropriate roles.

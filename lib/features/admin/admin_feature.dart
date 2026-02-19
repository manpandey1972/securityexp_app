/// Admin feature for managing support tickets, FAQs, skills, and users.
///
/// This feature is only accessible to users with Support, Admin, or SuperAdmin roles.
///
/// ## Architecture
///
/// The feature is organized in the following structure:
/// - **data**: Data layer (models, repositories)
/// - **services**: Business logic and permission checks
/// - **presentation**: UI layer (state, view models)
/// - **pages**: Full screen pages
/// - **widgets**: Reusable UI components
///
/// ## Structure
///
/// ```
/// lib/features/admin/
/// ├── data/
/// │   ├── models/          # Data models (AdminUser, AdminSkill, Faq, etc.)
/// │   └── repositories/    # Data access layer (Firestore operations)
/// ├── services/            # Business logic services
/// ├── presentation/
/// │   ├── state/           # Immutable state classes
/// │   └── view_models/     # ChangeNotifier view models
/// ├── pages/               # Full screen pages
/// └── widgets/             # Reusable UI components
/// ```
library;

// Models
export 'data/models/models.dart';

// Repositories
export 'data/repositories/repositories.dart';

// Services
export 'services/admin_user_service.dart';
export 'services/admin_skills_service.dart';
export 'services/admin_faq_service.dart';
export 'services/admin_ticket_service.dart';

// State
export 'presentation/state/admin_state.dart';

// View Models
export 'presentation/view_models/admin_dashboard_view_model.dart';
export 'presentation/view_models/admin_users_view_model.dart';
export 'presentation/view_models/admin_skills_view_model.dart';
export 'presentation/view_models/admin_faqs_view_model.dart';
export 'presentation/view_models/admin_tickets_view_model.dart';
export 'presentation/view_models/admin_ticket_detail_view_model.dart';

// Widgets
export 'widgets/widgets.dart';

// Pages
export 'pages/admin_dashboard_page.dart';
export 'pages/admin_users_page.dart';
export 'pages/admin_skills_page.dart';
export 'pages/admin_skill_editor_page.dart';
export 'pages/admin_faqs_page.dart';
export 'pages/admin_faq_editor_page.dart';
export 'pages/admin_tickets_page.dart';
export 'pages/admin_ticket_detail_page.dart';

/// Support Feature Module
///
/// This module provides customer support functionality including:
/// - Support ticket creation and management
/// - Real-time ticket conversation/messaging
/// - File attachments for tickets
/// - User satisfaction ratings
/// - Device context capture for bug reports
///
/// ## Architecture
///
/// The feature is organized in the following structure:
/// - **data**: Data layer (models, repositories)
/// - **services**: Business logic and external service integration
/// - **presentation**: UI layer (widgets, pages, view models, state)
///
/// ## Usage
///
/// ```
/// lib/features/support/
/// ├── data/
/// │   ├── models/          # Data models (SupportTicket, SupportMessage, etc.)
/// │   └── repositories/    # Firestore & Storage operations
/// ├── services/            # Business logic services
/// ├── presentation/
/// │   ├── state/           # Immutable state classes
/// │   └── view_models/     # ChangeNotifier view models
/// ├── widgets/             # Reusable UI components
/// └── pages/               # Full screen pages
/// ```
///
/// ## Usage
///
/// Navigate to the support hub:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const SupportHubPage()),
/// );
/// ```
///
/// Or directly to ticket list:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const TicketListPage()),
/// );
/// ```
///
/// Create a new ticket:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const NewTicketPage()),
/// );
/// ```
library;

// Models
export 'data/models/models.dart';

// Repositories
export 'data/repositories/support_repository.dart';
export 'data/repositories/support_attachment_repository.dart';

// Services
export 'services/services.dart';

// Presentation
export 'presentation/state/state.dart';
export 'presentation/view_models/view_models.dart';

// Widgets
export 'widgets/widgets.dart';

// Pages
export 'pages/pages.dart';

/// Repository interfaces for dependency injection and testing.
///
/// These abstract interfaces define contracts for data operations,
/// allowing implementations to be swapped (e.g., Firestore vs Mock).
///
/// Usage:
/// ```dart
/// // Register in service locator
/// sl.registerSingleton<IUserRepository>(UserRepository());
///
/// // Use via interface
/// final userRepo = sl<IUserRepository>();
/// ```
library;

export 'user_repository_interface.dart';
export 'expert_repository_interface.dart';
export 'chat_room_repository_interface.dart';
export 'chat_message_repository_interface.dart';
export 'product_repository_interface.dart';
export 'pagination_cursor.dart';

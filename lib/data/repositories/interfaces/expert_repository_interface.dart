import 'package:securityexperts_app/data/models/models.dart';

/// Abstract interface for expert repository operations.
/// 
/// This interface defines the contract for expert-related data operations,
/// enabling dependency injection and easier testing through mocking.
abstract class IExpertRepository {
  /// Get all experts, optionally forcing a refresh from the server
  Future<List<User>> getExperts({bool forceRefresh = false});

  /// Get a specific expert by their ID
  Future<User?> getExpertById(String expertId);

  /// Stream of experts for real-time updates
  Stream<List<User>> watchExperts();

  /// Clear the cached experts list
  void clearCache();
}

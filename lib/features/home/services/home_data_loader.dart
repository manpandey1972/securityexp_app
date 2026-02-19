import 'dart:async';
import 'package:securityexperts_app/data/models/models.dart' as models;
import 'package:securityexperts_app/data/repositories/expert/expert_repository.dart';
import 'package:securityexperts_app/data/repositories/product/product_repository.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/chat/services/unread_messages_service.dart';
import 'package:securityexperts_app/shared/services/user_cache_service.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';
import 'package:securityexperts_app/utils/expert_search_utils.dart';
import 'package:securityexperts_app/core/analytics/analytics_service.dart';

/// Consolidated data loading service for home page
/// Handles all data initialization and loading operations
class HomeDataLoader {
  static Completer<void>? _initializationCompleter;

  final ExpertRepository _expertRepository = ExpertRepository();
  final ProductRepository _productRepository = ProductRepository();
  final ExpertSearchUtils _searchUtils = ExpertSearchUtils();
  final UnreadMessagesService _unreadMessagesService = UnreadMessagesService();

  /// Initialize all data with atomic operation
  /// Returns Future that completes when initialization is done
  Future<void> initializeData({
    required Function() onExpertsLoaded,
    required Function() onError,
  }) async {
    // Prevent concurrent initialization
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      await _initializationCompleter!.future;
      return;
    }

    // Create completer for this initialization
    _initializationCompleter = Completer<void>();

    await ErrorHandler.handle<void>(
      operation: () async {
        await _performInitialization(onExpertsLoaded: onExpertsLoaded);
        _initializationCompleter!.complete();
      },
      onError: (error) {
        _initializationCompleter!.completeError(error);
        onError();
      },
    );
  }

  Future<void> _performInitialization({
    required Function() onExpertsLoaded,
  }) async {
    final trace = sl<AnalyticsService>().newTrace('home_initial_data_load');
    await trace.start();
    
    // Load skills first
    await _searchUtils.loadSkills();
    trace.putAttribute('skills_loaded', 'true');

    // Load experts to ensure they're available when HomePage initializes
    await onExpertsLoaded();
    
    await trace.stop();
  }

  /// Load experts from Firestore
  /// Returns list of experts
  Future<List<models.User>?> loadExperts() async {
    final trace = sl<AnalyticsService>().newTrace('expert_list_load');
    await trace.start();
    
    return ErrorHandler.handle(
      operation: () async {
        final experts = await _expertRepository.getExperts();
        
        trace.putAttribute('expert_count', experts.length.toString());
        await trace.stop();

        // Populate UserCacheService with experts
        sl<UserCacheService>().loadUsers(experts);

        return experts;
      },
      onError: (error) async {
        await trace.stop();
      },
    );
  }

  /// Load products from Firestore
  Future<List<models.Product>?> loadProducts() async {
    return ErrorHandler.handle(
      operation: () async {
        return await _productRepository.getProducts();
      },
      fallback: null,
    );
  }

  /// Get search utilities instance
  ExpertSearchUtils get searchUtils => _searchUtils;

  /// Get unread messages service
  UnreadMessagesService get unreadMessagesService => _unreadMessagesService;
}

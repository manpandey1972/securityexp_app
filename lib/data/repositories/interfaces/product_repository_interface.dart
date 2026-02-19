import 'package:securityexperts_app/data/models/models.dart';

/// Abstract interface for product repository operations.
/// 
/// This interface defines the contract for product-related data operations,
/// enabling dependency injection and easier testing through mocking.
abstract class IProductRepository {
  /// Get all products, optionally forcing a refresh from the server
  Future<List<Product>> getProducts({bool forceRefresh = false});

  /// Get a specific product by its ID
  Future<Product?> getProductById(String productId);

  /// Stream of products for real-time updates
  Stream<List<Product>> watchProducts();

  /// Clear the cached products list
  void clearCache();
}

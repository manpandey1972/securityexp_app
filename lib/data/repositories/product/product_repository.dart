import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/data/repositories/interfaces/repository_interfaces.dart';

/// Repository for product-related Firestore operations.
///
/// Handles fetching and caching of products from Firestore.
///
/// Example:
/// ```dart
/// final repo = ProductRepository();
/// final products = await repo.getProducts();
/// final product = await repo.getProductById('productId');
/// ```
class ProductRepository implements IProductRepository {
  final FirestoreInstance _firestoreService = FirestoreInstance();
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'ProductRepository';

  // Cache for products list
  List<Product>? _cachedProducts;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 10);

  /// Products collection name
  static const String productsCollection = 'products';

  /// Get the Firestore instance
  FirebaseFirestore get _db => _firestoreService.db;

  /// Get all products from Firestore.
  ///
  /// Returns cached data if available and not expired.
  @override
  Future<List<Product>> getProducts({bool forceRefresh = false}) async {
    // Return cached data if valid
    if (!forceRefresh && _isCacheValid()) {
      return _cachedProducts!;
    }

    return await ErrorHandler.handle<List<Product>>(
      operation: () async {
        final snapshot = await _db
            .collection(productsCollection)
            .orderBy('name')
            .get();

        final products = snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Use document ID as product ID if not present
              if (!data.containsKey('id') ||
                  (data['id'] as String?)?.isEmpty == true) {
                data['id'] = doc.id;
              }
              try {
                return Product.fromJson(data);
              } catch (e, stackTrace) {
                _log.error('Error parsing product ${doc.id}: $e', tag: _tag, stackTrace: stackTrace);
                return null;
              }
            })
            .whereType<Product>()
            .toList();

        // Update cache
        _cachedProducts = products;
        _cacheTimestamp = DateTime.now();

        return products;
      },
      fallback: _cachedProducts ?? [],
      onError: (error) =>
          _log.error('Error fetching products: $error', tag: _tag),
    );
  }

  /// Get a specific product by ID.
  ///
  /// First checks cached products, then fetches from Firestore if not found.
  @override
  Future<Product?> getProductById(String productId) async {
    // Check cache first
    if (_cachedProducts != null) {
      final cached = _cachedProducts!
          .where((p) => p.id == productId)
          .firstOrNull;
      if (cached != null) return cached;
    }

    return await ErrorHandler.handle<Product?>(
      operation: () async {
        final doc = await _db
            .collection(productsCollection)
            .doc(productId)
            .get();

        if (!doc.exists) return null;

        final data = doc.data()!;
        if (!data.containsKey('id') ||
            (data['id'] as String?)?.isEmpty == true) {
          data['id'] = doc.id;
        }

        return Product.fromJson(data);
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error fetching product $productId: $error', tag: _tag),
    );
  }

  /// Watch products list for real-time updates.
  ///
  /// Returns a stream that emits updated list whenever products change.
  @override
  Stream<List<Product>> watchProducts() {
    return _db.collection(productsCollection).orderBy('name').snapshots().map((
      snapshot,
    ) {
      final products = snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (!data.containsKey('id') ||
                (data['id'] as String?)?.isEmpty == true) {
              data['id'] = doc.id;
            }
            try {
              return Product.fromJson(data);
            } catch (_) {
              return null;
            }
          })
          .whereType<Product>()
          .toList();

      // Update cache
      _cachedProducts = products;
      _cacheTimestamp = DateTime.now();

      return products;
    });
  }

  /// Clear the products cache.
  @override
  void clearCache() {
    _cachedProducts = null;
    _cacheTimestamp = null;
  }

  /// Check if cache is valid.
  bool _isCacheValid() {
    if (_cachedProducts == null || _cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';
import 'package:securityexperts_app/features/admin/data/repositories/admin_faq_repository.dart';
import 'package:securityexperts_app/shared/services/error_handler.dart';

/// Service for managing FAQs in admin panel.
///
/// This service handles business logic and permission checks.
/// Data access is delegated to [AdminFaqRepository].
class AdminFaqService {
  final AdminFaqRepository _repository;
  final FirebaseAuth _auth;
  final RoleService _roleService;
  final AppLogger _log;

  static const String _tag = 'AdminFaqService';

  AdminFaqService({
    AdminFaqRepository? repository,
    FirebaseAuth? auth,
    RoleService? roleService,
    AppLogger? logger,
  })  : _repository = repository ?? FirestoreAdminFaqRepository(),
        _auth = auth ?? FirebaseAuth.instance,
        _roleService = roleService ?? sl<RoleService>(),
        _log = logger ?? sl<AppLogger>();

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============= Permission Checks =============

  Future<void> _ensurePermission(AdminPermission permission) async {
    final hasPermission = await _roleService.hasPermission(permission);
    if (!hasPermission) {
      _log.warning('Permission denied: ${permission.name}', tag: _tag);
      throw Exception('Permission denied: ${permission.name}');
    }
  }

  // ============= FAQ Categories =============

  /// Get all FAQ categories.
  Future<List<FaqCategory>> getCategories() async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<List<FaqCategory>>(
      operation: () => _repository.getCategories(),
      fallback: [],
      onError: (error) =>
          _log.error('Error getting FAQ categories: $error', tag: _tag),
    );
  }

  /// Create a new FAQ category.
  Future<String?> createCategory({
    required String name,
    String? description,
    String? icon,
    int order = 0,
    bool isActive = true,
  }) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<String?>(
      operation: () async {
        final categoryId = await _repository.createCategory(
          name: name,
          description: description,
          icon: icon,
          order: order,
          isActive: isActive,
        );
        _log.info('Created FAQ category: $name', tag: _tag);
        return categoryId;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error creating FAQ category: $error', tag: _tag),
    );
  }

  /// Update a FAQ category.
  Future<bool> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? icon,
    int? order,
    bool? isActive,
  }) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updateCategory(
          categoryId,
          name: name,
          description: description,
          icon: icon,
          order: order,
          isActive: isActive,
        );
        _log.info('Updated FAQ category: $categoryId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error updating FAQ category: $error', tag: _tag),
    );
  }

  /// Delete a FAQ category.
  Future<bool> deleteCategory(String categoryId) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<bool>(
      operation: () async {
        // Check if category has FAQs
        final hasFaqs = await _repository.categoryHasFaqs(categoryId);
        if (hasFaqs) {
          throw Exception(
              'Cannot delete category with existing FAQs. Move or delete FAQs first.');
        }

        await _repository.deleteCategory(categoryId);
        _log.info('Deleted FAQ category: $categoryId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error deleting FAQ category: $error', tag: _tag),
    );
  }

  // ============= FAQs =============

  /// Get all FAQs with optional filters.
  Future<List<Faq>> getFaqs({
    String? categoryId,
    bool? isPublished,
    String? searchQuery,
    int limit = 1000,
  }) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<List<Faq>>(
      operation: () async {
        var faqs = await _repository.getFaqs(
          categoryId: categoryId,
          isPublished: isPublished,
          limit: limit,
        );

        // Client-side search if query provided
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final lowerQuery = searchQuery.toLowerCase();
          faqs = faqs.where((faq) {
            return faq.question.toLowerCase().contains(lowerQuery) ||
                faq.answer.toLowerCase().contains(lowerQuery) ||
                faq.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
          }).toList();
        }

        return faqs;
      },
      fallback: [],
      onError: (error) => _log.error('Error getting FAQs: $error', tag: _tag),
    );
  }

  /// Get a single FAQ by ID.
  Future<Faq?> getFaq(String faqId) async {
    return ErrorHandler.handle<Faq?>(
      operation: () => _repository.getFaq(faqId),
      fallback: null,
      onError: (error) => _log.error('Error getting FAQ: $error', tag: _tag),
    );
  }

  /// Create a new FAQ.
  Future<String?> createFaq({
    required String question,
    required String answer,
    required String categoryId,
    List<String> tags = const [],
    bool isPublished = false,
    int order = 0,
  }) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<String?>(
      operation: () async {
        final faqId = await _repository.createFaq(
          question: question,
          answer: answer,
          categoryId: categoryId,
          tags: tags,
          isPublished: isPublished,
          order: order,
          createdBy: _currentUserId,
        );
        _log.info('Created FAQ: $question', tag: _tag);
        return faqId;
      },
      fallback: null,
      onError: (error) => _log.error('Error creating FAQ: $error', tag: _tag),
    );
  }

  /// Update a FAQ.
  Future<bool> updateFaq(
    String faqId, {
    String? question,
    String? answer,
    String? categoryId,
    List<String>? tags,
    bool? isPublished,
    int? order,
  }) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updateFaq(
          faqId,
          question: question,
          answer: answer,
          categoryId: categoryId,
          tags: tags,
          isPublished: isPublished,
          order: order,
          updatedBy: _currentUserId,
        );
        _log.info('Updated FAQ: $faqId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) => _log.error('Error updating FAQ: $error', tag: _tag),
    );
  }

  /// Delete a FAQ.
  Future<bool> deleteFaq(String faqId) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.deleteFaq(faqId);
        _log.info('Deleted FAQ: $faqId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) => _log.error('Error deleting FAQ: $error', tag: _tag),
    );
  }

  /// Toggle FAQ published status.
  Future<bool> togglePublished(String faqId) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<bool>(
      operation: () async {
        final newPublished = await _repository.togglePublished(faqId);
        _log.info(
            'FAQ $faqId ${newPublished ? 'published' : 'unpublished'}',
            tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error toggling FAQ published: $error', tag: _tag),
    );
  }

  /// Reorder FAQs within a category.
  Future<bool> reorderFaqs(List<String> faqIds) async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.reorderFaqs(faqIds);
        _log.info('Reordered ${faqIds.length} FAQs', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error reordering FAQs: $error', tag: _tag),
    );
  }

  /// Get FAQ statistics.
  Future<Map<String, int>> getStats() async {
    await _ensurePermission(AdminPermission.manageFaqs);

    return ErrorHandler.handle<Map<String, int>>(
      operation: () async {
        final data = await _repository.getDataForStats();
        final faqs = data.faqs;
        final categories = data.categories;

        return {
          'totalFaqs': faqs.length,
          'publishedFaqs': faqs.where((f) => f.isPublished).length,
          'draftFaqs': faqs.where((f) => !f.isPublished).length,
          'totalCategories': categories.length,
          'totalViews': faqs.fold(0, (total, f) => total + f.viewCount),
        };
      },
      fallback: {},
      onError: (error) =>
          _log.error('Error getting FAQ stats: $error', tag: _tag),
    );
  }
}

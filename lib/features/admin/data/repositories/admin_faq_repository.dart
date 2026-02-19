import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';

/// Repository for admin FAQ data operations.
///
/// This repository handles all Firestore operations for FAQ management.
/// Business logic and permission checks are handled by [AdminFaqService].
abstract class AdminFaqRepository {
  // ============= Categories =============

  /// Get all FAQ categories ordered by 'order' field.
  Future<List<FaqCategory>> getCategories();

  /// Create a new FAQ category and return its ID.
  Future<String> createCategory({
    required String name,
    String? description,
    String? icon,
    int order = 0,
    bool isActive = true,
  });

  /// Update a FAQ category.
  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? icon,
    int? order,
    bool? isActive,
  });

  /// Delete a FAQ category.
  Future<void> deleteCategory(String categoryId);

  /// Check if a category has any FAQs.
  Future<bool> categoryHasFaqs(String categoryId);

  // ============= FAQs =============

  /// Get all FAQs with optional filters.
  Future<List<Faq>> getFaqs({
    String? categoryId,
    bool? isPublished,
    int limit = 1000,
  });

  /// Get a single FAQ by ID.
  Future<Faq?> getFaq(String faqId);

  /// Create a new FAQ and return its ID.
  Future<String> createFaq({
    required String question,
    required String answer,
    required String categoryId,
    List<String> tags = const [],
    bool isPublished = false,
    int order = 0,
    String? createdBy,
  });

  /// Update a FAQ.
  Future<void> updateFaq(
    String faqId, {
    String? question,
    String? answer,
    String? categoryId,
    List<String>? tags,
    bool? isPublished,
    int? order,
    String? updatedBy,
  });

  /// Delete a FAQ.
  Future<void> deleteFaq(String faqId);

  /// Toggle FAQ published status and return new status.
  Future<bool> togglePublished(String faqId);

  /// Reorder FAQs by updating their order field.
  Future<void> reorderFaqs(List<String> faqIds);

  /// Get all FAQs and categories for statistics.
  Future<({List<Faq> faqs, List<FaqCategory> categories})> getDataForStats();
}

/// Firestore implementation of [AdminFaqRepository].
class FirestoreAdminFaqRepository implements AdminFaqRepository {
  final FirebaseFirestore _firestore;

  static const String _faqsCollection = 'faqs';
  static const String _categoriesCollection = 'faq_categories';

  FirestoreAdminFaqRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreInstance().db;

  CollectionReference<Map<String, dynamic>> get _faqCollection =>
      _firestore.collection(_faqsCollection);

  CollectionReference<Map<String, dynamic>> get _categoryCollection =>
      _firestore.collection(_categoriesCollection);

  // ============= Categories =============

  @override
  Future<List<FaqCategory>> getCategories() async {
    final snapshot =
        await _categoryCollection.orderBy('order').get();
    return snapshot.docs
        .map((doc) => FaqCategory.fromFirestore(doc))
        .toList();
  }

  @override
  Future<String> createCategory({
    required String name,
    String? description,
    String? icon,
    int order = 0,
    bool isActive = true,
  }) async {
    final docRef = await _categoryCollection.add({
      'name': name,
      'description': description,
      'icon': icon ?? '📋',
      'order': order,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? icon,
    int? order,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (icon != null) updates['icon'] = icon;
    if (order != null) updates['order'] = order;
    if (isActive != null) updates['isActive'] = isActive;

    await _categoryCollection.doc(categoryId).update(updates);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    await _categoryCollection.doc(categoryId).delete();
  }

  @override
  Future<bool> categoryHasFaqs(String categoryId) async {
    final faqs = await _faqCollection
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();
    return faqs.docs.isNotEmpty;
  }

  // ============= FAQs =============

  @override
  Future<List<Faq>> getFaqs({
    String? categoryId,
    bool? isPublished,
    int limit = 1000,
  }) async {
    Query query = _faqCollection;

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    if (isPublished != null) {
      query = query.where('isPublished', isEqualTo: isPublished);
    }

    query = query.orderBy('order').limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Faq.fromFirestore(doc)).toList();
  }

  @override
  Future<Faq?> getFaq(String faqId) async {
    final doc = await _faqCollection.doc(faqId).get();
    if (!doc.exists) return null;
    return Faq.fromFirestore(doc);
  }

  @override
  Future<String> createFaq({
    required String question,
    required String answer,
    required String categoryId,
    List<String> tags = const [],
    bool isPublished = false,
    int order = 0,
    String? createdBy,
  }) async {
    final docRef = await _faqCollection.add({
      'question': question,
      'answer': answer,
      'categoryId': categoryId,
      'tags': tags,
      'isPublished': isPublished,
      'order': order,
      'viewCount': 0,
      'helpfulCount': 0,
      'notHelpfulCount': 0,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<void> updateFaq(
    String faqId, {
    String? question,
    String? answer,
    String? categoryId,
    List<String>? tags,
    bool? isPublished,
    int? order,
    String? updatedBy,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (question != null) updates['question'] = question;
    if (answer != null) updates['answer'] = answer;
    if (categoryId != null) updates['categoryId'] = categoryId;
    if (tags != null) updates['tags'] = tags;
    if (isPublished != null) updates['isPublished'] = isPublished;
    if (order != null) updates['order'] = order;
    if (updatedBy != null) updates['updatedBy'] = updatedBy;

    await _faqCollection.doc(faqId).update(updates);
  }

  @override
  Future<void> deleteFaq(String faqId) async {
    await _faqCollection.doc(faqId).delete();
  }

  @override
  Future<bool> togglePublished(String faqId) async {
    final doc = await _faqCollection.doc(faqId).get();
    if (!doc.exists) {
      throw Exception('FAQ not found: $faqId');
    }

    final currentPublished = doc.data()?['isPublished'] as bool? ?? false;
    final newPublished = !currentPublished;

    await _faqCollection.doc(faqId).update({
      'isPublished': newPublished,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return newPublished;
  }

  @override
  Future<void> reorderFaqs(List<String> faqIds) async {
    final batch = _firestore.batch();

    for (int i = 0; i < faqIds.length; i++) {
      batch.update(
        _faqCollection.doc(faqIds[i]),
        {'order': i},
      );
    }

    await batch.commit();
  }

  @override
  Future<({List<Faq> faqs, List<FaqCategory> categories})>
      getDataForStats() async {
    final faqSnapshot = await _faqCollection.get();
    final categorySnapshot = await _categoryCollection.get();

    return (
      faqs: faqSnapshot.docs.map((doc) => Faq.fromFirestore(doc)).toList(),
      categories: categorySnapshot.docs
          .map((doc) => FaqCategory.fromFirestore(doc))
          .toList(),
    );
  }
}

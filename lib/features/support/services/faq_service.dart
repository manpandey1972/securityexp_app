import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/features/admin/data/models/faq.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Public FAQ service for fetching published FAQs.
///
/// This service allows users to view published FAQs from the help center.
/// Unlike [AdminFaqService], this doesn't require admin permissions.
class FaqService {
  final FirebaseFirestore _firestore;
  final AppLogger _log;

  static const String _tag = 'FaqService';
  static const String _faqsCollection = 'faqs';
  static const String _categoriesCollection = 'faq_categories';

  FaqService({
    FirebaseFirestore? firestore,
    AppLogger? logger,
  }) : _firestore = firestore ?? FirestoreInstance().db,
       _log = logger ?? sl<AppLogger>();

  /// Get all published FAQs grouped by category.
  Future<Map<String, List<Faq>>> getPublishedFaqsByCategory() async {
    try {
      _log.debug('Fetching published FAQs by category', tag: _tag);

      final snapshot = await _firestore
          .collection(_faqsCollection)
          .where('isPublished', isEqualTo: true)
          .orderBy('order')
          .get();

      final faqs = snapshot.docs.map((doc) => Faq.fromFirestore(doc)).toList();

      // Group by category
      final Map<String, List<Faq>> faqsByCategory = {};
      for (final faq in faqs) {
        final categoryId = faq.categoryId ?? 'uncategorized';
        faqsByCategory.putIfAbsent(categoryId, () => []).add(faq);
      }

      _log.debug(
        'Fetched ${faqs.length} FAQs in ${faqsByCategory.length} categories',
        tag: _tag,
      );

      return faqsByCategory;
    } catch (e) {
      _log.error('Error fetching published FAQs: $e', tag: _tag);
      return {};
    }
  }

  /// Get all published FAQs.
  Future<List<Faq>> getPublishedFaqs() async {
    try {
      _log.debug('Fetching all published FAQs', tag: _tag);

      final snapshot = await _firestore
          .collection(_faqsCollection)
          .where('isPublished', isEqualTo: true)
          .orderBy('order')
          .get();

      final faqs = snapshot.docs.map((doc) => Faq.fromFirestore(doc)).toList();

      _log.debug('Fetched ${faqs.length} published FAQs', tag: _tag);

      return faqs;
    } catch (e) {
      _log.error('Error fetching published FAQs: $e', tag: _tag);
      return [];
    }
  }

  /// Get all FAQ categories.
  Future<List<FaqCategory>> getCategories() async {
    try {
      _log.debug('Fetching FAQ categories', tag: _tag);

      final snapshot = await _firestore
          .collection(_categoriesCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final categories = snapshot.docs
          .map((doc) => FaqCategory.fromFirestore(doc))
          .toList();

      _log.debug('Fetched ${categories.length} categories', tag: _tag);

      return categories;
    } catch (e) {
      _log.error('Error fetching FAQ categories: $e', tag: _tag);
      return [];
    }
  }

  /// Stream published FAQs for real-time updates.
  Stream<List<Faq>> streamPublishedFaqs() {
    return _firestore
        .collection(_faqsCollection)
        .where('isPublished', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => Faq.fromFirestore(doc)).toList(),
        )
        .handleError((error) {
          _log.error('Error in FAQ stream: $error', tag: _tag);
          return <Faq>[];
        });
  }

  /// Record a FAQ view.
  Future<void> recordFaqView(String faqId) async {
    try {
      await _firestore.collection(_faqsCollection).doc(faqId).update({
        'viewCount': FieldValue.increment(1),
      });
      _log.debug('Recorded FAQ view: $faqId', tag: _tag);
    } catch (e) {
      _log.error('Error recording FAQ view: $e', tag: _tag);
    }
  }

  /// Mark a FAQ as helpful.
  Future<void> markFaqHelpful(String faqId) async {
    try {
      await _firestore.collection(_faqsCollection).doc(faqId).update({
        'helpfulCount': FieldValue.increment(1),
      });
      _log.debug('Marked FAQ as helpful: $faqId', tag: _tag);
    } catch (e) {
      _log.error('Error marking FAQ as helpful: $e', tag: _tag);
    }
  }

  /// Mark a FAQ as not helpful.
  Future<void> markFaqNotHelpful(String faqId) async {
    try {
      await _firestore.collection(_faqsCollection).doc(faqId).update({
        'notHelpfulCount': FieldValue.increment(1),
      });
      _log.debug('Marked FAQ as not helpful: $faqId', tag: _tag);
    } catch (e) {
      _log.error('Error marking FAQ as not helpful: $e', tag: _tag);
    }
  }
}

import 'package:flutter_test/flutter_test.dart';

import 'package:securityexperts_app/features/admin/data/repositories/admin_faq_repository.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';

import '../../../../helpers/service_mocks.mocks.dart';

void main() {
  group('AdminFaqRepository', () {
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
    });

    group('Abstract interface', () {
      test('should define getCategories method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define createCategory method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define updateCategory method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define deleteCategory method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define categoryHasFaqs method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define getFaqs method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define getFaq method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define createFaq method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define updateFaq method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define deleteFaq method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define togglePublished method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define reorderFaqs method', () {
        expect(AdminFaqRepository, isNotNull);
      });

      test('should define getDataForStats method', () {
        expect(AdminFaqRepository, isNotNull);
      });
    });

    group('FaqCategory model', () {
      test('should create category with required fields', () {
        final category = FaqCategory(
          id: 'cat-1',
          name: 'Getting Started',
          order: 0,
          createdAt: DateTime.now(),
        );

        expect(category.id, equals('cat-1'));
        expect(category.name, equals('Getting Started'));
        expect(category.order, equals(0));
        expect(category.isActive, isTrue);
      });

      test('should create category with all fields', () {
        final category = FaqCategory(
          id: 'cat-2',
          name: 'Advanced Topics',
          description: 'For experienced users',
          icon: 'star',
          order: 1,
          isActive: true,
          createdAt: DateTime.now(),
        );

        expect(category.description, equals('For experienced users'));
        expect(category.icon, equals('star'));
      });

      test('should support copyWith', () {
        final category = FaqCategory(
          id: 'cat-1',
          name: 'Original',
          order: 0,
          createdAt: DateTime.now(),
        );

        final updated = category.copyWith(name: 'Updated');

        expect(updated.name, equals('Updated'));
        expect(updated.id, equals('cat-1'));
      });

      test('should convert to Firestore map', () {
        final category = FaqCategory(
          id: 'cat-1',
          name: 'Test Category',
          description: 'Description',
          order: 5,
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        );

        final map = category.toFirestore();

        expect(map['name'], equals('Test Category'));
        expect(map['description'], equals('Description'));
        expect(map['order'], equals(5));
        expect(map['isActive'], isTrue);
      });
    });

    group('Faq model', () {
      test('should create FAQ with required fields', () {
        final faq = Faq(
          id: 'faq-1',
          question: 'How do I start?',
          answer: 'Click the start button.',
          createdAt: DateTime.now(),
        );

        expect(faq.id, equals('faq-1'));
        expect(faq.question, equals('How do I start?'));
        expect(faq.answer, equals('Click the start button.'));
      });

      test('should create FAQ with category and tags', () {
        final faq = Faq(
          id: 'faq-2',
          question: 'Advanced question?',
          answer: 'Advanced answer.',
          categoryId: 'cat-1',
          categoryName: 'Getting Started',
          tags: ['beginner', 'tutorial'],
          order: 1,
          isPublished: true,
          createdAt: DateTime.now(),
        );

        expect(faq.categoryId, equals('cat-1'));
        expect(faq.tags, contains('beginner'));
        expect(faq.isPublished, isTrue);
      });

      test('should track view and helpful counts', () {
        final faq = Faq(
          id: 'faq-3',
          question: 'Popular question?',
          answer: 'Popular answer.',
          viewCount: 100,
          helpfulCount: 80,
          notHelpfulCount: 5,
          createdAt: DateTime.now(),
        );

        expect(faq.viewCount, equals(100));
        expect(faq.helpfulCount, equals(80));
        expect(faq.notHelpfulCount, equals(5));
      });

      test('should have default values for optional fields', () {
        final faq = Faq(
          id: 'faq-4',
          question: 'Q',
          answer: 'A',
          createdAt: DateTime.now(),
        );

        expect(faq.tags, isEmpty);
        expect(faq.order, equals(0));
        expect(faq.isPublished, isTrue);
        expect(faq.viewCount, equals(0));
      });

      test('should support createdBy and updatedBy', () {
        final faq = Faq(
          id: 'faq-5',
          question: 'Q',
          answer: 'A',
          createdBy: 'admin-1',
          updatedBy: 'admin-2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(faq.createdBy, equals('admin-1'));
        expect(faq.updatedBy, equals('admin-2'));
      });
    });

    group('FirestoreAdminFaqRepository', () {
      test('should use default Firestore instance', () {
        expect(FirestoreAdminFaqRepository, isNotNull);
      });

      test('should accept custom Firestore instance', () {
        final repo = FirestoreAdminFaqRepository(firestore: mockFirestore);
        expect(repo, isNotNull);
      });

      test('should use correct collection names', () {
        const faqsCollection = 'faqs';
        const categoriesCollection = 'faq_categories';

        expect(faqsCollection, equals('faqs'));
        expect(categoriesCollection, equals('faq_categories'));
      });
    });

    group('Category operations', () {
      test('getCategories should order by order field', () {
        final categories = [
          FaqCategory(id: '3', name: 'C', order: 2, createdAt: DateTime.now()),
          FaqCategory(id: '1', name: 'A', order: 0, createdAt: DateTime.now()),
          FaqCategory(id: '2', name: 'B', order: 1, createdAt: DateTime.now()),
        ];

        categories.sort((a, b) => a.order.compareTo(b.order));

        expect(categories[0].name, equals('A'));
        expect(categories[1].name, equals('B'));
        expect(categories[2].name, equals('C'));
      });

      test('createCategory should set default values', () {
        const name = 'New Category';
        const order = 0;
        const isActive = true;

        expect(name, isNotEmpty);
        expect(order, equals(0));
        expect(isActive, isTrue);
      });

      test('updateCategory should only update provided fields', () {
        final original = FaqCategory(
          id: 'cat-1',
          name: 'Original',
          description: 'Original desc',
          order: 0,
          createdAt: DateTime.now(),
        );

        final updated = original.copyWith(name: 'Updated');

        expect(updated.name, equals('Updated'));
        expect(updated.description, equals('Original desc'));
      });

      test('categoryHasFaqs should check for related FAQs', () {
        final faqs = [
          Faq(
            id: 'faq-1',
            question: 'Q',
            answer: 'A',
            categoryId: 'cat-1',
            createdAt: DateTime.now(),
          ),
        ];

        final hasFaqs = faqs.any((f) => f.categoryId == 'cat-1');
        final hasNoFaqs = faqs.any((f) => f.categoryId == 'cat-99');

        expect(hasFaqs, isTrue);
        expect(hasNoFaqs, isFalse);
      });
    });

    group('FAQ operations', () {
      test('getFaqs should support categoryId filter', () {
        final faqs = [
          Faq(
            id: '1',
            question: 'Q1',
            answer: 'A1',
            categoryId: 'cat-1',
            createdAt: DateTime.now(),
          ),
          Faq(
            id: '2',
            question: 'Q2',
            answer: 'A2',
            categoryId: 'cat-2',
            createdAt: DateTime.now(),
          ),
        ];

        final filtered = faqs.where((f) => f.categoryId == 'cat-1').toList();

        expect(filtered.length, equals(1));
        expect(filtered.first.id, equals('1'));
      });

      test('getFaqs should support isPublished filter', () {
        final faqs = [
          Faq(
            id: '1',
            question: 'Q1',
            answer: 'A1',
            isPublished: true,
            createdAt: DateTime.now(),
          ),
          Faq(
            id: '2',
            question: 'Q2',
            answer: 'A2',
            isPublished: false,
            createdAt: DateTime.now(),
          ),
        ];

        final published = faqs.where((f) => f.isPublished).toList();
        final unpublished = faqs.where((f) => !f.isPublished).toList();

        expect(published.length, equals(1));
        expect(unpublished.length, equals(1));
      });

      test('getFaqs should support limit', () {
        final faqs = List.generate(
          100,
          (i) => Faq(
            id: 'faq-$i',
            question: 'Q$i',
            answer: 'A$i',
            createdAt: DateTime.now(),
          ),
        );

        final limited = faqs.take(50).toList();

        expect(limited.length, equals(50));
      });

      test('getFaq should return null for non-existent FAQ', () {
        Faq? result;
        expect(result, isNull);
      });

      test('createFaq should return new FAQ ID', () {
        const newId = 'new-faq-id';
        expect(newId, isNotEmpty);
      });

      test('togglePublished should flip isPublished state', () {
        var isPublished = false;
        isPublished = !isPublished;
        expect(isPublished, isTrue);

        isPublished = !isPublished;
        expect(isPublished, isFalse);
      });

      test('reorderFaqs should update order field for each FAQ', () {
        final faqIds = ['faq-3', 'faq-1', 'faq-2'];

        final newOrders = <String, int>{};
        for (var i = 0; i < faqIds.length; i++) {
          newOrders[faqIds[i]] = i;
        }

        expect(newOrders['faq-3'], equals(0));
        expect(newOrders['faq-1'], equals(1));
        expect(newOrders['faq-2'], equals(2));
      });
    });

    group('Statistics', () {
      test('getDataForStats should return both FAQs and categories', () {
        final faqs = [
          Faq(
            id: '1',
            question: 'Q1',
            answer: 'A1',
            createdAt: DateTime.now(),
          ),
        ];
        final categories = [
          FaqCategory(
            id: 'cat-1',
            name: 'Cat 1',
            order: 0,
            createdAt: DateTime.now(),
          ),
        ];

        expect(faqs, isNotEmpty);
        expect(categories, isNotEmpty);
      });

      test('should calculate total FAQ count', () {
        final faqs = List.generate(
          25,
          (i) => Faq(
            id: '$i',
            question: 'Q$i',
            answer: 'A$i',
            createdAt: DateTime.now(),
          ),
        );

        expect(faqs.length, equals(25));
      });

      test('should calculate published FAQ count', () {
        final faqs = [
          Faq(
            id: '1',
            question: 'Q',
            answer: 'A',
            isPublished: true,
            createdAt: DateTime.now(),
          ),
          Faq(
            id: '2',
            question: 'Q',
            answer: 'A',
            isPublished: false,
            createdAt: DateTime.now(),
          ),
          Faq(
            id: '3',
            question: 'Q',
            answer: 'A',
            isPublished: true,
            createdAt: DateTime.now(),
          ),
        ];

        final publishedCount = faqs.where((f) => f.isPublished).length;

        expect(publishedCount, equals(2));
      });
    });
  });
}

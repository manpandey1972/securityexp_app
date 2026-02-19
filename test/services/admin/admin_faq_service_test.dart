import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:securityexperts_app/core/auth/role_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';
import 'package:securityexperts_app/features/admin/data/repositories/admin_faq_repository.dart';
import 'package:securityexperts_app/features/admin/services/admin_faq_service.dart';

@GenerateMocks([
  AdminFaqRepository,
  FirebaseAuth,
  User,
  RoleService,
  AppLogger,
])
import 'admin_faq_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdminFaqService service;
  late MockAdminFaqRepository mockRepository;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockRoleService mockRoleService;
  late MockAppLogger mockLogger;

  setUp(() {
    mockRepository = MockAdminFaqRepository();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockRoleService = MockRoleService();
    mockLogger = MockAppLogger();

    // Setup auth
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_admin_id');

    // Setup default permission - allow all by default for most tests
    when(mockRoleService.hasPermission(any)).thenAnswer((_) async => true);

    // Register mocks in service locator
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockLogger);

    if (sl.isRegistered<RoleService>()) {
      sl.unregister<RoleService>();
    }
    sl.registerSingleton<RoleService>(mockRoleService);

    service = AdminFaqService(
      repository: mockRepository,
      auth: mockAuth,
      roleService: mockRoleService,
      logger: mockLogger,
    );
  });

  tearDown(() {
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    if (sl.isRegistered<RoleService>()) {
      sl.unregister<RoleService>();
    }
  });

  group('AdminFaqService', () {
    group('FaqCategory model', () {
      test('should create FaqCategory with all fields', () {
        final category = FaqCategory(
          id: 'cat_1',
          name: 'Getting Started',
          description: 'Beginner FAQs',
          icon: '🚀',
          order: 1,
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
        );

        expect(category.id, 'cat_1');
        expect(category.name, 'Getting Started');
        expect(category.description, 'Beginner FAQs');
        expect(category.icon, '🚀');
        expect(category.order, 1);
        expect(category.isActive, true);
      });

      test('should create FaqCategory with default values', () {
        final category = FaqCategory(
          id: 'cat_1',
          name: 'Test',
          order: 0,
          createdAt: DateTime(2024, 1, 1),
        );

        expect(category.isActive, true);
        expect(category.description, isNull);
        expect(category.icon, isNull);
      });

      test('copyWith should create new instance with updated fields', () {
        final original = FaqCategory(
          id: 'cat_1',
          name: 'Original',
          order: 1,
          createdAt: DateTime(2024, 1, 1),
        );

        final updated = original.copyWith(name: 'Updated', order: 2);

        expect(updated.id, 'cat_1');
        expect(updated.name, 'Updated');
        expect(updated.order, 2);
        expect(original.name, 'Original'); // Original unchanged
      });
    });

    group('Faq model', () {
      test('should create Faq with all fields', () {
        final faq = Faq(
          id: 'faq_1',
          question: 'How do I get started?',
          answer: 'Follow these steps...',
          categoryId: 'cat_1',
          tags: ['beginner', 'setup'],
          order: 1,
          isPublished: true,
          viewCount: 100,
          helpfulCount: 50,
          notHelpfulCount: 5,
          createdAt: DateTime(2024, 1, 1),
        );

        expect(faq.id, 'faq_1');
        expect(faq.question, 'How do I get started?');
        expect(faq.answer, 'Follow these steps...');
        expect(faq.categoryId, 'cat_1');
        expect(faq.tags, ['beginner', 'setup']);
        expect(faq.isPublished, true);
        expect(faq.viewCount, 100);
        expect(faq.helpfulCount, 50);
      });

      test('should create Faq with default values', () {
        final faq = Faq(
          id: 'faq_1',
          question: 'Test question?',
          answer: 'Test answer',
          createdAt: DateTime.now(),
        );

        expect(faq.tags, isEmpty);
        expect(faq.isPublished, true);
        expect(faq.viewCount, 0);
        expect(faq.helpfulCount, 0);
        expect(faq.notHelpfulCount, 0);
      });

      test('copyWith should create new instance with updated fields', () {
        final original = Faq(
          id: 'faq_1',
          question: 'Original?',
          answer: 'Original answer',
          createdAt: DateTime.now(),
        );

        final updated = original.copyWith(
          question: 'Updated?',
          isPublished: true,
        );

        expect(updated.id, 'faq_1');
        expect(updated.question, 'Updated?');
        expect(updated.isPublished, true);
        expect(original.question, 'Original?'); // Original unchanged
      });
    });

    group('getCategories', () {
      test('should return list of categories', () async {
        final categories = [
          FaqCategory(
            id: 'cat_1',
            name: 'Getting Started',
            description: 'First steps',
            icon: '🚀',
            order: 0,
            isActive: true,
            createdAt: DateTime(2024, 1, 1),
          ),
          FaqCategory(
            id: 'cat_2',
            name: 'Advanced',
            description: 'Advanced topics',
            icon: '⚡',
            order: 1,
            isActive: true,
            createdAt: DateTime(2024, 1, 2),
          ),
        ];

        when(mockRepository.getCategories()).thenAnswer((_) async => categories);

        final result = await service.getCategories();

        expect(result.length, 2);
        expect(result[0].id, 'cat_1');
        expect(result[0].name, 'Getting Started');
        expect(result[1].id, 'cat_2');
        expect(result[1].name, 'Advanced');
        verify(mockRoleService.hasPermission(AdminPermission.manageFaqs)).called(1);
      });

      test('should return empty list on error', () async {
        when(mockRepository.getCategories()).thenThrow(Exception('Network error'));

        final result = await service.getCategories();

        expect(result, isEmpty);
        verify(mockLogger.error(any, tag: 'AdminFaqService')).called(1);
      });

      test('should throw when permission denied', () async {
        when(mockRoleService.hasPermission(AdminPermission.manageFaqs))
            .thenAnswer((_) async => false);

        expect(() => service.getCategories(), throwsException);
      });
    });

    group('createCategory', () {
      test('should create category and return document ID', () async {
        when(mockRepository.createCategory(
          name: anyNamed('name'),
          description: anyNamed('description'),
          icon: anyNamed('icon'),
          order: anyNamed('order'),
          isActive: anyNamed('isActive'),
        )).thenAnswer((_) async => 'new_cat_id');

        final result = await service.createCategory(
          name: 'New Category',
          description: 'Test description',
          icon: '📋',
          order: 5,
        );

        expect(result, 'new_cat_id');
        verify(mockRepository.createCategory(
          name: 'New Category',
          description: 'Test description',
          icon: '📋',
          order: 5,
          isActive: true,
        )).called(1);
        verify(mockLogger.info(any, tag: 'AdminFaqService')).called(1);
      });

      test('should return null on error', () async {
        when(mockRepository.createCategory(
          name: anyNamed('name'),
          description: anyNamed('description'),
          icon: anyNamed('icon'),
          order: anyNamed('order'),
          isActive: anyNamed('isActive'),
        )).thenThrow(Exception('Write error'));

        final result = await service.createCategory(name: 'Test');

        expect(result, isNull);
        verify(mockLogger.error(any, tag: 'AdminFaqService')).called(1);
      });
    });

    group('updateCategory', () {
      test('should update category and return true', () async {
        when(mockRepository.updateCategory(
          any,
          name: anyNamed('name'),
          description: anyNamed('description'),
          icon: anyNamed('icon'),
          order: anyNamed('order'),
          isActive: anyNamed('isActive'),
        )).thenAnswer((_) async {});

        final result = await service.updateCategory(
          'cat_1',
          name: 'Updated Name',
          isActive: false,
        );

        expect(result, true);
        verify(mockRepository.updateCategory(
          'cat_1',
          name: 'Updated Name',
          isActive: false,
        )).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.updateCategory(
          any,
          name: anyNamed('name'),
          description: anyNamed('description'),
          icon: anyNamed('icon'),
          order: anyNamed('order'),
          isActive: anyNamed('isActive'),
        )).thenThrow(Exception('Update error'));

        final result = await service.updateCategory('cat_1', name: 'Test');

        expect(result, false);
      });
    });

    group('deleteCategory', () {
      test('should delete category without FAQs and return true', () async {
        when(mockRepository.categoryHasFaqs('cat_1')).thenAnswer((_) async => false);
        when(mockRepository.deleteCategory('cat_1')).thenAnswer((_) async {});

        final result = await service.deleteCategory('cat_1');

        expect(result, true);
        verify(mockRepository.deleteCategory('cat_1')).called(1);
      });

      test('should not delete category with existing FAQs', () async {
        when(mockRepository.categoryHasFaqs('cat_1')).thenAnswer((_) async => true);

        final result = await service.deleteCategory('cat_1');

        expect(result, false);
        verifyNever(mockRepository.deleteCategory(any));
      });
    });

    group('getFaqs', () {
      test('should return filtered FAQs', () async {
        final faqs = [
          Faq(
            id: 'faq_1',
            question: 'Test question?',
            answer: 'Test answer',
            categoryId: 'cat_1',
            tags: ['test'],
            order: 0,
            isPublished: true,
            viewCount: 10,
            helpfulCount: 5,
            notHelpfulCount: 1,
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        when(mockRepository.getFaqs(
          categoryId: anyNamed('categoryId'),
          isPublished: anyNamed('isPublished'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => faqs);

        final result = await service.getFaqs(
          categoryId: 'cat_1',
          isPublished: true,
        );

        expect(result.length, 1);
        expect(result[0].id, 'faq_1');
        expect(result[0].question, 'Test question?');
      });

      test('should apply client-side search filter', () async {
        final faqs = [
          Faq(
            id: 'faq_1',
            question: 'How to plant tomatoes?',
            answer: 'Follow these steps',
            tags: ['gardening'],
            isPublished: true,
            createdAt: DateTime(2024, 1, 1),
          ),
          Faq(
            id: 'faq_2',
            question: 'What is composting?',
            answer: 'Composting is a process',
            tags: ['compost'],
            isPublished: true,
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        when(mockRepository.getFaqs(
          categoryId: anyNamed('categoryId'),
          isPublished: anyNamed('isPublished'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => faqs);

        final result = await service.getFaqs(searchQuery: 'tomato');

        // Should only return FAQ containing "tomato"
        expect(result.length, 1);
        expect(result[0].question, contains('tomato'));
      });

      test('should return empty list on error', () async {
        when(mockRepository.getFaqs(
          categoryId: anyNamed('categoryId'),
          isPublished: anyNamed('isPublished'),
          limit: anyNamed('limit'),
        )).thenThrow(Exception('Query error'));

        final result = await service.getFaqs();

        expect(result, isEmpty);
      });
    });

    group('getFaq', () {
      test('should return FAQ by ID', () async {
        final faq = Faq(
          id: 'faq_1',
          question: 'Test?',
          answer: 'Test answer',
          tags: [],
          isPublished: true,
          viewCount: 0,
          helpfulCount: 0,
          notHelpfulCount: 0,
          createdAt: DateTime(2024, 1, 1),
        );

        when(mockRepository.getFaq('faq_1')).thenAnswer((_) async => faq);

        final result = await service.getFaq('faq_1');

        expect(result, isNotNull);
        expect(result!.id, 'faq_1');
      });

      test('should return null for non-existent FAQ', () async {
        when(mockRepository.getFaq('faq_999')).thenAnswer((_) async => null);

        final result = await service.getFaq('faq_999');

        expect(result, isNull);
      });
    });

    group('createFaq', () {
      test('should create FAQ and return document ID', () async {
        when(mockRepository.createFaq(
          question: anyNamed('question'),
          answer: anyNamed('answer'),
          categoryId: anyNamed('categoryId'),
          tags: anyNamed('tags'),
          isPublished: anyNamed('isPublished'),
          order: anyNamed('order'),
          createdBy: anyNamed('createdBy'),
        )).thenAnswer((_) async => 'new_faq_id');

        final result = await service.createFaq(
          question: 'How do I start?',
          answer: 'Follow these steps...',
          categoryId: 'cat_1',
          tags: ['beginner'],
          isPublished: true,
        );

        expect(result, 'new_faq_id');
        verify(mockRepository.createFaq(
          question: 'How do I start?',
          answer: 'Follow these steps...',
          categoryId: 'cat_1',
          tags: ['beginner'],
          isPublished: true,
          order: 0,
          createdBy: 'test_admin_id',
        )).called(1);
      });

      test('should return null on error', () async {
        when(mockRepository.createFaq(
          question: anyNamed('question'),
          answer: anyNamed('answer'),
          categoryId: anyNamed('categoryId'),
          tags: anyNamed('tags'),
          isPublished: anyNamed('isPublished'),
          order: anyNamed('order'),
          createdBy: anyNamed('createdBy'),
        )).thenThrow(Exception('Write error'));

        final result = await service.createFaq(
          question: 'Test',
          answer: 'Test',
          categoryId: 'cat_1',
        );

        expect(result, isNull);
      });
    });

    group('updateFaq', () {
      test('should update FAQ fields and return true', () async {
        when(mockRepository.updateFaq(
          any,
          question: anyNamed('question'),
          answer: anyNamed('answer'),
          categoryId: anyNamed('categoryId'),
          tags: anyNamed('tags'),
          isPublished: anyNamed('isPublished'),
          order: anyNamed('order'),
          updatedBy: anyNamed('updatedBy'),
        )).thenAnswer((_) async {});

        final result = await service.updateFaq(
          'faq_1',
          question: 'Updated question?',
          answer: 'Updated answer',
          isPublished: true,
        );

        expect(result, true);
        verify(mockRepository.updateFaq(
          'faq_1',
          question: 'Updated question?',
          answer: 'Updated answer',
          isPublished: true,
          updatedBy: 'test_admin_id',
        )).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.updateFaq(
          any,
          question: anyNamed('question'),
          answer: anyNamed('answer'),
          categoryId: anyNamed('categoryId'),
          tags: anyNamed('tags'),
          isPublished: anyNamed('isPublished'),
          order: anyNamed('order'),
          updatedBy: anyNamed('updatedBy'),
        )).thenThrow(Exception('Update error'));

        final result = await service.updateFaq('faq_1', question: 'Test');

        expect(result, false);
      });
    });

    group('deleteFaq', () {
      test('should delete FAQ and return true', () async {
        when(mockRepository.deleteFaq('faq_1')).thenAnswer((_) async {});

        final result = await service.deleteFaq('faq_1');

        expect(result, true);
        verify(mockRepository.deleteFaq('faq_1')).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.deleteFaq('faq_1')).thenThrow(Exception('Delete error'));

        final result = await service.deleteFaq('faq_1');

        expect(result, false);
      });
    });

    group('togglePublished', () {
      test('should toggle published status', () async {
        when(mockRepository.togglePublished('faq_1')).thenAnswer((_) async => true);

        final result = await service.togglePublished('faq_1');

        expect(result, true);
        verify(mockRepository.togglePublished('faq_1')).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.togglePublished('faq_999'))
            .thenThrow(Exception('Toggle error'));

        final result = await service.togglePublished('faq_999');

        expect(result, false);
      });
    });

    group('reorderFaqs', () {
      test('should reorder FAQs', () async {
        when(mockRepository.reorderFaqs(any)).thenAnswer((_) async {});

        final result = await service.reorderFaqs(['faq_1', 'faq_2']);

        expect(result, true);
        verify(mockRepository.reorderFaqs(['faq_1', 'faq_2'])).called(1);
      });

      test('should return false on error', () async {
        when(mockRepository.reorderFaqs(any)).thenThrow(Exception('Reorder error'));

        final result = await service.reorderFaqs(['faq_1', 'faq_2']);

        expect(result, false);
      });
    });

    group('getStats', () {
      test('should return FAQ statistics', () async {
        final faqs = [
          Faq(
            id: 'faq_1',
            question: 'Q1?',
            answer: 'A1',
            isPublished: true,
            viewCount: 100,
            createdAt: DateTime(2024, 1, 1),
          ),
          Faq(
            id: 'faq_2',
            question: 'Q2?',
            answer: 'A2',
            isPublished: false,
            viewCount: 50,
            createdAt: DateTime(2024, 1, 1),
          ),
        ];

        final categories = <FaqCategory>[];

        when(mockRepository.getDataForStats())
            .thenAnswer((_) async => (faqs: faqs, categories: categories));

        final result = await service.getStats();

        expect(result['totalFaqs'], 2);
        expect(result['publishedFaqs'], 1);
        expect(result['draftFaqs'], 1);
        expect(result['totalViews'], 150);
      });

      test('should return empty map on error', () async {
        when(mockRepository.getDataForStats()).thenThrow(Exception('Query error'));

        final result = await service.getStats();

        expect(result, isEmpty);
      });
    });
  });
}

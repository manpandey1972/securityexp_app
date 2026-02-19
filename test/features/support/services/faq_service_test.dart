import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:securityexperts_app/features/support/services/faq_service.dart';
import 'package:securityexperts_app/features/admin/data/models/faq.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  DocumentReference,
  AppLogger,
])
import 'faq_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FaqService faqService;
  late MockFirebaseFirestore mockFirestore;
  late MockAppLogger mockLogger;
  late MockCollectionReference<Map<String, dynamic>> mockFaqsCollection;
  late MockCollectionReference<Map<String, dynamic>> mockCategoriesCollection;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuery<Map<String, dynamic>> mockOrderedQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockLogger = MockAppLogger();
    mockFaqsCollection = MockCollectionReference<Map<String, dynamic>>();
    mockCategoriesCollection = MockCollectionReference<Map<String, dynamic>>();
    mockQuery = MockQuery<Map<String, dynamic>>();
    mockOrderedQuery = MockQuery<Map<String, dynamic>>();
    mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();

    // Setup collection mocks
    when(mockFirestore.collection('faqs')).thenReturn(mockFaqsCollection);
    when(mockFirestore.collection('faq_categories')).thenReturn(mockCategoriesCollection);

    faqService = FaqService(
      firestore: mockFirestore,
      logger: mockLogger,
    );
  });

  group('FaqService', () {
    group('getPublishedFaqs', () {
      test('should return list of published FAQs', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

        when(mockDoc1.id).thenReturn('faq1');
        when(mockDoc1.data()).thenReturn({
          'question': 'How to reset password?',
          'answer': 'Go to settings and click reset.',
          'categoryId': 'account',
          'isPublished': true,
          'order': 1,
          'viewCount': 100,
          'helpfulCount': 80,
          'notHelpfulCount': 5,
          'createdAt': Timestamp.now(),
        });

        when(mockDoc2.id).thenReturn('faq2');
        when(mockDoc2.data()).thenReturn({
          'question': 'How to contact support?',
          'answer': 'Use the help center.',
          'categoryId': 'support',
          'isPublished': true,
          'order': 2,
          'viewCount': 50,
          'helpfulCount': 40,
          'notHelpfulCount': 2,
          'createdAt': Timestamp.now(),
        });

        when(mockFaqsCollection.where('isPublished', isEqualTo: true))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('order')).thenReturn(mockOrderedQuery);
        when(mockOrderedQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

        // Act
        final result = await faqService.getPublishedFaqs();

        // Assert
        expect(result.length, 2);
        expect(result[0].question, 'How to reset password?');
        expect(result[1].question, 'How to contact support?');
        verify(mockLogger.debug(any, tag: 'FaqService')).called(2);
      });

      test('should return empty list on error', () async {
        // Arrange
        when(mockFaqsCollection.where('isPublished', isEqualTo: true))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('order')).thenReturn(mockOrderedQuery);
        when(mockOrderedQuery.get()).thenThrow(Exception('Firestore error'));

        // Act
        final result = await faqService.getPublishedFaqs();

        // Assert
        expect(result, isEmpty);
        verify(mockLogger.error(any, tag: 'FaqService')).called(1);
      });

      test('should return empty list when no FAQs published', () async {
        // Arrange
        when(mockFaqsCollection.where('isPublished', isEqualTo: true))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('order')).thenReturn(mockOrderedQuery);
        when(mockOrderedQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Act
        final result = await faqService.getPublishedFaqs();

        // Assert
        expect(result, isEmpty);
      });
    });

    group('getPublishedFaqsByCategory', () {
      test('should group FAQs by category', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc3 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

        when(mockDoc1.id).thenReturn('faq1');
        when(mockDoc1.data()).thenReturn({
          'question': 'Question 1',
          'answer': 'Answer 1',
          'categoryId': 'account',
          'isPublished': true,
          'order': 1,
          'createdAt': Timestamp.now(),
        });

        when(mockDoc2.id).thenReturn('faq2');
        when(mockDoc2.data()).thenReturn({
          'question': 'Question 2',
          'answer': 'Answer 2',
          'categoryId': 'account',
          'isPublished': true,
          'order': 2,
          'createdAt': Timestamp.now(),
        });

        when(mockDoc3.id).thenReturn('faq3');
        when(mockDoc3.data()).thenReturn({
          'question': 'Question 3',
          'answer': 'Answer 3',
          'categoryId': 'support',
          'isPublished': true,
          'order': 1,
          'createdAt': Timestamp.now(),
        });

        when(mockFaqsCollection.where('isPublished', isEqualTo: true))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('order')).thenReturn(mockOrderedQuery);
        when(mockOrderedQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);

        // Act
        final result = await faqService.getPublishedFaqsByCategory();

        // Assert
        expect(result.keys.length, 2);
        expect(result['account']?.length, 2);
        expect(result['support']?.length, 1);
      });

      test('should use uncategorized for FAQs without category', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

        when(mockDoc.id).thenReturn('faq1');
        when(mockDoc.data()).thenReturn({
          'question': 'Question 1',
          'answer': 'Answer 1',
          'categoryId': null,
          'isPublished': true,
          'order': 1,
          'createdAt': Timestamp.now(),
        });

        when(mockFaqsCollection.where('isPublished', isEqualTo: true))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('order')).thenReturn(mockOrderedQuery);
        when(mockOrderedQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        // Act
        final result = await faqService.getPublishedFaqsByCategory();

        // Assert
        expect(result.containsKey('uncategorized'), true);
        expect(result['uncategorized']?.length, 1);
      });

      test('should return empty map on error', () async {
        // Arrange
        when(mockFaqsCollection.where('isPublished', isEqualTo: true))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('order')).thenReturn(mockOrderedQuery);
        when(mockOrderedQuery.get()).thenThrow(Exception('Error'));

        // Act
        final result = await faqService.getPublishedFaqsByCategory();

        // Assert
        expect(result, isEmpty);
      });
    });

    group('getCategories', () {
      test('should return list of active categories', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

        when(mockDoc.id).thenReturn('cat1');
        when(mockDoc.data()).thenReturn({
          'name': 'Account',
          'description': 'Account related questions',
          'icon': 'account_circle',
          'order': 1,
          'isActive': true,
          'createdAt': Timestamp.now(),
        });

        final mockCatQuery = MockQuery<Map<String, dynamic>>();
        final mockCatOrderedQuery = MockQuery<Map<String, dynamic>>();
        final mockCatSnapshot = MockQuerySnapshot<Map<String, dynamic>>();

        when(mockCategoriesCollection.where('isActive', isEqualTo: true))
            .thenReturn(mockCatQuery);
        when(mockCatQuery.orderBy('order')).thenReturn(mockCatOrderedQuery);
        when(mockCatOrderedQuery.get()).thenAnswer((_) async => mockCatSnapshot);
        when(mockCatSnapshot.docs).thenReturn([mockDoc]);

        // Act
        final result = await faqService.getCategories();

        // Assert
        expect(result.length, 1);
        expect(result[0].name, 'Account');
        expect(result[0].description, 'Account related questions');
      });

      test('should return empty list on error', () async {
        // Arrange
        final mockCatQuery = MockQuery<Map<String, dynamic>>();

        when(mockCategoriesCollection.where('isActive', isEqualTo: true))
            .thenReturn(mockCatQuery);
        when(mockCatQuery.orderBy('order')).thenThrow(Exception('Error'));

        // Act
        final result = await faqService.getCategories();

        // Assert
        expect(result, isEmpty);
      });
    });

    group('recordFaqView', () {
      test('should increment view count', () async {
        // Arrange
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(mockFaqsCollection.doc('faq1')).thenReturn(mockDocRef);
        when(mockDocRef.update(any)).thenAnswer((_) async {});

        // Act
        await faqService.recordFaqView('faq1');

        // Assert
        verify(mockDocRef.update({'viewCount': FieldValue.increment(1)})).called(1);
        verify(mockLogger.debug(any, tag: 'FaqService')).called(1);
      });

      test('should handle error gracefully', () async {
        // Arrange
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(mockFaqsCollection.doc('faq1')).thenReturn(mockDocRef);
        when(mockDocRef.update(any)).thenThrow(Exception('Error'));

        // Act
        await faqService.recordFaqView('faq1');

        // Assert
        verify(mockLogger.error(any, tag: 'FaqService')).called(1);
      });
    });

    group('markFaqHelpful', () {
      test('should increment helpful count', () async {
        // Arrange
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(mockFaqsCollection.doc('faq1')).thenReturn(mockDocRef);
        when(mockDocRef.update(any)).thenAnswer((_) async {});

        // Act
        await faqService.markFaqHelpful('faq1');

        // Assert
        verify(mockDocRef.update({'helpfulCount': FieldValue.increment(1)})).called(1);
      });

      test('should handle error gracefully', () async {
        // Arrange
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(mockFaqsCollection.doc('faq1')).thenReturn(mockDocRef);
        when(mockDocRef.update(any)).thenThrow(Exception('Error'));

        // Act
        await faqService.markFaqHelpful('faq1');

        // Assert
        verify(mockLogger.error(any, tag: 'FaqService')).called(1);
      });
    });

    group('markFaqNotHelpful', () {
      test('should increment not helpful count', () async {
        // Arrange
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(mockFaqsCollection.doc('faq1')).thenReturn(mockDocRef);
        when(mockDocRef.update(any)).thenAnswer((_) async {});

        // Act
        await faqService.markFaqNotHelpful('faq1');

        // Assert
        verify(mockDocRef.update({'notHelpfulCount': FieldValue.increment(1)})).called(1);
      });

      test('should handle error gracefully', () async {
        // Arrange
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(mockFaqsCollection.doc('faq1')).thenReturn(mockDocRef);
        when(mockDocRef.update(any)).thenThrow(Exception('Error'));

        // Act
        await faqService.markFaqNotHelpful('faq1');

        // Assert
        verify(mockLogger.error(any, tag: 'FaqService')).called(1);
      });
    });
  });

  group('Faq Model', () {
    test('should calculate helpfulness score correctly', () {
      final faq = Faq(
        id: 'test',
        question: 'Test question',
        answer: 'Test answer',
        helpfulCount: 80,
        notHelpfulCount: 20,
        createdAt: DateTime.now(),
      );

      expect(faq.helpfulnessScore, 80.0);
    });

    test('should return 0 helpfulness score when no votes', () {
      final faq = Faq(
        id: 'test',
        question: 'Test question',
        answer: 'Test answer',
        helpfulCount: 0,
        notHelpfulCount: 0,
        createdAt: DateTime.now(),
      );

      expect(faq.helpfulnessScore, 0.0);
    });

    test('should create Faq with copyWith', () {
      final original = Faq(
        id: 'test',
        question: 'Original question',
        answer: 'Original answer',
        createdAt: DateTime.now(),
      );

      final copied = original.copyWith(
        question: 'Updated question',
        isPublished: false,
      );

      expect(copied.id, 'test');
      expect(copied.question, 'Updated question');
      expect(copied.answer, 'Original answer');
      expect(copied.isPublished, false);
    });

    test('should convert to Firestore map', () {
      final now = DateTime.now();
      final faq = Faq(
        id: 'test',
        question: 'Test question',
        answer: 'Test answer',
        categoryId: 'cat1',
        tags: ['tag1', 'tag2'],
        order: 5,
        isPublished: true,
        viewCount: 100,
        helpfulCount: 80,
        notHelpfulCount: 10,
        createdAt: now,
      );

      final map = faq.toFirestore();

      expect(map['question'], 'Test question');
      expect(map['answer'], 'Test answer');
      expect(map['categoryId'], 'cat1');
      expect(map['tags'], ['tag1', 'tag2']);
      expect(map['order'], 5);
      expect(map['isPublished'], true);
      expect(map['viewCount'], 100);
    });
  });

  group('FaqCategory Model', () {
    test('should create FaqCategory with copyWith', () {
      final original = FaqCategory(
        id: 'cat1',
        name: 'Original Name',
        order: 1,
        createdAt: DateTime.now(),
      );

      final copied = original.copyWith(
        name: 'Updated Name',
        isActive: false,
      );

      expect(copied.id, 'cat1');
      expect(copied.name, 'Updated Name');
      expect(copied.isActive, false);
    });

    test('should convert to Firestore map', () {
      final now = DateTime.now();
      final category = FaqCategory(
        id: 'cat1',
        name: 'Test Category',
        description: 'Test description',
        icon: 'test_icon',
        order: 1,
        isActive: true,
        createdAt: now,
      );

      final map = category.toFirestore();

      expect(map['name'], 'Test Category');
      expect(map['description'], 'Test description');
      expect(map['icon'], 'test_icon');
      expect(map['order'], 1);
      expect(map['isActive'], true);
    });
  });
}

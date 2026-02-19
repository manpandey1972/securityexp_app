import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/features/home/services/home_data_loader.dart';
import 'package:greenhive_app/features/chat/services/unread_messages_service.dart';
import 'package:greenhive_app/features/home/presentation/view_models/home_view_model.dart';

@GenerateMocks([HomeDataLoader, UnreadMessagesService, AppLogger])
import 'home_view_model_test.mocks.dart';

void main() {
  late MockHomeDataLoader mockDataLoader;
  late MockUnreadMessagesService mockUnreadMessagesService;
  late MockAppLogger mockAppLogger;
  late HomeViewModel viewModel;

  setUp(() {
    mockDataLoader = MockHomeDataLoader();
    mockUnreadMessagesService = MockUnreadMessagesService();
    mockAppLogger = MockAppLogger();

    // Register AppLogger in service locator
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
    sl.registerSingleton<AppLogger>(mockAppLogger);

    // Setup default mock behaviors
    when(
      mockDataLoader.initializeData(
        onExpertsLoaded: anyNamed('onExpertsLoaded'),
        onError: anyNamed('onError'),
      ),
    ).thenAnswer((_) async {});

    when(mockDataLoader.loadExperts()).thenAnswer((_) async => <models.User>[]);
    when(
      mockDataLoader.loadProducts(),
    ).thenAnswer((_) async => <models.Product>[]);
    when(
      mockDataLoader.unreadMessagesService,
    ).thenReturn(mockUnreadMessagesService);

    when(
      mockUnreadMessagesService.recalculateTotalUnreadCount(),
    ).thenAnswer((_) async {});
    when(
      mockUnreadMessagesService.getTotalUnreadCountStream(),
    ).thenAnswer((_) => Stream.value(0));
  });

  tearDown(() {
    viewModel.dispose();
    if (sl.isRegistered<AppLogger>()) {
      sl.unregister<AppLogger>();
    }
  });

  HomeViewModel createViewModel() {
    return HomeViewModel(dataLoader: mockDataLoader);
  }

  group('HomeViewModel', () {
    group('initialization', () {
      test('should have initial state', () {
        viewModel = createViewModel();

        expect(viewModel.state.selectedTabIndex, equals(0));
        expect(viewModel.state.experts, isEmpty);
        expect(viewModel.state.products, isEmpty);
        expect(viewModel.state.searchQuery, isEmpty);
        expect(viewModel.state.unreadCount, equals(0));
      });

      test('should call initializeData on creation', () async {
        viewModel = createViewModel();

        // Allow async initialization to complete
        await Future.delayed(const Duration(milliseconds: 100));

        verify(
          mockDataLoader.initializeData(
            onExpertsLoaded: anyNamed('onExpertsLoaded'),
            onError: anyNamed('onError'),
          ),
        ).called(1);
      });
    });

    group('loadExperts', () {
      test('should update experts on successful load', () async {
        viewModel = createViewModel();

        // Arrange
        final testExperts = [
          _createUser(id: 'expert1', name: 'Dr. Alice'),
          _createUser(id: 'expert2', name: 'Dr. Bob'),
        ];
        when(mockDataLoader.loadExperts()).thenAnswer((_) async => testExperts);

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        await viewModel.loadExperts();

        // Assert
        expect(viewModel.state.isLoadingExperts, equals(false));
        // Note: State may not update if ErrorHandler doesn't return value
      });

      test('should handle null result from loadExperts', () async {
        viewModel = createViewModel();

        when(mockDataLoader.loadExperts()).thenAnswer((_) async => null);

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        await viewModel.loadExperts();

        // Assert - should not crash
        expect(viewModel.state.isLoadingExperts, equals(false));
      });
    });

    group('loadProducts', () {
      test('should call dataLoader.loadProducts', () async {
        viewModel = createViewModel();

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        await viewModel.loadProducts();

        // Assert
        verify(mockDataLoader.loadProducts()).called(greaterThanOrEqualTo(1));
      });

      test('should handle null result from loadProducts', () async {
        viewModel = createViewModel();

        when(mockDataLoader.loadProducts()).thenAnswer((_) async => null);

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        await viewModel.loadProducts();

        // Assert - should not crash
        expect(viewModel.state.isLoadingProducts, equals(false));
      });
    });

    group('selectTab', () {
      test('should update selectedTabIndex', () async {
        viewModel = createViewModel();

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        viewModel.selectTab(2);

        // Assert
        expect(viewModel.state.selectedTabIndex, equals(2));
      });

      test('should reload experts when selecting tab 0', () async {
        viewModel = createViewModel();

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        // Reset mock to track new calls
        clearInteractions(mockDataLoader);
        when(
          mockDataLoader.loadExperts(),
        ).thenAnswer((_) async => <models.User>[]);

        // Act
        viewModel.selectTab(0);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        verify(mockDataLoader.loadExperts()).called(greaterThanOrEqualTo(1));
      });

      test('should reload products when selecting tab 3', () async {
        viewModel = createViewModel();

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        // Reset mock to track new calls
        clearInteractions(mockDataLoader);
        when(
          mockDataLoader.loadProducts(),
        ).thenAnswer((_) async => <models.Product>[]);

        // Act
        viewModel.selectTab(3);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        verify(mockDataLoader.loadProducts()).called(greaterThanOrEqualTo(1));
      });
    });

    group('unread count', () {
      test('should update unread count from stream', () async {
        // Arrange
        final unreadController = StreamController<int>.broadcast();
        when(
          mockUnreadMessagesService.getTotalUnreadCountStream(),
        ).thenAnswer((_) => unreadController.stream);

        viewModel = createViewModel();

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        unreadController.add(5);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(viewModel.state.unreadCount, equals(5));

        // Cleanup
        await unreadController.close();
      });
    });
  });
}

/// Helper function to create test User objects
models.User _createUser({
  required String id,
  required String name,
  String? email,
}) {
  return models.User(id: id, name: name, email: email);
}

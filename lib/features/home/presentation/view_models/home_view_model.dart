import 'dart:async';
import 'package:flutter/material.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/features/home/services/home_data_loader.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/shared/services/event_bus.dart';
import '../state/home_state.dart';

/// ViewModel for HomePage - manages all business logic and state
/// Uses ChangeNotifier pattern to notify UI of state changes
class HomeViewModel extends ChangeNotifier {
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'HomeViewModel';
  
  final HomeDataLoader _dataLoader;

  HomeState _state = HomeState.initial();
  HomeState get state => _state;

  // Stream subscriptions
  StreamSubscription? _profileUpdatedSubscription;
  StreamSubscription? _unreadCountSubscription;

  // Callback for ChatsTab load triggering
  void Function()? _triggerChatLoad;
  void Function()? get triggerChatLoad => _triggerChatLoad;

  // Instance tracking for debugging
  static int _instanceCounter = 0;
  final int _instanceId;

  HomeViewModel({required HomeDataLoader dataLoader})
    : _dataLoader = dataLoader,
      _instanceId = ++_instanceCounter {
    _log.debug('Created', tag: _tag, data: {'instanceId': _instanceId, 'totalInstances': _instanceCounter});
    _initialize();
  }

  /// Initialize all data on startup
  Future<void> _initialize() async {
    await _dataLoader.initializeData(
      onExpertsLoaded: loadExperts,
      onError: () {
        _updateState(
          _state.copyWith(expertsError: 'Failed to initialize data'),
        );
      },
    );

    _initializeUnreadMessages();
    _setupEventListeners();
  }

  /// Setup event listeners
  void _setupEventListeners() {
    _profileUpdatedSubscription = EventBus().onProfileUpdated.listen((_) {
      loadProducts();
    });
  }

  /// Initialize unread messages stream
  void _initializeUnreadMessages() {
    final unreadService = _dataLoader.unreadMessagesService;
    unreadService.recalculateTotalUnreadCount();

    _unreadCountSubscription = unreadService.getTotalUnreadCountStream().listen(
      (count) {
        _updateState(_state.copyWith(unreadCount: count));
      },
      onError: (e) {
        // Silently handle errors in unread count stream
      },
    );
  }

  /// Load experts from data loader
  Future<void> loadExperts() async {
    _updateState(_state.copyWith(isLoadingExperts: true, expertsError: null));

    final result = await ErrorHandler.handle<List<User>?>(
      operation: () => _dataLoader.loadExperts(),
      fallback: null,
      onError: (error) {
        _updateState(
          _state.copyWith(
            expertsError: 'Failed to load experts. Please try again.',
          ),
        );
      },
    );

    if (result != null) {
      _updateState(_state.copyWith(experts: result));
    }

    _updateState(_state.copyWith(isLoadingExperts: false));
  }

  /// Load products from data loader
  Future<void> loadProducts() async {
    _updateState(_state.copyWith(isLoadingProducts: true, productsError: null));

    final result = await ErrorHandler.handle<List<Product>?>(
      operation: () => _dataLoader.loadProducts(),
      fallback: null,
      onError: (error) {
        _updateState(
          _state.copyWith(
            productsError: 'Failed to load products. Please try again.',
          ),
        );
      },
    );

    if (result != null) {
      _updateState(_state.copyWith(products: result));
    }

    _updateState(_state.copyWith(isLoadingProducts: false));
  }

  /// Handle tab selection with lazy loading
  void selectTab(int index) {
    // Clear search query and focus when switching away from experts tab
    if (_state.selectedTabIndex == 0 && index != 0 && (_state.searchQuery.isNotEmpty || _state.isSearchFocused)) {
      _updateState(_state.copyWith(
        selectedTabIndex: index, 
        searchQuery: '', 
        isSearchFocused: false,
      ));
    } else {
      _updateState(_state.copyWith(selectedTabIndex: index));
    }

    // Load experts when user selects the Experts tab
    if (index == 0) {
      loadExperts();
    }

    // Load products when user selects the Products tab
    if (index == 3) {
      loadProducts();
    }
    // Load chats when user selects the Chats tab
    if (index == 1) {
      if (_triggerChatLoad != null) {
        _triggerChatLoad!();
      }
    }
    // Calls tab - no reload needed (call history is managed from call screen)
    if (index == 2) {
      // Call history is now automatically persisted via Firestore
      // No need to reload anything here
    }
  }

  /// Update search query
  void updateSearchQuery(String query) {
    _updateState(_state.copyWith(searchQuery: query));
  }

  /// Update search focus state
  void setSearchFocused(bool focused) {
    _updateState(_state.copyWith(isSearchFocused: focused));
  }

  /// Register callback for ChatsTab load triggering
  void registerChatLoadCallback(void Function() callback) {
    _triggerChatLoad = callback;
  }

  /// Get search utilities from data loader
  dynamic get searchUtils => _dataLoader.searchUtils;

  /// Update state and notify listeners
  void _updateState(HomeState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    try {
      _log.debug('Disposing', tag: _tag, data: {'instanceId': _instanceId});
    } catch (_) {}
    _profileUpdatedSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }
}

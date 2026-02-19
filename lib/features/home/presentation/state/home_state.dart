import 'package:greenhive_app/data/models/models.dart';

/// Immutable state object for HomePage
/// Consolidates all state variables into a single object for better state management
class HomeState {
  final int selectedTabIndex;
  final bool isLoadingExperts;
  final String? expertsError;
  final List<User> experts;
  final bool isLoadingProducts;
  final String? productsError;
  final List<Product> products;
  final String searchQuery;
  final int unreadCount;
  final bool isSearchFocused;

  const HomeState({
    this.selectedTabIndex = 0,
    this.isLoadingExperts = true,
    this.expertsError,
    this.experts = const [],
    this.isLoadingProducts = false,
    this.productsError,
    this.products = const [],
    this.searchQuery = '',
    this.unreadCount = 0,
    this.isSearchFocused = false,
  });

  /// Create a copy of this state with some fields replaced
  HomeState copyWith({
    int? selectedTabIndex,
    bool? isLoadingExperts,
    String? expertsError,
    List<User>? experts,
    bool? isLoadingProducts,
    String? productsError,
    List<Product>? products,
    String? searchQuery,
    int? unreadCount,
    bool? isSearchFocused,
  }) {
    return HomeState(
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      isLoadingExperts: isLoadingExperts ?? this.isLoadingExperts,
      expertsError: expertsError ?? this.expertsError,
      experts: experts ?? this.experts,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      productsError: productsError ?? this.productsError,
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
      unreadCount: unreadCount ?? this.unreadCount,
      isSearchFocused: isSearchFocused ?? this.isSearchFocused,
    );
  }

  /// Create initial state
  factory HomeState.initial() => const HomeState();
}

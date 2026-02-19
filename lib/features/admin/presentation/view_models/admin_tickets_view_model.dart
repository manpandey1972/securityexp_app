import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/features/admin/presentation/state/admin_state.dart';
import 'package:securityexperts_app/features/admin/services/admin_ticket_service.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';

/// ViewModel for the admin tickets list page.
class AdminTicketsViewModel extends ChangeNotifier {
  final AdminTicketService _ticketService;
  final AppLogger _log;

  static const String _tag = 'AdminTicketsViewModel';
  static const int _pageSize = 20;

  AdminTicketsState _state = const AdminTicketsState();
  AdminTicketsState get state => _state;

  StreamSubscription? _ticketsSubscription;

  AdminTicketsViewModel({AdminTicketService? ticketService, AppLogger? logger})
    : _ticketService = ticketService ?? sl<AdminTicketService>(),
      _log = logger ?? sl<AppLogger>();

  /// Initialize and start watching tickets.
  Future<void> initialize() async {
    await loadTickets();
  }

  /// Load tickets with current filters.
  Future<void> loadTickets() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final tickets = await _ticketService.getAllTickets(
        statusFilter: _state.filters.status,
        priorityFilter: _state.filters.priority,
        categoryFilter: _state.filters.category,
        unassignedOnly: _state.filters.unassignedOnly,
        limit: _pageSize,
      );

      _state = _state.copyWith(
        isLoading: false,
        tickets: tickets,
        hasMore: tickets.length >= _pageSize,
      );
    } catch (e) {
      _log.error('Error loading tickets: $e', tag: _tag);
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to load tickets',
      );
    }

    notifyListeners();
  }

  /// Load more tickets for pagination.
  Future<void> loadMore() async {
    if (_state.isLoadingMore || !_state.hasMore || _state.tickets.isEmpty) {
      return;
    }

    _state = _state.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      // Get last document for pagination
      final lastTicketId = _state.tickets.last.id;
      final lastDoc = await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(lastTicketId)
          .get();

      final newTickets = await _ticketService.getAllTickets(
        statusFilter: _state.filters.status,
        priorityFilter: _state.filters.priority,
        categoryFilter: _state.filters.category,
        unassignedOnly: _state.filters.unassignedOnly,
        limit: _pageSize,
        startAfter: lastDoc,
      );

      _state = _state.copyWith(
        isLoadingMore: false,
        tickets: [..._state.tickets, ...newTickets],
        hasMore: newTickets.length >= _pageSize,
      );
    } catch (e) {
      _log.error('Error loading more tickets: $e', tag: _tag);
      _state = _state.copyWith(isLoadingMore: false);
    }

    notifyListeners();
  }

  /// Update filters and reload.
  void updateFilters(AdminTicketFilters filters) {
    _state = _state.copyWith(filters: filters);
    notifyListeners();
    loadTickets();
  }

  /// Set status filter.
  void setStatusFilter(TicketStatus? status) {
    updateFilters(
      _state.filters.copyWith(status: status, clearStatus: status == null),
    );
  }

  /// Set priority filter.
  void setPriorityFilter(TicketPriority? priority) {
    updateFilters(
      _state.filters.copyWith(
        priority: priority,
        clearPriority: priority == null,
      ),
    );
  }

  /// Set category filter.
  void setCategoryFilter(TicketCategory? category) {
    updateFilters(
      _state.filters.copyWith(
        category: category,
        clearCategory: category == null,
      ),
    );
  }

  /// Toggle unassigned only filter.
  void toggleUnassignedOnly() {
    updateFilters(
      _state.filters.copyWith(unassignedOnly: !_state.filters.unassignedOnly),
    );
  }

  /// Set search query (local filter).
  void setSearchQuery(String query) {
    _state = _state.copyWith(
      filters: _state.filters.copyWith(searchQuery: query),
    );
    notifyListeners();
  }

  /// Clear all filters.
  void clearFilters() {
    updateFilters(const AdminTicketFilters());
  }

  /// Refresh tickets.
  Future<void> refresh() async {
    await loadTickets();
  }

  @override
  void dispose() {
    _ticketsSubscription?.cancel();
    super.dispose();
  }
}

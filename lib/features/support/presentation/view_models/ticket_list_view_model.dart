import 'dart:async';

import 'package:flutter/material.dart';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import '../../data/models/models.dart';
import '../../services/support_service.dart';
import '../../services/support_analytics.dart';
import '../state/ticket_list_state.dart';

/// ViewModel for the ticket list page.
///
/// Manages loading, filtering, and real-time updates for support tickets.
class TicketListViewModel extends ChangeNotifier {
  final SupportService _supportService;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'TicketListViewModel';

  TicketListState _state = TicketListState.initial();
  TicketListState get state => _state;

  StreamSubscription<List<SupportTicket>>? _allTicketsSubscription;
  StreamSubscription<List<SupportTicket>>? _filteredTicketsSubscription;
  bool _isDisposed = false;

  TicketListViewModel({required SupportService supportService})
    : _supportService = supportService;

  /// Initialize the view model and start listening to tickets.
  void initialize() {
    _log.debug('Initializing ticket list', tag: _tag);
    _subscribeToAllTickets();
    _subscribeToFilteredTickets();
    _loadUnreadCount();
  }

  /// Subscribe to ALL tickets (without filter) for calculating counts.
  void _subscribeToAllTickets() {
    _allTicketsSubscription?.cancel();

    _allTicketsSubscription = _supportService
        .watchUserTickets(statusFilter: null)
        .listen(
          (tickets) {
            if (_isDisposed) return;

            _updateState(
              _state.copyWith(
                allTickets: tickets,
                clearError: true,
              ),
            );
          },
          onError: (error) {
            if (_isDisposed) return;
            _log.error('Error watching all tickets', error: error, tag: _tag);
          },
        );
  }

  /// Subscribe to filtered tickets for display.
  void _subscribeToFilteredTickets() {
    _filteredTicketsSubscription?.cancel();

    _filteredTicketsSubscription = _supportService
        .watchUserTickets(statusFilter: _state.statusFilter)
        .listen(
          (tickets) {
            if (_isDisposed) return;

            _updateState(
              _state.copyWith(
                tickets: tickets,
                isLoading: false,
                clearError: true,
              ),
            );
          },
          onError: (error) {
            if (_isDisposed) return;

            _log.error('Error watching filtered tickets', error: error, tag: _tag);
            _updateState(
              _state.copyWith(
                isLoading: false,
                error: 'Failed to load tickets. Pull to refresh.',
              ),
            );
          },
        );
  }

  /// Load unread ticket count.
  Future<void> _loadUnreadCount() async {
    final count = await _supportService.getUnreadTicketCount();
    if (!_isDisposed) {
      _updateState(_state.copyWith(unreadCount: count));
    }
  }

  /// Refresh tickets manually.
  Future<void> refresh() async {
    _log.debug('Refreshing tickets', tag: _tag);
    _updateState(_state.copyWith(isLoading: true, clearError: true));

    final result = await _supportService.getUserTickets(
      statusFilter: _state.statusFilter,
    );

    if (_isDisposed) return;

    if (result.isSuccess) {
      _updateState(_state.copyWith(tickets: result.value, isLoading: false));
    } else {
      _updateState(
        _state.copyWith(
          isLoading: false,
          error: result.error?.message ?? 'Failed to refresh',
        ),
      );
    }

    // Also refresh all tickets for counts
    final allResult = await _supportService.getUserTickets(statusFilter: null);
    if (allResult.isSuccess && !_isDisposed) {
      _updateState(_state.copyWith(allTickets: allResult.value));
    }

    await _loadUnreadCount();
  }

  /// Set status filter.
  void setStatusFilter(TicketStatus? status) {
    if (_state.statusFilter == status) return;

    _log.debug('Setting status filter: $status', tag: _tag);
    
    // Track filter change
    sl<SupportAnalytics>().trackTicketFiltered(statusFilter: status);
    
    _updateState(
      _state.copyWith(
        statusFilter: status,
        clearStatusFilter: status == null,
        isLoading: true,
      ),
    );

    // Re-subscribe to filtered tickets with new filter
    _subscribeToFilteredTickets();
  }

  /// Clear status filter.
  void clearStatusFilter() {
    setStatusFilter(null);
  }

  /// Get filtered tickets (client-side additional filtering if needed).
  List<SupportTicket> getFilteredTickets({TicketType? typeFilter}) {
    var tickets = _state.tickets;

    if (typeFilter != null) {
      tickets = tickets.where((t) => t.type == typeFilter).toList();
    }

    return tickets;
  }

  /// Update state and notify listeners.
  void _updateState(TicketListState newState) {
    _state = newState;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _allTicketsSubscription?.cancel();
    _filteredTicketsSubscription?.cancel();
    super.dispose();
  }
}

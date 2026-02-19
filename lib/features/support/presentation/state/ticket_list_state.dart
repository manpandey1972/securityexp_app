import 'package:flutter/foundation.dart';
import '../../data/models/models.dart';

/// State for ticket list view.
@immutable
class TicketListState {
  /// List of ALL user's support tickets (unfiltered).
  final List<SupportTicket> allTickets;

  /// List of filtered tickets based on current filter.
  final List<SupportTicket> tickets;

  /// Whether tickets are currently loading.
  final bool isLoading;

  /// Error message if loading failed.
  final String? error;

  /// Current filter for ticket status.
  final TicketStatus? statusFilter;

  /// Count of tickets with unread support messages.
  final int unreadCount;

  /// Whether all tickets have been loaded (no more pagination).
  final bool hasReachedEnd;

  const TicketListState({
    this.allTickets = const [],
    this.tickets = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter,
    this.unreadCount = 0,
    this.hasReachedEnd = false,
  });

  /// Initial state for loading.
  factory TicketListState.initial() {
    return const TicketListState(isLoading: true);
  }

  /// Create a copy with updated fields.
  TicketListState copyWith({
    List<SupportTicket>? allTickets,
    List<SupportTicket>? tickets,
    bool? isLoading,
    String? error,
    bool clearError = false,
    TicketStatus? statusFilter,
    bool clearStatusFilter = false,
    int? unreadCount,
    bool? hasReachedEnd,
  }) {
    return TicketListState(
      allTickets: allTickets ?? this.allTickets,
      tickets: tickets ?? this.tickets,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      unreadCount: unreadCount ?? this.unreadCount,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
    );
  }

  /// Get open tickets count from all tickets.
  int get openCount => allTickets.where((t) => t.status == TicketStatus.open).length;

  /// Get in-progress tickets count from all tickets.
  int get inProgressCount => allTickets.where((t) => t.status == TicketStatus.inProgress).length;

  /// Get resolved tickets count from all tickets.
  int get resolvedCount => allTickets.where((t) => t.status == TicketStatus.resolved).length;

  /// Get closed tickets count from all tickets.
  int get closedCount => allTickets.where((t) => t.status == TicketStatus.closed).length;

  /// Whether any tickets exist.
  bool get hasTickets => tickets.isNotEmpty;

  /// Whether state represents an error.
  bool get hasError => error != null;
}

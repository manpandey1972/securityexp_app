/// Ticket statistics for admin dashboard.
///
/// Contains aggregated counts of tickets by status for display
/// in the admin panel.
class TicketStats {
  final int totalTickets;
  final int openTickets;
  final int inProgressTickets;
  final int resolvedTickets;
  final int closedTickets;
  final int highPriorityTickets;
  final int unassignedTickets;
  final int ticketsToday;

  const TicketStats({
    this.totalTickets = 0,
    this.openTickets = 0,
    this.inProgressTickets = 0,
    this.resolvedTickets = 0,
    this.closedTickets = 0,
    this.highPriorityTickets = 0,
    this.unassignedTickets = 0,
    this.ticketsToday = 0,
  });

  /// Creates a zero-initialized stats object.
  factory TicketStats.empty() => const TicketStats();

  TicketStats copyWith({
    int? totalTickets,
    int? openTickets,
    int? inProgressTickets,
    int? resolvedTickets,
    int? closedTickets,
    int? highPriorityTickets,
    int? unassignedTickets,
    int? ticketsToday,
  }) {
    return TicketStats(
      totalTickets: totalTickets ?? this.totalTickets,
      openTickets: openTickets ?? this.openTickets,
      inProgressTickets: inProgressTickets ?? this.inProgressTickets,
      resolvedTickets: resolvedTickets ?? this.resolvedTickets,
      closedTickets: closedTickets ?? this.closedTickets,
      highPriorityTickets: highPriorityTickets ?? this.highPriorityTickets,
      unassignedTickets: unassignedTickets ?? this.unassignedTickets,
      ticketsToday: ticketsToday ?? this.ticketsToday,
    );
  }

  /// Sum of pending tickets (open + in progress).
  int get pendingTickets => openTickets + inProgressTickets;

  /// Sum of completed tickets (resolved + closed).
  int get completedTickets => resolvedTickets + closedTickets;

  @override
  String toString() {
    return 'TicketStats(total: $totalTickets, open: $openTickets, '
        'inProgress: $inProgressTickets, resolved: $resolvedTickets, '
        'closed: $closedTickets, highPriority: $highPriorityTickets, '
        'unassigned: $unassignedTickets, today: $ticketsToday)';
  }
}

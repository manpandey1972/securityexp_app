import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/admin/presentation/state/admin_state.dart';
import 'package:greenhive_app/features/admin/services/admin_ticket_service.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';

/// ViewModel for the admin dashboard page.
class AdminDashboardViewModel extends ChangeNotifier {
  final AdminTicketService _ticketService;
  final AppLogger _log;

  static const String _tag = 'AdminDashboardViewModel';

  AdminDashboardState _state = const AdminDashboardState();
  AdminDashboardState get state => _state;

  AdminDashboardViewModel({
    AdminTicketService? ticketService,
    AppLogger? logger,
  }) : _ticketService = ticketService ?? sl<AdminTicketService>(),
       _log = logger ?? sl<AppLogger>();

  /// Initialize the dashboard.
  Future<void> initialize() async {
    await loadData();
  }

  /// Load dashboard data.
  Future<void> loadData() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      // Load stats and recent tickets in parallel
      final results = await Future.wait([
        _ticketService.getTicketStats(),
        _ticketService.getAllTickets(limit: 5),
      ]);

      _state = _state.copyWith(
        isLoading: false,
        stats: results[0] as TicketStats,
        recentTickets: results[1] as List<SupportTicket>,
      );
    } catch (e) {
      _log.error('Error loading dashboard data: $e', tag: _tag);
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to load dashboard data',
      );
    }

    notifyListeners();
  }

  /// Refresh dashboard data.
  Future<void> refresh() async {
    await loadData();
  }
}

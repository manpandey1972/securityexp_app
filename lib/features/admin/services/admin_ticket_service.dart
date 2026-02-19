import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/auth/role_service.dart';
import 'package:greenhive_app/core/permissions/permission_types.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/features/admin/data/models/internal_note.dart';
import 'package:greenhive_app/features/admin/data/models/ticket_stats.dart';
import 'package:greenhive_app/features/admin/data/repositories/admin_ticket_repository.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';

export 'package:greenhive_app/features/admin/data/models/internal_note.dart';
export 'package:greenhive_app/features/admin/data/models/ticket_stats.dart';

/// Service for admin ticket operations.
///
/// This service handles business logic and permission checks.
/// Data access is delegated to [AdminTicketRepository].
///
/// Provides methods for:
/// - Fetching all tickets with filters
/// - Updating ticket status and priority
/// - Assigning tickets to agents
/// - Managing internal notes
/// - Getting ticket statistics
class AdminTicketService {
  final AdminTicketRepository _repository;
  final FirestoreInstance _firestoreService;
  final RoleService _roleService;
  final AppLogger _log;

  static const String _tag = 'AdminTicketService';
  static const String _ticketsCollection = 'support_tickets';

  AdminTicketService({
    AdminTicketRepository? repository,
    FirestoreInstance? firestoreService,
    RoleService? roleService,
    AppLogger? logger,
  })  : _repository = repository ?? FirestoreAdminTicketRepository(),
        _firestoreService = firestoreService ?? FirestoreInstance(),
        _roleService = roleService ?? sl<RoleService>(),
        _log = logger ?? sl<AppLogger>();

  FirebaseFirestore get _db => _firestoreService.db;

  // ============= Permission Checks =============

  Future<void> _ensurePermission(AdminPermission permission) async {
    final hasPermission = await _roleService.hasPermission(permission);
    if (!hasPermission) {
      throw Exception('Permission denied: ${permission.name}');
    }
  }

  // ============= Ticket Queries =============

  /// Get all tickets with optional filters.
  Future<List<SupportTicket>> getAllTickets({
    TicketStatus? statusFilter,
    TicketPriority? priorityFilter,
    TicketCategory? categoryFilter,
    String? assignedTo,
    bool unassignedOnly = false,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    await _ensurePermission(AdminPermission.viewAllTickets);

    return await ErrorHandler.handle<List<SupportTicket>>(
      operation: () => _repository.getTickets(
        statusFilter: statusFilter,
        priorityFilter: priorityFilter,
        categoryFilter: categoryFilter,
        assignedTo: assignedTo,
        unassignedOnly: unassignedOnly,
        limit: limit,
        startAfter: startAfter,
      ),
      fallback: [],
      onError: (error) =>
          _log.error('Error getting all tickets: $error', tag: _tag),
    );
  }

  /// Stream all tickets for real-time updates.
  Stream<List<SupportTicket>> watchAllTickets({
    TicketStatus? statusFilter,
    int limit = 50,
  }) {
    return _repository.watchTickets(
      statusFilter: statusFilter,
      limit: limit,
    );
  }

  /// Get a single ticket by ID.
  Future<SupportTicket?> getTicket(String ticketId) async {
    await _ensurePermission(AdminPermission.viewAllTickets);

    return await ErrorHandler.handle<SupportTicket?>(
      operation: () => _repository.getTicket(ticketId),
      fallback: null,
      onError: (error) =>
          _log.error('Error getting ticket $ticketId: $error', tag: _tag),
    );
  }

  /// Stream a single ticket for real-time updates.
  Stream<SupportTicket?> watchTicket(String ticketId) {
    return _repository.watchTicket(ticketId);
  }

  // ============= Ticket Updates =============

  /// Update ticket status.
  Future<bool> updateStatus(String ticketId, TicketStatus newStatus) async {
    await _ensurePermission(AdminPermission.closeTickets);

    return await ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updateStatus(ticketId, newStatus);
        _log.info(
          'Updated ticket $ticketId status to ${newStatus.name}',
          tag: _tag,
        );
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error updating ticket status: $error', tag: _tag),
    );
  }

  /// Update ticket priority.
  Future<bool> updatePriority(
    String ticketId,
    TicketPriority newPriority,
  ) async {
    await _ensurePermission(AdminPermission.respondToTickets);

    return await ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updatePriority(ticketId, newPriority);
        _log.info(
          'Updated ticket $ticketId priority to ${newPriority.name}',
          tag: _tag,
        );
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error updating ticket priority: $error', tag: _tag),
    );
  }

  /// Assign ticket to an agent.
  Future<bool> assignTicket(String ticketId, String? agentId) async {
    await _ensurePermission(AdminPermission.assignTickets);

    return await ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.assignTicket(ticketId, agentId);
        _log.info('Assigned ticket $ticketId to agent $agentId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error assigning ticket: $error', tag: _tag),
    );
  }

  /// Update resolution details.
  Future<bool> updateResolution(
    String ticketId, {
    required String resolution,
    required ResolutionType resolutionType,
  }) async {
    await _ensurePermission(AdminPermission.closeTickets);

    return await ErrorHandler.handle<bool>(
      operation: () async {
        await _repository.updateResolution(
          ticketId,
          resolution: resolution,
          resolutionType: resolutionType,
        );
        _log.info(
          'Resolved ticket $ticketId with type ${resolutionType.name}',
          tag: _tag,
        );
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error updating resolution: $error', tag: _tag),
    );
  }

  // ============= Internal Notes =============

  /// Get internal notes for a ticket.
  Future<List<InternalNote>> getInternalNotes(String ticketId) async {
    await _ensurePermission(AdminPermission.respondToTickets);

    return await ErrorHandler.handle<List<InternalNote>>(
      operation: () => _repository.getInternalNotes(ticketId),
      fallback: [],
      onError: (error) =>
          _log.error('Error getting internal notes: $error', tag: _tag),
    );
  }

  /// Stream internal notes for a ticket.
  Stream<List<InternalNote>> watchInternalNotes(String ticketId) {
    return _repository.watchInternalNotes(ticketId);
  }

  /// Add an internal note to a ticket.
  Future<InternalNote?> addInternalNote({
    required String ticketId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    await _ensurePermission(AdminPermission.respondToTickets);

    return await ErrorHandler.handle<InternalNote?>(
      operation: () async {
        final note = await _repository.addInternalNote(
          ticketId: ticketId,
          authorId: authorId,
          authorName: authorName,
          content: content,
        );
        _log.info('Added internal note to ticket $ticketId', tag: _tag);
        return note;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error adding internal note: $error', tag: _tag),
    );
  }

  // ============= Statistics =============

  /// Get ticket statistics for dashboard.
  Future<TicketStats> getTicketStats() async {
    await _ensurePermission(AdminPermission.viewAllTickets);

    return await ErrorHandler.handle<TicketStats>(
      operation: () => _repository.getTicketStats(),
      fallback: const TicketStats(),
      onError: (error) =>
          _log.error('Error getting ticket stats: $error', tag: _tag),
    );
  }

  // ============= Admin Reply =============

  /// Send a reply as admin/support.
  Future<bool> sendAdminReply({
    required String ticketId,
    required String senderId,
    required String senderName,
    required String content,
    List<TicketAttachment> attachments = const [],
  }) async {
    await _ensurePermission(AdminPermission.respondToTickets);

    return await ErrorHandler.handle<bool>(
      operation: () async {
        final batch = _db.batch();

        // Add message
        final messageRef = _db
            .collection(_ticketsCollection)
            .doc(ticketId)
            .collection('messages')
            .doc();

        batch.set(messageRef, {
          'senderId': senderId,
          'senderName': senderName,
          'senderType': 'support',
          'content': content,
          'isFromSupport': true,
          'attachments': attachments.map((a) => a.toJson()).toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'readAt': null,
        });

        // Update ticket
        final ticketRef = _db.collection(_ticketsCollection).doc(ticketId);
        batch.update(ticketRef, {
          'lastActivityAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'messageCount': FieldValue.increment(1),
          'hasUnreadSupportMessages': true,
          'status': TicketStatus.inReview.toJson(),
        });

        await batch.commit();
        _log.info('Sent admin reply to ticket $ticketId', tag: _tag);
        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error sending admin reply: $error', tag: _tag),
    );
  }
}

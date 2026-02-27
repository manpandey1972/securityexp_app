import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';

/// Abstract interface for support-ticket and message operations.
///
/// Implementations handle storage details (Firestore, mocks, etc.).
abstract class ISupportRepository {
  // ── Ticket CRUD ──────────────────────────────────────────────────────
  Future<SupportTicket?> getTicket(String ticketId);

  Future<SupportTicket?> getTicketByBooking(String bookingId);

  Future<SupportTicket?> createTicket(SupportTicket ticket);

  Future<bool> updateTicket(String ticketId, Map<String, dynamic> updates);

  Future<bool> updateTicketSatisfaction(
    String ticketId, {
    required int rating,
    String? feedback,
  });

  // ── Ticket Queries ───────────────────────────────────────────────────
  Future<List<SupportTicket>> getTicketsByUser({
    required String userId,
    TicketStatus? statusFilter,
    TicketType? typeFilter,
    int limit,
    DocumentSnapshot? startAfter,
  });

  Future<List<SupportTicket>> getOpenTickets(String userId);

  Future<int> getUnreadTicketCount(String userId);

  // ── Ticket Streams ───────────────────────────────────────────────────
  Stream<SupportTicket?> watchTicket(String ticketId);

  Stream<List<SupportTicket>> watchUserTickets(
    String userId, {
    TicketStatus? statusFilter,
  });

  // ── Message Operations ───────────────────────────────────────────────
  Future<SupportMessage?> addMessage(String ticketId, SupportMessage message);

  Future<List<SupportMessage>> getMessages(
    String ticketId, {
    int limit,
    DocumentSnapshot? startAfter,
  });

  Stream<List<SupportMessage>> watchMessages(String ticketId);

  Future<void> markMessagesAsRead(String ticketId);

  // ── Utility ──────────────────────────────────────────────────────────
  Future<DocumentSnapshot?> getLastTicketSnapshot(String userId);
}

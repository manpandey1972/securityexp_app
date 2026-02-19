import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';
import 'package:securityexperts_app/features/admin/data/models/internal_note.dart';
import 'package:securityexperts_app/features/admin/data/models/ticket_stats.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';

/// Repository for admin ticket data operations.
///
/// This repository handles all Firestore operations for ticket management.
/// Business logic and permission checks are handled by [AdminTicketService].
abstract class AdminTicketRepository {
  // ============= Ticket Queries =============

  /// Get all tickets with optional filters.
  Future<List<SupportTicket>> getTickets({
    TicketStatus? statusFilter,
    TicketPriority? priorityFilter,
    TicketCategory? categoryFilter,
    String? assignedTo,
    bool unassignedOnly = false,
    int limit = 50,
    DocumentSnapshot? startAfter,
  });

  /// Stream all tickets for real-time updates.
  Stream<List<SupportTicket>> watchTickets({
    TicketStatus? statusFilter,
    int limit = 50,
  });

  /// Get a single ticket by ID.
  Future<SupportTicket?> getTicket(String ticketId);

  /// Stream a single ticket for real-time updates.
  Stream<SupportTicket?> watchTicket(String ticketId);

  // ============= Ticket Updates =============

  /// Update ticket status.
  Future<void> updateStatus(String ticketId, TicketStatus newStatus);

  /// Update ticket priority.
  Future<void> updatePriority(String ticketId, TicketPriority newPriority);

  /// Assign ticket to an agent.
  Future<void> assignTicket(String ticketId, String? agentId);

  /// Update resolution details.
  Future<void> updateResolution(
    String ticketId, {
    required String resolution,
    required ResolutionType resolutionType,
  });

  // ============= Internal Notes =============

  /// Get internal notes for a ticket.
  Future<List<InternalNote>> getInternalNotes(String ticketId);

  /// Stream internal notes for a ticket.
  Stream<List<InternalNote>> watchInternalNotes(String ticketId);

  /// Add an internal note to a ticket.
  Future<InternalNote> addInternalNote({
    required String ticketId,
    required String authorId,
    required String authorName,
    required String content,
  });

  // ============= Statistics =============

  /// Get ticket statistics for dashboard.
  Future<TicketStats> getTicketStats();
}

/// Firestore implementation of [AdminTicketRepository].
class FirestoreAdminTicketRepository implements AdminTicketRepository {
  final FirebaseFirestore _firestore;

  static const String _ticketsCollection = 'support_tickets';
  static const String _notesSubcollection = 'internal_notes';

  FirestoreAdminTicketRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreInstance().db;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_ticketsCollection);

  // ============= Ticket Queries =============

  @override
  Future<List<SupportTicket>> getTickets({
    TicketStatus? statusFilter,
    TicketPriority? priorityFilter,
    TicketCategory? categoryFilter,
    String? assignedTo,
    bool unassignedOnly = false,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _collection;

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.toJson());
    }
    if (priorityFilter != null) {
      query = query.where('priority', isEqualTo: priorityFilter.toJson());
    }
    if (categoryFilter != null) {
      query = query.where('category', isEqualTo: categoryFilter.toJson());
    }
    if (assignedTo != null) {
      query = query.where('assignedTo', isEqualTo: assignedTo);
    }
    if (unassignedOnly) {
      query = query.where('assignedTo', isNull: true);
    }

    query = query.orderBy('lastActivityAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => SupportTicket.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  @override
  Stream<List<SupportTicket>> watchTickets({
    TicketStatus? statusFilter,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _collection;

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.toJson());
    }

    query = query.orderBy('lastActivityAt', descending: true).limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => SupportTicket.fromJson(doc.data(), docId: doc.id))
          .toList();
    });
  }

  @override
  Future<SupportTicket?> getTicket(String ticketId) async {
    final doc = await _collection.doc(ticketId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return SupportTicket.fromJson(doc.data()!, docId: doc.id);
  }

  @override
  Stream<SupportTicket?> watchTicket(String ticketId) {
    return _collection.doc(ticketId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return SupportTicket.fromJson(snapshot.data()!, docId: snapshot.id);
    });
  }

  // ============= Ticket Updates =============

  @override
  Future<void> updateStatus(String ticketId, TicketStatus newStatus) async {
    final updates = <String, dynamic>{
      'status': newStatus.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == TicketStatus.resolved) {
      updates['resolvedAt'] = FieldValue.serverTimestamp();
    } else if (newStatus == TicketStatus.closed) {
      updates['closedAt'] = FieldValue.serverTimestamp();
    }

    await _collection.doc(ticketId).update(updates);
  }

  @override
  Future<void> updatePriority(
    String ticketId,
    TicketPriority newPriority,
  ) async {
    await _collection.doc(ticketId).update({
      'priority': newPriority.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> assignTicket(String ticketId, String? agentId) async {
    await _collection.doc(ticketId).update({
      'assignedTo': agentId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (agentId != null) 'status': TicketStatus.inProgress.name,
    });
  }

  @override
  Future<void> updateResolution(
    String ticketId, {
    required String resolution,
    required ResolutionType resolutionType,
  }) async {
    await _collection.doc(ticketId).update({
      'resolution': resolution,
      'resolutionType': resolutionType.toJson(),
      'status': TicketStatus.resolved.toJson(),
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  // ============= Internal Notes =============

  @override
  Future<List<InternalNote>> getInternalNotes(String ticketId) async {
    final snapshot = await _collection
        .doc(ticketId)
        .collection(_notesSubcollection)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => InternalNote.fromJson(doc.data(), docId: doc.id))
        .toList();
  }

  @override
  Stream<List<InternalNote>> watchInternalNotes(String ticketId) {
    return _collection
        .doc(ticketId)
        .collection(_notesSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InternalNote.fromJson(doc.data(), docId: doc.id))
          .toList();
    });
  }

  @override
  Future<InternalNote> addInternalNote({
    required String ticketId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    final docRef =
        _collection.doc(ticketId).collection(_notesSubcollection).doc();

    final note = InternalNote(
      id: docRef.id,
      ticketId: ticketId,
      authorId: authorId,
      authorName: authorName,
      content: content,
      createdAt: DateTime.now(),
    );

    await docRef.set(note.toJson());
    return note;
  }

  // ============= Statistics =============

  @override
  Future<TicketStats> getTicketStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Get counts for each status using aggregation queries
    final openCount = await _getCountByStatus(TicketStatus.open);
    final inProgressCount = await _getCountByStatus(TicketStatus.inProgress);
    final resolvedCount = await _getCountByStatus(TicketStatus.resolved);
    final closedCount = await _getCountByStatus(TicketStatus.closed);

    // Get high priority count - count ALL high priority tickets regardless of status
    // This matches what the user will see when they click on the "High Priority" stat
    final highPrioritySnapshot = await _collection
        .where('priority', isEqualTo: TicketPriority.high.toJson())
        .count()
        .get();

    // Get unassigned count - count ALL unassigned tickets regardless of status
    // This matches what the user will see when they click on the "Unassigned" stat
    final unassignedSnapshot = await _collection
        .where('assignedTo', isNull: true)
        .count()
        .get();

    // Get tickets created today
    final todaySnapshot = await _collection
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .count()
        .get();

    return TicketStats(
      totalTickets: openCount + inProgressCount + resolvedCount + closedCount,
      openTickets: openCount,
      inProgressTickets: inProgressCount,
      resolvedTickets: resolvedCount,
      closedTickets: closedCount,
      highPriorityTickets: highPrioritySnapshot.count ?? 0,
      unassignedTickets: unassignedSnapshot.count ?? 0,
      ticketsToday: todaySnapshot.count ?? 0,
    );
  }

  Future<int> _getCountByStatus(TicketStatus status) async {
    final snapshot = await _collection
        .where('status', isEqualTo: status.toJson())
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

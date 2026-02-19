import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';

import '../models/models.dart';

/// Repository for support ticket and message operations.
///
/// Handles all Firestore operations for support tickets including
/// CRUD operations, queries, and real-time streams.
class SupportRepository {
  final FirestoreInstance _firestoreService = FirestoreInstance();
  final AppLogger _log = sl<AppLogger>();

  static const String _tag = 'SupportRepository';
  static const String _ticketsCollection = 'support_tickets';
  static const String _messagesSubcollection = 'messages';

  /// Get the Firestore instance
  FirebaseFirestore get _db => _firestoreService.db;

  /// Get a ticket reference
  DocumentReference<Map<String, dynamic>> _ticketRef(String ticketId) =>
      _db.collection(_ticketsCollection).doc(ticketId);

  /// Get messages collection reference for a ticket
  CollectionReference<Map<String, dynamic>> _messagesRef(String ticketId) =>
      _ticketRef(ticketId).collection(_messagesSubcollection);

  // ============= Ticket CRUD Operations =============

  /// Get a single ticket by ID
  Future<SupportTicket?> getTicket(String ticketId) async {
    return await ErrorHandler.handle<SupportTicket?>(
      operation: () async {
        final doc = await _ticketRef(ticketId).get();
        if (!doc.exists || doc.data() == null) {
          return null;
        }
        return SupportTicket.fromJson(doc.data()!, docId: doc.id);
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error getting ticket $ticketId: $error', tag: _tag),
    );
  }

  /// Get a ticket by booking ID
  Future<SupportTicket?> getTicketByBooking(String bookingId) async {
    return await ErrorHandler.handle<SupportTicket?>(
      operation: () async {
        final snapshot = await _db
            .collection(_ticketsCollection)
            .where('bookingId', isEqualTo: bookingId)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          return null;
        }

        final doc = snapshot.docs.first;
        return SupportTicket.fromJson(doc.data(), docId: doc.id);
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error getting ticket by booking: $error', tag: _tag),
    );
  }

  /// Create a new support ticket
  Future<SupportTicket?> createTicket(SupportTicket ticket) async {
    return await ErrorHandler.handle<SupportTicket?>(
      operation: () async {
        final now = DateTime.now();
        final docRef = _db.collection(_ticketsCollection).doc();

        final newTicket = ticket.copyWith(
          id: docRef.id,
          createdAt: now,
          updatedAt: now,
          lastActivityAt: now,
        );

        await docRef.set(newTicket.toJson());
        _log.info('Created ticket: ${docRef.id}', tag: _tag);

        return newTicket;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error creating ticket: $error', tag: _tag),
    );
  }

  /// Update a ticket
  Future<bool> updateTicket(
    String ticketId,
    Map<String, dynamic> updates,
  ) async {
    return await ErrorHandler.handle<bool>(
      operation: () async {
        updates['updatedAt'] = FieldValue.serverTimestamp();

        await _ticketRef(ticketId).update(updates);
        _log.info('Updated ticket: $ticketId', tag: _tag);

        return true;
      },
      fallback: false,
      onError: (error) =>
          _log.error('Error updating ticket $ticketId: $error', tag: _tag),
    );
  }

  /// Update ticket satisfaction rating
  Future<bool> updateTicketSatisfaction(
    String ticketId, {
    required int rating,
    String? feedback,
  }) async {
    return await ErrorHandler.handle<bool>(
      operation: () async {
        final updates = <String, dynamic>{
          'userSatisfactionRating': rating,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (feedback != null) {
          updates['userSatisfactionFeedback'] = feedback;
        }

        await _ticketRef(ticketId).update(updates);
        _log.info('Updated ticket satisfaction: $ticketId', tag: _tag);

        return true;
      },
      fallback: false,
      onError: (error) => _log.error(
        'Error updating ticket satisfaction $ticketId: $error',
        tag: _tag,
      ),
    );
  }

  // ============= Ticket Queries =============

  /// Get tickets for a specific user
  Future<List<SupportTicket>> getTicketsByUser({
    required String userId,
    TicketStatus? statusFilter,
    TicketType? typeFilter,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    return await ErrorHandler.handle<List<SupportTicket>>(
      operation: () async {
        Query<Map<String, dynamic>> query = _db
            .collection(_ticketsCollection)
            .where('userId', isEqualTo: userId);

        if (statusFilter != null) {
          query = query.where('status', isEqualTo: statusFilter.toJson());
        }

        if (typeFilter != null) {
          query = query.where('type', isEqualTo: typeFilter.toJson());
        }

        query = query.orderBy('lastActivityAt', descending: true).limit(limit);

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        final snapshot = await query.get();

        return snapshot.docs
            .map((doc) => SupportTicket.fromJson(doc.data(), docId: doc.id))
            .toList();
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting user tickets: $error', tag: _tag),
    );
  }

  /// Get open tickets for a user (convenience method)
  Future<List<SupportTicket>> getOpenTickets(String userId) async {
    return await ErrorHandler.handle<List<SupportTicket>>(
      operation: () async {
        final snapshot = await _db
            .collection(_ticketsCollection)
            .where('userId', isEqualTo: userId)
            .where('status', whereIn: ['open', 'in_review', 'in_progress'])
            .orderBy('lastActivityAt', descending: true)
            .get();

        return snapshot.docs
            .map((doc) => SupportTicket.fromJson(doc.data(), docId: doc.id))
            .toList();
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting open tickets: $error', tag: _tag),
    );
  }

  /// Count unread tickets for a user
  Future<int> getUnreadTicketCount(String userId) async {
    return await ErrorHandler.handle<int>(
      operation: () async {
        final snapshot = await _db
            .collection(_ticketsCollection)
            .where('userId', isEqualTo: userId)
            .where('hasUnreadSupportMessages', isEqualTo: true)
            .count()
            .get();

        return snapshot.count ?? 0;
      },
      fallback: 0,
      onError: (error) =>
          _log.error('Error counting unread tickets: $error', tag: _tag),
    );
  }

  // ============= Real-time Streams =============

  /// Watch a single ticket for real-time updates
  Stream<SupportTicket?> watchTicket(String ticketId) {
    return _ticketRef(ticketId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return SupportTicket.fromJson(snapshot.data()!, docId: snapshot.id);
    });
  }

  /// Watch all tickets for a user
  Stream<List<SupportTicket>> watchUserTickets(
    String userId, {
    TicketStatus? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection(_ticketsCollection)
        .where('userId', isEqualTo: userId);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.toJson());
    }

    return query
        .orderBy('lastActivityAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupportTicket.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  // ============= Message Operations =============

  /// Add a message to a ticket
  Future<SupportMessage?> addMessage(
    String ticketId,
    SupportMessage message,
  ) async {
    return await ErrorHandler.handle<SupportMessage?>(
      operation: () async {
        final docRef = _messagesRef(ticketId).doc();
        final now = DateTime.now();

        final newMessage = message.copyWith(
          id: docRef.id,
          ticketId: ticketId,
          createdAt: now,
        );

        _log.info('DEBUG: Creating message document at ${docRef.path}', tag: _tag);
        _log.info('DEBUG: Message data: ${newMessage.toJson()}', tag: _tag);
        
        try {
          await docRef.set(newMessage.toJson());
          _log.info('DEBUG: Message document created successfully', tag: _tag);
        } catch (e) {
          _log.error('DEBUG: Failed to create message document: $e', tag: _tag);
          rethrow;
        }

        _log.info('DEBUG: Updating ticket metadata at ${_ticketRef(ticketId).path}', tag: _tag);
        
        try {
          // Update ticket's lastActivityAt
          await _ticketRef(ticketId).update({
            'lastActivityAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'messageCount': FieldValue.increment(1),
          });
          _log.info('DEBUG: Ticket metadata updated successfully', tag: _tag);
        } catch (e) {
          _log.error('DEBUG: Failed to update ticket metadata: $e', tag: _tag);
          rethrow;
        }

        _log.info('Added message to ticket $ticketId: ${docRef.id}', tag: _tag);

        return newMessage;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error adding message to $ticketId: $error', tag: _tag),
    );
  }

  /// Get messages for a ticket
  Future<List<SupportMessage>> getMessages(
    String ticketId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    return await ErrorHandler.handle<List<SupportMessage>>(
      operation: () async {
        Query<Map<String, dynamic>> query = _messagesRef(
          ticketId,
        ).orderBy('createdAt', descending: false).limit(limit);

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        final snapshot = await query.get();

        return snapshot.docs
            .map((doc) => SupportMessage.fromJson(doc.data(), docId: doc.id))
            .toList();
      },
      fallback: [],
      onError: (error) =>
          _log.error('Error getting messages for $ticketId: $error', tag: _tag),
    );
  }

  /// Watch messages for a ticket in real-time
  Stream<List<SupportMessage>> watchMessages(String ticketId) {
    return _messagesRef(ticketId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupportMessage.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  /// Mark all support messages as read for a user
  Future<void> markMessagesAsRead(String ticketId) async {
    await ErrorHandler.handle<void>(
      operation: () async {
        _log.info('Marking messages as read for ticket: $ticketId', tag: _tag);
        final now = DateTime.now();

        // Get unread support messages
        final snapshot = await _messagesRef(ticketId)
            .where('senderType', isEqualTo: 'support')
            .where('readAt', isNull: true)
            .get();

        _log.info('Found ${snapshot.docs.length} unread support messages', tag: _tag);
        
        if (snapshot.docs.isEmpty) {
          _log.info('No unread messages to mark, updating ticket flag anyway', tag: _tag);
          // Still update ticket flag to ensure consistency
          await _ticketRef(ticketId).update({'hasUnreadSupportMessages': false});
          return;
        }

        // Batch update all unread messages
        final batch = _db.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {'readAt': Timestamp.fromDate(now)});
        }
        await batch.commit();
        _log.info('Updated readAt for ${snapshot.docs.length} messages', tag: _tag);

        // Update ticket unread flag
        await _ticketRef(ticketId).update({'hasUnreadSupportMessages': false});
        _log.info('Updated ticket hasUnreadSupportMessages to false', tag: _tag);

        _log.info(
          'Marked ${snapshot.docs.length} messages as read for ticket $ticketId',
          tag: _tag,
        );
      },
      onError: (error) {
        _log.error('Error marking messages as read for $ticketId: $error', tag: _tag);
      },
    );
  }

  // ============= Utility Methods =============

  /// Get the last document snapshot for pagination
  Future<DocumentSnapshot?> getLastTicketSnapshot(String userId) async {
    return await ErrorHandler.handle<DocumentSnapshot?>(
      operation: () async {
        final snapshot = await _db
            .collection(_ticketsCollection)
            .where('userId', isEqualTo: userId)
            .orderBy('lastActivityAt', descending: true)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) return null;
        return snapshot.docs.last;
      },
      fallback: null,
      onError: (error) =>
          _log.error('Error getting last ticket snapshot: $error', tag: _tag),
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/admin/presentation/state/admin_state.dart';
import 'package:greenhive_app/features/admin/services/admin_ticket_service.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';
import 'package:greenhive_app/features/support/data/repositories/support_repository.dart';
import 'package:greenhive_app/shared/services/user_profile_service.dart';

/// ViewModel for the admin ticket detail page.
class AdminTicketDetailViewModel extends ChangeNotifier {
  final AdminTicketService _ticketService;
  final SupportRepository _supportRepository;
  final AppLogger _log;

  static const String _tag = 'AdminTicketDetailViewModel';

  final String ticketId;

  AdminTicketDetailState _state = const AdminTicketDetailState();
  AdminTicketDetailState get state => _state;

  StreamSubscription? _ticketSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _notesSubscription;

  AdminTicketDetailViewModel({
    required this.ticketId,
    AdminTicketService? ticketService,
    SupportRepository? supportRepository,
    AppLogger? logger,
  }) : _ticketService = ticketService ?? sl<AdminTicketService>(),
       _supportRepository = supportRepository ?? sl<SupportRepository>(),
       _log = logger ?? sl<AppLogger>();

  /// Initialize and start watching the ticket.
  Future<void> initialize() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    // Watch ticket
    _ticketSubscription = _ticketService
        .watchTicket(ticketId)
        .listen(
          (ticket) {
            _state = _state.copyWith(isLoading: false, ticket: ticket);
            notifyListeners();
          },
          onError: (error) {
            _log.error('Error watching ticket: $error', tag: _tag);
            _state = _state.copyWith(
              isLoading: false,
              error: 'Failed to load ticket',
            );
            notifyListeners();
          },
        );

    // Watch messages
    _messagesSubscription = _supportRepository.watchMessages(ticketId).listen((
      messages,
    ) {
      _state = _state.copyWith(messages: messages);
      notifyListeners();
    });

    // Watch internal notes
    _notesSubscription = _ticketService.watchInternalNotes(ticketId).listen((
      notes,
    ) {
      _state = _state.copyWith(internalNotes: notes);
      notifyListeners();
    });
  }

  /// Update reply text.
  void setReplyText(String text) {
    _state = _state.copyWith(replyText: text);
    notifyListeners();
  }

  /// Update internal note text.
  void setInternalNoteText(String text) {
    _state = _state.copyWith(internalNoteText: text);
    notifyListeners();
  }

  /// Toggle internal notes visibility.
  void toggleInternalNotes() {
    _state = _state.copyWith(showInternalNotes: !_state.showInternalNotes);
    notifyListeners();
  }

  /// Send reply as admin.
  Future<bool> sendReply() async {
    if (_state.replyText.trim().isEmpty) return false;

    _state = _state.copyWith(isSending: true);
    notifyListeners();

    try {
      final userProfile = UserProfileService().userProfile;
      final success = await _ticketService.sendAdminReply(
        ticketId: ticketId,
        senderId: userProfile?.id ?? '',
        senderName: userProfile?.name ?? 'Support',
        content: _state.replyText.trim(),
      );

      if (success) {
        _state = _state.copyWith(isSending: false, replyText: '');
      } else {
        _state = _state.copyWith(
          isSending: false,
          error: 'Failed to send reply',
        );
      }
      notifyListeners();
      return success;
    } catch (e) {
      _log.error('Error sending reply: $e', tag: _tag);
      _state = _state.copyWith(isSending: false, error: 'Failed to send reply');
      notifyListeners();
      return false;
    }
  }

  /// Add internal note.
  Future<bool> addInternalNote() async {
    if (_state.internalNoteText.trim().isEmpty) return false;

    _state = _state.copyWith(isSending: true);
    notifyListeners();

    try {
      final userProfile = UserProfileService().userProfile;
      final note = await _ticketService.addInternalNote(
        ticketId: ticketId,
        authorId: userProfile?.id ?? '',
        authorName: userProfile?.name ?? 'Admin',
        content: _state.internalNoteText.trim(),
      );

      if (note != null) {
        _state = _state.copyWith(isSending: false, internalNoteText: '');
      } else {
        _state = _state.copyWith(isSending: false, error: 'Failed to add note');
      }
      notifyListeners();
      return note != null;
    } catch (e) {
      _log.error('Error adding internal note: $e', tag: _tag);
      _state = _state.copyWith(isSending: false, error: 'Failed to add note');
      notifyListeners();
      return false;
    }
  }

  /// Update ticket status.
  Future<bool> updateStatus(TicketStatus status) async {
    _state = _state.copyWith(isUpdating: true);
    notifyListeners();

    try {
      final success = await _ticketService.updateStatus(ticketId, status);
      _state = _state.copyWith(isUpdating: false);
      notifyListeners();
      return success;
    } catch (e) {
      _log.error('Error updating status: $e', tag: _tag);
      _state = _state.copyWith(
        isUpdating: false,
        error: 'Failed to update status',
      );
      notifyListeners();
      return false;
    }
  }

  /// Update ticket priority.
  Future<bool> updatePriority(TicketPriority priority) async {
    _state = _state.copyWith(isUpdating: true);
    notifyListeners();

    try {
      final success = await _ticketService.updatePriority(ticketId, priority);
      _state = _state.copyWith(isUpdating: false);
      notifyListeners();
      return success;
    } catch (e) {
      _log.error('Error updating priority: $e', tag: _tag);
      _state = _state.copyWith(
        isUpdating: false,
        error: 'Failed to update priority',
      );
      notifyListeners();
      return false;
    }
  }

  /// Assign ticket to agent.
  Future<bool> assignTicket(String? agentId) async {
    _state = _state.copyWith(isUpdating: true);
    notifyListeners();

    try {
      final success = await _ticketService.assignTicket(ticketId, agentId);
      _state = _state.copyWith(isUpdating: false);
      notifyListeners();
      return success;
    } catch (e) {
      _log.error('Error assigning ticket: $e', tag: _tag);
      _state = _state.copyWith(
        isUpdating: false,
        error: 'Failed to assign ticket',
      );
      notifyListeners();
      return false;
    }
  }

  /// Resolve ticket with resolution details.
  Future<bool> resolveTicket({
    required String resolution,
    required ResolutionType resolutionType,
  }) async {
    _state = _state.copyWith(isUpdating: true);
    notifyListeners();

    try {
      final success = await _ticketService.updateResolution(
        ticketId,
        resolution: resolution,
        resolutionType: resolutionType,
      );
      _state = _state.copyWith(isUpdating: false);
      notifyListeners();
      return success;
    } catch (e) {
      _log.error('Error resolving ticket: $e', tag: _tag);
      _state = _state.copyWith(
        isUpdating: false,
        error: 'Failed to resolve ticket',
      );
      notifyListeners();
      return false;
    }
  }

  /// Clear error.
  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    _messagesSubscription?.cancel();
    _notesSubscription?.cancel();
    super.dispose();
  }
}

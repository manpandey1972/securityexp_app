import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/validators/pii_validator.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';

import '../../data/models/models.dart';
import '../../services/support_service.dart';
import '../../services/support_analytics.dart';
import '../state/ticket_detail_state.dart';

/// ViewModel for the ticket detail/conversation page.
///
/// Manages ticket data, messages, replies, and satisfaction rating.
class TicketDetailViewModel extends ChangeNotifier {
  final SupportService _supportService;
  final String ticketId;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'TicketDetailViewModel';

  TicketDetailState _state = TicketDetailState.initial();
  TicketDetailState get state => _state;

  StreamSubscription<SupportTicket?>? _ticketSubscription;
  StreamSubscription<List<SupportMessage>>? _messagesSubscription;
  bool _isDisposed = false;

  TicketDetailViewModel({
    required SupportService supportService,
    required this.ticketId,
  }) : _supportService = supportService;

  /// Initialize and start listening to ticket and messages.
  void initialize() {
    _log.debug('Initializing ticket detail: $ticketId', tag: _tag);
    _subscribeToTicket();
    _subscribeToMessages();
    
    // Track ticket viewed (delayed to get status after subscription)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed && _state.ticket != null) {
        sl<SupportAnalytics>().trackTicketViewed(
          ticketId: ticketId,
          status: _state.ticket!.status,
        );
      }
    });
  }

  /// Subscribe to ticket updates.
  void _subscribeToTicket() {
    _ticketSubscription?.cancel();

    _ticketSubscription = _supportService
        .watchTicket(ticketId)
        .listen(
          (ticket) {
            if (_isDisposed) return;

            _updateState(
              _state.copyWith(
                ticket: ticket,
                isLoading: false,
                clearError: true,
              ),
            );

            // Show rating dialog if applicable
            if (ticket != null && _state.canRate && !_state.showRatingDialog) {
              // Don't auto-show, user will trigger it
            }
          },
          onError: (error) {
            if (_isDisposed) return;

            _log.error('Error watching ticket', error: error, tag: _tag);
            _updateState(
              _state.copyWith(isLoading: false, error: 'Failed to load ticket'),
            );
          },
        );
  }

  /// Subscribe to message updates.
  void _subscribeToMessages() {
    _messagesSubscription?.cancel();

    _messagesSubscription = _supportService
        .watchTicketMessages(ticketId)
        .listen(
          (messages) async {
            if (_isDisposed) return;

            _updateState(
              _state.copyWith(messages: messages, isLoadingMessages: false),
            );

            // Mark messages as read (await to ensure it completes)
            await _markMessagesAsRead();
          },
          onError: (error) {
            if (_isDisposed) return;

            _log.error('Error watching messages', error: error, tag: _tag);
            _updateState(_state.copyWith(isLoadingMessages: false));
          },
        );
  }

  /// Mark support messages as read.
  Future<void> _markMessagesAsRead() async {
    if (_state.hasUnreadMessages) {
      _log.info('Marking ${_state.unreadSupportMessages.length} messages as read for ticket $ticketId', tag: _tag);
      try {
        await _supportService.markMessagesAsRead(ticketId);
        _log.info('Successfully marked messages as read', tag: _tag);
      } catch (e) {
        _log.error('Failed to mark messages as read', error: e, tag: _tag);
      }
    }
  }

  // ========================================
  // MESSAGE COMPOSITION
  // ========================================

  /// Set message text.
  void setMessageText(String text) {
    _updateState(_state.copyWith(messageText: text));
  }

  /// Pick an image for message (uses FilePicker for web compatibility).
  Future<void> pickImage() async {
    if (!_state.canAddAttachment) {
      SnackbarService.show('Maximum 5 attachments allowed');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // Always load bytes for web compatibility
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        
        // Check file size
        final sizeBytes = platformFile.size;
        if (sizeBytes > 10 * 1024 * 1024) {
          SnackbarService.show('File too large. Maximum 10MB allowed.');
          return;
        }

        PendingAttachment attachment;
        if (platformFile.bytes != null) {
          attachment = PendingAttachment.fromBytes(platformFile.bytes!, platformFile.name);
        } else if (platformFile.path != null && platformFile.path!.isNotEmpty) {
          attachment = PendingAttachment.fromPath(platformFile.path!, platformFile.name);
        } else {
          SnackbarService.show('Failed to read image data');
          return;
        }
        
        final newAttachments = List<PendingAttachment>.from(_state.messageAttachments)
          ..add(attachment);
        _updateState(_state.copyWith(messageAttachments: newAttachments));
      }
    } catch (e, stack) {
      _log.error('Failed to pick image', error: e, stackTrace: stack, tag: _tag);
      SnackbarService.show('Failed to pick image. Please try again.');
    }
  }

  /// Pick a file for message.
  Future<void> pickFile() async {
    if (!_state.canAddAttachment) {
      SnackbarService.show('Maximum 5 attachments allowed');
      return;
    }

    try {
      // Use FileType.any with withData for web compatibility
      final result = await FilePicker.platform.pickFiles(
        withData: true, // Always load bytes for web compatibility
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        
        // Validate file extension
        final ext = platformFile.extension?.toLowerCase() ?? '';
        final allowedExtensions = ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'gif', 'webp'];
        if (!allowedExtensions.contains(ext)) {
          SnackbarService.show('Only images, PDF, or text files allowed');
          return;
        }
        
        // Check file size using platformFile.size (works on all platforms)
        final sizeBytes = platformFile.size;
        if (sizeBytes > 10 * 1024 * 1024) {
          SnackbarService.show('File too large. Maximum 10MB allowed.');
          return;
        }

        PendingAttachment attachment;
        if (platformFile.bytes != null) {
          attachment = PendingAttachment.fromBytes(platformFile.bytes!, platformFile.name);
        } else if (platformFile.path != null && platformFile.path!.isNotEmpty) {
          attachment = PendingAttachment.fromPath(platformFile.path!, platformFile.name);
        } else {
          SnackbarService.show('Failed to read file data');
          return;
        }
            
        final newAttachments = List<PendingAttachment>.from(_state.messageAttachments)
          ..add(attachment);
        _updateState(_state.copyWith(messageAttachments: newAttachments));
      }
    } catch (e, stack) {
      _log.error('Failed to pick file', error: e, stackTrace: stack, tag: _tag);
      SnackbarService.show('Failed to pick file. Please try again.');
    }
  }

  /// Remove attachment at index.
  void removeAttachment(int index) {
    if (index < 0 || index >= _state.messageAttachments.length) return;

    final newAttachments = List<PendingAttachment>.from(_state.messageAttachments)
      ..removeAt(index);
    _updateState(_state.copyWith(messageAttachments: newAttachments));
  }

  /// Send the message.
  Future<bool> sendMessage() async {
    if (!_state.canSendMessage) return false;

    // Check for PII (phone numbers, emails) before sending
    final piiResult = PIIValidator().validate(_state.messageText);
    if (!piiResult.isValid) {
      SnackbarService.show(piiResult.message ?? 'Personal information detected');
      return false;
    }

    _log.info('Sending reply to ticket: $ticketId', tag: _tag);
    _updateState(_state.copyWith(isSending: true));

    final result = await _supportService.replyToTicket(
      ticketId: ticketId,
      content: _state.messageText,
      attachments: _state.messageAttachments.isNotEmpty
          ? _state.messageAttachments
          : null,
    );

    if (_isDisposed) return false;

    if (result.isSuccess) {
      _log.info('Reply sent successfully', tag: _tag);
      
      // Track message sent
      sl<SupportAnalytics>().trackMessageSent(
        ticketId: ticketId,
        attachmentCount: _state.messageAttachments.length,
      );
      
      _updateState(
        _state.copyWith(
          isSending: false,
          messageText: '',
          messageAttachments: [],
        ),
      );
      return true;
    } else {
      _log.warning('Failed to send reply: ${result.error?.message}', tag: _tag);
      _updateState(_state.copyWith(isSending: false));
      SnackbarService.show(result.error?.message ?? 'Failed to send message');
      return false;
    }
  }

  // ========================================
  // SATISFACTION RATING
  // ========================================

  /// Show the rating dialog.
  void showRatingDialog() {
    _updateState(_state.copyWith(showRatingDialog: true));
  }

  /// Hide the rating dialog.
  void hideRatingDialog() {
    _updateState(
      _state.copyWith(
        showRatingDialog: false,
        clearSelectedRating: true,
        ratingComment: '',
      ),
    );
  }

  /// Set rating value.
  void setRating(int rating) {
    _updateState(_state.copyWith(selectedRating: rating));
  }

  /// Set rating comment.
  void setRatingComment(String comment) {
    _updateState(_state.copyWith(ratingComment: comment));
  }

  /// Submit the rating.
  Future<bool> submitRating() async {
    if (_state.selectedRating == null) {
      SnackbarService.show('Please select a rating');
      return false;
    }

    _log.info('Submitting rating: ${_state.selectedRating}', tag: _tag);
    _updateState(_state.copyWith(isSubmittingRating: true));

    final result = await _supportService.rateSupportExperience(
      ticketId: ticketId,
      rating: _state.selectedRating!,
      comment: _state.ratingComment.isNotEmpty ? _state.ratingComment : null,
    );

    if (_isDisposed) return false;

    if (result.isSuccess) {
      _log.info('Rating submitted successfully', tag: _tag);
      
      // Track satisfaction rated
      sl<SupportAnalytics>().trackSatisfactionRated(
        ticketId: ticketId,
        rating: _state.selectedRating!,
        hasComment: _state.ratingComment.isNotEmpty,
      );
      
      _updateState(
        _state.copyWith(
          isSubmittingRating: false,
          showRatingDialog: false,
          clearSelectedRating: true,
          ratingComment: '',
        ),
      );
      SnackbarService.show('Thank you for your feedback!');
      return true;
    } else {
      _log.warning(
        'Failed to submit rating: ${result.error?.message}',
        tag: _tag,
      );
      _updateState(_state.copyWith(isSubmittingRating: false));
      SnackbarService.show(result.error?.message ?? 'Failed to submit rating');
      return false;
    }
  }

  // ========================================
  // HELPERS
  // ========================================

  /// Refresh ticket data.
  Future<void> refresh() async {
    _updateState(_state.copyWith(isLoading: true, clearError: true));

    final result = await _supportService.getTicketById(ticketId);

    if (_isDisposed) return;

    if (result.isSuccess) {
      _updateState(_state.copyWith(ticket: result.value, isLoading: false));
    } else {
      _updateState(
        _state.copyWith(isLoading: false, error: result.error?.message),
      );
    }
  }

  /// Update state and notify listeners.
  void _updateState(TicketDetailState newState) {
    _state = newState;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ticketSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}

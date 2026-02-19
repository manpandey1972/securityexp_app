import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';

/// State for ticket detail/conversation view.
@immutable
class TicketDetailState {
  /// The ticket being viewed.
  final SupportTicket? ticket;

  /// List of messages in the ticket.
  final List<SupportMessage> messages;

  /// Whether ticket data is loading.
  final bool isLoading;

  /// Whether messages are loading.
  final bool isLoadingMessages;

  /// Error message if loading failed.
  final String? error;

  /// Current message being composed.
  final String messageText;

  /// Attachments for current message.
  final List<PendingAttachment> messageAttachments;

  /// Whether message is being sent.
  final bool isSending;

  /// Whether rating dialog should be shown.
  final bool showRatingDialog;

  /// Currently selected rating (1-5).
  final int? selectedRating;

  /// Rating feedback comment.
  final String ratingComment;

  /// Whether rating is being submitted.
  final bool isSubmittingRating;

  const TicketDetailState({
    this.ticket,
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMessages = false,
    this.error,
    this.messageText = '',
    this.messageAttachments = const [],
    this.isSending = false,
    this.showRatingDialog = false,
    this.selectedRating,
    this.ratingComment = '',
    this.isSubmittingRating = false,
  });

  /// Initial loading state.
  factory TicketDetailState.initial() {
    return const TicketDetailState(isLoading: true);
  }

  /// Create copy with updated fields.
  TicketDetailState copyWith({
    SupportTicket? ticket,
    List<SupportMessage>? messages,
    bool? isLoading,
    bool? isLoadingMessages,
    String? error,
    bool clearError = false,
    String? messageText,
    List<PendingAttachment>? messageAttachments,
    bool? isSending,
    bool? showRatingDialog,
    int? selectedRating,
    bool clearSelectedRating = false,
    String? ratingComment,
    bool? isSubmittingRating,
  }) {
    return TicketDetailState(
      ticket: ticket ?? this.ticket,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      error: clearError ? null : (error ?? this.error),
      messageText: messageText ?? this.messageText,
      messageAttachments: messageAttachments ?? this.messageAttachments,
      isSending: isSending ?? this.isSending,
      showRatingDialog: showRatingDialog ?? this.showRatingDialog,
      selectedRating: clearSelectedRating
          ? null
          : (selectedRating ?? this.selectedRating),
      ratingComment: ratingComment ?? this.ratingComment,
      isSubmittingRating: isSubmittingRating ?? this.isSubmittingRating,
    );
  }

  /// Whether ticket can be replied to.
  bool get canReply => ticket?.canReply ?? false;

  /// Whether ticket can be rated.
  bool get canRate {
    if (ticket == null) return false;
    return (ticket!.status == TicketStatus.resolved ||
            ticket!.status == TicketStatus.closed) &&
        ticket!.userSatisfactionRating == null;
  }

  /// Whether message can be sent.
  bool get canSendMessage {
    return canReply &&
        (messageText.trim().isNotEmpty || messageAttachments.isNotEmpty) &&
        !isSending;
  }

  /// Whether attachments can be added to message.
  bool get canAddAttachment => messageAttachments.length < 5;

  /// Get unread messages from support.
  List<SupportMessage> get unreadSupportMessages {
    return messages.where((m) => m.isFromSupport && m.readAt == null).toList();
  }

  /// Whether there are unread messages.
  bool get hasUnreadMessages => unreadSupportMessages.isNotEmpty;

  /// Last message in conversation.
  SupportMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  /// Status display color.
  String get statusText => ticket?.status.displayName ?? 'Unknown';
}

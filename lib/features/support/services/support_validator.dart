import '../data/models/models.dart';
import 'support_models.dart';

/// Validation utilities for support service operations.
class SupportValidator {
  SupportValidator._();

  /// Validate ticket input.
  static SupportError? validateTicketInput(
    String subject,
    String description,
    List<PendingAttachment>? attachments,
  ) {
    if (subject.trim().isEmpty) {
      return SupportError.invalidSubject;
    }
    if (subject.length > SupportConstants.maxSubjectLength) {
      return SupportError.subjectTooLong;
    }
    if (description.trim().isEmpty) {
      return SupportError.invalidDescription;
    }
    if (description.length > SupportConstants.maxDescriptionLength) {
      return SupportError.descriptionTooLong;
    }
    if (attachments != null && attachments.length > SupportConstants.maxAttachments) {
      return SupportError.tooManyAttachments;
    }
    return null;
  }

  /// Validate attachment size.
  static SupportError? validateAttachmentSize(List<PendingAttachment>? attachments) {
    if (attachments == null) return null;
    
    for (final attachment in attachments) {
      final sizeBytes = attachment.bytes?.length ?? 0;
      final sizeMB = sizeBytes / (1024 * 1024);
      if (sizeMB > SupportConstants.maxAttachmentSizeMB) {
        return SupportError.attachmentTooLarge;
      }
    }
    return null;
  }

  /// Validate reply message.
  static SupportError? validateReplyMessage(
    String content,
    List<PendingAttachment>? attachments,
  ) {
    if (content.trim().isEmpty && (attachments == null || attachments.isEmpty)) {
      return SupportError.invalidMessage;
    }
    if (content.length > SupportConstants.maxMessageLength) {
      return SupportError.descriptionTooLong;
    }
    if (attachments != null && attachments.length > SupportConstants.maxAttachments) {
      return SupportError.tooManyAttachments;
    }
    return null;
  }

  /// Validate rating.
  static SupportError? validateRating(int rating) {
    if (rating < 1 || rating > 5) {
      return SupportError.invalidRating;
    }
    return null;
  }

  /// Get priority based on ticket type.
  static TicketPriority getPriorityFromType(TicketType type) {
    switch (type) {
      case TicketType.bug:
        return TicketPriority.high;
      case TicketType.account:
      case TicketType.payment:
        return TicketPriority.medium;
      case TicketType.featureRequest:
      case TicketType.feedback:
      case TicketType.support:
        return TicketPriority.low;
    }
  }
}

/// Support operation errors.
enum SupportError {
  invalidSubject,
  subjectTooLong,
  invalidDescription,
  descriptionTooLong,
  tooManyAttachments,
  attachmentTooLarge,
  invalidFileType,
  attachmentUploadFailed,
  notAuthenticated,
  ticketNotFound,
  accessDenied,
  ticketClosed,
  invalidMessage,
  invalidRating,
  cannotRateUnresolvedTicket,
  networkError,
  unknown;

  String get message {
    switch (this) {
      case SupportError.invalidSubject:
        return 'Please enter a subject';
      case SupportError.subjectTooLong:
        return 'Subject is too long (max 100 characters)';
      case SupportError.invalidDescription:
        return 'Please describe your issue';
      case SupportError.descriptionTooLong:
        return 'Description is too long (max 5000 characters)';
      case SupportError.tooManyAttachments:
        return 'Maximum 5 attachments allowed';
      case SupportError.attachmentTooLarge:
        return 'Attachment too large (max 10MB)';
      case SupportError.invalidFileType:
        return 'Invalid file type. Allowed: images, PDF, text';
      case SupportError.attachmentUploadFailed:
        return 'Failed to upload attachment';
      case SupportError.notAuthenticated:
        return 'Please sign in to continue';
      case SupportError.ticketNotFound:
        return 'Ticket not found';
      case SupportError.accessDenied:
        return 'Access denied';
      case SupportError.ticketClosed:
        return 'This ticket is closed';
      case SupportError.invalidMessage:
        return 'Please enter a message';
      case SupportError.invalidRating:
        return 'Please select a rating (1-5)';
      case SupportError.cannotRateUnresolvedTicket:
        return 'Cannot rate unresolved ticket';
      case SupportError.networkError:
        return 'Network error. Please try again';
      case SupportError.unknown:
        return 'An error occurred. Please try again';
    }
  }
}

/// Result wrapper for support operations.
class SupportResult<T> {
  final T? value;
  final SupportError? error;

  const SupportResult._({this.value, this.error});

  factory SupportResult.success(T value) => SupportResult._(value: value);
  factory SupportResult.failure(SupportError error) =>
      SupportResult._(error: error);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

/// Constants for support service validation.
class SupportConstants {
  SupportConstants._();

  static const int maxAttachments = 5;
  static const int maxAttachmentSizeMB = 10;
  static const int maxSubjectLength = 100;
  static const int maxDescriptionLength = 5000;
  static const int maxMessageLength = 5000;
}

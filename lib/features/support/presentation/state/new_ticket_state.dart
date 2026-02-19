import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';

/// State for creating a new support ticket.
@immutable
class NewTicketState {
  /// Selected ticket type.
  final TicketType? type;

  /// Selected ticket category.
  final TicketCategory? category;

  /// Subject text.
  final String subject;

  /// Description text.
  final String description;

  /// Selected attachments.
  final List<PendingAttachment> attachments;

  /// Whether submission is in progress.
  final bool isSubmitting;

  /// Error message if submission failed.
  final String? error;

  /// Success message after submission.
  final String? successMessage;

  /// Whether form has been validated.
  final bool hasAttemptedSubmit;

  const NewTicketState({
    this.type,
    this.category,
    this.subject = '',
    this.description = '',
    this.attachments = const [],
    this.isSubmitting = false,
    this.error,
    this.successMessage,
    this.hasAttemptedSubmit = false,
  });

  /// Initial empty state.
  factory NewTicketState.initial() {
    return const NewTicketState();
  }

  /// Create copy with updated fields.
  NewTicketState copyWith({
    TicketType? type,
    bool clearType = false,
    TicketCategory? category,
    bool clearCategory = false,
    String? subject,
    String? description,
    List<PendingAttachment>? attachments,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccessMessage = false,
    bool? hasAttemptedSubmit,
  }) {
    return NewTicketState(
      type: clearType ? null : (type ?? this.type),
      category: clearCategory ? null : (category ?? this.category),
      subject: subject ?? this.subject,
      description: description ?? this.description,
      attachments: attachments ?? this.attachments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      hasAttemptedSubmit: hasAttemptedSubmit ?? this.hasAttemptedSubmit,
    );
  }

  /// Whether form is complete and valid.
  bool get isValid {
    return type != null &&
        category != null &&
        subject.trim().isNotEmpty &&
        subject.length <= 100 &&
        description.trim().isNotEmpty &&
        description.length <= 5000 &&
        attachments.length <= 5;
  }

  /// Whether subject is valid.
  bool get isSubjectValid {
    if (!hasAttemptedSubmit) return true;
    return subject.trim().isNotEmpty && subject.length <= 100;
  }

  /// Whether description is valid.
  bool get isDescriptionValid {
    if (!hasAttemptedSubmit) return true;
    return description.trim().isNotEmpty && description.length <= 5000;
  }

  /// Error message for subject field.
  String? get subjectError {
    if (!hasAttemptedSubmit) return null;
    if (subject.trim().isEmpty) return 'Please enter a subject';
    if (subject.length > 100) return 'Subject is too long (max 100 characters)';
    return null;
  }

  /// Error message for description field.
  String? get descriptionError {
    if (!hasAttemptedSubmit) return null;
    if (description.trim().isEmpty) return 'Please describe your issue';
    if (description.length > 5000) {
      return 'Description is too long (max 5000 characters)';
    }
    return null;
  }

  /// Characters remaining for subject.
  int get subjectCharsRemaining => 100 - subject.length;

  /// Characters remaining for description.
  int get descriptionCharsRemaining => 5000 - description.length;

  /// Attachments count display.
  String get attachmentsCountText => '${attachments.length}/5 attachments';

  /// Total size of attachments in MB.
  double get totalAttachmentSizeMB {
    int totalBytes = 0;
    for (final attachment in attachments) {
      if (attachment.bytes != null) {
        totalBytes += attachment.bytes!.length;
      }
    }
    return totalBytes / (1024 * 1024);
  }

  /// Whether more attachments can be added.
  bool get canAddAttachment => attachments.length < 5;
}

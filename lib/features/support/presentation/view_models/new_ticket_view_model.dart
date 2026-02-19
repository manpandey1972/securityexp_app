import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/validators/pii_validator.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';

import '../../data/models/models.dart';
import '../../services/support_service.dart';
import '../../services/support_analytics.dart';
import '../state/new_ticket_state.dart';

/// ViewModel for creating a new support ticket.
///
/// Manages form state, validation, attachment handling, and submission.
class NewTicketViewModel extends ChangeNotifier {
  final SupportService _supportService;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'NewTicketViewModel';

  NewTicketState _state = NewTicketState.initial();
  NewTicketState get state => _state;

  bool _isDisposed = false;

  NewTicketViewModel({required SupportService supportService})
    : _supportService = supportService;

  // ========================================
  // FORM FIELD SETTERS
  // ========================================

  /// Set ticket type.
  void setType(TicketType? type) {
    _updateState(_state.copyWith(type: type, clearError: true));

    // Auto-set category for certain types
    if (type == TicketType.bug) {
      setCategory(TicketCategory.performance);
    } else if (type == TicketType.payment) {
      setCategory(TicketCategory.other);
    } else if (type == TicketType.account) {
      setCategory(TicketCategory.profile);
    }
  }

  /// Set ticket category.
  void setCategory(TicketCategory? category) {
    _updateState(_state.copyWith(category: category, clearError: true));
  }

  /// Set subject text.
  void setSubject(String subject) {
    _updateState(_state.copyWith(subject: subject, clearError: true));
  }

  /// Set description text.
  void setDescription(String description) {
    _updateState(_state.copyWith(description: description, clearError: true));
  }

  // ========================================
  // ATTACHMENT HANDLING
  // ========================================

  /// Pick an image from gallery (uses FilePicker for web compatibility).
  Future<void> pickImageFromGallery() async {
    if (!_state.canAddAttachment) {
      SnackbarService.show('Maximum 5 attachments allowed');
      return;
    }

    try {
      // Use FilePicker with media type for web compatibility (same as chat)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // Always load bytes for web compatibility
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        await _addAttachmentFromPlatformFile(result.files.single);
      }
    } catch (e, stackTrace) {
      _log.error('Failed to pick image', error: e, stackTrace: stackTrace, tag: _tag);
      SnackbarService.show('Failed to select image');
    }
  }

  /// Take a photo with camera.
  Future<void> takePhoto() async {
    if (!_state.canAddAttachment) {
      SnackbarService.show('Maximum 5 attachments allowed');
      return;
    }

    // Camera not available on web - use gallery instead
    if (kIsWeb) {
      SnackbarService.show('Camera not available on web. Use gallery instead.');
      return;
    }

    // On mobile, use FilePicker with camera (or fallback to gallery)
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        await _addAttachmentFromPlatformFile(result.files.single);
      }
    } catch (e, stackTrace) {
      _log.error('Failed to take photo', error: e, stackTrace: stackTrace, tag: _tag);
      SnackbarService.show('Failed to take photo');
    }
  }

  /// Pick a file (PDF or document).
  Future<void> pickFile() async {
    if (!_state.canAddAttachment) {
      SnackbarService.show('Maximum 5 attachments allowed');
      return;
    }

    try {
      // Use FileType.any instead of FileType.custom for better web compatibility
      final result = await FilePicker.platform.pickFiles(
        withData: true, // Always load bytes for web compatibility
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        
        // Validate file extension
        final ext = file.extension?.toLowerCase() ?? '';
        final allowedExtensions = ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'gif', 'webp'];
        if (!allowedExtensions.contains(ext)) {
          SnackbarService.show('Only images, PDF, or text files allowed');
          return;
        }
        
        await _addAttachmentFromPlatformFile(file);
      }
    } catch (e, stackTrace) {
      _log.error('Failed to pick file', error: e, stackTrace: stackTrace, tag: _tag);
      SnackbarService.show('Failed to select file');
    }
  }

  /// Add attachment from PlatformFile (FilePicker result).
  Future<void> _addAttachmentFromPlatformFile(PlatformFile platformFile) async {
    try {
      // Check file size
      final sizeBytes = platformFile.size;
      final sizeMB = sizeBytes / (1024 * 1024);
      
      if (sizeMB > 10) {
        SnackbarService.show('File too large. Maximum 10MB allowed.');
        return;
      }
      
      PendingAttachment attachment;
      
      if (platformFile.bytes != null) {
        // Use bytes (works on both web and native when withData: true)
        attachment = PendingAttachment.fromBytes(
          platformFile.bytes!,
          platformFile.name,
        );
      } else if (platformFile.path != null && platformFile.path!.isNotEmpty) {
        // Fallback to file path on native
        attachment = PendingAttachment.fromPath(
          platformFile.path!,
          platformFile.name,
        );
      } else {
        SnackbarService.show('Failed to read file data');
        return;
      }

      final newAttachments = List<PendingAttachment>.from(_state.attachments)
        ..add(attachment);
      _updateState(
        _state.copyWith(attachments: newAttachments, clearError: true),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to add attachment', error: e, stackTrace: stackTrace, tag: _tag);
      SnackbarService.show('Failed to add attachment');
    }
  }

  /// Remove an attachment at index.
  void removeAttachment(int index) {
    if (index < 0 || index >= _state.attachments.length) return;

    final newAttachments = List<PendingAttachment>.from(_state.attachments)..removeAt(index);
    _updateState(_state.copyWith(attachments: newAttachments));
  }

  /// Clear all attachments.
  void clearAttachments() {
    _updateState(_state.copyWith(attachments: []));
  }

  // ========================================
  // FORM VALIDATION & SUBMISSION
  // ========================================

  /// Validate the form before submission.
  bool validate() {
    _updateState(_state.copyWith(hasAttemptedSubmit: true));

    if (_state.type == null) {
      _updateState(_state.copyWith(error: 'Please select a ticket type'));
      return false;
    }

    if (_state.category == null) {
      _updateState(_state.copyWith(error: 'Please select a category'));
      return false;
    }

    if (_state.subject.trim().isEmpty) {
      _updateState(_state.copyWith(error: 'Please enter a subject'));
      return false;
    }

    if (_state.subject.length > 100) {
      _updateState(_state.copyWith(error: 'Subject is too long'));
      return false;
    }

    // Check subject for PII
    final subjectPiiResult = PIIValidator().validate(_state.subject);
    if (!subjectPiiResult.isValid) {
      _updateState(_state.copyWith(error: subjectPiiResult.message));
      return false;
    }

    if (_state.description.trim().isEmpty) {
      _updateState(_state.copyWith(error: 'Please describe your issue'));
      return false;
    }

    if (_state.description.length > 5000) {
      _updateState(_state.copyWith(error: 'Description is too long'));
      return false;
    }

    // Check description for PII
    final descPiiResult = PIIValidator().validate(_state.description);
    if (!descPiiResult.isValid) {
      _updateState(_state.copyWith(error: descPiiResult.message));
      return false;
    }

    return true;
  }

  /// Submit the ticket.
  Future<SupportTicket?> submit() async {
    if (!validate()) return null;

    _log.info(
      'Submitting ticket: ${_state.type}, ${_state.category}',
      tag: _tag,
    );
    _updateState(_state.copyWith(isSubmitting: true, clearError: true));

    final result = await _supportService.createTicket(
      type: _state.type!,
      category: _state.category!,
      subject: _state.subject,
      description: _state.description,
      attachments: _state.attachments.isNotEmpty ? _state.attachments : null,
    );

    if (_isDisposed) return null;

    if (result.isSuccess) {
      _log.info('Ticket created: ${result.value?.id}', tag: _tag);
      
      // Track successful submission
      sl<SupportAnalytics>().trackTicketSubmitted(
        ticketId: result.value?.id ?? '',
        type: _state.type!,
        category: _state.category!,
        priority: TicketPriority.fromTicketType(_state.type!),
        attachmentCount: _state.attachments.length,
      );
      
      _updateState(
        _state.copyWith(
          isSubmitting: false,
          successMessage: 'Ticket submitted successfully!',
        ),
      );
      return result.value;
    } else {
      _log.warning(
        'Ticket submission failed: ${result.error?.message}',
        tag: _tag,
      );
      _updateState(
        _state.copyWith(
          isSubmitting: false,
          error: result.error?.message ?? 'Failed to submit ticket',
        ),
      );
      return null;
    }
  }

  /// Reset form to initial state.
  void reset() {
    _updateState(NewTicketState.initial());
  }

  /// Clear error message.
  void clearError() {
    _updateState(_state.copyWith(clearError: true));
  }

  /// Update state and notify listeners.
  void _updateState(NewTicketState newState) {
    _state = newState;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

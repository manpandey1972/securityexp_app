// SupportValidator tests
//
// Tests for the support validator which validates ticket and reply inputs.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart';
import 'package:securityexperts_app/features/support/services/support_validator.dart';
import 'package:securityexperts_app/features/support/services/support_models.dart';

void main() {
  group('SupportValidator', () {
    group('validateTicketInput', () {
      test('should return null for valid input', () {
        final result = SupportValidator.validateTicketInput(
          'Valid Subject',
          'This is a valid description of the issue.',
          null,
        );
        expect(result, isNull);
      });

      test('should return invalidSubject for empty subject', () {
        final result = SupportValidator.validateTicketInput(
          '',
          'Valid description',
          null,
        );
        expect(result, SupportError.invalidSubject);
      });

      test('should return invalidSubject for whitespace only subject', () {
        final result = SupportValidator.validateTicketInput(
          '   ',
          'Valid description',
          null,
        );
        expect(result, SupportError.invalidSubject);
      });

      test('should return subjectTooLong for subject exceeding max length', () {
        final longSubject = 'A' * (SupportConstants.maxSubjectLength + 1);
        final result = SupportValidator.validateTicketInput(
          longSubject,
          'Valid description',
          null,
        );
        expect(result, SupportError.subjectTooLong);
      });

      test('should return invalidDescription for empty description', () {
        final result = SupportValidator.validateTicketInput(
          'Valid Subject',
          '',
          null,
        );
        expect(result, SupportError.invalidDescription);
      });

      test('should return invalidDescription for whitespace only description', () {
        final result = SupportValidator.validateTicketInput(
          'Valid Subject',
          '   ',
          null,
        );
        expect(result, SupportError.invalidDescription);
      });

      test('should return descriptionTooLong for description exceeding max length', () {
        final longDescription = 'A' * (SupportConstants.maxDescriptionLength + 1);
        final result = SupportValidator.validateTicketInput(
          'Valid Subject',
          longDescription,
          null,
        );
        expect(result, SupportError.descriptionTooLong);
      });

      test('should return tooManyAttachments when exceeding max attachments', () {
        final attachments = List<PendingAttachment>.generate(
          SupportConstants.maxAttachments + 1,
          (i) => PendingAttachment(filename: 'file$i.jpg'),
        );
        final result = SupportValidator.validateTicketInput(
          'Valid Subject',
          'Valid description',
          attachments,
        );
        expect(result, SupportError.tooManyAttachments);
      });

      test('should allow max attachments', () {
        final attachments = List<PendingAttachment>.generate(
          SupportConstants.maxAttachments,
          (i) => PendingAttachment(filename: 'file$i.jpg'),
        );
        final result = SupportValidator.validateTicketInput(
          'Valid Subject',
          'Valid description',
          attachments,
        );
        expect(result, isNull);
      });

      test('should accept subject at max length', () {
        final maxSubject = 'A' * SupportConstants.maxSubjectLength;
        final result = SupportValidator.validateTicketInput(
          maxSubject,
          'Valid description',
          null,
        );
        expect(result, isNull);
      });

      test('should accept description at max length', () {
        final maxDescription = 'A' * SupportConstants.maxDescriptionLength;
        final result = SupportValidator.validateTicketInput(
          'Valid Subject',
          maxDescription,
          null,
        );
        expect(result, isNull);
      });
    });

    group('validateAttachmentSize', () {
      test('should return null for null attachments', () {
        final result = SupportValidator.validateAttachmentSize(null);
        expect(result, isNull);
      });

      test('should return null for empty attachments list', () {
        final result = SupportValidator.validateAttachmentSize([]);
        expect(result, isNull);
      });

      test('should return null for attachments within size limit', () {
        final attachments = [
          PendingAttachment(
            filename: 'small.jpg',
            bytes: Uint8List(1024 * 1024), // 1 MB
          ),
        ];
        final result = SupportValidator.validateAttachmentSize(attachments);
        expect(result, isNull);
      });

      test('should return attachmentTooLarge for oversized attachment', () {
        final attachments = [
          PendingAttachment(
            filename: 'large.jpg',
            bytes: Uint8List(
              (SupportConstants.maxAttachmentSizeMB + 1) * 1024 * 1024,
            ),
          ),
        ];
        final result = SupportValidator.validateAttachmentSize(attachments);
        expect(result, SupportError.attachmentTooLarge);
      });

      test('should return null for attachment without bytes', () {
        final attachments = [
          PendingAttachment(filename: 'file.jpg'),
        ];
        final result = SupportValidator.validateAttachmentSize(attachments);
        expect(result, isNull);
      });

      test('should check all attachments and fail on first oversized', () {
        final attachments = [
          PendingAttachment(
            filename: 'small.jpg',
            bytes: Uint8List(1024), // 1 KB
          ),
          PendingAttachment(
            filename: 'large.jpg',
            bytes: Uint8List(
              (SupportConstants.maxAttachmentSizeMB + 1) * 1024 * 1024,
            ),
          ),
        ];
        final result = SupportValidator.validateAttachmentSize(attachments);
        expect(result, SupportError.attachmentTooLarge);
      });
    });

    group('validateReplyMessage', () {
      test('should return null for valid message', () {
        final result = SupportValidator.validateReplyMessage(
          'This is a valid reply message.',
          null,
        );
        expect(result, isNull);
      });

      test('should return invalidMessage for empty content without attachments', () {
        final result = SupportValidator.validateReplyMessage('', null);
        expect(result, SupportError.invalidMessage);
      });

      test('should return invalidMessage for whitespace content without attachments', () {
        final result = SupportValidator.validateReplyMessage('   ', null);
        expect(result, SupportError.invalidMessage);
      });

      test('should return invalidMessage for empty content with empty attachments', () {
        final result = SupportValidator.validateReplyMessage('', []);
        expect(result, SupportError.invalidMessage);
      });

      test('should return null for empty content with attachments', () {
        final attachments = [
          PendingAttachment(filename: 'file.jpg'),
        ];
        final result = SupportValidator.validateReplyMessage('', attachments);
        expect(result, isNull);
      });

      test('should return descriptionTooLong for message exceeding max length', () {
        final longMessage = 'A' * (SupportConstants.maxMessageLength + 1);
        final result = SupportValidator.validateReplyMessage(longMessage, null);
        expect(result, SupportError.descriptionTooLong);
      });

      test('should return tooManyAttachments when exceeding max', () {
        final attachments = List<PendingAttachment>.generate(
          SupportConstants.maxAttachments + 1,
          (i) => PendingAttachment(filename: 'file$i.jpg'),
        );
        final result = SupportValidator.validateReplyMessage(
          'Valid message',
          attachments,
        );
        expect(result, SupportError.tooManyAttachments);
      });

      test('should accept message at max length', () {
        final maxMessage = 'A' * SupportConstants.maxMessageLength;
        final result = SupportValidator.validateReplyMessage(maxMessage, null);
        expect(result, isNull);
      });
    });

    group('validateRating', () {
      test('should return null for valid ratings', () {
        expect(SupportValidator.validateRating(1), isNull);
        expect(SupportValidator.validateRating(2), isNull);
        expect(SupportValidator.validateRating(3), isNull);
        expect(SupportValidator.validateRating(4), isNull);
        expect(SupportValidator.validateRating(5), isNull);
      });

      test('should return invalidRating for rating below 1', () {
        expect(SupportValidator.validateRating(0), SupportError.invalidRating);
        expect(SupportValidator.validateRating(-1), SupportError.invalidRating);
      });

      test('should return invalidRating for rating above 5', () {
        expect(SupportValidator.validateRating(6), SupportError.invalidRating);
        expect(SupportValidator.validateRating(10), SupportError.invalidRating);
      });
    });

    group('getPriorityFromType', () {
      test('should return high priority for bug reports', () {
        expect(
          SupportValidator.getPriorityFromType(TicketType.bug),
          TicketPriority.high,
        );
      });

      test('should return medium priority for account issues', () {
        expect(
          SupportValidator.getPriorityFromType(TicketType.account),
          TicketPriority.medium,
        );
      });

      test('should return medium priority for payment issues', () {
        expect(
          SupportValidator.getPriorityFromType(TicketType.payment),
          TicketPriority.medium,
        );
      });

      test('should return low priority for feature requests', () {
        expect(
          SupportValidator.getPriorityFromType(TicketType.featureRequest),
          TicketPriority.low,
        );
      });

      test('should return low priority for feedback', () {
        expect(
          SupportValidator.getPriorityFromType(TicketType.feedback),
          TicketPriority.low,
        );
      });

      test('should return low priority for support', () {
        expect(
          SupportValidator.getPriorityFromType(TicketType.support),
          TicketPriority.low,
        );
      });
    });
  });

  group('SupportError', () {
    test('should have user-friendly messages for all errors', () {
      for (final error in SupportError.values) {
        expect(error.message, isNotEmpty);
        expect(error.message, isA<String>());
      }
    });

    test('should have specific messages for common errors', () {
      expect(
        SupportError.invalidSubject.message,
        'Please enter a subject',
      );
      expect(
        SupportError.invalidDescription.message,
        'Please describe your issue',
      );
      expect(
        SupportError.invalidRating.message,
        'Please select a rating (1-5)',
      );
    });
  });

  group('SupportConstants', () {
    test('should have reasonable limits', () {
      expect(SupportConstants.maxAttachments, greaterThan(0));
      expect(SupportConstants.maxAttachmentSizeMB, greaterThan(0));
      expect(SupportConstants.maxSubjectLength, greaterThan(0));
      expect(SupportConstants.maxDescriptionLength, greaterThan(0));
      expect(SupportConstants.maxMessageLength, greaterThan(0));
    });
  });

  group('SupportResult', () {
    test('should create success result', () {
      final result = SupportResult<String>.success('test value');
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.value, 'test value');
      expect(result.error, isNull);
    });

    test('should create failure result', () {
      final result = SupportResult<String>.failure(SupportError.unknown);
      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.value, isNull);
      expect(result.error, SupportError.unknown);
    });
  });
}

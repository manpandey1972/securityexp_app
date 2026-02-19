import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/core/validators/pii_validator.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/data/repositories/chat/chat_repositories.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/shared/services/profanity/profanity_filter_service.dart';
import 'package:greenhive_app/shared/services/snackbar_service.dart';

/// Handles message sending logic in chat
class MessageSendHandler {
  final ChatMessageRepository _messageRepository;
  final FirebaseAuth _firebaseAuth;
  final String roomId;
  final ItemScrollController itemScrollController;
  final Message? Function() getReplyToMessage;
  final Function() clearReply;

  MessageSendHandler({
    required ChatMessageRepository messageRepository,
    required this.roomId,
    required this.itemScrollController,
    required this.getReplyToMessage,
    required this.clearReply,
    FirebaseAuth? firebaseAuth,
  }) : _messageRepository = messageRepository,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Send a text message
  Future<void> sendMessage({
    required String text,
    required VoidCallback onSuccess,
  }) async {
    if (text.trim().isEmpty) return;

    // Check for PII (phone numbers, emails) before sending
    final piiResult = PIIValidator().validate(text);
    if (!piiResult.isValid) {
      SnackbarService.show(
        piiResult.message ?? 'Personal information detected',
        duration: const Duration(seconds: 3),
      );
      return; // Block sending
    }

    // Check for profanity before sending
    final profanityFilter = sl<ProfanityFilterService>();
    final profanityResult = profanityFilter.checkProfanitySync(text, context: 'chat');
    
    if (profanityResult.containsProfanity) {
      SnackbarService.show(
        'Your message contains inappropriate language. Please revise your message.',
        duration: const Duration(seconds: 3),
      );
      return; // Block sending
    }

    await ErrorHandler.handle<void>(
      operation: () async {
        // If there is no server roomId, skip server send (local-only chat)
        if (roomId.isEmpty) return;

        final user = _firebaseAuth.currentUser;
        if (user == null) return;

        final userId = user.uid;
        final message = Message(
          id: '',
          senderId: userId,
          type: MessageType.text,
          text: text,
          mediaUrl: null,
          replyToMessageId: getReplyToMessage()?.id,
          replyToMessage: getReplyToMessage(),
          timestamp: Timestamp.now(),
        );

        await _messageRepository.sendMessage(roomId, message);

        onSuccess();
        clearReply();

        // Scroll to bottom to show new message (after stream updates with longer delay)
        Future.delayed(const Duration(milliseconds: 800), () {
          if (itemScrollController.isAttached) {
            // For reversed ListView, index 0 (newest) is at bottom
            // Animate to position 0 to show new message
            itemScrollController.scrollTo(
              index: 0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          }
        });
        // Message will appear in real-time through stream
      },
      onError: (error) {
        // Error already shown by ErrorHandler, nothing extra needed
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:greenhive_app/data/models/models.dart';
import 'package:greenhive_app/features/chat/utils/chat_utils.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Helper class for message-related operations
class ChatMessageHelper {
  /// Check if a message is the last message from the current user
  static bool isLastMessageFromUser(Message message, List<Message> messages) {
    if (messages.isEmpty) {
      return false;
    }

    // Check if message is from current user
    final currentUserId = sl<FirebaseAuth>().currentUser?.uid;
    if (currentUserId == null || message.senderId != currentUserId) {
      return false;
    }

    // Check if this message is the very last message in the entire chat
    // Messages are in ascending order (oldest first), so the last message is at the end
    final lastMessage = messages.last;
    return lastMessage.id == message.id;
  }

  /// Copy message content to clipboard
  static void copyMessageToClipboard(BuildContext context, Message message) {
    DateTimeFormatter.copyMessageToClipboard(context, message);
  }

  /// Check if message can be edited (must be from current user and recent)
  static bool canEditMessage(Message message) {
    final currentUserId = sl<FirebaseAuth>().currentUser?.uid;
    if (currentUserId == null || message.senderId != currentUserId) {
      return false;
    }

    // Allow editing for messages sent within last 24 hours
    try {
      final timestamp = message.timestamp;
      final messageDateTime = timestamp.toDate();
      final hoursDiff = DateTime.now().difference(messageDateTime).inHours;
      return hoursDiff < 24;
    } catch (_) {
      return false;
    }
  }

  /// Check if message can be deleted (must be from current user)
  static bool canDeleteMessage(Message message) {
    final currentUserId = sl<FirebaseAuth>().currentUser?.uid;
    return currentUserId != null && message.senderId == currentUserId;
  }
}

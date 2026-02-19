import 'package:flutter_test/flutter_test.dart';
import 'package:securityexperts_app/data/models/chat_message_actions.dart';
import 'package:securityexperts_app/data/models/models.dart';

void main() {
  group('ChatMessageActions', () {
    // Track callback invocations
    late List<String> callbackLog;
    late Message testMessage;

    setUp(() {
      callbackLog = [];
      testMessage = Message(
        id: 'msg_123',
        senderId: 'user_1',
        type: MessageType.text,
        text: 'Test message',
        timestamp: Timestamp.now(),
      );
    });

    ChatMessageActions createActions({
      Function(Message)? onDelete,
      Function(Message)? onReply,
      Function(Message, String)? onEdit,
      Function(String)? onShowImagePreview,
      Function(String)? onPlayAudio,
      Function(String)? onPlayVideo,
      Function(Message)? onPlayReplyAudio,
      Function(Message)? onPlayReplyVideo,
      Function(String)? onShowReplyImagePreview,
      Function(Message)? onCopy,
      Function(String, String, String)? onDownload,
    }) {
      return ChatMessageActions(
        onDelete: onDelete ?? (msg) => callbackLog.add('delete:${msg.id}'),
        onReply: onReply ?? (msg) => callbackLog.add('reply:${msg.id}'),
        onEdit: onEdit ?? (msg, text) => callbackLog.add('edit:${msg.id}:$text'),
        onShowImagePreview: onShowImagePreview ?? (url) => callbackLog.add('imagePreview:$url'),
        onPlayAudio: onPlayAudio ?? (url) => callbackLog.add('playAudio:$url'),
        onPlayVideo: onPlayVideo ?? (url) => callbackLog.add('playVideo:$url'),
        onPlayReplyAudio: onPlayReplyAudio ?? (msg) => callbackLog.add('playReplyAudio:${msg.id}'),
        onPlayReplyVideo: onPlayReplyVideo ?? (msg) => callbackLog.add('playReplyVideo:${msg.id}'),
        onShowReplyImagePreview: onShowReplyImagePreview ?? (url) => callbackLog.add('replyImagePreview:$url'),
        onCopy: onCopy ?? (msg) => callbackLog.add('copy:${msg.id}'),
        onDownload: onDownload,
      );
    }

    group('Constructor', () {
      test('should create ChatMessageActions with all required callbacks', () {
        final actions = createActions();

        expect(actions.onDelete, isNotNull);
        expect(actions.onReply, isNotNull);
        expect(actions.onEdit, isNotNull);
        expect(actions.onShowImagePreview, isNotNull);
        expect(actions.onPlayAudio, isNotNull);
        expect(actions.onPlayVideo, isNotNull);
        expect(actions.onPlayReplyAudio, isNotNull);
        expect(actions.onPlayReplyVideo, isNotNull);
        expect(actions.onShowReplyImagePreview, isNotNull);
        expect(actions.onCopy, isNotNull);
      });

      test('should allow optional onDownload callback', () {
        final actionsWithoutDownload = createActions();
        expect(actionsWithoutDownload.onDownload, isNull);

        final actionsWithDownload = createActions(
          onDownload: (url, name, type) => callbackLog.add('download:$url'),
        );
        expect(actionsWithDownload.onDownload, isNotNull);
      });
    });

    group('Callback Invocation', () {
      test('onDelete should be callable with Message', () {
        final actions = createActions();
        
        actions.onDelete(testMessage);
        
        expect(callbackLog, contains('delete:msg_123'));
      });

      test('onReply should be callable with Message', () {
        final actions = createActions();
        
        actions.onReply(testMessage);
        
        expect(callbackLog, contains('reply:msg_123'));
      });

      test('onEdit should be callable with Message and String', () {
        final actions = createActions();
        
        actions.onEdit(testMessage, 'Edited text');
        
        expect(callbackLog, contains('edit:msg_123:Edited text'));
      });

      test('onShowImagePreview should be callable with URL', () {
        final actions = createActions();
        
        actions.onShowImagePreview('https://example.com/image.jpg');
        
        expect(callbackLog, contains('imagePreview:https://example.com/image.jpg'));
      });

      test('onPlayAudio should be callable with URL', () {
        final actions = createActions();
        
        actions.onPlayAudio('https://example.com/audio.m4a');
        
        expect(callbackLog, contains('playAudio:https://example.com/audio.m4a'));
      });

      test('onPlayVideo should be callable with URL', () {
        final actions = createActions();
        
        actions.onPlayVideo('https://example.com/video.mp4');
        
        expect(callbackLog, contains('playVideo:https://example.com/video.mp4'));
      });

      test('onPlayReplyAudio should be callable with Message', () {
        final actions = createActions();
        final replyMessage = Message(
          id: 'reply_audio_msg',
          senderId: 'user_2',
          type: MessageType.audio,
          mediaUrl: 'https://example.com/reply_audio.m4a',
          timestamp: Timestamp.now(),
        );
        
        actions.onPlayReplyAudio(replyMessage);
        
        expect(callbackLog, contains('playReplyAudio:reply_audio_msg'));
      });

      test('onPlayReplyVideo should be callable with Message', () {
        final actions = createActions();
        final replyMessage = Message(
          id: 'reply_video_msg',
          senderId: 'user_2',
          type: MessageType.video,
          mediaUrl: 'https://example.com/reply_video.mp4',
          timestamp: Timestamp.now(),
        );
        
        actions.onPlayReplyVideo(replyMessage);
        
        expect(callbackLog, contains('playReplyVideo:reply_video_msg'));
      });

      test('onShowReplyImagePreview should be callable with URL', () {
        final actions = createActions();
        
        actions.onShowReplyImagePreview('https://example.com/reply_image.jpg');
        
        expect(callbackLog, contains('replyImagePreview:https://example.com/reply_image.jpg'));
      });

      test('onCopy should be callable with Message', () {
        final actions = createActions();
        
        actions.onCopy(testMessage);
        
        expect(callbackLog, contains('copy:msg_123'));
      });

      test('onDownload should be callable with URL, name, and type', () {
        final actions = createActions(
          onDownload: (url, name, type) => callbackLog.add('download:$url:$name:$type'),
        );
        
        actions.onDownload!('https://example.com/file.pdf', 'file.pdf', 'doc');
        
        expect(callbackLog, contains('download:https://example.com/file.pdf:file.pdf:doc'));
      });
    });

    group('Multiple Callback Invocations', () {
      test('should allow invoking same callback multiple times', () {
        final actions = createActions();
        
        actions.onDelete(testMessage);
        actions.onDelete(testMessage);
        actions.onDelete(testMessage);
        
        expect(callbackLog.where((e) => e.startsWith('delete:')).length, 3);
      });

      test('should allow invoking different callbacks in sequence', () {
        final actions = createActions();
        
        actions.onReply(testMessage);
        actions.onCopy(testMessage);
        actions.onDelete(testMessage);
        
        expect(callbackLog, contains('reply:msg_123'));
        expect(callbackLog, contains('copy:msg_123'));
        expect(callbackLog, contains('delete:msg_123'));
        expect(callbackLog.length, 3);
      });
    });

    group('Callback with Different Message Types', () {
      test('should handle text message', () {
        final actions = createActions();
        final textMessage = Message(
          id: 'text_msg',
          senderId: 'user_1',
          type: MessageType.text,
          text: 'Hello world',
          timestamp: Timestamp.now(),
        );
        
        actions.onCopy(textMessage);
        
        expect(callbackLog, contains('copy:text_msg'));
      });

      test('should handle image message', () {
        final actions = createActions();
        final imageMessage = Message(
          id: 'image_msg',
          senderId: 'user_1',
          type: MessageType.image,
          mediaUrl: 'https://example.com/image.jpg',
          timestamp: Timestamp.now(),
        );
        
        actions.onShowImagePreview(imageMessage.mediaUrl!);
        
        expect(callbackLog, contains('imagePreview:https://example.com/image.jpg'));
      });

      test('should handle audio message', () {
        final actions = createActions();
        final audioMessage = Message(
          id: 'audio_msg',
          senderId: 'user_1',
          type: MessageType.audio,
          mediaUrl: 'https://example.com/audio.m4a',
          timestamp: Timestamp.now(),
        );
        
        actions.onPlayAudio(audioMessage.mediaUrl!);
        
        expect(callbackLog, contains('playAudio:https://example.com/audio.m4a'));
      });

      test('should handle video message', () {
        final actions = createActions();
        final videoMessage = Message(
          id: 'video_msg',
          senderId: 'user_1',
          type: MessageType.video,
          mediaUrl: 'https://example.com/video.mp4',
          timestamp: Timestamp.now(),
        );
        
        actions.onPlayVideo(videoMessage.mediaUrl!);
        
        expect(callbackLog, contains('playVideo:https://example.com/video.mp4'));
      });

      test('should handle document message', () {
        final actions = createActions(
          onDownload: (url, name, type) => callbackLog.add('download:$url:$name:$type'),
        );
        final docMessage = Message(
          id: 'doc_msg',
          senderId: 'user_1',
          type: MessageType.doc,
          mediaUrl: 'https://example.com/document.pdf',
          timestamp: Timestamp.now(),
        );
        
        actions.onDownload!(docMessage.mediaUrl!, 'document.pdf', 'doc');
        
        expect(callbackLog, contains('download:https://example.com/document.pdf:document.pdf:doc'));
      });
    });

    group('Reply Message Handling', () {
      test('should handle reply audio playback', () {
        final actions = createActions();
        final originalMessage = Message(
          id: 'original_msg',
          senderId: 'user_1',
          type: MessageType.audio,
          mediaUrl: 'https://example.com/original_audio.m4a',
          timestamp: Timestamp.now(),
        );
        final replyMessage = Message(
          id: 'reply_to_audio',
          senderId: 'user_2',
          type: MessageType.text,
          text: 'Reply to your audio',
          replyToMessageId: originalMessage.id,
          replyToMessage: originalMessage,
          timestamp: Timestamp.now(),
        );
        
        actions.onPlayReplyAudio(replyMessage.replyToMessage!);
        
        expect(callbackLog, contains('playReplyAudio:original_msg'));
      });

      test('should handle reply video playback', () {
        final actions = createActions();
        final originalMessage = Message(
          id: 'original_video',
          senderId: 'user_1',
          type: MessageType.video,
          mediaUrl: 'https://example.com/original_video.mp4',
          timestamp: Timestamp.now(),
        );
        
        actions.onPlayReplyVideo(originalMessage);
        
        expect(callbackLog, contains('playReplyVideo:original_video'));
      });

      test('should handle reply image preview', () {
        final actions = createActions();
        final originalUrl = 'https://example.com/original_image.jpg';
        
        actions.onShowReplyImagePreview(originalUrl);
        
        expect(callbackLog, contains('replyImagePreview:https://example.com/original_image.jpg'));
      });
    });

    group('Edge Cases', () {
      test('should handle message with empty text', () {
        final actions = createActions();
        final emptyMessage = Message(
          id: 'empty_msg',
          senderId: 'user_1',
          type: MessageType.text,
          text: '',
          timestamp: Timestamp.now(),
        );
        
        actions.onCopy(emptyMessage);
        
        expect(callbackLog, contains('copy:empty_msg'));
      });

      test('should handle edit with empty new text', () {
        final actions = createActions();
        
        actions.onEdit(testMessage, '');
        
        expect(callbackLog, contains('edit:msg_123:'));
      });

      test('should handle URLs with special characters', () {
        final actions = createActions();
        final specialUrl = 'https://example.com/path?query=value&foo=bar#anchor';
        
        actions.onShowImagePreview(specialUrl);
        
        expect(callbackLog, contains('imagePreview:$specialUrl'));
      });

      test('should handle message with special characters in text', () {
        final actions = createActions();
        final specialMessage = Message(
          id: 'special_msg',
          senderId: 'user_1',
          type: MessageType.text,
          text: 'Hello <script>alert("xss")</script> & "quotes"',
          timestamp: Timestamp.now(),
        );
        
        actions.onCopy(specialMessage);
        
        expect(callbackLog, contains('copy:special_msg'));
      });
    });

    group('const Constructor', () {
      test('should be usable as const', () {
        // Since ChatMessageActions has a const constructor and all fields are final
        // we verify the immutability aspect
        final actions = ChatMessageActions(
          onDelete: (msg) {},
          onReply: (msg) {},
          onEdit: (msg, text) {},
          onShowImagePreview: (url) {},
          onPlayAudio: (url) {},
          onPlayVideo: (url) {},
          onPlayReplyAudio: (msg) {},
          onPlayReplyVideo: (msg) {},
          onShowReplyImagePreview: (url) {},
          onCopy: (msg) {},
        );
        
        expect(actions, isNotNull);
      });
    });
  });
}

import 'package:securityexperts_app/data/models/models.dart';

/// Consolidates all message action callbacks into a single model
class ChatMessageActions {
  final Function(Message) onDelete;
  final Function(Message) onReply;
  final Function(Message, String) onEdit;
  final Function(String) onShowImagePreview;
  final Function(String) onPlayAudio;
  final Function(String) onPlayVideo;
  final Function(Message) onPlayReplyAudio;
  final Function(Message) onPlayReplyVideo;
  final Function(String) onShowReplyImagePreview;
  final Function(Message) onCopy;
  final Function(String, String, String)? onDownload;

  const ChatMessageActions({
    required this.onDelete,
    required this.onReply,
    required this.onEdit,
    required this.onShowImagePreview,
    required this.onPlayAudio,
    required this.onPlayVideo,
    required this.onPlayReplyAudio,
    required this.onPlayReplyVideo,
    required this.onShowReplyImagePreview,
    required this.onCopy,
    this.onDownload,
  });
}

/// Message type enumeration for chat messages.
enum MessageType { text, image, video, audio, system, doc, callLog }

/// Extension methods for [MessageType] serialization.
extension MessageTypeExtension on MessageType {
  String toJson() {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.audio:
        return 'audio';
      case MessageType.system:
        return 'system';
      case MessageType.doc:
        return 'doc';
      case MessageType.callLog:
        return 'call_log';
    }
  }

  static MessageType fromJson(String json) {
    switch (json.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'system':
        return MessageType.system;
      case 'doc':
        return MessageType.doc;
      case 'call_log':
        return MessageType.callLog;
      case 'text':
      default:
        return MessageType.text;
    }
  }
}

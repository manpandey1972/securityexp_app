/// Helper class for determining media file types and categories
/// Consolidates file type checking logic used throughout the app
class MediaTypeHelper {
  /// List of image file extensions
  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  ];

  /// List of video file extensions
  static const List<String> videoExtensions = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    'flv',
    '3gp',
    'wmv',
  ];

  /// List of audio file extensions
  static const List<String> audioExtensions = [
    'mp3',
    'wav',
    'aac',
    'flac',
    'ogg',
    'm4a',
    'wma',
    'aiff',
  ];

  /// List of document file extensions
  static const List<String> documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'zip',
    'csv',
    'json',
  ];

  /// Get the file extension from a file path (lowercase, without dot)
  static String getExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filePath.substring(lastDot + 1).toLowerCase();
  }

  /// Check if a file is an image
  static bool isImage(String filePath) {
    final ext = getExtension(filePath);
    return imageExtensions.contains(ext);
  }

  /// Check if a file is a video
  static bool isVideo(String filePath) {
    final ext = getExtension(filePath);
    return videoExtensions.contains(ext);
  }

  /// Check if a file is audio
  static bool isAudio(String filePath) {
    final ext = getExtension(filePath);
    return audioExtensions.contains(ext);
  }

  /// Check if a file is a document
  static bool isDocument(String filePath) {
    final ext = getExtension(filePath);
    return documentExtensions.contains(ext);
  }

  /// Get the media category for a file
  /// Returns one of: 'image', 'video', 'audio', 'document', or 'unknown'
  static String getMediaCategory(String filePath) {
    if (isImage(filePath)) return 'image';
    if (isVideo(filePath)) return 'video';
    if (isAudio(filePath)) return 'audio';
    if (isDocument(filePath)) return 'document';
    return 'unknown';
  }

  /// Check if a file is a supported media type
  static bool isSupportedMedia(String filePath) {
    return isImage(filePath) ||
        isVideo(filePath) ||
        isAudio(filePath) ||
        isDocument(filePath);
  }

  /// Get a user-friendly name for the media type
  static String getMediaTypeName(String filePath) {
    switch (getMediaCategory(filePath)) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Document';
      default:
        return 'File';
    }
  }
}

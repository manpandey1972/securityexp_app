import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Represents a pending attachment that hasn't been uploaded yet.
/// Handles both web (bytes) and native (file path) platforms.
class PendingAttachment {
  /// The filename
  final String filename;

  /// File path (null on web)
  final String? filePath;

  /// File bytes (used on web, optional on native)
  final Uint8List? bytes;

  /// Original XFile reference (useful for reading bytes later)
  final XFile? xFile;

  const PendingAttachment({
    required this.filename,
    this.filePath,
    this.bytes,
    this.xFile,
  });

  /// Create from XFile (from image picker)
  static Future<PendingAttachment> fromXFile(XFile xFile) async {
    final bytes = await xFile.readAsBytes();
    return PendingAttachment(
      filename: xFile.name,
      filePath: xFile.path.isNotEmpty ? xFile.path : null,
      bytes: bytes,
      xFile: xFile,
    );
  }

  /// Create from file path (native only)
  factory PendingAttachment.fromPath(String filePath, String filename) {
    return PendingAttachment(
      filename: filename,
      filePath: filePath,
    );
  }

  /// Create from bytes with filename
  factory PendingAttachment.fromBytes(Uint8List bytes, String filename) {
    return PendingAttachment(
      filename: filename,
      bytes: bytes,
    );
  }
}

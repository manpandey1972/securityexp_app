import 'dart:typed_data';

/// Stub implementation for non-web platforms.
/// Returns null since blob URLs are a browser concept.
String? createBlobUrl(Uint8List bytes, String mimeType) => null;

/// Stub: no-op on non-web platforms.
void triggerBlobDownload(Uint8List bytes, String mimeType, String filename) {}

/// Stub: no-op on non-web platforms.
void openBlobInNewTab(Uint8List bytes, String mimeType) {}

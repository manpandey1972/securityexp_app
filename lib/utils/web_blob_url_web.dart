// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart';
import 'dart:typed_data';
import 'dart:js_interop';

/// Creates a blob URL from raw bytes for use with HTML5 media elements.
/// Only available on web platform.
String? createBlobUrl(Uint8List bytes, String mimeType) {
  try {
    final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: mimeType));
    return URL.createObjectURL(blob);
  } catch (_) {
    return null;
  }
}

/// Trigger a browser file download from decrypted bytes.
/// Creates a temporary blob URL, programmatically clicks an anchor, then
/// revokes the URL.
void triggerBlobDownload(Uint8List bytes, String mimeType, String filename) {
  final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: mimeType));
  final blobUrl = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement();
  anchor.href = blobUrl;
  anchor.download = filename;
  anchor.style.display = 'none';
  document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(blobUrl);
}

/// Open decrypted bytes in a new browser tab via blob URL.
/// Used for PDFs and other documents that the browser can natively render.
void openBlobInNewTab(Uint8List bytes, String mimeType) {
  final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: mimeType));
  final blobUrl = URL.createObjectURL(blob);
  window.open(blobUrl, '_blank');
}

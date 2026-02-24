// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Creates a blob URL from raw bytes for use with HTML5 media elements.
/// Only available on web platform.
String? createBlobUrl(Uint8List bytes, String mimeType) {
  try {
    final blob = html.Blob([bytes], mimeType);
    return html.Url.createObjectUrlFromBlob(blob);
  } catch (_) {
    return null;
  }
}

/// Trigger a browser file download from decrypted bytes.
/// Creates a temporary blob URL, programmatically clicks an anchor, then
/// revokes the URL.
void triggerBlobDownload(Uint8List bytes, String mimeType, String filename) {
  final blob = html.Blob([bytes], mimeType);
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: blobUrl)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(blobUrl);
}

// Conditional export: uses stub on native, real implementation on web.
export 'web_blob_url_stub.dart'
    if (dart.library.html) 'web_blob_url_web.dart';

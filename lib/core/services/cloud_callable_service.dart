import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Workaround for Firebase Functions iOS SDK native crash (SIGABRT)
/// under Xcode 26. Replicates the Firebase callable protocol using
/// raw Dart HTTP, bypassing the native iOS SDK entirely.
///
/// Uses the same request/response format as the Firebase callable protocol:
/// - Request: POST with JSON body `{"data": <payload>}` + Bearer auth token
/// - Response: `{"result": <data>}` on success
///
/// TODO: Remove this when the Firebase iOS SDK crash is fixed upstream.
/// Track: https://github.com/firebase/flutterfire/issues
class CloudCallableService {
  final FirebaseAuth _auth;
  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'CloudCallable';

  /// Base URL for cloud functions.
  /// For v2 callable functions in us-central1.
  static const String _baseUrl =
      'https://us-central1-securityexp-app.cloudfunctions.net';

  CloudCallableService({required FirebaseAuth auth}) : _auth = auth;

  /// Call a cloud function, replicating the Firebase callable protocol.
  /// Returns the parsed response data (equivalent to `HttpsCallableResult.data`).
  Future<dynamic> call(
    String functionName,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = await user.getIdToken();
    final url = Uri.parse('$_baseUrl/$functionName');

    _log.debug('Calling $functionName via HTTP', tag: _tag);

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'data': payload}),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // Firebase callable protocol wraps response in {"result": ...}
      final result = body['result'];
      _log.debug('$functionName returned successfully', tag: _tag);
      return result;
    } else {
      _log.error(
        '$functionName failed with status ${response.statusCode}',
        tag: _tag,
        error: response.body,
      );
      // Parse Firebase error format if possible
      try {
        final body = jsonDecode(response.body);
        final error = body['error'];
        if (error != null) {
          throw FirebaseCallableException(
            code: error['status'] ?? 'UNKNOWN',
            message: error['message'] ?? 'Cloud function error',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        if (e is FirebaseCallableException) rethrow;
      }
      throw FirebaseCallableException(
        code: 'HTTP_${response.statusCode}',
        message: 'Cloud function returned ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Whether this workaround should be used (iOS only, not on web).
  static bool get shouldUseHttpWorkaround => !kIsWeb && Platform.isIOS;
}

class FirebaseCallableException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  FirebaseCallableException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => 'FirebaseCallableException($code): $message';
}

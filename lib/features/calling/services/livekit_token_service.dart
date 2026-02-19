import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:greenhive_app/core/config/livekit_config.dart';
import 'package:greenhive_app/shared/services/error_handler.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Service for generating LiveKit access tokens from cloud function
class LiveKitTokenService {
  static final LiveKitTokenService _instance = LiveKitTokenService._internal();

  factory LiveKitTokenService() => _instance;
  LiveKitTokenService._internal();

  final _log = sl<AppLogger>();
  static const _tag = 'LiveKitTokenService';

  /// Generate access token from cloud function
  Future<String> generateToken({
    required String userId,
    required String userName,
    required String roomName,
    required bool canPublish,
    required bool canSubscribe,
  }) async {
    return await ErrorHandler.handle<String>(
      operation: () async {
        _log.debug(
          'Requesting token for user: $userId, room: $roomName',
          tag: _tag,
        );

        // Use Firebase Cloud Functions SDK instead of raw HTTP
        final functions = FirebaseFunctions.instance;
        final result = await functions
            .httpsCallable('generateLiveKitTokenFunction')
            .call({
              'user_id': userId,
              'user_name': userName,
              'room': roomName,
              'can_publish': canPublish,
              'can_subscribe': canSubscribe,
            });

        final response = Map<String, dynamic>.from(result.data);
        _log.debug('Cloud function response received', tag: _tag);

        final success = response['success'] as bool? ?? false;
        if (!success) {
          final errorMsg = response['message'] ?? 'Token generation failed';
          _log.error('Token service returned success: false: $errorMsg', tag: _tag);
          throw Exception(errorMsg);
        }

        final resultData = Map<String, dynamic>.from(response['data']);
        final token = resultData['token'] as String?;
        
        if (token == null || token.isEmpty) {
          const errorMsg = 'Token service returned empty token';
          _log.error(errorMsg, tag: _tag);
          throw Exception(errorMsg);
        }

        _log.debug(
          'Token generated successfully (${token.length} chars)',
          tag: _tag,
        );

        // ✅ FIX: Validate token expiration before returning
        _validateTokenExpiration(token);

        return token;
      },
      fallback: '',
      onError: (error) =>
          _log.error('Failed to generate token: $error', tag: _tag),
    );
  }

  /// Get LiveKit server URL
  String get liveKitServerUrl => LiveKitConfig.liveKitServerUrl;

  /// ✅ FIX: Validate JWT token expiration to catch server-side issues early
  /// This prevents connection attempts with expired tokens
  void _validateTokenExpiration(String token) {
    ErrorHandler.handleSync(
      operation: () {
        // JWT format: header.payload.signature
        final parts = token.split('.');
        if (parts.length != 3) {
          throw Exception(
            'Invalid JWT format - expected 3 parts, got ${parts.length}',
          );
        }

        // Decode payload (base64url without padding)
        String payload = parts[1];

        // Add padding if necessary
        final padLength = (4 - (payload.length % 4)) % 4;
        payload += '=' * padLength;

        // Decode from base64url
        final decoded = utf8.decode(base64Url.decode(payload));
        final json = jsonDecode(decoded) as Map<String, dynamic>;

        // Get expiration claim
        final exp = json['exp'] as int?;
        if (exp == null) {
          throw Exception('Token missing exp (expiration) claim');
        }

        // Get current time in seconds
        final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Check if token is already expired
        if (exp < nowInSeconds) {
          final expiredSince = nowInSeconds - exp;
          final errorMsg =
              'Token is EXPIRED (by ${expiredSince}s). '
              'exp: $exp, now: $nowInSeconds. '
              '⚠️ Check Cloud Function - may be setting exp to hardcoded value like 7200 instead of now+7200';
          _log.error(errorMsg, tag: _tag);
          throw Exception(errorMsg);
        }

        // Check if token will expire soon (within 30 seconds)
        final timeToExpiry = exp - nowInSeconds;
        if (timeToExpiry < 30) {
          _log.warning(
            'Token expires very soon (in ${timeToExpiry}s). '
            'Consider requesting a new token.',
            tag: _tag,
          );
        }

        // Calculate actual TTL
        final ttlSeconds = exp - nowInSeconds;
        final ttlMinutes = ttlSeconds / 60;
        _log.debug(
          'Token validation passed. '
          'Expires in: ${ttlSeconds}s (${ttlMinutes.toStringAsFixed(1)}m). '
          'exp: $exp, now: $nowInSeconds',
          tag: _tag,
        );
      },
      onError: (error) {
        if (error is Exception && error.toString().contains('EXPIRED')) {
          throw error; // Re-throw expiration errors as-is
        }
        _log.warning('Could not validate token expiration: $error', tag: _tag);
        // Don't throw here - token might still be valid, just couldn't parse
      },
    );
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;

import 'incoming_call_path.dart';

/// Fallback path for platforms without native CallKit (web, desktop). The
/// Firestore listener is the sole source of incoming calls; every event
/// that isn't already terminal is forwarded straight to the Flutter
/// incoming-call dialog.
class DefaultIncomingCallPath extends IncomingCallPath {
  DefaultIncomingCallPath();

  @override
  String get tag => 'DefaultIncomingCallPath';

  @override
  Future<void> initialize() async {
    log.debug(
      'Initialized for ${kIsWeb ? "Web" : "non-mobile"} (Firestore-only mode)',
      tag: tag,
    );
  }

  @override
  Future<void> handleIncomingCall(Map<String, dynamic> callData) async {
    final callId = extractCallKey(callData) ?? '';
    log.debug('handleIncomingCall: callId=$callId', tag: tag);

    final status = callData['status'] as String?;
    if (isStaleCallStatus(status)) {
      log.debug('Call $callId already $status, ignoring', tag: tag);
      return;
    }

    if (incomingCallManager.hasIncomingCall) {
      log.debug('Already showing incoming call, skipping', tag: tag);
      return;
    }

    incomingCallManager.showIncomingCall(callData);
  }
}

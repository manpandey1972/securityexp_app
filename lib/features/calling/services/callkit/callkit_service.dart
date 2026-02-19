import 'dart:async';

import 'package:flutter/services.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

import '../incoming_call_strategy.dart';
import '../platform_utils.dart';
import 'package:uuid/uuid.dart';

/// Represents the state of a CallKit call
enum CallKitCallState {
  /// Call is connecting (outgoing)
  connecting,

  /// Call is ringing (incoming or outgoing)
  ringing,

  /// Call is active/connected
  active,

  /// Call is on hold
  held,

  /// Call has ended
  ended,
}

/// Data class representing a CallKit call action from native side
class CallKitAction {
  final String callUUID;
  final String action;
  final Map<String, dynamic>? data;

  CallKitAction({required this.callUUID, required this.action, this.data});

  factory CallKitAction.fromMap(Map<String, dynamic> map) {
    return CallKitAction(
      callUUID: map['callUUID'] as String,
      action: map['action'] as String,
      data: map['data'] as Map<String, dynamic>?,
    );
  }
}

/// Service for managing CallKit integration on iOS.
///
/// This service handles:
/// - Reporting incoming calls to iOS CallKit
/// - Reporting outgoing calls
/// - Managing call state transitions
/// - Processing user actions from the native call UI
/// - VoIP push token management
class CallKitService {
  static const _channelName = 'com.greenhive/callkit';

  static CallKitService? _instance;

  final MethodChannel _channel;

  /// Stream controller for call actions from native side
  final StreamController<CallKitAction> _callActionController =
      StreamController<CallKitAction>.broadcast();

  /// Stream controller for VoIP token updates
  final StreamController<String> _voipTokenController =
      StreamController<String>.broadcast();

  /// Current active call UUID
  String? _activeCallUUID;

  /// Current VoIP push token
  String? _voipToken;

  CallKitService._internal() : _channel = const MethodChannel(_channelName) {
    sl<AppLogger>().debug('Service singleton created', tag: 'CallKit');
    _setupEventListener();
  }

  /// Get the singleton instance
  factory CallKitService() {
    if (_instance == null) {
      sl<AppLogger>().debug('Creating new singleton instance', tag: 'CallKit');
    }
    _instance ??= CallKitService._internal();
    return _instance!;
  }

  /// Stream of call actions from native CallKit UI
  Stream<CallKitAction> get callActions => _callActionController.stream;

  /// Stream of VoIP token updates
  Stream<String> get voipTokenUpdates => _voipTokenController.stream;

  /// Current active call UUID
  String? get activeCallUUID => _activeCallUUID;

  /// Current VoIP push token
  String? get voipToken => _voipToken;

  /// Check if CallKit is available (iOS only)
  bool get isAvailable => PlatformUtils.isIOS;

  void _setupEventListener() {
    if (!isAvailable) {
      sl<AppLogger>().debug('Not available on this platform, skipping setup', tag: 'CallKit');
      return;
    }

    sl<AppLogger>().debug('Setting up method call handler', tag: 'CallKit');

    // Set up method call handler to receive events from native side
    // Native code uses invokeMethod to send events, not EventChannel
    _channel.setMethodCallHandler(_handleMethodCall);

    // Initialize native side (registers for VoIP push)
    _initializeNative();
  }

  /// Initialize native CallKit and PushKit
  Future<void> _initializeNative() async {
    sl<AppLogger>().debug('Calling native initialize...', tag: 'CallKit');
    try {
      await _channel.invokeMethod('initialize');
      sl<AppLogger>().debug('Native side initialized successfully', tag: 'CallKit');
    } catch (e, stackTrace) {
      sl<AppLogger>().warning('Error initializing native: $e', tag: 'CallKit');
      sl<AppLogger>().warning('Stack: $stackTrace', tag: 'CallKit');
    }
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    sl<AppLogger>().debug('Received method from native: ${call.method}', tag: 'CallKit');

    switch (call.method) {
      case 'onVoIPTokenReceived':
        final args = call.arguments as Map?;
        final token = args?['token'] as String?;
        if (token != null) {
          _voipToken = token;
          _voipTokenController.add(token);
          sl<AppLogger>().debug(
            'VoIP token received: ${token.substring(0, 20)}...',
            tag: 'CallKit',
          );
        }
        break;

      case 'onVoIPTokenInvalidated':
        _voipToken = null;
        sl<AppLogger>().debug('VoIP token invalidated', tag: 'CallKit');
        break;

      case 'onCallAction':
        final args = call.arguments as Map?;
        if (args != null) {
          final action = CallKitAction.fromMap(Map<String, dynamic>.from(args));
          _handleCallAction(action);
        }
        break;

      case 'onIncomingVoIPPush':
        // VoIP push received - the payload contains call info
        // Native CallKit UI is already shown, we need to mark this call as handled
        final args = call.arguments as Map?;
        sl<AppLogger>().debug('VoIP push received: $args', tag: 'CallKit');

        if (args != null) {
          final callId =
              args['callId'] as String? ?? args['roomName'] as String? ?? '';
          final callerId = args['callerId'] as String? ?? '';
          final callerName = args['callerName'] as String? ?? 'Unknown';
          final hasVideo =
              args['isVideo'] as bool? ?? args['hasVideo'] as bool? ?? false;
          final roomName = args['roomName'] as String?;
          final callUUID = args['callUUID'] as String?;

          // Store the active call UUID for later use when ending the call
          if (callUUID != null) {
            _activeCallUUID = callUUID;
            sl<AppLogger>().debug(
              'Stored active call UUID: $_activeCallUUID',
              tag: 'CallKit',
            );
          }

          // Mark this call as handled by CallKit to prevent duplicate Flutter dialog
          IncomingCallStrategy().handleVoIPPushCall(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            hasVideo: hasVideo,
            roomName: roomName,
          );
        }
        break;

      case 'onCallAccepted':
        // User accepted call via CallKit native UI
        final args = call.arguments as Map?;
        // Swift sends 'uuid' or 'callId', not 'callUUID'
        final callUUID =
            args?['uuid'] as String? ??
            args?['callUUID'] as String? ??
            args?['callId'] as String?;
        sl<AppLogger>().debug('Call accepted via CallKit UI: $callUUID', tag: 'CallKit');
        sl<AppLogger>().debug('Call accepted args: $args', tag: 'CallKit');
        _activeCallUUID = callUUID;
        // Always emit action if we have args - the pending data in strategy has the call info
        if (args != null || callUUID != null) {
          final action = CallKitAction(
            callUUID: callUUID ?? _activeCallUUID ?? '',
            action: 'answerCall',
            data: args != null ? Map<String, dynamic>.from(args) : null,
          );
          _callActionController.add(action);
        }
        break;

      case 'onCallEnded':
        // Call ended via CallKit native UI (user pressed end button)
        final args = call.arguments as Map?;
        final callUUID = args?['callUUID'] as String?;
        sl<AppLogger>().debug('Call ended via CallKit UI: $callUUID', tag: 'CallKit');
        if (callUUID != null && _activeCallUUID == callUUID) {
          _activeCallUUID = null;
        }
        if (callUUID != null) {
          final action = CallKitAction(
            callUUID: callUUID,
            action: 'endCall',
            data: args != null ? Map<String, dynamic>.from(args) : null,
          );
          _callActionController.add(action);
        }
        break;

      case 'onCallDeclined':
        // User declined incoming call via CallKit native UI
        final args = call.arguments as Map?;
        final callUUID = args?['callUUID'] as String?;
        sl<AppLogger>().debug('Call declined via CallKit UI: $callUUID', tag: 'CallKit');
        if (callUUID != null) {
          final action = CallKitAction(
            callUUID: callUUID,
            action: 'endCall',
            data: {'reason': 'declined', ...?args},
          );
          _callActionController.add(action);
        }
        break;

      case 'onCallMuted':
      case 'onMuteToggled':
        // User toggled mute via CallKit native UI
        final args = call.arguments as Map?;
        final callUUID =
            args?['callUUID'] as String? ?? args?['callId'] as String?;
        final muted =
            args?['muted'] as bool? ?? args?['isMuted'] as bool? ?? false;
        sl<AppLogger>().debug('Call muted=$muted via CallKit UI: $callUUID', tag: 'CallKit');
        if (callUUID != null) {
          final action = CallKitAction(
            callUUID: callUUID,
            action: 'setMuted',
            data: {'muted': muted, ...?args},
          );
          _callActionController.add(action);
        }
        break;

      default:
        sl<AppLogger>().debug('Unknown method from native: ${call.method}', tag: 'CallKit');
    }
    return null;
  }

  void _handleCallAction(CallKitAction action) {
    sl<AppLogger>().debug(
      'Call action: ${action.action} for ${action.callUUID}',
      tag: 'CallKit',
    );

    switch (action.action) {
      case 'answerCall':
        _activeCallUUID = action.callUUID;
        break;

      case 'endCall':
        if (_activeCallUUID == action.callUUID) {
          _activeCallUUID = null;
        }
        break;

      case 'startCall':
        _activeCallUUID = action.callUUID;
        break;

      case 'setMuted':
      case 'setHeld':
        // State managed by call page
        break;
    }

    _callActionController.add(action);
  }

  /// Report an incoming call to CallKit
  ///
  /// Returns the call UUID for tracking
  Future<String?> reportIncomingCall({
    required String callerName,
    required String callerId,
    String? callUUID,
    bool hasVideo = false,
  }) async {
    if (!isAvailable) {
      sl<AppLogger>().warning('Not available on this platform', tag: 'CallKit');
      return null;
    }

    try {
      final uuid = callUUID ?? const Uuid().v4();
      sl<AppLogger>().debug(
        'Reporting incoming call from $callerName (UUID: $uuid)',
        tag: 'CallKit',
      );

      final result = await _channel.invokeMethod<bool>('reportIncomingCall', {
        'callUUID': uuid,
        'callerName': callerName,
        'callerId': callerId,
        'hasVideo': hasVideo,
      });

      if (result == true) {
        _activeCallUUID = uuid;
        sl<AppLogger>().debug('Incoming call reported successfully', tag: 'CallKit');
        return uuid;
      } else {
        sl<AppLogger>().error('Failed to report incoming call', tag: 'CallKit');
        return null;
      }
    } on PlatformException catch (e) {
      sl<AppLogger>().error(
        'Platform error reporting incoming call: ${e.message}',
        tag: 'CallKit',
      );
      return null;
    } catch (e) {
      sl<AppLogger>().error('Error reporting incoming call', tag: 'CallKit', error: e);
      return null;
    }
  }

  /// Report an outgoing call starting
  Future<String?> reportOutgoingCall({
    required String calleeName,
    required String calleeId,
    String? callUUID,
    bool hasVideo = false,
  }) async {
    if (!isAvailable) return null;

    try {
      final uuid = callUUID ?? const Uuid().v4();
      sl<AppLogger>().debug(
        'Reporting outgoing call to $calleeName (UUID: $uuid)',
        tag: 'CallKit',
      );

      final result = await _channel.invokeMethod<bool>('reportOutgoingCall', {
        'callUUID': uuid,
        'calleeName': calleeName,
        'calleeId': calleeId,
        'hasVideo': hasVideo,
      });

      if (result == true) {
        _activeCallUUID = uuid;
        sl<AppLogger>().debug('Outgoing call reported successfully', tag: 'CallKit');
        return uuid;
      }
      return null;
    } on PlatformException catch (e) {
      sl<AppLogger>().error(
        'Platform error reporting outgoing call: ${e.message}',
        tag: 'CallKit',
      );
      return null;
    }
  }

  /// Report that the outgoing call has connected
  Future<void> reportOutgoingCallConnected({String? callUUID}) async {
    if (!isAvailable) return;

    final uuid = callUUID ?? _activeCallUUID;
    if (uuid == null) {
      sl<AppLogger>().warning('No active call to mark as connected', tag: 'CallKit');
      return;
    }

    try {
      await _channel.invokeMethod('reportOutgoingCallConnected', {
        'callUUID': uuid,
      });
      sl<AppLogger>().debug('Outgoing call marked as connected', tag: 'CallKit');
    } on PlatformException catch (e) {
      sl<AppLogger>().error('Error marking call connected: ${e.message}', tag: 'CallKit');
    }
  }

  /// End the current call
  Future<void> endCall({String? callUUID, int reason = 2}) async {
    if (!isAvailable) return;

    final uuid = callUUID ?? _activeCallUUID;
    sl<AppLogger>().debug(
      'endCall() called - uuid=$uuid, activeCallUUID=$_activeCallUUID',
      tag: 'CallKit',
    );

    // Always try to call native - it will use its stored UUID if ours is null
    try {
      await _channel.invokeMethod('endCall', {
        'callUUID': uuid, // May be null, native will handle it
        'reason': reason,
      });
      _activeCallUUID = null;
      sl<AppLogger>().debug('Call ended successfully', tag: 'CallKit');
    } on PlatformException catch (e) {
      sl<AppLogger>().error('Error ending call: ${e.message}', tag: 'CallKit');
    }
  }

  /// Set the mute state of the current call
  Future<void> setMuted(bool muted, {String? callUUID}) async {
    if (!isAvailable) return;

    final uuid = callUUID ?? _activeCallUUID;
    if (uuid == null) return;

    try {
      await _channel.invokeMethod('setMuted', {
        'callUUID': uuid,
        'muted': muted,
      });
      sl<AppLogger>().debug('Mute state set to: $muted', tag: 'CallKit');
    } on PlatformException catch (e) {
      sl<AppLogger>().error('Error setting mute: ${e.message}', tag: 'CallKit');
    }
  }

  /// Set the held state of the current call
  Future<void> setHeld(bool held, {String? callUUID}) async {
    if (!isAvailable) return;

    final uuid = callUUID ?? _activeCallUUID;
    if (uuid == null) return;

    try {
      await _channel.invokeMethod('setHeld', {'callUUID': uuid, 'held': held});
      sl<AppLogger>().debug('Hold state set to: $held', tag: 'CallKit');
    } on PlatformException catch (e) {
      sl<AppLogger>().error('Error setting hold: ${e.message}', tag: 'CallKit');
    }
  }

  /// Get the current VoIP push token
  Future<String?> getVoIPToken() async {
    if (!isAvailable) return null;

    try {
      final token = await _channel.invokeMethod<String>('getVoIPToken');
      if (token != null) {
        _voipToken = token;
      }
      return token;
    } on PlatformException catch (e) {
      sl<AppLogger>().error('Error getting VoIP token: ${e.message}', tag: 'CallKit');
      return null;
    }
  }

  /// Check if there is an active call
  bool get hasActiveCall => _activeCallUUID != null;

  /// Generate a new call UUID
  String generateCallUUID() => const Uuid().v4();

  /// Dispose of resources
  void dispose() {
    _channel.setMethodCallHandler(null);
    _callActionController.close();
    _voipTokenController.close();
    _instance = null;
  }
}

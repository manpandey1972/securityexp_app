import 'package:flutter/material.dart';
import 'package:greenhive_app/features/calling/pages/call_controller.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Coordinator for call UI navigation and minimization
///
/// This class manages the UI aspects of calls such as:
/// - Minimizing/restoring the call UI
/// - Tracking if there's an active call
/// - Coordinating between CallController and UI layers
///
/// Unlike the old CallManager, this does NOT duplicate call state.
/// It only manages UI navigation concerns.
class CallNavigationCoordinator extends ChangeNotifier {
  static final CallNavigationCoordinator _instance =
      CallNavigationCoordinator._internal();
  factory CallNavigationCoordinator() => _instance;
  CallNavigationCoordinator._internal();

  final AppLogger _log = sl<AppLogger>();
  static const String _tag = 'CallNavigationCoordinator';

  CallController? _activeController;
  bool _isMinimized = false;
  String _minimizedPosition = 'bottom'; // 'top' or 'bottom'
  
  // Listener for controller state changes
  VoidCallback? _controllerListener;

  // Pending call metadata (set before controller is created)
  String? _pendingCalleeId;
  String? _pendingCalleeName;
  String? _pendingRoomId;
  bool _pendingIsVideo = false;
  bool _pendingIsCaller = false;

  // Getters
  bool get isMinimized => _isMinimized;
  String get minimizedPosition => _minimizedPosition;

  /// Returns true if there's an active call or a pending call
  /// For outgoing calls (isCaller=true), we only need calleeId
  /// For incoming calls, we also need a non-empty roomId
  bool get hasActiveCall =>
      _activeController != null ||
      (_pendingCalleeId != null &&
          (_pendingIsCaller ||
              (_pendingRoomId != null && _pendingRoomId!.isNotEmpty)));
  CallController? get activeController => _activeController;

  // For backward compatibility with old CallManager API
  bool get isCallActive => hasActiveCall;
  String? get calleeId => _activeController?.calleeId ?? _pendingCalleeId;

  /// Callee name is stored in coordinator, not controller
  String? get calleeName => _pendingCalleeName;
  String? get roomId => _activeController?.session?.roomId ?? _pendingRoomId;
  bool get isVideo => _activeController?.isVideo ?? _pendingIsVideo;
  bool get isCaller => _activeController?.isCaller ?? _pendingIsCaller;

  /// Initiates a call UI without a controller yet
  ///
  /// This is called when starting a call from the UI (e.g., home page)
  /// before the CallController is actually created. Sets up the metadata
  /// needed for CallOverlay to display the call UI.
  void initiateCall({
    required String calleeId,
    required String calleeName,
    required bool isVideo,
    required bool isCaller,
    String? roomId,
  }) {
    _log.info(
      'initiateCall()',
      tag: _tag,
      data: {
        'calleeId': calleeId,
        'calleeName': calleeName,
        'isVideo': isVideo,
        'isCaller': isCaller,
        'roomId': roomId,
      },
    );
    _pendingCalleeId = calleeId;
    _pendingCalleeName = calleeName;
    // Only reset roomId if not provided - for incoming CallKit calls, roomId may be pre-set
    _pendingRoomId = roomId ?? _pendingRoomId ?? '';
    _pendingIsVideo = isVideo;
    _pendingIsCaller = isCaller;
    _isMinimized = false;
    _log.debug(
      'initiateCall() - hasActiveCall will be: $hasActiveCall',
      tag: _tag,
    );
    notifyListeners();
  }

  /// Sets the room ID for a pending call
  void setRoomId(String roomId) {
    _pendingRoomId = roomId;
    notifyListeners();
  }

  /// Starts tracking a new call
  ///
  /// Should be called when a CallController is created and
  /// the call UI is being shown.
  void startCall(CallController controller, {required String calleeName}) {
    // Remove listener from previous controller if any
    _removeControllerListener();
    
    _activeController = controller;
    _pendingCalleeName = calleeName;
    _isMinimized = false;

    // Listen to controller state changes and forward to our listeners
    // Only notify when UI-relevant state actually changes to prevent excessive rebuilds
    CallState? lastCallState = controller.callState;
    bool? lastHasMediaManager = controller.mediaManager != null;
    _controllerListener = () {
      final currentState = controller.callState;
      final currentHasMedia = controller.mediaManager != null;
      if (currentState != lastCallState || currentHasMedia != lastHasMediaManager) {
        _log.debug('Controller state changed: $lastCallState → $currentState', tag: _tag);
        lastCallState = currentState;
        lastHasMediaManager = currentHasMedia;
        notifyListeners();
      }
    };
    controller.addListener(_controllerListener!);

    // Delay notification to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  /// Remove listener from controller
  void _removeControllerListener() {
    if (_controllerListener != null && _activeController != null) {
      _activeController!.removeListener(_controllerListener!);
      _controllerListener = null;
    }
  }

  /// Minimizes the call UI
  ///
  /// The call continues in the background, but the UI is minimized
  /// to a small overlay.
  /// [position] can be 'top' or 'bottom' to control vertical alignment
  void minimize({String position = 'bottom'}) {
    _log.debug('minimize() called with position: $position', tag: _tag);
    if (_activeController != null) {
      // Defensive: no-op if already minimized to prevent redundant rebuilds
      if (_isMinimized && _minimizedPosition == position) {
        _log.verbose('Already minimized at $position, skipping', tag: _tag);
        return;
      }
      _log.debug(
        'Setting _isMinimized = true, position = $position',
        tag: _tag,
      );
      _isMinimized = true;
      _minimizedPosition = position;
      notifyListeners();
      _log.verbose(
        'After notifyListeners - isMinimized: $_isMinimized',
        tag: _tag,
      );
    } else {
      _log.warning('Cannot minimize - _activeController is null!', tag: _tag);
    }
  }

  /// Restores the call UI from minimized state
  void restore() {
    _isMinimized = false;
    notifyListeners();
  }

  /// Alias for minimize - kept for backward compatibility
  void setMinimized(bool minimized) {
    if (minimized) {
      minimize(position: 'bottom');
    } else {
      restore();
    }
  }

  /// Ends the current call
  ///
  /// Delegates to the CallController to actually end the call,
  /// then clears the active controller reference.
  /// Nullifies controller reference first to avoid reentrancy bugs.
  Future<void> endCall() async {
    final controller = _activeController;
    
    // If no controller exists, this might be a pending call (before controller created)
    // In that case, just clear the pending state
    if (controller == null) {
      _log.debug('endCall() called with no controller - clearing pending state', tag: _tag);
      _clearInternalState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return;
    }

    // Remove listener and clear reference first to avoid double-end if controller emits end event
    _removeControllerListener();
    _activeController = null;
    _isMinimized = false;
    
    // Also clear pending state to ensure clean state
    _pendingCalleeId = null;
    _pendingCalleeName = null;
    _pendingRoomId = null;
    _pendingIsVideo = false;
    _pendingIsCaller = false;

    // Delay notification to avoid setState during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    // Now safely end the call
    await controller.endCall();
  }

  /// Clears the active call without actually ending it
  ///
  /// Used when the call has already ended on the controller side
  /// and we just need to update the navigation state.
  void clearCall() {
    _clearInternalState();

    // Delay notification to avoid setState during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Internal helper to clear all call state
  void _clearInternalState() {
    _removeControllerListener();
    _activeController = null;
    _pendingCalleeId = null;
    _pendingCalleeName = null;
    _pendingRoomId = null;
    _pendingIsVideo = false;
    _pendingIsCaller = false;
    _isMinimized = false;
  }

  /// Reset singleton state (useful for testing and logout)
  void reset() {
    _clearInternalState();
    _log.debug('Reset complete', tag: _tag);
    // Notify listeners so UI updates on logout
    notifyListeners();
  }

  @override
  void dispose() {
    _activeController?.dispose();
    super.dispose();
  }
}

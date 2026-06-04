import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/features/calling/services/call_navigation_coordinator.dart';
import 'package:securityexperts_app/features/calling/services/incoming_call_manager.dart';
import 'package:securityexperts_app/features/calling/pages/call_page_v2.dart'
    show VideoCallScreenV2;
import 'package:securityexperts_app/features/calling/pages/call_controller.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/signaling_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/models/models.dart' show User;
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/features/calling/widgets/incoming_call_banner.dart';
import 'package:securityexperts_app/features/calling/widgets/call_connecting_view.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';

class CallOverlay extends StatefulWidget {
  final Widget child;

  const CallOverlay({super.key, required this.child});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  late final CallNavigationCoordinator _coordinator;
  late final IncomingCallManager _incomingCallManager;

  static const String _tag = 'CallOverlay';
  late final AppLogger _log;

  // Track listener registration to prevent duplicates during hot reload
  static int _instanceCounter = 0;
  late final int _instanceId;
  bool _listenersAttached = false;
  bool _initialized = false;

  // Position for the minimized floating window
  late double _top;
  late double _left;
  bool _wasMinimized = false; // Track previous minimized state
  bool _rebuildScheduled = false; // Debounce multiple setState calls
  
  // Peer user for profile picture in connecting view
  User? _peerUser;
  String? _lastFetchedCalleeId; // Track to avoid redundant fetches

  @override
  void initState() {
    super.initState();

    // Initialize instance counter and services in initState (safer than constructor)
    _instanceId = ++_instanceCounter;
    _log = sl<AppLogger>();
    _log.debug(
      'Instance $_instanceId created (total: $_instanceCounter)',
      tag: _tag,
    );

    _coordinator = CallNavigationCoordinator();
    _incomingCallManager = sl<IncomingCallManager>();
    _initialized = true;

    // Initialize to top right corner
    _top = 100;
    _left = 0; // Will be calculated in build based on screen size

    // Defer listener attachment to after the first frame.
    // This ensures the entire widget tree has finished building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _attachListeners();
      }
    });
  }

  void _attachListeners() {
    if (_listenersAttached) {
      _log.warning('Listeners already attached, skipping', tag: _tag);
      return;
    }
    _listenersAttached = true;
    _log.debug('Attaching listeners', tag: _tag);
    _coordinator.addListener(_onCallStateChanged);
    _incomingCallManager.addListener(_onCallStateChanged);

    // After attaching, manually trigger a state check in case there's
    // already an active call or incoming call (but defer it safely)
    if (_coordinator.isCallActive || _incomingCallManager.hasIncomingCall) {
      _onCallStateChanged();
    }
  }

  @override
  void dispose() {
    _log.debug('Disposing', tag: _tag);
    if (_listenersAttached) {
      _coordinator.removeListener(_onCallStateChanged);
      _incomingCallManager.removeListener(_onCallStateChanged);
      _listenersAttached = false;
    }
    super.dispose();
  }

  void _onCallStateChanged() {
    if (!mounted) return;

    // Debounce: if a rebuild is already scheduled, skip
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;

    _log.debug(
      'State changed - hasIncomingCall: ${_incomingCallManager.hasIncomingCall}, isCallActive: ${_coordinator.isCallActive}',
      tag: _tag,
    );
    
    // Fetch peer user if call is active and we haven't fetched for this callee
    final calleeId = _coordinator.calleeId;
    if (_coordinator.isCallActive && calleeId != null && calleeId != _lastFetchedCalleeId) {
      _fetchPeerUser(calleeId);
    }
    
    // Clear peer user if call is no longer active
    if (!_coordinator.isCallActive && _peerUser != null) {
      _peerUser = null;
      _lastFetchedCalleeId = null;
    }

    // Always use Future.delayed to ensure we're outside any build phase.
    // This is more reliable than checking schedulerPhase on web.
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      _rebuildScheduled = false;
      setState(() {
        // Force rebuild to show/hide incoming call dialog
      });
    });
  }
  
  /// Fetch peer user profile from Firestore for profile picture
  Future<void> _fetchPeerUser(String calleeId) async {
    _lastFetchedCalleeId = calleeId;
    try {
      final doc = await FirestoreInstance().db
          .collection('users')
          .doc(calleeId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _peerUser = User.fromJson(doc.data()!);
        });
      }
    } catch (e) {
      _log.warning('Error fetching peer user: $e', tag: _tag);
      // Fallback: create minimal user with profile picture URL
      if (mounted) {
        setState(() {
          _peerUser = _createCallerUser(calleeId, _coordinator.calleeName ?? 'Unknown');
        });
      }
    }
  }

  /// Create a minimal User object with profile picture URL for the caller
  User _createCallerUser(String callerId, String callerName) {
    // Create user with the ID - getProfilePictureThumbnail() will generate the URL
    final user = User(id: callerId, name: callerName, hasProfilePicture: true);

    return user.copyWith(profilePictureUrl: user.getProfilePictureThumbnail());
  }

  @override
  Widget build(BuildContext context) {
    // Guard against build before initState completes (shouldn't happen but safe)
    if (!_initialized) {
      return widget.child;
    }

    final size = MediaQuery.of(context).size;
    final isMinimized = _coordinator.isMinimized;
    final isCallActive = _coordinator.isCallActive;
    final hasIncomingCall = _incomingCallManager.hasIncomingCall;
    final incomingCallData = _incomingCallManager.incomingCallData;
    final minimizedPosition = _coordinator.minimizedPosition;

    if (hasIncomingCall) {
      _log.debug('Building with incoming call: $incomingCallData', tag: _tag);
    }

    // Initialize position based on minimizedPosition when FIRST minimized
    // Don't reset position during dragging (when already minimized)
    if (isMinimized && !_wasMinimized) {
      _log.debug(
        'Transitioning to minimized - setting initial position: $minimizedPosition',
        tag: _tag,
      );
      if (minimizedPosition == 'top') {
        _top = 48;
      } else {
        _top = size.height - 220 - 48;
      }
      _left = size.width - 150 - 16; // right: 16
    }

    // Dismiss keyboard when expanding from minimized to full screen
    if (!isMinimized && _wasMinimized) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    // Track state for next build
    _wasMinimized = isMinimized;

    // Check if call is in connecting state
    // For outgoing calls, controller might not exist yet (connecting phase before CallPageV2 creates it)
    final controller = _coordinator.activeController;
    final isCaller = _coordinator.isCaller;
    
    // Determine if we're in a "pending" connecting state (no controller yet but call initiated)
    // Only applies to caller - callee goes straight to call screen
    final isPendingConnect = isCallActive && controller == null && isCaller;
    
    // Determine if controller exists and is in connecting/initial state
    final isControllerConnecting = controller != null &&
        (controller.callState == CallState.connecting ||
         controller.callState == CallState.initial);
    
    // Check if call is in a terminal state (ended or failed)
    final isTerminalState = controller != null &&
        (controller.callState == CallState.ended ||
         controller.callState == CallState.failed);
    
    // Should we mount CallPageV2 at all?
    // Mount it when call is active and NOT in terminal state
    // This ensures CallController gets created and connection starts
    final shouldMountCallPage = isCallActive &&
        !isTerminalState &&
        _coordinator.calleeId != null &&
        _coordinator.calleeName != null;
    
    // Show connecting banner ONLY for the CALLER during connecting phase
    // Callee goes directly to the call screen (they already accepted)
    final showConnectingBanner = isCaller &&
        !isTerminalState &&
        (isPendingConnect || isControllerConnecting) && 
        !isMinimized && 
        isCallActive;
    
    // Should CallPageV2 be visible (not hidden behind banner)?
    // For caller: Only visible when connected/reconnecting (not connecting/initial) - OR minimized
    // For callee: Always visible (no connecting banner)
    final shouldShowCallPageVisually = shouldMountCallPage &&
        controller != null &&
        (!showConnectingBanner || isMinimized);
    
    // Debug log for troubleshooting
    if (isCallActive) {
      _log.debug(
        'CallOverlay build - isCaller: $isCaller, controllerState: ${controller?.callState}, '
        'showConnectingBanner: $showConnectingBanner, shouldShowCallPageVisually: $shouldShowCallPageVisually',
        tag: _tag,
      );
    }

    return Stack(
      children: [
        widget.child,

        // CALL PAGE — kept continuously mounted at the same LOGICAL size
        // while the call is active.
        //
        // The RTCVideoView used by flutter_webrtc is an Android platform view
        // backed by an ImageReaderSurfaceProducer. Any of these operations
        // races its `onImage` callback with the engine and crashes with:
        //   "Cannot execute operation because FlutterJNI is not attached to
        //    native"
        //   - unmounting the widget that hosts it
        //   - changing its logical size dramatically (e.g. full-screen → 150x220)
        //   - rebuilding it inside a different parent on the same frame
        //
        // To avoid all of that we ALWAYS render VideoCallScreenV2 at the
        // screen's logical full size, and only visually scale the result down
        // when minimised using FittedBox. The platform view inside never sees
        // a layout change.
        if (shouldMountCallPage)
          Positioned(
            top: isMinimized ? _top : 0,
            left: isMinimized ? _left : 0,
            width: isMinimized ? 150 : size.width,
            height: isMinimized ? 220 : size.height,
            child: Visibility(
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              // Hide (but keep mounted) while the connecting banner is showing
              // for the caller — keeps the controller alive without flashing
              // the half-built call UI behind the banner.
              visible: shouldShowCallPageVisually,
              child: GestureDetector(
                behavior: isMinimized
                    ? HitTestBehavior.opaque
                    : HitTestBehavior.deferToChild,
                onPanUpdate: isMinimized
                    ? (details) {
                        setState(() {
                          _top = (_top + details.delta.dy)
                              .clamp(50.0, size.height - 270);
                          _left = (_left + details.delta.dx)
                              .clamp(10.0, size.width - 160);
                        });
                      }
                    : null,
                onTap: isMinimized ? () => _coordinator.restore() : null,
                child: Material(
                  elevation: isMinimized ? 8 : 0,
                  clipBehavior: Clip.antiAlias,
                  color: Colors.transparent,
                  shadowColor: isMinimized
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : null,
                  shape: isMinimized
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        )
                      : null,
                  // FittedBox visually scales the constant-sized call page
                  // down to fit the minimised slot. When not minimised the
                  // child already matches the parent size so FittedBox is a
                  // no-op. IgnorePointer blocks inner controls while
                  // minimised so the outer GestureDetector (drag / tap-to-
                  // restore) wins.
                  child: IgnorePointer(
                    ignoring: isMinimized,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: _buildCallPageContent(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Connecting Banner - show when call is connecting but not yet connected
        // This includes the "pending" phase before controller exists (for outgoing calls)
        if (showConnectingBanner)
          Positioned.fill(
            child: CallConnectingView(
              displayName: _coordinator.calleeName ?? 'Unknown',
              peerUser: _peerUser,
              status: isPendingConnect || controller?.callState == CallState.initial
                  ? "Initializing..."
                  : "Connecting...",
              onEndCall: () => _coordinator.endCall(),
            ),
          ),

        // Incoming Call Banner (CallKit-style)
        if (hasIncomingCall && incomingCallData != null)
          Positioned.fill(
            child: IncomingCallBanner(
              callerName: incomingCallData['caller_name'] ?? 'Unknown',
              callerId: incomingCallData['caller_id'] ?? '',
              isVideoCall: incomingCallData['is_video'] ?? false,
              // Create minimal User from caller_id for profile picture
              callerUser:
                  (incomingCallData['caller_id'] as String?)?.isNotEmpty == true
                  ? _createCallerUser(
                      incomingCallData['caller_id'] as String,
                      incomingCallData['caller_name'] ?? 'Unknown',
                    )
                  : null,
              onAccept: () async {
                // Let IncomingCallManager handle logic, which orchestrates Signaling
                await _incomingCallManager.acceptCall();
              },
              onDecline: () async {
                final roomId = incomingCallData['room_id'] as String;
                // 1. Update UI immediately
                await _incomingCallManager.rejectCall();
                // 2. Tell Server via DI
                await sl<SignalingService>().rejectCall(roomId);
              },
            ),
          ),
      ],
    );
  }

  /// Build the call page content — a nested Navigator hosting
  /// VideoCallScreenV2. Always rendered at full logical size; visual
  /// minimisation is done by [build] via FittedBox so the RTCVideoView
  /// platform view inside never resizes or unmounts.
  Widget _buildCallPageContent(BuildContext context) {
    return HeroControllerScope(
      controller: HeroController(),
      child: Navigator(
        key: const ValueKey('call_navigator'),
        pages: [
          MaterialPage(
            key: ValueKey('call_page_${_coordinator.roomId ?? ''}'),
            child: VideoCallScreenV2(
              key: ValueKey('video_call_${_coordinator.roomId ?? ''}'),
              calleeId: _coordinator.calleeId!,
              calleeName: _coordinator.calleeName!,
              roomId: _coordinator.roomId ?? '',
              isVideo: _coordinator.isVideo,
              isCaller: _coordinator.isCaller,
              // Always false — minimisation is purely visual (FittedBox in
              // CallOverlay) so VideoCallScreenV2 never swaps its subtree
              // and the platform view stays mounted across the transition.
              isMinimized: false,
            ),
          ),
        ],
        onDidRemovePage: (page) {
          // Page was removed from navigation stack
        },
      ),
    );
  }
}

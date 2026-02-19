// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/features/calling/services/call_navigation_coordinator.dart';
import 'package:greenhive_app/features/calling/services/incoming_call_manager.dart';
import 'package:greenhive_app/core/di/call_dependencies.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/features/calling/services/interfaces/signaling_service.dart';
import 'package:greenhive_app/features/calling/services/interfaces/media_manager_factory.dart';
import 'package:greenhive_app/features/calling/services/call_logger.dart';
import 'package:greenhive_app/core/config/call_config.dart';
import 'package:greenhive_app/core/errors/call_error_handler.dart';
import 'package:greenhive_app/features/calling/services/analytics/call_analytics.dart';
import 'package:greenhive_app/features/calling/services/monitoring/network_quality_monitor.dart';
import 'package:greenhive_app/data/services/firestore_instance.dart';
import 'package:greenhive_app/shared/services/user_profile_service.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/features/calling/pages/call_controller.dart';
import 'package:greenhive_app/features/calling/widgets/call_connecting_view.dart';
import 'package:greenhive_app/features/calling/widgets/call_room_view.dart';
import 'package:greenhive_app/features/calling/widgets/minimized_call_view.dart';
import 'package:greenhive_app/features/ratings/utils/post_call_rating_prompt.dart';

class VideoCallScreenV2 extends StatefulWidget {
  final String calleeId;
  final String calleeName;
  final String roomId; // This is the callId
  final bool isVideo;
  final bool isCaller;
  final bool isMinimized;

  const VideoCallScreenV2({
    super.key,
    required this.calleeId,
    required this.calleeName,
    required this.roomId,
    required this.isVideo,
    required this.isCaller,
    this.isMinimized = false,
  });

  @override
  State<VideoCallScreenV2> createState() => _VideoCallScreenV2State();
}

class _VideoCallScreenV2State extends State<VideoCallScreenV2> {
  late final CallController _controller;
  late final CallLogger _logger;
  models.User? _peerUser;
  models.User? _currentUser;
  bool _ownsController =
      false; // Track if we created the controller or reused it

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    // Get dependencies from DI container
    _logger = sl<CallLogger>();

    // Fetch user profiles
    _fetchUserProfiles();

    // Check if there's already an active controller we can reuse
    // This prevents creating duplicate controllers when widget is recreated (e.g., during minimize)
    final existingController = CallNavigationCoordinator().activeController;
    if (existingController != null && !existingController.isDisposed) {
      _logger.debug('Reusing existing CallController');
      _controller = existingController;
      // Take ownership when reusing - we become responsible for cleanup
      _ownsController = true;
    } else {
      _logger.debug('Creating new CallController');
      // Create CallController using DI
      _controller = CallController(
        isCaller: widget.isCaller,
        isVideo: widget.isVideo,
        calleeId: widget.calleeId,
        callId: widget.roomId,
        signaling: sl<SignalingService>(),
        mediaFactory: sl<MediaManagerFactory>(),
        logger: _logger,
        config: sl<CallConfig>(),
        errorHandler: sl<CallErrorHandler>(),
        analytics: sl<CallAnalytics>(),
        networkMonitor: sl<NetworkQualityMonitor>(),
      );
      _ownsController = true;

      // Register with navigation coordinator
      CallNavigationCoordinator().startCall(
        _controller,
        calleeName: widget.calleeName,
      );

      // Start the connection process
      _controller.connect();
    }

    // Listen for cleanup or navigation events
    _controller.addListener(_handleStateChange);
  }

  @override
  void didUpdateWidget(VideoCallScreenV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If isMinimized parameter changed, trigger rebuild
    if (oldWidget.isMinimized != widget.isMinimized) {
      _logger.debug(
        'isMinimized changed: ${oldWidget.isMinimized} → ${widget.isMinimized}',
      );
      setState(() {
        // Force rebuild with new isMinimized value
      });
    }
  }

  void _handleStateChange() {
    // If call ended, pop immediately (without delay) to avoid showing blank screen
    if (_controller.callState == CallState.ended) {
      _logger.debug('Call ended - cleaning up');

      // Capture call info before cleanup for rating prompt
      final callDuration = _controller.durationSeconds.value;
      final peerId = widget.calleeId;
      final peerName = widget.calleeName;
      final callId = widget.roomId;
      
      // Check if peer is an expert — only experts can be rated
      final peerIsExpert = _peerUser?.roles.contains('Expert') ?? false;
      
      _logger.info(
        '📞 Call Ended - Rating Eligibility Check (peerIsExpert=$peerIsExpert, duration=$callDuration)',
        {
          'peerIsExpert': peerIsExpert,
          'callDuration': '$callDuration seconds',
          'peerId': peerId,
          'peerName': peerName,
          'callId': callId,
        },
      );

      // Ensure we exit the minimized state before popping
      if (CallNavigationCoordinator().isMinimized) {
        CallNavigationCoordinator().restore();
      }

      // Clear call from coordinator
      CallNavigationCoordinator().clearCall();

      // Force reset IncomingCallManager to ensure clean state for next call
      sl<IncomingCallManager>().forceReset();
      _logger.debug('All managers reset');

      // Capture values before the callback (in case widget gets unmounted)
      final isEligibleForRating = peerIsExpert && callDuration >= 30;

      _logger.debug(
        'Checking rating prompt eligibility: peerIsExpert=$peerIsExpert, duration=$callDuration, eligible=$isEligibleForRating',
      );

      // Pop the call page on next frame to allow state to settle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Try to pop if still mounted
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Show rating prompt after call ends (if peer is an expert and call was long enough)
        // PostCallRatingPrompt uses global navigator key, so it works even after unmount
        if (isEligibleForRating) {
          _logger.info(
            '✅ Rating prompt eligible - triggering PostCallRatingPrompt',
          );
          // Trigger rating prompt after a short delay to let pop complete
          Future.delayed(const Duration(milliseconds: 300), () {
            PostCallRatingPrompt.showIfEligible(
              expertId: peerId,
              expertName: peerName,
              callId: callId,
              callDurationSeconds: callDuration,
            );
          });
        } else {
          _logger.warning(
            '❌ Rating prompt NOT eligible - peerIsExpert=$peerIsExpert, callDuration=$callDuration',
          );
        }
      });
    }

    // If call failed, show error and pop after delay
    if (_controller.callState == CallState.failed) {
      _logger.debug('Call failed - showing error and cleaning up');

      // Ensure we exit the minimized state before popping
      if (CallNavigationCoordinator().isMinimized) {
        CallNavigationCoordinator().restore();
      }

      // Clear call from coordinator
      CallNavigationCoordinator().clearCall();

      // Force reset IncomingCallManager
      sl<IncomingCallManager>().forceReset();

      // Show error message and pop after short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _controller.errorMessage ?? 'Call connection failed',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );

          // Pop after 1 second to show the error briefly
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      });
    }
  }

  Future<void> _fetchUserProfiles() async {
    try {
      // Get current user from UserProfileService
      _currentUser = UserProfileService().userProfile;

      // Fetch peer user from Firestore
      final doc = await FirestoreInstance().db
          .collection('users')
          .doc(widget.calleeId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _peerUser = models.User.fromJson(doc.data()!);
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Error fetching user profiles', e, stackTrace);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller.removeListener(_handleStateChange);

    // Only dispose the controller if:
    // 1. We own it AND
    // 2. No other widget is currently using it (coordinator doesn't have an active controller)
    //    OR the call has ended/failed
    final coordinatorController = CallNavigationCoordinator().activeController;
    final callEnded =
        _controller.callState == CallState.ended ||
        _controller.callState == CallState.failed ||
        _controller.isDisposed;

    // If coordinator has this controller and call is still active,
    // another widget instance may be using it - don't dispose
    final shouldDispose =
        _ownsController &&
        (callEnded ||
            coordinatorController == null ||
            coordinatorController != _controller);

    if (shouldDispose) {
      _logger.debug(
        'Disposing controller (call ended or no other user)',
      );
      _controller.dispose();
      // Note: clearCall() may have already been called from _handleStateChange()
      // but it's idempotent (sets values to null) so calling again is safe
      CallNavigationCoordinator().clearCall();
    } else {
      _logger.debug(
        'Not disposing - controller still active in coordinator',
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use widget.isMinimized parameter from CallOverlay
    // CallOverlay rebuilds this via Navigator pages when minimize state changes
    if (widget.isMinimized) {
      // MinimizedCallView uses ValueListenableBuilder internally for dynamic
      // values (mute state, remote video). No need for ListenableBuilder here
      // which would cause excessive rebuilds on every controller notification
      // (quality stats, track events, etc.).
      _logger.debug(
        'Building MinimizedCallView (isMinimized=true)',
      );
      return MinimizedCallView(
        controller: _controller,
        peerUser: _peerUser,
        displayName: widget.calleeName,
        onRestore: () {
          CallNavigationCoordinator().restore();
        },
      );
    }

    // Full call view
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.callState;
        _logger.debug('Building UI for state: $state');
        _logger.debug('   mediaManager: ${_controller.mediaManager != null}');

        switch (state) {
          case CallState.initial:
          case CallState.connecting:
          case CallState.reconnecting:
            // For CALLER: Show connecting banner overlay
            // For CALLEE: Skip connecting view - they already accepted, show loading instead
            if (widget.isCaller) {
              _logger.debug('   → Showing CallConnectingView banner overlay');
              // Show connecting banner as overlay on top of existing content
              return Stack(
                children: [
                  // Keep the app content visible in background
                  Container(
                    color: AppColors.background,
                    child: const SizedBox.expand(),
                  ),
                  // Overlay the connecting banner on top
                  CallConnectingView(
                    displayName: widget.calleeName,
                    peerUser: _peerUser,
                    status: state == CallState.reconnecting
                        ? "Reconnecting..."
                        : "Connecting...",
                    onEndCall: () => _controller.endCall(),
                  ),
                ],
              );
            } else {
              // Callee: Show simple loading while connecting to LiveKit
              _logger.debug('   → Callee connecting - showing loading state');
              return Container(
                color: AppColors.background,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        state == CallState.reconnecting
                            ? 'Reconnecting...'
                            : 'Joining call...',
                        style: AppTypography.bodyRegular.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

          // 'ringing' state might be needed in CallController if we want to show it explicitly
          // Current CallStatus enum has 'ringing', so let's see if CallController maps it.
          // CallController defines: initial, connecting, connected, ended, failed, reconnecting.
          // It seems 'ringing' might be treated as 'connecting' for now in valid logic,
          // or we should update CallController to expose 'ringing'.
          // Update: UnifiedSignalingService emits 'ringing'. CallController defaults to connecting.

          case CallState.connected:
            _logger.debug('   → Transitioning to CallRoomView');
            // Ensure media manager is ready
            if (_controller.mediaManager == null) {
              _logger.warning('   ⚠️ mediaManager is NULL - showing spinner');
              return const Center(child: CircularProgressIndicator());
            }

            _logger.debug('   ✅ Showing CallRoomView');
            return CallRoomView(
              controller: _controller,
              displayName: widget.calleeName,
              peerUser: _peerUser,
              currentUser: _currentUser,
              onMinimize: ({String position = 'bottom'}) {
                _logger.debug(
                  'onMinimize called with position: $position - minimizing...',
                );
                CallNavigationCoordinator().minimize(position: position);
                _logger.debug(
                  'isMinimized now: ${CallNavigationCoordinator().isMinimized}',
                );
              },
            );

          case CallState.failed:
            _logger.debug('   → Call failed - showing error message');
            return Container(
              color: AppColors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _controller.errorMessage ?? 'Call connection failed',
                      style: AppTypography.headingSmall.copyWith(color: AppColors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            );

          case CallState.ended:
            _logger.debug('   → Call ended - returning empty widget');
            // Return empty container as the page should be popped immediately
            return const SizedBox.shrink();
        }
      },
    );
  }
}

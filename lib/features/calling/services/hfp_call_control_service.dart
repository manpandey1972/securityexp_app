import 'package:flutter/services.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/features/calling/services/call_navigation_coordinator.dart';
import 'package:securityexperts_app/features/calling/services/incoming_call_manager.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Service to handle Hands-Free Profile (HFP) call control from car Bluetooth systems
/// This allows users to answer/end calls using physical buttons on their car steering wheel
class HFPCallControlService {
  static final HFPCallControlService _instance =
      HFPCallControlService._internal();

  factory HFPCallControlService() => _instance;

  HFPCallControlService._internal();

  static const MethodChannel _platform = MethodChannel(
    'com.example.securityexpertsApp.call/hfp',
  );
  late final IncomingCallManager _incomingCallManager =
      sl<IncomingCallManager>();
  bool _isInitialized = false;

  /// Initialize the HFP call control handler
  /// Should be called once during app startup
  Future<void> initialize() async {
    if (_isInitialized) {
      sl<AppLogger>().debug('Already initialized, skipping', tag: 'HFP');
      return;
    }

    try {
      _platform.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      sl<AppLogger>().debug('Call control method channel initialized', tag: 'HFP');
    } catch (e) {
      sl<AppLogger>().error('Failed to initialize', tag: 'HFP', error: e);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    sl<AppLogger>().debug('Method call received: ${call.method}', tag: 'HFP');

    if (call.method == 'handleCallControl') {
      final String action = call.arguments['action'] as String;
      sl<AppLogger>().debug('Call control action: $action', tag: 'HFP');

      if (action == 'endCall') {
        sl<AppLogger>().debug('Car button pressed to end call', tag: 'HFP');
        await _endCall();
        return true;
      } else if (action == 'answerCall') {
        sl<AppLogger>().debug('Car button pressed to answer call', tag: 'HFP');
        await _answerCall();
        return true;
      }
    }

    return false;
  }

  Future<void> _endCall() async {
    sl<AppLogger>().debug('Ending call from HFP device (car button)', tag: 'HFP');

    // Check if there's an incoming call first (reject it)
    if (_incomingCallManager.hasIncomingCall) {
      sl<AppLogger>().debug('Rejecting incoming call from HFP device', tag: 'HFP');
      await _incomingCallManager.rejectCall();
      SnackbarService.show('Call rejected from car system');
      return;
    }

    // Otherwise, end active call
    if (CallNavigationCoordinator().isCallActive) {
      await CallNavigationCoordinator().endCall();
      sl<AppLogger>().debug('Call ended successfully from HFP device', tag: 'HFP');
      SnackbarService.show('Call ended from car system');
    } else {
      sl<AppLogger>().debug('No active call to end', tag: 'HFP');
    }
  }

  Future<void> _answerCall() async {
    sl<AppLogger>().debug('Answering call from HFP device (car button)', tag: 'HFP');

    if (_incomingCallManager.hasIncomingCall) {
      sl<AppLogger>().debug('Accepting incoming call from HFP device', tag: 'HFP');
      await _incomingCallManager.acceptCall();
      SnackbarService.show('Call answered from car system');
    } else {
      sl<AppLogger>().warning('No incoming call to answer', tag: 'HFP');
    }
  }

  /// Dispose of the service
  void dispose() {
    _isInitialized = false;
    sl<AppLogger>().debug('Service disposed', tag: 'HFP');
  }
}

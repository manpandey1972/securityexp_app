import Foundation
import CallKit
import AVFoundation
import Flutter

/// CallKit manager for handling native iOS call UI
/// Provides integration with iOS system call screen for incoming/outgoing calls
class CallKitManager: NSObject {
    static let shared = CallKitManager()
    
    private let provider: CXProvider
    private let callController = CXCallController()
    private(set) var activeCallUUID: UUID?
    
    // Store pending call data from VoIP push
    var pendingCallData: [String: Any]?
    
    // Flutter method channel for callbacks
    var flutterChannel: FlutterMethodChannel?
    
    // Audio session state
    private var isAudioSessionActive = false
    
    private override init() {
        // Configure CallKit provider
        let config = CXProviderConfiguration(localizedName: "GreenHive")
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.supportedHandleTypes = [.generic, .phoneNumber]
        config.includesCallsInRecents = true
        
        // Set app icon for call screen (optional - uses app icon by default)
        if let iconImage = UIImage(named: "CallKitIcon") {
            config.iconTemplateImageData = iconImage.pngData()
        }
        
        // Ringtone (uses system default if not set)
        // config.ringtoneSound = "ringtone.caf"
        
        provider = CXProvider(configuration: config)
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
        
        debugPrint("flutter: 📞 [CallKit] Manager initialized")
    }
    
    // MARK: - Public API
    
    /// Report an incoming call to CallKit (shows native call UI)
    func reportIncomingCall(
        uuid: UUID,
        callerId: String,
        callerName: String,
        hasVideo: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        debugPrint("flutter: 📞 [CallKit] Reporting incoming call: \(callerName) (video: \(hasVideo))")
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerId)
        update.localizedCallerName = callerName
        update.hasVideo = hasVideo
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        
        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                debugPrint("flutter: ❌ [CallKit] Failed to report incoming call: \(error.localizedDescription)")
            } else {
                debugPrint("flutter: ✅ [CallKit] Incoming call reported successfully")
                self?.activeCallUUID = uuid
            }
            completion(error)
        }
    }
    
    /// Report an outgoing call to CallKit
    func reportOutgoingCall(uuid: UUID, handle: String, hasVideo: Bool) {
        debugPrint("flutter: 📞 [CallKit] Starting outgoing call: \(handle)")
        
        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = hasVideo
        
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { [weak self] error in
            if let error = error {
                debugPrint("flutter: ❌ [CallKit] Failed to start outgoing call: \(error.localizedDescription)")
            } else {
                debugPrint("flutter: ✅ [CallKit] Outgoing call started")
                self?.activeCallUUID = uuid
                
                // Report that outgoing call is connecting
                self?.provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
            }
        }
    }
    
    /// Report that outgoing call has connected
    func reportOutgoingCallConnected(uuid: UUID) {
        debugPrint("flutter: ✅ [CallKit] Outgoing call connected")
        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
    }
    
    /// Report that a call has ended
    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason) {
        debugPrint("flutter: 📴 [CallKit] Call ended with reason: \(reason.rawValue)")
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
        activeCallUUID = nil
        pendingCallData = nil
        
        // Deactivate audio session
        deactivateAudioSession()
    }
    
    /// End the current active call
    func endCall(uuid: UUID) {
        debugPrint("flutter: 📴 [CallKit] Requesting call end for: \(uuid.uuidString)")
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callController.request(transaction) { [weak self] error in
            if let error = error {
                debugPrint("flutter: ❌ [CallKit] Failed to end call: \(error.localizedDescription)")
                // Even if the request fails, try to clean up
                self?.activeCallUUID = nil
                self?.pendingCallData = nil
                self?.deactivateAudioSession()
            } else {
                debugPrint("flutter: ✅ [CallKit] Call end requested successfully")
            }
        }
    }
    
    /// Set call on hold
    func setHeld(uuid: UUID, onHold: Bool) {
        let setHeldAction = CXSetHeldCallAction(call: uuid, onHold: onHold)
        let transaction = CXTransaction(action: setHeldAction)
        
        callController.request(transaction) { error in
            if let error = error {
                debugPrint("flutter: ❌ [CallKit] Failed to set hold: \(error.localizedDescription)")
            }
        }
    }
    
    /// Mute/unmute the call
    func setMuted(uuid: UUID, muted: Bool) {
        let setMutedAction = CXSetMutedCallAction(call: uuid, muted: muted)
        let transaction = CXTransaction(action: setMutedAction)
        
        callController.request(transaction) { error in
            if let error = error {
                debugPrint("flutter: ❌ [CallKit] Failed to set mute: \(error.localizedDescription)")
            }
        }
    }
    
    /// Update call info (e.g., caller name after lookup)
    func updateCall(uuid: UUID, callerName: String?, hasVideo: Bool?) {
        let update = CXCallUpdate()
        if let name = callerName {
            update.localizedCallerName = name
        }
        if let video = hasVideo {
            update.hasVideo = video
        }
        provider.reportCall(with: uuid, updated: update)
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() {
        debugPrint("flutter: 🔊 [CallKit] Configuring audio session for call via AudioSessionManager")
        
        // Use centralized AudioSessionManager with standardized options
        AudioSessionManager.shared.transition(to: .activeCall)
        isAudioSessionActive = AudioSessionManager.shared.isAudioSessionActive
        
        debugPrint("flutter: ✅ [CallKit] Audio session configured via AudioSessionManager")
    }
    
    private func deactivateAudioSession() {
        debugPrint("flutter: 🔇 [CallKit] Deactivating audio session via AudioSessionManager")
        
        AudioSessionManager.shared.deactivateSession()
        isAudioSessionActive = false
        
        debugPrint("flutter: ✅ [CallKit] Audio session deactivated via AudioSessionManager")
    }
}

// MARK: - CXProviderDelegate
extension CallKitManager: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        debugPrint("flutter: 🔄 [CallKit] Provider did reset")
        
        // End all calls and reset state
        activeCallUUID = nil
        pendingCallData = nil
        
        // Notify Flutter
        flutterChannel?.invokeMethod("onCallKitReset", arguments: nil)
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        debugPrint("flutter: 🚀 [CallKit] Provider did begin")
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        debugPrint("flutter: 📞 [CallKit] Starting call action")
        
        // Configure audio session
        configureAudioSession()
        
        // Signal to the provider that the action has been fulfilled
        action.fulfill()
        
        // Notify Flutter
        flutterChannel?.invokeMethod("onOutgoingCallStarted", arguments: [
            "callId": action.callUUID.uuidString,
            "handle": action.handle.value,
            "isVideo": action.isVideo
        ])
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        debugPrint("flutter: ✅ [CallKit] User answered call")
        
        // Configure audio session
        configureAudioSession()
        
        // Get pending call data
        var callData: [String: Any] = [
            "callId": action.callUUID.uuidString,
            "callUUID": action.callUUID.uuidString  // Also send as callUUID for Flutter
        ]
        
        if let pending = pendingCallData {
            callData.merge(pending) { (current, _) in current }
            debugPrint("flutter: ✅ [CallKit] Merged pending call data: \(pending)")
        } else {
            debugPrint("flutter: ⚠️ [CallKit] No pending call data found!")
        }
        
        debugPrint("flutter: ✅ [CallKit] Sending onCallAccepted with: \(callData)")
        
        // Notify Flutter that call was answered
        flutterChannel?.invokeMethod("onCallAccepted", arguments: callData)
        
        // Fulfill the action
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        debugPrint("flutter: 📴 [CallKit] User ended/rejected call: \(action.callUUID.uuidString)")
        
        // Build arguments with call UUID and pending data
        var arguments: [String: Any] = [
            "callUUID": action.callUUID.uuidString,
            "reason": "userEnded"
        ]
        
        // Include pending call data so Flutter can reject properly
        if let pending = pendingCallData {
            arguments.merge(pending) { (current, _) in current }
        }
        
        debugPrint("flutter: 📴 [CallKit] Sending onCallEnded to Flutter with: \(arguments)")
        
        // Notify Flutter
        flutterChannel?.invokeMethod("onCallEnded", arguments: arguments)
        
        // Clean up
        activeCallUUID = nil
        pendingCallData = nil
        
        // Deactivate audio session
        deactivateAudioSession()
        
        // Fulfill the action
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        debugPrint("flutter: ⏸️ [CallKit] Call hold toggled: \(action.isOnHold)")
        
        // Notify Flutter
        flutterChannel?.invokeMethod("onCallHoldToggled", arguments: [
            "callId": action.callUUID.uuidString,
            "isOnHold": action.isOnHold
        ])
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        debugPrint("flutter: 🔇 [CallKit] Mute toggled: \(action.isMuted)")
        
        // Notify Flutter
        flutterChannel?.invokeMethod("onMuteToggled", arguments: [
            "callId": action.callUUID.uuidString,
            "isMuted": action.isMuted
        ])
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        debugPrint("flutter: ⏰ [CallKit] Action timed out: \(type(of: action))")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        debugPrint("flutter: 🔊 [CallKit] Audio session activated by system")
        
        // Notify AudioSessionManager of activation
        AudioSessionManager.shared.didActivateAudioSession(audioSession)
        isAudioSessionActive = true
        
        // IMPORTANT: This is the safe point to start WebRTC media capture
        // Notify Flutter that audio is ready - WebRTC should wait for this before starting
        flutterChannel?.invokeMethod("onAudioSessionActivated", arguments: nil)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        debugPrint("flutter: 🔇 [CallKit] Audio session deactivated by system")
        
        // Notify AudioSessionManager of deactivation
        AudioSessionManager.shared.didDeactivateAudioSession(audioSession)
        isAudioSessionActive = false
        
        // Notify Flutter
        flutterChannel?.invokeMethod("onAudioSessionDeactivated", arguments: nil)
    }
}

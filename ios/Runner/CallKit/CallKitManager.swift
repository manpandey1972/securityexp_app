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
    
    // Store the current call participant name so it can be re-applied
    // at every CallKit state transition (Tesla/cars re-read the name)
    private(set) var currentCallName: String?
    
    // Track whether the current call is video to preserve hasVideo
    // in name-only CXCallUpdate pushes (default false resets video → audio)
    private(set) var currentCallIsVideo: Bool = false
    
    // Suppress CXSetMutedCallAction echo-back when mute originated from Flutter.
    // When Flutter calls setMuted → CXCallController.request(CXSetMutedCallAction),
    // iOS triggers our CXProviderDelegate which would echo 'onMuteToggled' right
    // back to Flutter creating a feedback loop.
    private var muteSetByFlutter: Bool = false
    
    // Flutter method channel for callbacks
    var flutterChannel: FlutterMethodChannel?
    
    // Audio session state
    private var isAudioSessionActive = false
    
    private override init() {
        // Configure CallKit provider
        let config = CXProviderConfiguration(localizedName: "Security Experts")
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
        currentCallName = callerName
        currentCallIsVideo = hasVideo
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
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
    func reportOutgoingCall(uuid: UUID, handle: String, calleeName: String?, hasVideo: Bool) {
        debugPrint("flutter: 📞 [CallKit] Starting outgoing call: \(calleeName ?? handle)")
        
        let displayName = calleeName ?? "Unknown"
        currentCallName = displayName
        currentCallIsVideo = hasVideo
        let handle = CXHandle(type: .generic, value: displayName)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = hasVideo
        // Set contact identifier so car displays show the name
        startCallAction.contactIdentifier = calleeName
        
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { [weak self] error in
            if let error = error {
                debugPrint("flutter: ❌ [CallKit] Failed to start outgoing call: \(error.localizedDescription)")
            } else {
                debugPrint("flutter: ✅ [CallKit] Outgoing call started")
                self?.activeCallUUID = uuid
                
                // Update the call with callee name so car displays and system UI
                // show the name instead of the handle string
                if let name = calleeName {
                    let update = CXCallUpdate()
                    update.localizedCallerName = name
                    update.remoteHandle = handle
                    update.hasVideo = hasVideo
                    self?.provider.reportCall(with: uuid, updated: update)
                }
                
                // Report that outgoing call is connecting
                self?.provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
            }
        }
    }
    
    /// Report that outgoing call has connected
    func reportOutgoingCallConnected(uuid: UUID) {
        debugPrint("flutter: ✅ [CallKit] Outgoing call connected")
        
        // Re-send localizedCallerName so car displays (Tesla) refresh the name
        // when the call transitions to connected state
        if let name = currentCallName {
            let update = CXCallUpdate()
            update.localizedCallerName = name
            update.remoteHandle = CXHandle(type: .generic, value: name)
            update.hasVideo = currentCallIsVideo
            provider.reportCall(with: uuid, updated: update)
            debugPrint("flutter: ✅ [CallKit] Re-sent name on connect: \(name) (video: \(currentCallIsVideo))")
        }
        
        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
    }
    
    /// Report that a call has ended
    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason) {
        debugPrint("flutter: 📴 [CallKit] Call ended with reason: \(reason.rawValue)")
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
        activeCallUUID = nil
        pendingCallData = nil
        currentCallName = nil
        currentCallIsVideo = false
        
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
                self?.currentCallName = nil
                self?.currentCallIsVideo = false
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
    
    /// Mute/unmute the call (called from Flutter)
    func setMuted(uuid: UUID, muted: Bool) {
        // Mark that this mute change originated from Flutter so the
        // CXProviderDelegate callback (CXSetMutedCallAction) won't echo
        // it back to Flutter, preventing a feedback loop.
        muteSetByFlutter = true
        
        let setMutedAction = CXSetMutedCallAction(call: uuid, muted: muted)
        let transaction = CXTransaction(action: setMutedAction)
        
        callController.request(transaction) { [weak self] error in
            if let error = error {
                debugPrint("flutter: ❌ [CallKit] Failed to set mute: \(error.localizedDescription)")
                self?.muteSetByFlutter = false
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
        currentCallName = nil
        currentCallIsVideo = false
        
        // Notify Flutter
        flutterChannel?.invokeMethod("onCallKitReset", arguments: nil)
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        debugPrint("flutter: 🚀 [CallKit] Provider did begin")
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        debugPrint("flutter: 📞 [CallKit] Starting call action: \(currentCallName ?? action.handle.value)")
        
        // Configure audio session
        configureAudioSession()
        
        // Update localizedCallerName BEFORE fulfilling the action
        // so car displays (Tesla) get the name during initial HFP negotiation.
        // Without this, Tesla shows the call UUID instead of the name.
        if let name = currentCallName {
            let update = CXCallUpdate()
            update.localizedCallerName = name
            update.remoteHandle = CXHandle(type: .generic, value: name)
            update.hasVideo = currentCallIsVideo
            provider.reportCall(with: action.callUUID, updated: update)
            debugPrint("flutter: ✅ [CallKit] Set localizedCallerName before fulfill: \(name) (video: \(currentCallIsVideo))")
        }
        
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
        
        // Re-apply localizedCallerName AFTER fulfill so car displays
        // (Tesla, CarPlay) refresh the name during the connected state.
        // Some car systems only read the name after the call transitions.
        let callerName = pendingCallData?["callerName"] as? String ?? currentCallName
        if let name = callerName {
            let nameUpdate = CXCallUpdate()
            nameUpdate.localizedCallerName = name
            nameUpdate.remoteHandle = CXHandle(type: .generic, value: name)
            nameUpdate.hasVideo = currentCallIsVideo
            provider.reportCall(with: action.callUUID, updated: nameUpdate)
            debugPrint("flutter: ✅ [CallKit] Updated answered call with name: \(name) (video: \(currentCallIsVideo))")
        }
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
        currentCallName = nil
        currentCallIsVideo = false
        
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
        debugPrint("flutter: 🔇 [CallKit] Mute action received: isMuted=\(action.isMuted), uuid=\(action.callUUID.uuidString), fromFlutter=\(muteSetByFlutter)")
        
        if muteSetByFlutter {
            // This CXSetMutedCallAction was triggered by Flutter calling setMuted.
            // Do NOT echo it back — Flutter already knows the mute state.
            debugPrint("flutter: 🔇 [CallKit] Suppressing echo-back (mute originated from Flutter)")
            muteSetByFlutter = false
            action.fulfill()
            return
        }
        
        // This mute came from the system, car display (Tesla), or iOS Control Center.
        // Forward it to Flutter so the app can update its state.
        debugPrint("flutter: 🔇 [CallKit] Forwarding external mute to Flutter: \(action.isMuted)")
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
        
        // Delayed name re-push for car displays (Tesla, CarPlay).
        // HFP connection may not be fully negotiated when the call is first reported.
        // By the time didActivate fires, Bluetooth SCO link is up and the car
        // may re-query call info. Push the name again after a short delay so
        // the car picks it up during the active HFP session.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self,
                  let uuid = self.activeCallUUID,
                  let name = self.currentCallName else { return }
            let delayedUpdate = CXCallUpdate()
            delayedUpdate.localizedCallerName = name
            delayedUpdate.remoteHandle = CXHandle(type: .generic, value: name)
            delayedUpdate.hasVideo = self.currentCallIsVideo
            self.provider.reportCall(with: uuid, updated: delayedUpdate)
            debugPrint("flutter: ✅ [CallKit] Delayed name re-push (1.5s post-activate): \(name)")
        }
        
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

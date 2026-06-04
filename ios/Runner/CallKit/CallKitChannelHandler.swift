import Flutter
import CallKit

/// Method channel handler for CallKit operations
/// Bridges Flutter calls to native CallKit functionality
class CallKitChannelHandler {
    private let channel: FlutterMethodChannel
    
    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.goaegent.securityexperts/callkit",
            binaryMessenger: messenger
        )
        
        // Set this channel for callbacks
        CallKitManager.shared.flutterChannel = channel
        PushKitManager.shared.flutterChannel = channel
        
        // Setup method call handler
        channel.setMethodCallHandler(handleMethodCall)
        
        debugPrint("flutter: 📞 [CallKitChannel] Handler initialized")
    }
    
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        debugPrint("flutter: 📞 [CallKitChannel] Received method: \(call.method)")
        
        switch call.method {
        case "initialize":
            // Register for VoIP push
            PushKitManager.shared.registerForVoIPPush()
            result(nil)
            
        case "reportIncomingCall":
            handleReportIncomingCall(call: call, result: result)
            
        case "reportOutgoingCall":
            handleReportOutgoingCall(call: call, result: result)
            
        case "reportOutgoingCallConnected":
            handleReportOutgoingCallConnected(call: call, result: result)
            
        case "reportCallEnded":
            handleReportCallEnded(call: call, result: result)
            
        case "endCall":
            handleEndCall(call: call, result: result)
            
        case "setMuted":
            handleSetMuted(call: call, result: result)
            
        case "updateCallInfo":
            handleUpdateCallInfo(call: call, result: result)
            
        case "getVoIPToken":
            if let token = PushKitManager.shared.voipToken {
                result([
                    "token": token,
                    "environment": PushKitManager.shared.apnsEnvironment
                ])
            } else {
                result(nil)
            }
            
        case "isCallKitSupported":
            result(true) // iOS always supports CallKit
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Method Handlers
    
    private func handleReportIncomingCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let callId = args["callId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "callId is required",
                details: nil
            ))
            return
        }
        
        let callerName = args["callerName"] as? String ?? "Unknown"
        let callerId = args["callerId"] as? String ?? callId
        let hasVideo = args["hasVideo"] as? Bool ?? false
        
        // Create or use provided UUID
        let uuid = UUID(uuidString: callId) ?? UUID()
        
        CallKitManager.shared.reportIncomingCall(
            uuid: uuid,
            callerId: callerId,
            callerName: callerName,
            hasVideo: hasVideo
        ) { error in
            if let error = error {
                result(FlutterError(
                    code: "CALLKIT_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(uuid.uuidString)
            }
        }
    }
    
    private func handleReportOutgoingCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let callUUID = args["callUUID"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "callUUID is required",
                details: nil
            ))
            return
        }
        
        let calleeId = args["calleeId"] as? String ?? callUUID
        let calleeName = args["calleeName"] as? String
        let hasVideo = args["hasVideo"] as? Bool ?? false
        let uuid = UUID(uuidString: callUUID) ?? UUID()
        
        CallKitManager.shared.reportOutgoingCall(
            uuid: uuid,
            handle: calleeId,
            calleeName: calleeName,
            hasVideo: hasVideo
        )
        
        result(true)
    }
    
    private func handleReportOutgoingCallConnected(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let callUUID = args["callUUID"] as? String,
              let uuid = UUID(uuidString: callUUID) else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Valid callUUID is required",
                details: nil
            ))
            return
        }
        
        CallKitManager.shared.reportOutgoingCallConnected(uuid: uuid)
        result(nil)
    }
    
    private func handleReportCallEnded(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Arguments are required",
                details: nil
            ))
            return
        }
        
        // Accept both callUUID and callId for compatibility
        let callIdString = args["callUUID"] as? String ?? args["callId"] as? String
        
        // If we have a UUID string, use it. Otherwise use the active call UUID
        let uuid: UUID?
        if let callIdString = callIdString {
            uuid = UUID(uuidString: callIdString)
        } else {
            uuid = CallKitManager.shared.activeCallUUID
        }
        
        guard let finalUUID = uuid else {
            debugPrint("flutter: ⚠️ [CallKitChannel] No valid UUID for reportCallEnded")
            result(nil)
            return
        }
        
        // Map reason string to CXCallEndedReason
        let reasonString = args["reason"] as? String ?? "remoteEnded"
        let reason: CXCallEndedReason
        
        switch reasonString {
        case "failed":
            reason = .failed
        case "unanswered":
            reason = .unanswered
        case "answeredElsewhere":
            reason = .answeredElsewhere
        case "declinedElsewhere":
            reason = .declinedElsewhere
        default:
            reason = .remoteEnded
        }
        
        debugPrint("flutter: 📴 [CallKitChannel] Reporting call ended: \(finalUUID.uuidString) with reason: \(reasonString)")
        CallKitManager.shared.reportCallEnded(uuid: finalUUID, reason: reason)
        result(nil)
    }
    
    private func handleEndCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Arguments are required",
                details: nil
            ))
            return
        }
        
        // Accept both callUUID and callId for compatibility
        let callIdString = args["callUUID"] as? String ?? args["callId"] as? String
        
        // If we have a UUID string, use it. Otherwise use the active call UUID
        let uuid: UUID?
        if let callIdString = callIdString {
            uuid = UUID(uuidString: callIdString)
        } else {
            uuid = CallKitManager.shared.activeCallUUID
        }
        
        guard let finalUUID = uuid else {
            debugPrint("flutter: ⚠️ [CallKitChannel] No valid UUID for endCall, trying active call")
            // Try ending active call anyway
            if let activeUUID = CallKitManager.shared.activeCallUUID {
                CallKitManager.shared.endCall(uuid: activeUUID)
            }
            result(nil)
            return
        }
        
        debugPrint("flutter: 📴 [CallKitChannel] Ending call: \(finalUUID.uuidString)")
        CallKitManager.shared.endCall(uuid: finalUUID)
        result(nil)
    }
    
    private func handleSetMuted(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let callIdStr = args["callUUID"] as? String ?? args["callId"] as? String,
              let muted = args["muted"] as? Bool else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "callUUID/callId and muted are required",
                details: nil
            ))
            return
        }
        
        let uuid = UUID(uuidString: callIdStr) ?? CallKitManager.shared.activeCallUUID ?? UUID()
        debugPrint("flutter: 🔇 [CallKitChannel] setMuted: uuid=\(uuid.uuidString), muted=\(muted)")
        CallKitManager.shared.setMuted(uuid: uuid, muted: muted)
        result(nil)
    }
    
    private func handleUpdateCallInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let callIdStr = args["callUUID"] as? String ?? args["callId"] as? String,
              let uuid = UUID(uuidString: callIdStr) else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Valid callUUID/callId is required",
                details: nil
            ))
            return
        }
        
        let callerName = args["callerName"] as? String
        let hasVideo = args["hasVideo"] as? Bool
        
        CallKitManager.shared.updateCall(uuid: uuid, callerName: callerName, hasVideo: hasVideo)
        result(nil)
    }
}

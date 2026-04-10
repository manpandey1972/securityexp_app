import PushKit
import Flutter
import UIKit

/// PushKit manager for handling VoIP push notifications
/// Enables receiving incoming call notifications even when app is killed
class PushKitManager: NSObject {
    static let shared = PushKitManager()
    
    private var pushRegistry: PKPushRegistry?
    private(set) var voipToken: String?
    
    /// APNS environment derived from the app's provisioning profile.
    /// Development profiles → "sandbox", distribution profiles → "production".
    /// App Store / TestFlight builds have no embedded.mobileprovision → "production".
    lazy var apnsEnvironment: String = {
        guard let provisioningURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let provisioningData = try? Data(contentsOf: provisioningURL) else {
            // No provisioning profile = App Store / TestFlight → always production
            debugPrint("flutter: 📱 [PushKit] No embedded provisioning profile, using production APNS")
            return "production"
        }
        
        // The provisioning profile is a binary CMS/PKCS7 container with an embedded XML plist.
        // Search for the XML boundaries directly in the binary data to avoid encoding issues.
        guard let xmlStartMarker = "<?xml".data(using: .utf8),
              let xmlEndMarker = "</plist>".data(using: .utf8),
              let startRange = provisioningData.range(of: xmlStartMarker),
              let endRange = provisioningData.range(of: xmlEndMarker) else {
            // File exists but can't parse → not App Store, assume sandbox
            debugPrint("flutter: 📱 [PushKit] Could not find XML in provisioning profile, defaulting to sandbox")
            return "sandbox"
        }
        
        let xmlData = provisioningData.subdata(in: startRange.lowerBound..<endRange.upperBound)
        
        guard let plist = try? PropertyListSerialization.propertyList(from: xmlData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let apsEnv = entitlements["aps-environment"] as? String else {
            // Has profile but no aps-environment → assume sandbox
            debugPrint("flutter: 📱 [PushKit] No aps-environment in provisioning profile, defaulting to sandbox")
            return "sandbox"
        }
        
        debugPrint("flutter: 📱 [PushKit] aps-environment from profile: \(apsEnv)")
        return apsEnv == "production" ? "production" : "sandbox"
    }()
    
    // Flutter method channel for callbacks
    var flutterChannel: FlutterMethodChannel?
    
    private override init() {
        super.init()
        debugPrint("flutter: 📱 [PushKit] Manager initialized")
    }
    
    /// Register for VoIP push notifications
    func registerForVoIPPush() {
        debugPrint("flutter: 📱 [PushKit] Registering for VoIP push notifications")
        
        pushRegistry = PKPushRegistry(queue: .main)
        pushRegistry?.delegate = self
        pushRegistry?.desiredPushTypes = [.voIP]
    }
    
    /// Unregister from VoIP push notifications
    func unregister() {
        debugPrint("flutter: 📱 [PushKit] Unregistering from VoIP push")
        pushRegistry?.desiredPushTypes = []
        pushRegistry = nil
        voipToken = nil
    }
}

// MARK: - PKPushRegistryDelegate
extension PushKitManager: PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        
        // Convert token data to hex string
        let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        voipToken = token
        
        debugPrint("flutter: 📱 [PushKit] VoIP token received: \(token.prefix(20))... (env: \(apnsEnvironment))")
        
        // Send token to Flutter to store in backend
        flutterChannel?.invokeMethod("onVoIPTokenReceived", arguments: [
            "token": token,
            "environment": apnsEnvironment
        ])
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        
        debugPrint("flutter: ⚠️ [PushKit] VoIP token invalidated")
        voipToken = nil
        
        // Notify Flutter
        flutterChannel?.invokeMethod("onVoIPTokenInvalidated", arguments: nil)
    }
    
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }
        
        debugPrint("flutter: 📞 [PushKit] Received VoIP push notification")
        debugPrint("flutter: 📞 [PushKit] Payload: \(payload.dictionaryPayload)")
        
        // Extract call data from payload
        let data = payload.dictionaryPayload
        
        // Required fields
        let callId = data["callId"] as? String ?? UUID().uuidString
        let callerId = data["callerId"] as? String ?? "unknown"
        let callerName = data["callerName"] as? String ?? "Unknown Caller"
        let isVideo = data["isVideo"] as? Bool ?? data["hasVideo"] as? Bool ?? (data["isVideo"] as? String == "true") ?? (data["hasVideo"] as? String == "true")
        
        // Optional fields
        let callerPhoto = data["callerPhoto"] as? String
        let roomName = data["roomName"] as? String
        
        // Create UUID for this call (try to use callId if it's a valid UUID)
        let callUUID = UUID(uuidString: callId) ?? UUID()
        
        debugPrint("flutter: 📞 [PushKit] Processing call:")
        debugPrint("flutter:   - callId: \(callId)")
        debugPrint("flutter:   - callerId: \(callerId)")
        debugPrint("flutter:   - callerName: \(callerName)")
        debugPrint("flutter:   - isVideo: \(isVideo)")
        debugPrint("flutter:   - UUID: \(callUUID.uuidString)")
        
        // CRITICAL: Must report to CallKit immediately
        // iOS will terminate the app if we don't report within ~5 seconds
        CallKitManager.shared.reportIncomingCall(
            uuid: callUUID,
            callerId: callerId,
            callerName: callerName,
            hasVideo: isVideo
        ) { [weak self] error in
            if let error = error {
                debugPrint("flutter: ❌ [PushKit] Failed to report call to CallKit: \(error.localizedDescription)")
                
                // Log error details for debugging
                let nsError = error as NSError
                debugPrint("flutter: ⚠️ [PushKit] Error domain: \(nsError.domain), code: \(nsError.code)")
            } else {
                debugPrint("flutter: ✅ [PushKit] Call reported to CallKit successfully")
                
                // Store call data for when user answers
                CallKitManager.shared.pendingCallData = [
                    "callId": callId,
                    "callerId": callerId,
                    "callerName": callerName,
                    "callerPhoto": callerPhoto ?? "",
                    "isVideo": isVideo,
                    "roomName": roomName ?? "",
                    "uuid": callUUID.uuidString
                ]
            }
            
            // Notify Flutter about the incoming push (if app is running)
            self?.flutterChannel?.invokeMethod("onIncomingVoIPPush", arguments: [
                "callId": callId,
                "callerId": callerId,
                "callerName": callerName,
                "callerPhoto": callerPhoto ?? "",
                "isVideo": isVideo,
                "roomName": roomName ?? "",
                "callUUID": callUUID.uuidString
            ])
            
            // Must call completion handler
            completion()
        }
    }
}

import Flutter
import UIKit
import AVFoundation
import MediaPlayer
import FirebaseAuth

// Audio device stream handler for Flutter event channel
class AudioDeviceStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var portObserver: NSObjectProtocol?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        // Send current device immediately
        events(getCurrentDevice())
        
        // Track the last reported device to detect actual changes
        var lastReportedDevice = getCurrentDevice()
        
        // Setup observer for audio route changes
        portObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            // Log the actual current route BEFORE processing
            let sessionBefore = AVAudioSession.sharedInstance().currentRoute
            let outputsBefore = sessionBefore.outputs.map { "\($0.portType.rawValue)" }.joined(separator: ", ")
            let inputsBefore = sessionBefore.inputs.map { "\($0.portType.rawValue)" }.joined(separator: ", ")
            debugPrint("flutter: 🎯 [AudioRoute] Current actual route - Outputs: [\(outputsBefore)], Inputs: [\(inputsBefore)]")
            
            // Get the reason for route change
            if let userInfo = notification.userInfo,
               let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
               let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
                
                // Log the previous route from notification
                if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                    let prevOutputs = previousRoute.outputs.map { "\($0.portType.rawValue)" }.joined(separator: ", ")
                    debugPrint("flutter: 📍 [AudioRoute] Previous route was: [\(prevOutputs)]")
                }
                
                // Log the route change reason
                let reasonString: String
                var shouldRefresh = false
                var shouldNotify = true  // By default, notify Flutter of route changes
                
                switch reason {
                case .newDeviceAvailable:
                    reasonString = "NewDeviceAvailable (e.g., Bluetooth/headset connected)"
                    // Check if the route ACTUALLY changed to the new device
                    // If it did, iOS auto-switched (no user prompt), so we should notify
                    let currentDevice = self?.getCurrentDevice() ?? "speaker"
                    if currentDevice == "bluetooth" || currentDevice == "headset" {
                        debugPrint("flutter: ⚡ [AudioRoute] iOS auto-switched to \(currentDevice) without prompt")
                        shouldNotify = true
                        shouldRefresh = true
                    } else {
                        debugPrint("flutter: ⏸️ [AudioRoute] Device available but route unchanged - waiting for user")
                        shouldNotify = false
                    }
                case .oldDeviceUnavailable:
                    reasonString = "OldDeviceUnavailable (e.g., Bluetooth/headset disconnected)"
                    // Device disconnected, iOS auto-switches - refresh to ensure WebRTC picks it up
                    shouldRefresh = true
                case .categoryChange:
                    reasonString = "CategoryChange"
                    shouldRefresh = true
                case .override:
                    reasonString = "Override (manual user selection)"
                    // User selected device from iOS dialog - refresh WebRTC routing
                    shouldRefresh = true
                case .wakeFromSleep:
                    reasonString = "WakeFromSleep"
                case .noSuitableRouteForCategory:
                    reasonString = "NoSuitableRouteForCategory"
                case .routeConfigurationChange:
                    reasonString = "RouteConfigurationChange"
                    shouldRefresh = true
                default:
                    reasonString = "Unknown (\(reasonValue))"
                }
                
                debugPrint("flutter: 🔀 [AudioRoute] Change reason: \(reasonString)")
                
                // Only refresh WebRTC routing when route actually changes
                if shouldRefresh {
                    // Reactivate the audio session to make WebRTC pick up the new route
                    do {
                        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                        let currentRoute = AVAudioSession.sharedInstance().currentRoute
                        let outputs = currentRoute.outputs.map { "\($0.portType.rawValue)" }.joined(separator: ", ")
                        debugPrint("flutter: 🔄 [AudioRoute] Refreshed - Current output: \(outputs)")
                    } catch {
                        debugPrint("flutter: ❌ [AudioRoute] Error refreshing routing: \(error)")
                    }
                }
                
                // Only notify Flutter if we should (route actually changed, not just device available)
                if shouldNotify {
                    let currentDevice = self?.getCurrentDevice() ?? "speaker"
                    // Double check the device actually changed before notifying
                    if currentDevice != lastReportedDevice {
                        debugPrint("flutter: 📢 [AudioRoute] Device changed from \(lastReportedDevice) to \(currentDevice)")
                        lastReportedDevice = currentDevice
                        events(currentDevice)
                    }
                } else {
                    debugPrint("flutter: ⏸️ [AudioRoute] Skipping notification - waiting for user decision")
                }
            } else {
                // No reason provided, just send current device
                let device = self?.getCurrentDevice() ?? "speaker"
                if device != lastReportedDevice {
                    lastReportedDevice = device
                    events(device)
                }
            }
        }
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let observer = portObserver {
            NotificationCenter.default.removeObserver(observer)
            portObserver = nil
        }
        eventSink = nil
        return nil
    }
    
    func getCurrentDevice() -> String {
        let route = AVAudioSession.sharedInstance().currentRoute
        for output in route.outputs {
            switch output.portType {
            case .builtInSpeaker:
                return "speaker"
            case .builtInReceiver:
                return "earpiece"
            case .headphones:
                return "headset"
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                return "bluetooth"
            default:
                continue
            }
        }
        return "speaker"
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  var ringtonePlayer: AVAudioPlayer?
  var callKitHandler: CallKitChannelHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up method channel for notification handling and audio device management
    let controller = self.window?.rootViewController as! FlutterViewController
    
    // Notification channel
    let notificationChannel = FlutterMethodChannel(name: "com.example.securityexpertsApp/notifications",
                                                    binaryMessenger: controller.binaryMessenger)
    notificationChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "clearBadge":
        UIApplication.shared.applicationIconBadgeNumber = 0
        result(nil)
      case "setBadge":
        if let args = call.arguments as? [String: Any],
           let count = args["count"] as? Int {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Count required", details: nil))
        }
      case "getBadge":
        result(UIApplication.shared.applicationIconBadgeNumber)
      case "incrementBadge":
        let increment = (call.arguments as? [String: Any])?["count"] as? Int ?? 1
        UIApplication.shared.applicationIconBadgeNumber += increment
        result(UIApplication.shared.applicationIconBadgeNumber)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Ringtone channel
    let ringtoneChannel = FlutterMethodChannel(name: "com.example.securityexpertsApp.call/ringtone",
                                              binaryMessenger: controller.binaryMessenger)
    ringtoneChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "play":
        guard let args = call.arguments as? [String: Any],
              let assetPath = args["assetPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Asset path required", details: nil))
          return
        }
        
        let key = controller.lookupKey(forAsset: assetPath)
        if let path = Bundle.main.path(forResource: key, ofType: nil) {
            let url = URL(fileURLWithPath: path)
            do {
                // Ensure audio session is correct (PlayAndRecord) BEFORE playing
                // This matches WebRTC's needs, avoiding category switch issues
                let audioSession = AVAudioSession.sharedInstance()
                if audioSession.category != .playAndRecord {
                    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth])
                    try audioSession.setActive(true)
                }
                
                self.ringtonePlayer = try AVAudioPlayer(contentsOf: url)
                self.ringtonePlayer?.numberOfLoops = -1 // Loop indefinitely
                self.ringtonePlayer?.volume = 1.0
                self.ringtonePlayer?.prepareToPlay()
                self.ringtonePlayer?.play()
                debugPrint("flutter: 🔊 [iOS Native] Ringtone started via AVAudioPlayer")
                result(nil)
            } catch {
                debugPrint("flutter: ❌ [iOS Native] Error playing ringtone: \(error)")
                result(FlutterError(code: "PLAY_ERROR", message: error.localizedDescription, details: nil))
            }
        } else {
            debugPrint("flutter: ❌ [iOS Native] Asset not found at path: \(assetPath)")
             result(FlutterError(code: "ASSET_NOT_FOUND", message: "Asset not found", details: nil))
        }
        
      case "stop":
        if let player = self.ringtonePlayer, player.isPlaying {
            player.stop()
        }
        self.ringtonePlayer = nil
        debugPrint("flutter: 🔇 [iOS Native] Ringtone stopped")
        result(nil)
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Audio device channel
    let audioChannel = FlutterMethodChannel(name: "com.example.securityexpertsApp.call/audio",
                                           binaryMessenger: controller.binaryMessenger)
    audioChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getAvailableAudioDevices":
        result(self.getAvailableAudioDevices())
      case "getCurrentAudioDevice":
        let handler = AudioDeviceStreamHandler()
        result(handler.getCurrentDevice())
      case "setAudioDevice":
        let args = call.arguments as? [String: Any]
        let device = args?["device"] as? String ?? "speaker"
        debugPrint("flutter: 🎯 [iOS Native] setAudioDevice called with: \(device)")
        self.setAudioDevice(device)
        result(nil)
      case "resetAudioDevice":
        self.resetAudioDevice()
        result(nil)
      case "setSpeakerphoneOn":
        let args = call.arguments as? [String: Any]
        let enabled = args?["enabled"] as? Bool ?? false
        self.setSpeakerphoneOn(enabled)
        result(nil)
      case "configureForMediaPlayback":
        // Configure audio session for media playback (videos, audio messages)
        // This uses .playback category with defaultToSpeaker for loud speaker output
        self.configureAudioSessionForMediaPlayback()
        result(nil)
      case "configureForWebRTC":
        // Restore audio session for WebRTC calls
        self.configureAudioSessionForWebRTC()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Setup event channel for audio device changes
    let eventChannel = FlutterEventChannel(name: "com.example.securityexpertsApp.call/audioDeviceEvents",
                                          binaryMessenger: controller.binaryMessenger)
    eventChannel.setStreamHandler(AudioDeviceStreamHandler())
    
    // Initialize CallKit for native call UI
    callKitHandler = CallKitChannelHandler(messenger: controller.binaryMessenger)
    
    // NOTE: Do NOT configure audio session here in didFinishLaunchingWithOptions
    // Audio session should be configured on-demand when:
    // - A call starts (via AudioSessionManager.shared.transition(to: .activeCall))
    // - Media playback starts (via AudioSessionManager.shared.transition(to: .mediaPlayback))
    // This prevents conflicts with other audio apps on app launch.
    
    // Initialize HFP device detection
    initializeHFPDetection()
    
    // Initialize HFP call control (for car buttons)
    initializeHFPCallControl()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Firebase Phone Auth Support
  // Required because FirebaseAppDelegateProxyEnabled is false
  
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Forward APNs token to Firebase Auth for phone number verification
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(_ application: UIApplication,
                            didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Let Firebase Auth handle silent push for phone verification
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(UIBackgroundFetchResult.noData)
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
  
  override func application(_ app: UIApplication,
                            open url: URL,
                            options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    // Let Firebase Auth handle reCAPTCHA redirect
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
  
  private func configureAudioSessionForWebRTC() {
    // Use centralized AudioSessionManager for consistent audio configuration
    AudioSessionManager.shared.transition(to: .activeCall)
  }
  
  private func configureAudioSessionForMediaPlayback() {
    // Use centralized AudioSessionManager for consistent audio configuration
    AudioSessionManager.shared.transition(to: .mediaPlayback)
  }
  
  private func getAvailableAudioDevices() -> [String] {
    var devices: [String] = ["speaker"]
    
    // Check available inputs to detect connected peripherals
    // (Bluetooth and Headsets usually appear as inputs)
    if let inputs = AVAudioSession.sharedInstance().availableInputs {
      for input in inputs {
        switch input.portType {
        case .headsetMic, .headphones:
          if !devices.contains("headset") {
            devices.append("headset")
          }
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
          if !devices.contains("bluetooth") {
            devices.append("bluetooth")
          }
        case .carAudio:
          if !devices.contains("carplay") {
            devices.append("carplay")
            debugPrint("flutter: 🚗 [AudioDevices] CarPlay detected: \(input.portName)")
          }
        default:
          break
        }
      }
    }
    
    // Add earpiece if no external audio devices are connected
    // On iPhones, Speaker and Earpiece are always switchable when no external devices present
    let hasExternalDevices = devices.contains("bluetooth") || devices.contains("headset")
    if !hasExternalDevices && UIDevice.current.userInterfaceIdiom == .phone {
      // Always add earpiece for iPhones when no external devices are connected
      // Speaker and Earpiece are always available for switching
      if !devices.contains("earpiece") {
        devices.append("earpiece")
      }
    }
    
    return devices
  }
  
  private func setAudioDevice(_ device: String) {
    debugPrint("flutter: 🔊 [iOS Native] Switching to: \(device)")
    
    do {
      try AudioSessionManager.shared.setAudioDevice(device)
      debugPrint("flutter: ✅ [iOS Native] Audio device set to \(device)")
    } catch {
      debugPrint("flutter: ❌ [iOS Native] Error setting audio device: \(error)")
      // Fallback: try speaker as safe default
      do {
        try AudioSessionManager.shared.setAudioDevice("speaker")
        debugPrint("flutter: 🔄 [iOS Native] Fallback to speaker")
      } catch {
        debugPrint("flutter: ❌ [iOS Native] Fallback to speaker also failed")
      }
    }
  }

  private func resetAudioDevice() {
    AudioSessionManager.shared.resetToDefault()
    debugPrint("flutter: 🔄 [AudioDevice] Reset to system default routing")
  }
  
  private func setSpeakerphoneOn(_ enabled: Bool) {
    let audioSession = AVAudioSession.sharedInstance()
    do {
      if enabled {
        try audioSession.overrideOutputAudioPort(.speaker)
      } else {
        try audioSession.overrideOutputAudioPort(.none)
      }
    } catch {
      debugPrint("flutter: ❌ Error setting speakerphone: \(error)")
    }
  }
  
  private func initializeHFPDetection() {
    let audioSession = AVAudioSession.sharedInstance()
    
    // Log initial HFP device detection
    debugPrint("flutter: 🎧 [HFP] Initializing Hands-Free Profile (HFP) detection")
    
    if let inputs = audioSession.availableInputs {
      let hfpDevices = inputs.filter { $0.portType == .bluetoothHFP }
      let a2dpDevices = inputs.filter { $0.portType == .bluetoothA2DP }
      let leDevices = inputs.filter { $0.portType == .bluetoothLE }
      let carPlayDevices = inputs.filter { $0.portType == .carAudio }
      
      if !carPlayDevices.isEmpty {
        for device in carPlayDevices {
          debugPrint("flutter: 🚗 [HFP] Found CarPlay device: \(device.portName) (uid: \(device.uid))")
        }
      }
      
      if !hfpDevices.isEmpty {
        for device in hfpDevices {
          debugPrint("flutter: ✅ [HFP] Found HFP device: \(device.portName) (uid: \(device.uid))")
        }
      }
      
      if !a2dpDevices.isEmpty {
        for device in a2dpDevices {
          debugPrint("flutter: 📻 [HFP] Found A2DP device: \(device.portName) (uid: \(device.uid))")
        }
      }
      
      if !leDevices.isEmpty {
        for device in leDevices {
          debugPrint("flutter: 🔗 [HFP] Found Bluetooth LE device: \(device.portName) (uid: \(device.uid))")
        }
      }
      
      if hfpDevices.isEmpty && a2dpDevices.isEmpty && leDevices.isEmpty && carPlayDevices.isEmpty {
        debugPrint("flutter: ℹ️ [HFP] No Bluetooth or CarPlay devices currently connected")
      }
    } else {
      debugPrint("flutter: ⚠️ [HFP] Unable to access available audio inputs")
    }
    
    // Set up observer for route changes to detect HFP device connections
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: audioSession
    )
  }
  
  @objc private func handleAudioRouteChange(notification: NSNotification) {
    let audioSession = AVAudioSession.sharedInstance()
    
    // Get route change reason
    if let userInfo = notification.userInfo,
       let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
       let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
      debugPrint("flutter: 🎧 [HFP] Route change detected - Reason: \(reason.rawValue)")
    }
    
    // Check if HFP device is now available
    if let inputs = audioSession.availableInputs {
      let hfpDevices = inputs.filter { $0.portType == .bluetoothHFP }
      let a2dpDevices = inputs.filter { $0.portType == .bluetoothA2DP }
      let carPlayDevices = inputs.filter { $0.portType == .carAudio }
      
      if !carPlayDevices.isEmpty {
        debugPrint("flutter: 🚗 [HFP] CarPlay device(s) detected in audio route change")
        for device in carPlayDevices {
          debugPrint("flutter: 🚗 [HFP] CarPlay Available: \(device.portName) (uid: \(device.uid))")
        }
      }
      
      if !hfpDevices.isEmpty {
        debugPrint("flutter: 🎧 [HFP] HFP device(s) detected in audio route change")
        for device in hfpDevices {
          debugPrint("flutter: ✅ [HFP] HFP Available: \(device.portName) (uid: \(device.uid))")
        }
      }
      
      if !a2dpDevices.isEmpty {
        debugPrint("flutter: 📻 [HFP] A2DP device(s) also available")
        for device in a2dpDevices {
          debugPrint("flutter: 📻 [HFP] A2DP: \(device.portName) (uid: \(device.uid))")
        }
      }
    }
  }
  
  private func initializeHFPCallControl() {
    debugPrint("flutter: 🎧 [HFP] Initializing HFP call control for remote commands (car buttons)")
    
    let commandCenter = MPRemoteCommandCenter.shared()
    
    // Enable remote commands
    commandCenter.pauseCommand.isEnabled = false
    commandCenter.playCommand.isEnabled = false
    commandCenter.stopCommand.isEnabled = false
    
    // Handle pause/stop as end call
    let pauseTarget = commandCenter.pauseCommand.addTarget { [weak self] event in
      debugPrint("flutter: 📞 [HFP] Pause command received from HFP device (end call request)")
      self?.handleHFPCallControl(action: "endCall")
      return .success
    }
    
    let stopTarget = commandCenter.stopCommand.addTarget { [weak self] event in
      debugPrint("flutter: 📞 [HFP] Stop command received from HFP device (end call request)")
      self?.handleHFPCallControl(action: "endCall")
      return .success
    }
    
    // Handle play as answer/resume
    let playTarget = commandCenter.playCommand.addTarget { [weak self] event in
      debugPrint("flutter: 📞 [HFP] Play command received from HFP device (answer call request)")
      self?.handleHFPCallControl(action: "answerCall")
      return .success
    }
    
    debugPrint("flutter: ✅ [HFP] Remote command handlers registered")
    
    // Store targets to keep them alive
    objc_setAssociatedObject(self, "pauseCommandTarget", pauseTarget, .OBJC_ASSOCIATION_RETAIN)
    objc_setAssociatedObject(self, "stopCommandTarget", stopTarget, .OBJC_ASSOCIATION_RETAIN)
    objc_setAssociatedObject(self, "playCommandTarget", playTarget, .OBJC_ASSOCIATION_RETAIN)
  }
  
  private func handleHFPCallControl(action: String) {
    // Create a method channel to communicate with Flutter
    let controller = self.window?.rootViewController as? FlutterViewController
    guard let controller = controller else {
      debugPrint("flutter: ❌ [HFP] Could not get FlutterViewController")
      return
    }
    
    let hfpChannel = FlutterMethodChannel(name: "com.example.securityexpertsApp.call/hfp",
                                          binaryMessenger: controller.binaryMessenger)
    
    debugPrint("flutter: 📞 [HFP] Sending call control action to Flutter: \(action)")
    
    hfpChannel.invokeMethod("handleCallControl", arguments: ["action": action]) { result in
      if let result = result as? Bool, result {
        debugPrint("flutter: ✅ [HFP] Call control action '\(action)' handled successfully by Flutter")
      } else {
        debugPrint("flutter: ⚠️ [HFP] Flutter did not handle call control action '\(action)'")
      }
    }
  }
}

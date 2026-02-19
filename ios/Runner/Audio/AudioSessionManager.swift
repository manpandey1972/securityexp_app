import AVFoundation
import UIKit

/// Centralized manager for iOS audio session configuration
/// Prevents conflicts between media playback and calls by managing state transitions
class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    /// Audio context states for the application
    enum AudioContext {
        case idle
        case mediaPlayback
        case incomingCall
        case activeCall
        case callEnding
    }
    
    /// Standardized audio options for VoIP calls
    static let voipOptions: AVAudioSession.CategoryOptions = [
        .allowBluetooth,       // HFP for voice
        .allowBluetoothA2DP,   // High-quality Bluetooth audio
        .allowAirPlay,         // AirPlay speakers
        .duckOthers,           // Lower other audio during call
    ]
    
    /// Standardized audio options for media playback
    static let mediaOptions: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker,
        .allowBluetooth,
        .allowAirPlay,
    ]
    
    private(set) var currentContext: AudioContext = .idle
    private(set) var isAudioSessionActive: Bool = false
    
    private init() {
        debugPrint("flutter: 🎵 [AudioSessionManager] Initialized")
    }
    
    /// Transition to a new audio context
    /// - Parameter newContext: The target audio context
    func transition(to newContext: AudioContext) {
        guard newContext != currentContext else {
            debugPrint("flutter: 🎵 [AudioSessionManager] Already in context: \(contextDescription(newContext))")
            return
        }
        
        let previousContext = currentContext
        currentContext = newContext
        
        debugPrint("flutter: 🎵 [AudioSessionManager] Transitioning: \(contextDescription(previousContext)) → \(contextDescription(newContext))")
        
        switch newContext {
        case .idle:
            deactivateSession()
        case .mediaPlayback:
            configureForMediaPlayback()
        case .incomingCall:
            // Don't configure audio yet - wait for CallKit didActivate
            debugPrint("flutter: 🎵 [AudioSessionManager] Incoming call - deferring audio config to CallKit")
        case .activeCall:
            configureForActiveCall()
        case .callEnding:
            // Will be handled by CallKit deactivation callback
            debugPrint("flutter: 🎵 [AudioSessionManager] Call ending - waiting for CallKit didDeactivate")
        }
    }
    
    /// Configure audio session for an active VoIP call
    /// This is the single source of truth for call audio configuration
    func configureForActiveCall() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: AudioSessionManager.voipOptions
            )
            
            try audioSession.setActive(true, options: [])
            isAudioSessionActive = true
            
            debugPrint("flutter: ✅ [AudioSessionManager] Configured for active call")
            debugPrint("flutter: 🎵 [AudioSessionManager] Category: \(audioSession.category.rawValue)")
            debugPrint("flutter: 🎵 [AudioSessionManager] Mode: \(audioSession.mode.rawValue)")
            debugPrint("flutter: 🎵 [AudioSessionManager] Options: \(audioSession.categoryOptions.rawValue)")
            
        } catch {
            debugPrint("flutter: ❌ [AudioSessionManager] Failed to configure for call: \(error)")
        }
    }
    
    /// Configure audio session for media playback
    /// Used when playing non-call audio (music, videos, notifications)
    func configureForMediaPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: AudioSessionManager.mediaOptions
            )
            
            try audioSession.setActive(true, options: [])
            isAudioSessionActive = true
            
            debugPrint("flutter: ✅ [AudioSessionManager] Configured for media playback")
            
        } catch {
            debugPrint("flutter: ❌ [AudioSessionManager] Failed to configure for media: \(error)")
        }
    }
    
    /// Deactivate audio session and return to idle state
    func deactivateSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            isAudioSessionActive = false
            currentContext = .idle
            
            debugPrint("flutter: ✅ [AudioSessionManager] Audio session deactivated")
            
        } catch {
            debugPrint("flutter: ⚠️ [AudioSessionManager] Failed to deactivate: \(error)")
        }
    }
    
    /// Called by CallKit when audio session is activated by the system
    /// This is the safe point to start WebRTC media capture
    func didActivateAudioSession(_ audioSession: AVAudioSession) {
        isAudioSessionActive = true
        
        // If we're in incoming call state, transition to active
        if currentContext == .incomingCall {
            currentContext = .activeCall
        }
        
        debugPrint("flutter: ✅ [AudioSessionManager] CallKit audio session activated")
        debugPrint("flutter: 🎵 [AudioSessionManager] Sample rate: \(audioSession.sampleRate)")
        debugPrint("flutter: 🎵 [AudioSessionManager] Input channels: \(audioSession.inputNumberOfChannels)")
        debugPrint("flutter: 🎵 [AudioSessionManager] Output channels: \(audioSession.outputNumberOfChannels)")
    }
    
    /// Called by CallKit when audio session is deactivated by the system
    func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
        isAudioSessionActive = false
        currentContext = .idle
        
        debugPrint("flutter: 🎵 [AudioSessionManager] CallKit audio session deactivated")
    }
    
    /// Set preferred audio device
    /// - Parameter device: Device type string (speaker, bluetooth, earpiece, etc.)
    func setAudioDevice(_ device: String) throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        switch device.lowercased() {
        case "speaker":
            try audioSession.overrideOutputAudioPort(.speaker)
            debugPrint("flutter: 🔊 [AudioSessionManager] Set to speaker")
            
        case "earpiece":
            try audioSession.overrideOutputAudioPort(.none)
            debugPrint("flutter: 📱 [AudioSessionManager] Set to earpiece")
            
        case "bluetooth":
            try setBluetoothDevice(audioSession: audioSession)
            
        case "headset":
            try setHeadsetDevice(audioSession: audioSession)
            
        case "carplay":
            try setCarPlayDevice(audioSession: audioSession)
            
        default:
            debugPrint("flutter: ⚠️ [AudioSessionManager] Unknown device: \(device)")
        }
    }
    
    /// Set audio to Bluetooth device (HFP preferred)
    private func setBluetoothDevice(audioSession: AVAudioSession) throws {
        guard let inputs = audioSession.availableInputs else {
            throw AudioSessionError.noInputsAvailable
        }
        
        // Prefer HFP for voice calls, fall back to LE or A2DP
        var bluetoothInput = inputs.first(where: { $0.portType == .bluetoothHFP })
        if bluetoothInput == nil {
            bluetoothInput = inputs.first(where: { $0.portType == .bluetoothLE })
        }
        if bluetoothInput == nil {
            bluetoothInput = inputs.first(where: { $0.portType == .bluetoothA2DP })
        }
        
        if let input = bluetoothInput {
            try audioSession.setPreferredInput(input)
            try audioSession.overrideOutputAudioPort(.none)
            debugPrint("flutter: 🎧 [AudioSessionManager] Set to Bluetooth: \(input.portName)")
        } else {
            throw AudioSessionError.deviceNotAvailable("Bluetooth")
        }
    }
    
    /// Set audio to wired headset
    private func setHeadsetDevice(audioSession: AVAudioSession) throws {
        guard let inputs = audioSession.availableInputs else {
            throw AudioSessionError.noInputsAvailable
        }
        
        let headsetInput = inputs.first(where: { $0.portType == .headsetMic || $0.portType == .headphones })
        
        if let input = headsetInput {
            try audioSession.setPreferredInput(input)
            try audioSession.overrideOutputAudioPort(.none)
            debugPrint("flutter: 🎧 [AudioSessionManager] Set to headset: \(input.portName)")
        } else {
            throw AudioSessionError.deviceNotAvailable("Headset")
        }
    }
    
    /// Set audio to CarPlay
    private func setCarPlayDevice(audioSession: AVAudioSession) throws {
        guard let inputs = audioSession.availableInputs else {
            throw AudioSessionError.noInputsAvailable
        }
        
        let carPlayInput = inputs.first(where: { $0.portType == .carAudio })
        
        if let input = carPlayInput {
            try audioSession.setPreferredInput(input)
            try audioSession.overrideOutputAudioPort(.none)
            debugPrint("flutter: 🚗 [AudioSessionManager] Set to CarPlay: \(input.portName)")
        } else {
            throw AudioSessionError.deviceNotAvailable("CarPlay")
        }
    }
    
    /// Get current audio device
    func getCurrentDevice() -> String {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        
        // Check outputs first
        for output in currentRoute.outputs {
            switch output.portType {
            case .builtInSpeaker:
                return "speaker"
            case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
                return "bluetooth"
            case .headphones, .headsetMic:
                return "headset"
            case .builtInReceiver:
                return "earpiece"
            case .carAudio:
                return "carplay"
            default:
                continue
            }
        }
        
        return "earpiece" // Default fallback
    }
    
    /// Get list of available audio devices
    func getAvailableDevices() -> [String] {
        let audioSession = AVAudioSession.sharedInstance()
        var devices: [String] = ["speaker", "earpiece"]
        
        if let inputs = audioSession.availableInputs {
            for input in inputs {
                switch input.portType {
                case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
                    if !devices.contains("bluetooth") {
                        devices.append("bluetooth")
                    }
                case .headsetMic, .headphones:
                    if !devices.contains("headset") {
                        devices.append("headset")
                    }
                case .carAudio:
                    if !devices.contains("carplay") {
                        devices.append("carplay")
                    }
                default:
                    break
                }
            }
        }
        
        return devices
    }
    
    /// Reset audio device to system default
    func resetToDefault() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setPreferredInput(nil)
            try audioSession.overrideOutputAudioPort(.none)
            debugPrint("flutter: 🔄 [AudioSessionManager] Reset to default audio routing")
        } catch {
            debugPrint("flutter: ⚠️ [AudioSessionManager] Failed to reset: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func contextDescription(_ context: AudioContext) -> String {
        switch context {
        case .idle: return "idle"
        case .mediaPlayback: return "mediaPlayback"
        case .incomingCall: return "incomingCall"
        case .activeCall: return "activeCall"
        case .callEnding: return "callEnding"
        }
    }
}

// MARK: - Errors

enum AudioSessionError: Error, LocalizedError {
    case noInputsAvailable
    case deviceNotAvailable(String)
    
    var errorDescription: String? {
        switch self {
        case .noInputsAvailable:
            return "No audio inputs available"
        case .deviceNotAvailable(let device):
            return "\(device) device not available"
        }
    }
}

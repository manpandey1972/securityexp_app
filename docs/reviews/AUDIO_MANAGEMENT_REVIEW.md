# Audio Management & Configuration Review

**Review Date:** January 22, 2026  
**Focus Area:** Call setup audio configuration, device management, and iOS/Android native integration

---

## 📊 Executive Summary

| Area | Grade | Key Finding |
|------|-------|-------------|
| **iOS Audio Session** | B | Good configuration, but multiple initialization points risk conflicts |
| **Android Audio** | B- | Basic implementation, missing MODE_IN_COMMUNICATION |
| **Initialization Timing** | C+ | Audio initialized in multiple places without coordination |
| **Resource Cleanup** | B | Good disposal patterns, but stream controllers need attention |
| **CallKit Integration** | B+ | Proper audio session activation callbacks |

---

## 🔴 Critical Issues

### 1. Multiple Audio Session Configuration Points (HIGH)

**Problem:** Audio session is configured in at least 4 different places without coordination:

| Location | When Called | Category Set |
|----------|-------------|--------------|
| `AppDelegate.didFinishLaunching` | App startup | `.playAndRecord` + `.voiceChat` |
| `CallKitManager.configureAudioSession()` | CallKit actions | `.playAndRecord` + `.voiceChat` |
| `Ringtone channel handler` | Before ringtone | `.playAndRecord` + `.voiceChat` |
| `MediaAudioSessionHelper.configureForMediaPlayback()` | Before media playback | `.playback` |

**Risk:** When a user is playing media and receives a call, the audio session category may conflict:

```swift
// AppDelegate.swift line 212-219 - configureForMediaPlayback()
try audioSession.setCategory(
  AVAudioSession.Category.playback,  // ← Media uses .playback
  mode: AVAudioSession.Mode.default,
  options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay]
)

// CallKitManager.swift line 181-190 - configureAudioSession()  
try audioSession.setCategory(
  .playAndRecord,  // ← Calls use .playAndRecord
  mode: .voiceChat,
  options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers]
)
```

**Recommendation:**
- Create a centralized `AudioSessionManager` that tracks the current audio context
- Use a state machine pattern to handle transitions between media playback and calls
- Don't configure audio session in `didFinishLaunching` - defer until actually needed

---

### 2. Android Missing Audio Mode Configuration (HIGH)

**Problem:** Android's `MainActivity.kt` doesn't set `AudioManager.MODE_IN_COMMUNICATION` for VoIP calls.

**Current code:**
```kotlin
// MainActivity.kt line 93-101
private fun setAudioDevice(device: String) {
    when (device.lowercase()) {
        "speaker" -> {
            audioManager.isSpeakerphoneOn = true  // Only sets speaker, no mode
        }
        // ...
    }
}
```

**Best Practice:** For VoIP calls, Android requires:
```kotlin
// Should be added before setting speaker/earpiece
audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
audioManager.isSpeakerphoneOn = true
```

**Impact:** Without `MODE_IN_COMMUNICATION`:
- Echo cancellation may not work properly
- Audio routing may behave unpredictably
- Bluetooth SCO may not activate correctly

**Recommendation:**
```kotlin
fun configureForVoIPCall() {
    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
    audioManager.requestAudioFocus(
        audioFocusChangeListener,
        AudioManager.STREAM_VOICE_CALL,
        AudioManager.AUDIOFOCUS_GAIN
    )
}

fun releaseVoIPCall() {
    audioManager.mode = AudioManager.MODE_NORMAL
    audioManager.abandonAudioFocus(audioFocusChangeListener)
}
```

---

### 3. AudioDeviceService Initialized Multiple Times (MEDIUM)

**Problem:** `AudioDeviceService.initialize()` can be called multiple times:

```dart
// livekit_media_manager.dart line 84
await _audioService.initialize();

// webrtc_media_manager.dart line 83
await _audioService.initialize();
```

While there's a guard (`if (_initialized || _isDisposed) return;`), the service is registered as a singleton in GetIt but initialized from factory-created MediaManagers.

**Current flow:**
1. `AudioDeviceService` registered as lazy singleton in `call_dependencies.dart`
2. `LiveKitMediaManager` is created via factory
3. Each factory instance calls `_audioService.initialize()`
4. First call initializes, subsequent calls are no-ops

**Risk:** If `AudioDeviceService` is disposed and reused (which shouldn't happen with proper lifecycle management), the `_initialized` flag may be stale.

**Recommendation:**
- Move `AudioDeviceService.initialize()` to service locator setup, not MediaManager
- Or make initialization idempotent by checking listener state, not just a boolean flag

---

### 4. Duplicate Audio Session Configuration Options (MEDIUM)

**Problem:** iOS audio session options are inconsistent across configuration points.

| Location | Options Used |
|----------|--------------|
| `AppDelegate.configureAudioSessionForWebRTC()` | `.duckOthers`, `.allowBluetooth`, `.allowAirPlay` |
| `CallKitManager.configureAudioSession()` | `.allowBluetooth`, `.allowBluetoothA2DP`, `.duckOthers` |

**Differences:**
- AppDelegate allows AirPlay, CallKitManager doesn't
- CallKitManager explicitly allows BluetoothA2DP, AppDelegate uses generic `.allowBluetooth`

**Recommendation:** Standardize to a single configuration:
```swift
// Recommended standard for VoIP
options: [
    .allowBluetooth,       // HFP for voice
    .allowBluetoothA2DP,   // High-quality Bluetooth audio
    .allowAirPlay,         // AirPlay speakers
    .duckOthers,           // Lower other audio during call
]
```

---

## 🟡 Medium Priority Issues

### 5. No Audio Focus Management on Android (MEDIUM)

**Problem:** Android doesn't request/release audio focus, which can cause issues with:
- Music apps continuing to play during calls
- Other apps interrupting call audio
- System sounds interfering with calls

**Current state:** No `AudioManager.requestAudioFocus()` or `abandonAudioFocus()` calls.

**Recommendation:**
```kotlin
private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
    when (focusChange) {
        AudioManager.AUDIOFOCUS_LOSS -> {
            // Permanent loss - pause/mute
        }
        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
            // Temporary loss - pause
        }
        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
            // Can duck (lower volume)
        }
        AudioManager.AUDIOFOCUS_GAIN -> {
            // Regained focus - resume
        }
    }
}
```

---

### 6. Bluetooth SCO Lifecycle Not Managed (MEDIUM)

**Problem:** Android Bluetooth SCO is started but never stopped properly.

**Current code:**
```kotlin
// MainActivity.kt line 99-100
"bluetooth" -> {
    audioManager.isSpeakerphoneOn = false
    audioManager.startBluetoothSco()  // Started but never stopped!
}
```

**Missing:** `audioManager.stopBluetoothSco()` when switching away from Bluetooth or ending call.

**Impact:** 
- Bluetooth SCO channel may stay open unnecessarily
- Battery drain on Bluetooth device
- May prevent other apps from using Bluetooth audio

**Recommendation:**
```kotlin
private var isBluetoothScoStarted = false

fun setAudioDevice(device: String) {
    // Stop existing SCO if switching away
    if (isBluetoothScoStarted && device != "bluetooth") {
        audioManager.stopBluetoothSco()
        isBluetoothScoStarted = false
    }
    
    when (device) {
        "bluetooth" -> {
            audioManager.isSpeakerphoneOn = false
            audioManager.startBluetoothSco()
            isBluetoothScoStarted = true
        }
        // ...
    }
}
```

---

### 7. Race Condition in Audio Route Change Notification (MEDIUM)

**Problem:** iOS audio route changes are debounced at 300ms, but this may miss rapid device changes.

```dart
// audio_device_service.dart line 166-169
_deviceChangeDebounce = Timer(Duration(milliseconds: 300), () {
  // Handle device change
});
```

**Scenario:**
1. User connects Bluetooth (notification fired)
2. Debounce timer starts (300ms)
3. Bluetooth auto-disconnects within 300ms
4. New notification cancels debounce
5. User sees wrong device state

**Recommendation:** 
- Use shorter debounce (100-150ms) or
- Track pending state and always update to latest when debounce fires

---

### 8. CallKit Audio Activation Timing (MEDIUM)

**Problem:** Audio is configured in `CXAnswerCallAction` before CallKit confirms activation.

```swift
// CallKitManager.swift line 244-254
func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    configureAudioSession()  // ← Configured here
    // ...
    action.fulfill()
}

func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    // ← But system tells us audio is ready here
}
```

**Best Practice:** WebRTC should only be started after `didActivate` callback:

```swift
func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    isAudioSessionActive = true
    flutterChannel?.invokeMethod("onAudioSessionActivated", arguments: nil)
    // Flutter should start WebRTC media capture here
}
```

---

## 🟢 Low Priority / Observations

### 9. Unused `configureForWebRTC()` in MediaAudioSessionHelper (LOW)

**Observation:** `MediaAudioSessionHelper.configureForWebRTC()` is defined but grep shows it's rarely called.

```dart
// media_audio_session_helper.dart line 38-48
static Future<void> configureForWebRTC() async {
  if (kIsWeb) return;
  if (!Platform.isIOS) return;
  
  try {
    await _platform.invokeMethod('configureForWebRTC');
    // ...
  }
}
```

**Usage:** Only defined, not actively called from call setup flow.

**Question:** Is this meant to be called but isn't? Or is it legacy code?

---

### 10. StreamController Disposal Pattern (LOW)

**Observation:** `AudioDeviceService.dispose()` has a comment about not closing broadcast controllers:

```dart
// audio_device_service.dart line 395-398
Future<void> dispose() async {
  _deviceChangeDebounce?.cancel();
  await _audioDeviceListener?.cancel();
  // Do NOT close broadcast controllers as this is a singleton
  // await _deviceChangeController.close();
}
```

**Concern:** If the service is ever truly disposed and recreated, the old controllers would leak.

**Recommendation:** Either:
- Properly close controllers in dispose and recreate in initialize, or
- Make the singleton truly persistent (never disposed)

---

### 11. Missing Error Recovery for Audio Device Setting (LOW)

**Problem:** When `setAudioDevice` fails, error is caught but no recovery attempted.

```dart
// audio_device_service.dart line 251-260
Future<void> setAudioDevice(AudioDevice device) async {
  try {
    // ...
    await platform.invokeMethod('setAudioDevice', {'device': deviceString});
  } catch (e) {
    debugPrint('flutter: ❌ [AudioDeviceService] Error setting audio device: $e');
    rethrow;  // Just rethrows
  }
}
```

**Recommendation:** Add fallback behavior:
```dart
} catch (e) {
  debugPrint('Error setting audio device: $e');
  // Fallback: try to set speaker as safe default
  try {
    await platform.invokeMethod('setAudioDevice', {'device': 'speaker'});
    _currentDevice = AudioDevice.speaker;
  } catch (_) {
    // Log but don't crash
  }
  rethrow;
}
```

---

## ✅ Good Practices Found

### 1. Proper DI Pattern for AudioDeviceService
```dart
// call_dependencies.dart line 141
sl.registerLazySingleton<AudioDeviceService>(() => AudioDeviceService());
```
Audio service is correctly registered as singleton via GetIt.

### 2. Debounced Device Change Notifications
The 300ms debounce prevents UI flicker from rapid route changes.

### 3. Available Device Detection
Both iOS and Android properly enumerate available audio devices before showing UI.

### 4. CallKit Integration
Proper implementation of `CXProviderDelegate` with audio session lifecycle callbacks.

### 5. Bluetooth Priority
iOS correctly prioritizes HFP over A2DP for voice calls:
```swift
var bluetoothInput = inputs.first(where: { $0.portType == .bluetoothHFP })
if bluetoothInput == nil {
    bluetoothInput = inputs.first(where: { $0.portType == .bluetoothLE })
}
```

---

## 📋 Recommended Actions

### High Priority
| # | Action | Files Affected | Effort |
|---|--------|----------------|--------|
| 1 | Create centralized `AudioSessionManager` for iOS | `AppDelegate.swift`, `CallKitManager.swift` | 4h |
| 2 | Add `MODE_IN_COMMUNICATION` to Android | `MainActivity.kt` | 1h |
| 3 | Add audio focus management to Android | `MainActivity.kt` | 2h |

### Medium Priority
| # | Action | Files Affected | Effort |
|---|--------|----------------|--------|
| 4 | Standardize iOS audio session options | `AppDelegate.swift`, `CallKitManager.swift` | 1h |
| 5 | Add Bluetooth SCO lifecycle management | `MainActivity.kt` | 1h |
| 6 | Move `AudioDeviceService.initialize()` to DI setup | `call_dependencies.dart` | 30m |
| 7 | Wait for `didActivate` before starting WebRTC | `callkit_service.dart`, media managers | 2h |

### Low Priority
| # | Action | Files Affected | Effort |
|---|--------|----------------|--------|
| 8 | Add error recovery to `setAudioDevice` | `audio_device_service.dart` | 30m |
| 9 | Review `configureForWebRTC()` usage | `media_audio_session_helper.dart` | 30m |
| 10 | Clarify StreamController disposal strategy | `audio_device_service.dart` | 30m |

---

## 🏗️ Proposed Architecture

### Centralized Audio Session Manager (iOS)

```swift
/// Centralized manager for iOS audio session configuration
/// Prevents conflicts between media playback and calls
class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    enum AudioContext {
        case idle
        case mediaPlayback
        case incomingCall
        case activeCall
        case callEnding
    }
    
    private(set) var currentContext: AudioContext = .idle
    
    func transition(to newContext: AudioContext) {
        guard newContext != currentContext else { return }
        
        let previousContext = currentContext
        currentContext = newContext
        
        switch newContext {
        case .idle:
            deactivateSession()
        case .mediaPlayback:
            configureForMediaPlayback()
        case .incomingCall:
            // Don't configure yet - wait for CallKit
            break
        case .activeCall:
            configureForActiveCall()
        case .callEnding:
            // Handled by CallKit deactivation callback
            break
        }
        
        debugPrint("AudioSession: \(previousContext) → \(newContext)")
    }
    
    private func configureForActiveCall() {
        // Single source of truth for call audio config
    }
    
    private func configureForMediaPlayback() {
        // Single source of truth for media playback config
    }
}
```

### Android Audio Manager Enhancement

```kotlin
class AudioDeviceManager(private val context: Context) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var isBluetoothScoStarted = false
    private var hasAudioFocus = false
    
    fun configureForVoIPCall(): Boolean {
        // Request audio focus
        val result = audioManager.requestAudioFocus(
            focusChangeListener,
            AudioManager.STREAM_VOICE_CALL,
            AudioManager.AUDIOFOCUS_GAIN
        )
        hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        
        if (hasAudioFocus) {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        }
        
        return hasAudioFocus
    }
    
    fun releaseVoIPCall() {
        if (isBluetoothScoStarted) {
            audioManager.stopBluetoothSco()
            isBluetoothScoStarted = false
        }
        
        audioManager.mode = AudioManager.MODE_NORMAL
        
        if (hasAudioFocus) {
            audioManager.abandonAudioFocus(focusChangeListener)
            hasAudioFocus = false
        }
    }
}
```

---

*This document should be reviewed with the team and updated as fixes are implemented.*

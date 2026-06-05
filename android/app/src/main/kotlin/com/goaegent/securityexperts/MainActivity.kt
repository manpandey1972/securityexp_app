package com.goaegent.securityexperts

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterFragmentActivity() {
    private val TAG = "SecurityExpertsAudio"
    private val AUDIO_CHANNEL = "com.goaegent.securityexperts.call/audio"
    private val EVENT_CHANNEL = "com.goaegent.securityexperts.call/audioDeviceEvents"
    private val OAUTH_CHANNEL = "com.goaegent.securityexperts/oauth"
    
    private lateinit var audioManager: AudioManager
    private var audioDeviceChangeListener: AudioDeviceChangeListener? = null
    
    // Audio focus management
    private var hasAudioFocus = false
    private var audioFocusRequest: AudioFocusRequest? = null
    
    // Bluetooth SCO lifecycle tracking
    private var isBluetoothScoStarted = false
    
    // VoIP call state tracking
    private var isInVoIPCall = false

    // Back-gesture interception state for active calls.
    //
    // Why this exists:
    //   On Android 14+ with predictive back, the system asks Flutter
    //   whether it handles back. Flutter's embedding only claims back
    //   handling when the root Navigator can pop. When the user is on
    //   the home page with an active call overlaid (CallOverlay sits in
    //   MaterialApp.builder, outside Navigator), the Navigator's
    //   `canPop` is false, so the system finishes the Activity directly,
    //   FlutterJNI detaches, and any in-flight RTCVideoView frame
    //   crashes the process with:
    //     "Cannot execute operation because FlutterJNI is not attached
    //      to native"
    //
    //   We register an OnBackInvokedCallback at PRIORITY_OVERLAY (above
    //   Flutter's default) only while a call is active. When fired we
    //   notify Dart via the same MethodChannel so it can minimise the
    //   call UI; the gesture is consumed natively so the Activity is
    //   never finished.
    private var callBackGestureChannel: MethodChannel? = null
    private var callBackInvokedCallback: OnBackInvokedCallback? = null
    private var isCallActiveForBack = false

    // Audio focus change listener
    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                Log.d(TAG, "Audio focus lost permanently")
                hasAudioFocus = false
                // Permanent loss - another app took focus
                // Consider pausing/muting in Flutter via event channel
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                Log.d(TAG, "Audio focus lost transiently")
                // Temporary loss - pause temporarily
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                Log.d(TAG, "Audio focus lost - can duck")
                // Can lower volume temporarily
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                Log.d(TAG, "Audio focus gained")
                hasAudioFocus = true
                // Regained focus - resume full volume
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Method channel for audio device commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, methodResult ->
            when (call.method) {
                "getAvailableAudioDevices" -> {
                    methodResult.success(getAvailableAudioDevices())
                }
                "getCurrentAudioDevice" -> {
                    methodResult.success(getCurrentAudioDevice())
                }
                "setAudioDevice" -> {
                    val device = call.argument<String>("device")
                    if (device != null) {
                        try {
                            setAudioDevice(device)
                            methodResult.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error setting audio device: ${e.message}")
                            methodResult.success(null) // Silently fail, system will handle
                        }
                    } else {
                        methodResult.success(null)
                    }
                }
                "setSpeakerphoneOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    audioManager.isSpeakerphoneOn = enabled
                    methodResult.success(null)
                }
                "configureForVoIPCall" -> {
                    val success = configureForVoIPCall()
                    methodResult.success(success)
                }
                "releaseVoIPCall" -> {
                    releaseVoIPCall()
                    methodResult.success(null)
                }
                "resetAudioDevice" -> {
                    resetToDefault()
                    methodResult.success(null)
                }
                else -> methodResult.notImplemented()
            }
        }

        // Method channel for OAuth flows (e.g. Apple Sign-In Custom Tab handoff).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OAUTH_CHANNEL).setMethodCallHandler { call, methodResult ->
            when (call.method) {
                // Called from Dart immediately after signInWithProvider resolves.
                // signInWithProvider opens Apple's OAuth page in a Chrome Custom Tab
                // and Android may leave Chrome's task in front after the redirect.
                // This brings MainActivity's task back to the foreground so the app
                // appears instantly without waiting for post-auth work.
                "bringToFront" -> {
                    val intent = Intent(this, MainActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    startActivity(intent)
                    methodResult.success(null)
                }
                else -> methodResult.notImplemented()
            }
        }

        // Event channel for audio device changes
        audioDeviceChangeListener = AudioDeviceChangeListener(flutterEngine.dartExecutor.binaryMessenger)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(audioDeviceChangeListener)

        // Method channel for inspecting how MainActivity was launched. Used
        // by the Flutter side (`AndroidCallKitService._processColdStartActiveCalls`)
        // to decide whether the current process start was triggered by the
        // user tapping Accept on a `flutter_callkit_incoming` notification.
        // Without this, cold-start logic would treat any stale
        // `ACTIVE_CALLS` entry as an active accept and route the user to a
        // "joining call" screen on every normal launch.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.goaegent.securityexperts.call/launchIntent"
        ).setMethodCallHandler { call, methodResult ->
            when (call.method) {
                "wasLaunchedFromCallKit" -> {
                    val action = intent?.action ?: ""
                    val hasCallKitExtra = intent?.hasExtra("EXTRA_CALLKIT_CALL_DATA") == true
                    val fromCallKit = hasCallKitExtra ||
                        action.startsWith("com.hiennv.flutter_callkit_incoming.")
                    methodResult.success(fromCallKit)
                }
                else -> methodResult.notImplemented()
            }
        }

        // Method channel for tearing down CallKit state owned by our native
        // FCM service (GoAegentMessagingService).
        //
        // Why this exists:
        //   When the app is cold-started by an `incoming_call` FCM, our
        //   service creates its OWN `CallkitSoundPlayerManager` and
        //   `CallkitNotificationManager` instances. The plugin's accept /
        //   decline / timeout teardown path (`clearIncomingNotification`)
        //   only stops the sound player held by its own singleton — a
        //   DIFFERENT instance from ours. We can't intercept the plugin's
        //   broadcast either: `TransparentActivity` issues an EXPLICIT
        //   intent to `CallkitIncomingBroadcastReceiver::class.java`, so
        //   any manifest receiver we declare for the same action will
        //   never fire.
        //
        //   Dart is the one place that consistently sees every accept /
        //   decline / ended / timeout event (via the plugin's event
        //   channel), so it calls this method to explicitly stop our
        //   sound player and cancel the lingering incoming notification.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.goaegent.securityexperts.call/callkit"
        ).setMethodCallHandler { call, methodResult ->
            when (call.method) {
                "stopCallKit" -> {
                    val callId = call.argument<String>("callId")
                    try {
                        GoAegentMessagingService.activeSoundPlayer?.let {
                            try { it.stop() } catch (_: Throwable) {}
                        }
                        GoAegentMessagingService.activeSoundPlayer = null
                        if (!callId.isNullOrEmpty()) {
                            // Mirrors the notification id used by the plugin
                            // (`CallkitNotificationManager.getIncomingNotification`:
                            // `data.getString(EXTRA_CALLKIT_ID).hashCode()`).
                            val notificationId = callId.hashCode()
                            NotificationManagerCompat.from(applicationContext)
                                .cancel(notificationId)
                        }
                        methodResult.success(true)
                    } catch (t: Throwable) {
                        Log.w(TAG, "stopCallKit failed", t)
                        methodResult.success(false)
                    }
                }
                else -> methodResult.notImplemented()
            }
        }

        // Method channel for intercepting the Android system back gesture
        // while a call is active. See the field comment above
        // `callBackGestureChannel` for the full rationale.
        callBackGestureChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.goaegent.securityexperts.call/backgesture"
        )
        callBackGestureChannel!!.setMethodCallHandler { call, methodResult ->
            when (call.method) {
                "setCallActive" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    setCallBackInterception(active)
                    methodResult.success(null)
                }
                else -> methodResult.notImplemented()
            }
        }
    }

    /**
     * Enable or disable native interception of the Android system back
     * gesture while a call is active. When enabled, the back gesture is
     * consumed by [callBackInvokedCallback] and forwarded to Dart via
     * `com.goaegent.securityexperts.call/backgesture#onBackInvoked` so the call UI can
     * minimise without the Activity being finished.
     */
    private fun setCallBackInterception(active: Boolean) {
        isCallActiveForBack = active
        Log.d(TAG, "setCallBackInterception(active=$active)")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerOrUnregisterBackCallback(active)
        }
        // For API < 33 the legacy `onBackPressed()` override below handles it.
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun registerOrUnregisterBackCallback(active: Boolean) {
        val dispatcher = onBackInvokedDispatcher
        if (active) {
            if (callBackInvokedCallback == null) {
                callBackInvokedCallback = OnBackInvokedCallback {
                    Log.d(TAG, "OnBackInvokedCallback fired → notifying Dart")
                    callBackGestureChannel?.invokeMethod("onBackInvoked", null)
                }
            }
            // Re-register to make sure we sit at PRIORITY_OVERLAY above
            // Flutter's default callback. Unregister first to avoid stacking.
            callBackInvokedCallback?.let {
                runCatching { dispatcher.unregisterOnBackInvokedCallback(it) }
                dispatcher.registerOnBackInvokedCallback(
                    OnBackInvokedDispatcher.PRIORITY_OVERLAY,
                    it
                )
            }
        } else {
            callBackInvokedCallback?.let {
                runCatching { dispatcher.unregisterOnBackInvokedCallback(it) }
            }
        }
    }

    @Deprecated("Pre-Android 13 legacy back handling")
    override fun onBackPressed() {
        // For API < 33, the predictive-back framework is not used; the
        // system delivers KEYCODE_BACK to the Activity. Intercept it here
        // when a call is active and forward to Dart.
        if (isCallActiveForBack &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
        ) {
            Log.d(TAG, "onBackPressed intercepted (legacy) → notifying Dart")
            callBackGestureChannel?.invokeMethod("onBackInvoked", null)
            return
        }
        @Suppress("DEPRECATION")
        super.onBackPressed()
    }

    /**
     * Configure audio for VoIP call
     * Sets MODE_IN_COMMUNICATION and requests audio focus
     */
    private fun configureForVoIPCall(): Boolean {
        Log.d(TAG, "Configuring for VoIP call")
        
        // Set audio mode for VoIP
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        isInVoIPCall = true
        
        // Request audio focus
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setOnAudioFocusChangeListener(audioFocusChangeListener, Handler(Looper.getMainLooper()))
                .setAcceptsDelayedFocusGain(true)
                .build()
            
            audioManager.requestAudioFocus(audioFocusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
        
        hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        Log.d(TAG, "Audio focus request result: $result, granted: $hasAudioFocus")
        
        return hasAudioFocus
    }

    /**
     * Release VoIP call audio configuration
     * Stops Bluetooth SCO / clears communication device, resets mode, and abandons audio focus
     */
    private fun releaseVoIPCall() {
        Log.d(TAG, "Releasing VoIP call audio")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        } else {
            // Stop Bluetooth SCO if it was started (legacy path)
            if (isBluetoothScoStarted) {
                Log.d(TAG, "Stopping Bluetooth SCO")
                @Suppress("DEPRECATION")
                audioManager.stopBluetoothSco()
                isBluetoothScoStarted = false
            }
        }
        
        // Reset audio mode
        audioManager.mode = AudioManager.MODE_NORMAL
        isInVoIPCall = false
        
        // Abandon audio focus
        if (hasAudioFocus) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { request ->
                    audioManager.abandonAudioFocusRequest(request)
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(audioFocusChangeListener)
            }
            hasAudioFocus = false
        }
        
        Log.d(TAG, "VoIP call audio released")
    }

    private fun getAvailableAudioDevices(): List<String> {
        val devices = mutableListOf<String>()
        devices.add("speaker")
        devices.add("earpiece")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // API 31+: Use communication device APIs designed specifically for VoIP.
            // These correctly enumerate car Bluetooth (HFP/SCO) even before SCO is started.
            val commDevices = audioManager.availableCommunicationDevices
            Log.d(TAG, "Available communication devices (API31+): ${commDevices.map { it.type }}")
            for (device in commDevices) {
                when (device.type) {
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER ->
                        if (!devices.contains("speaker")) devices.add("speaker")
                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE ->
                        if (!devices.contains("earpiece")) devices.add("earpiece")
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_BLE_HEADSET ->
                        if (!devices.contains("bluetooth")) devices.add("bluetooth")
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_USB_HEADSET ->
                        if (!devices.contains("headset")) devices.add("headset")
                }
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Check both inputs and outputs — Bluetooth SCO (HFP/car) may only
            // appear in inputs before the SCO audio channel is established.
            val audioDevices = audioManager.getDevices(
                AudioManager.GET_DEVICES_OUTPUTS or AudioManager.GET_DEVICES_INPUTS
            )
            for (device in audioDevices) {
                when (device.type) {
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO ->
                        if (!devices.contains("bluetooth")) devices.add("bluetooth")
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET ->
                        if (!devices.contains("headset")) devices.add("headset")
                }
            }
        } else {
            @Suppress("DEPRECATION")
            if (audioManager.isBluetoothScoOn || audioManager.isBluetoothA2dpOn) devices.add("bluetooth")
            @Suppress("DEPRECATION")
            if (audioManager.isWiredHeadsetOn) devices.add("headset")
        }

        return devices
    }

    /**
     * Set audio device with proper Bluetooth lifecycle management.
     * Uses setCommunicationDevice() on API 31+ (designed for VoIP),
     * falls back to startBluetoothSco() on older Android.
     */
    private fun setAudioDevice(device: String) {
        Log.d(TAG, "Setting audio device: $device")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            when (device.lowercase()) {
                "bluetooth" -> {
                    val btDevice = audioManager.availableCommunicationDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        it.type == AudioDeviceInfo.TYPE_BLE_HEADSET
                    }
                    if (btDevice != null) {
                        val success = audioManager.setCommunicationDevice(btDevice)
                        Log.d(TAG, "setCommunicationDevice(bluetooth) success=$success, type=${btDevice.type}")
                    } else {
                        Log.w(TAG, "No Bluetooth SCO device available for setCommunicationDevice")
                    }
                }
                "speaker" -> {
                    val speakerDevice = audioManager.availableCommunicationDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    }
                    if (speakerDevice != null) {
                        audioManager.setCommunicationDevice(speakerDevice)
                    } else {
                        audioManager.clearCommunicationDevice()
                        @Suppress("DEPRECATION")
                        audioManager.isSpeakerphoneOn = true
                    }
                    Log.d(TAG, "Audio set to speaker")
                }
                "headset", "earpiece" -> {
                    // Clear any override — system will route to the best wired/earpiece device
                    audioManager.clearCommunicationDevice()
                    Log.d(TAG, "Audio set to $device (cleared communication device)")
                }
            }
            isBluetoothScoStarted = false // not used in API 31+ path
        } else {
            // Legacy path for API < 31
            if (isBluetoothScoStarted && device.lowercase() != "bluetooth") {
                Log.d(TAG, "Stopping Bluetooth SCO before switching to $device")
                @Suppress("DEPRECATION")
                audioManager.stopBluetoothSco()
                isBluetoothScoStarted = false
            }
            when (device.lowercase()) {
                "speaker" -> {
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = true
                    Log.d(TAG, "Audio set to speaker")
                }
                "headset", "earpiece" -> {
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = false
                    Log.d(TAG, "Audio set to $device")
                }
                "bluetooth" -> {
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = false
                    if (!isBluetoothScoStarted) {
                        Log.d(TAG, "Starting Bluetooth SCO")
                        @Suppress("DEPRECATION")
                        audioManager.startBluetoothSco()
                        isBluetoothScoStarted = true
                    }
                }
            }
        }
    }

    /**
     * Reset audio to system default
     */
    private fun resetToDefault() {
        Log.d(TAG, "Resetting audio to default")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        } else {
            if (isBluetoothScoStarted) {
                @Suppress("DEPRECATION")
                audioManager.stopBluetoothSco()
                isBluetoothScoStarted = false
            }
            @Suppress("DEPRECATION")
            audioManager.isSpeakerphoneOn = false
        }
    }

    private fun getCurrentAudioDevice(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val device = audioManager.communicationDevice ?: return "earpiece"
            return when (device.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_BLE_HEADSET -> "bluetooth"
                AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_USB_HEADSET -> "headset"
                else -> "earpiece"
            }
        }
        @Suppress("DEPRECATION")
        return when {
            audioManager.isSpeakerphoneOn -> "speaker"
            audioManager.isBluetoothScoOn || audioManager.isBluetoothA2dpOn -> "bluetooth"
            audioManager.isWiredHeadsetOn -> "headset"
            else -> "earpiece"
        }
    }

    override fun onDestroy() {
        // Clean up back-gesture callback so we don't leak it across
        // Activity recreation.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            callBackInvokedCallback?.let {
                runCatching { onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it) }
            }
        }
        callBackInvokedCallback = null
        callBackGestureChannel?.setMethodCallHandler(null)
        callBackGestureChannel = null

        super.onDestroy()
        // Clean up audio resources
        releaseVoIPCall()
    }

    private inner class AudioDeviceChangeListener(
        private val binaryMessenger: io.flutter.plugin.common.BinaryMessenger
    ) : EventChannel.StreamHandler {

        private var eventSink: EventChannel.EventSink? = null
        
        @RequiresApi(Build.VERSION_CODES.M)
        private val audioDeviceCallback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
                Log.d(TAG, "Audio devices added: ${addedDevices?.size ?: 0}")
                val currentDevice = getCurrentAudioDevice()
                eventSink?.success(currentDevice)
            }
            
            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                Log.d(TAG, "Audio devices removed: ${removedDevices?.size ?: 0}")
                val currentDevice = getCurrentAudioDevice()
                eventSink?.success(currentDevice)
            }
        }

        // API 31+: OnCommunicationDeviceChangedListener fires whenever the active
        // communication device changes (Bluetooth connects/disconnects, user switches, etc.).
        // This is far more reliable for VoIP than AudioDeviceCallback.
        private val communicationDeviceChangedListener =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                AudioManager.OnCommunicationDeviceChangedListener { device ->
                    val type = device?.type ?: return@OnCommunicationDeviceChangedListener
                    Log.d(TAG, "Communication device changed: type=$type")
                    val deviceStr = when (type) {
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                        AudioDeviceInfo.TYPE_BLE_HEADSET -> "bluetooth"
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
                        AudioDeviceInfo.TYPE_WIRED_HEADSET,
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                        AudioDeviceInfo.TYPE_USB_HEADSET -> "headset"
                        else -> "earpiece"
                    }
                    eventSink?.success(deviceStr)
                }
            } else null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            // Send current device immediately
            events?.success(getCurrentAudioDevice())

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                communicationDeviceChangedListener?.let {
                    audioManager.addOnCommunicationDeviceChangedListener(mainExecutor, it)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audioManager.registerAudioDeviceCallback(audioDeviceCallback, null)
            }
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                communicationDeviceChangedListener?.let {
                    audioManager.removeOnCommunicationDeviceChangedListener(it)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audioManager.unregisterAudioDeviceCallback(audioDeviceCallback)
            }
        }
    }
}

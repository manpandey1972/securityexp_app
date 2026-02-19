package com.example.securityexperts_app

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val TAG = "GreenHiveAudio"
    private val AUDIO_CHANNEL = "com.greenhive.call/audio"
    private val EVENT_CHANNEL = "com.greenhive.call/audioDeviceEvents"
    
    private lateinit var audioManager: AudioManager
    private var audioDeviceChangeListener: AudioDeviceChangeListener? = null
    
    // Audio focus management
    private var hasAudioFocus = false
    private var audioFocusRequest: AudioFocusRequest? = null
    
    // Bluetooth SCO lifecycle tracking
    private var isBluetoothScoStarted = false
    
    // VoIP call state tracking
    private var isInVoIPCall = false

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

        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

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

        // Event channel for audio device changes
        audioDeviceChangeListener = AudioDeviceChangeListener(flutterEngine.dartExecutor.binaryMessenger)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(audioDeviceChangeListener)
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
     * Stops Bluetooth SCO, resets mode, and abandons audio focus
     */
    private fun releaseVoIPCall() {
        Log.d(TAG, "Releasing VoIP call audio")
        
        // Stop Bluetooth SCO if it was started
        if (isBluetoothScoStarted) {
            Log.d(TAG, "Stopping Bluetooth SCO")
            audioManager.stopBluetoothSco()
            isBluetoothScoStarted = false
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
        devices.add("speaker") // Speaker always available

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val audioDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in audioDevices) {
                when (device.type) {
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> if (!devices.contains("speaker")) devices.add("speaker")
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> if (!devices.contains("bluetooth")) devices.add("bluetooth")
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> if (!devices.contains("headset")) devices.add("headset")
                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> if (!devices.contains("earpiece")) devices.add("earpiece")
                }
            }
        } else {
            // Fallback for older Android versions
            if (audioManager.isBluetoothScoOn || audioManager.isBluetoothA2dpOn) {
                devices.add("bluetooth")
            }
            if (audioManager.isWiredHeadsetOn) {
                devices.add("headset")
            }
        }

        return devices
    }

    /**
     * Set audio device with proper Bluetooth SCO lifecycle management
     */
    private fun setAudioDevice(device: String) {
        Log.d(TAG, "Setting audio device: $device (SCO active: $isBluetoothScoStarted)")
        
        // Stop Bluetooth SCO if switching away from Bluetooth
        if (isBluetoothScoStarted && device.lowercase() != "bluetooth") {
            Log.d(TAG, "Stopping Bluetooth SCO before switching to $device")
            audioManager.stopBluetoothSco()
            isBluetoothScoStarted = false
        }
        
        when (device.lowercase()) {
            "speaker" -> {
                audioManager.isSpeakerphoneOn = true
                Log.d(TAG, "Audio set to speaker")
            }
            "headset", "earpiece" -> {
                audioManager.isSpeakerphoneOn = false
                Log.d(TAG, "Audio set to $device")
            }
            "bluetooth" -> {
                audioManager.isSpeakerphoneOn = false
                if (!isBluetoothScoStarted) {
                    Log.d(TAG, "Starting Bluetooth SCO")
                    audioManager.startBluetoothSco()
                    isBluetoothScoStarted = true
                }
            }
        }
    }

    /**
     * Reset audio to system default
     */
    private fun resetToDefault() {
        Log.d(TAG, "Resetting audio to default")
        
        // Stop SCO if active
        if (isBluetoothScoStarted) {
            audioManager.stopBluetoothSco()
            isBluetoothScoStarted = false
        }
        
        audioManager.isSpeakerphoneOn = false
    }

    private fun getCurrentAudioDevice(): String {
        return when {
            audioManager.isSpeakerphoneOn -> "speaker"
            audioManager.isBluetoothScoOn || audioManager.isBluetoothA2dpOn -> "bluetooth"
            audioManager.isWiredHeadsetOn -> "headset"
            else -> "earpiece"
        }
    }

    override fun onDestroy() {
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

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            // Send current device immediately
            events?.success(getCurrentAudioDevice())

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audioManager.registerAudioDeviceCallback(audioDeviceCallback, null)
            }
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audioManager.unregisterAudioDeviceCallback(audioDeviceCallback)
            }
        }
    }
}

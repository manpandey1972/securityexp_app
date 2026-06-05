package com.goaegent.securityexperts

import android.app.ActivityManager
import android.content.Context
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.hiennv.flutter_callkit_incoming.CallkitNotificationManager
import com.hiennv.flutter_callkit_incoming.CallkitSoundPlayerManager
import com.hiennv.flutter_callkit_incoming.Data
import com.hiennv.flutter_callkit_incoming.addCall

/**
 * Native FCM handler responsible for showing the incoming-call CallKit UI
 * when the app is in the background or killed.
 *
 * Behaviour (Android only — iOS uses VoIP push, untouched):
 *
 *   • `type == "incoming_call"` AND app in foreground:
 *       → no-op. The firebase_messaging plugin's c2dm receiver still
 *         delivers the message to Dart `onMessage`, which renders the
 *         in-app banner.
 *   • `type == "incoming_call"` AND app in background/killed:
 *       → directly build a `CallkitNotificationManager` (NOT via the plugin
 *         singleton — that singleton is only initialized after Flutter
 *         starts, so on a cold start from a killed app it is null and the
 *         plugin's own broadcast pathway silently no-ops) and call
 *         `showIncomingNotification` + `addCall` ourselves. This is the
 *         critical path that previously failed: the broadcast was fired
 *         but the receiver did nothing because the manager was null.
 *   • any other message:
 *       → no-op. The plugin's c2dm receiver handles all normal delivery
 *         (Dart `onMessage` / `onBackgroundMessage`).
 *
 * The Dart `_handleBackgroundMessage` skips its own `showCallkitIncoming`
 * for Android `incoming_call` — this service is the sole authority.
 */
class GoAegentMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "GoAegentMsgService"

        /**
         * Sound player created by this service's CallKit dispatch.
         *
         * We need to keep a reference because the plugin's accept / decline /
         * end teardown stops the ringtone via
         * `FlutterCallkitIncomingPlugin.getInstance()?.getCallkitNotificationManager()?.callkitSoundPlayerManager`
         * — but on a cold start (app killed) that singleton is null OR holds
         * a DIFFERENT `CallkitSoundPlayerManager` instance from the one we
         * created here. We also can't intercept the plugin's own broadcast:
         * `TransparentActivity` issues an EXPLICIT intent at
         * `CallkitIncomingBroadcastReceiver::class.java`, so a manifest
         * receiver of our own can never fire for those actions.
         *
         * Instead, [MainActivity]'s `com.goaegent.securityexperts.call/callkit` MethodChannel
         * exposes `stopCallKit(callId)` which Dart calls on every accept /
         * decline / ended / timeout event. That handler reads this field and
         * stops the player.
         */
        @JvmStatic
        @Volatile
        var activeSoundPlayer: CallkitSoundPlayerManager? = null
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        if (data["type"] != "incoming_call") return

        if (isAppForeground()) {
            Log.d(TAG, "incoming_call in foreground — letting plugin route to Dart banner")
            return
        }

        try {
            dispatchCallKit(data)
        } catch (t: Throwable) {
            Log.e(TAG, "Native CallKit dispatch failed", t)
        }
    }

    private fun dispatchCallKit(data: Map<String, String>) {
        // Match the field-precedence used by the previous Dart implementation
        // (`_showAndroidCallKitFromFcm`): roomName → room_id → callId. This
        // matters because the Flutter side (peekActiveCallIds, the
        // `_callsHandledByCallKit` tracker, and the cold-start retry loop)
        // looks up calls by this id. If we stored `callId` instead, the
        // Firestore listener would not find a match and the in-app banner
        // would race against the synthesized answerCall.
        val callId = data["roomName"]
            ?: data["room_id"]
            ?: data["roomId"]
            ?: data["callId"]
            ?: run {
                Log.w(TAG, "incoming_call missing roomName/callId — abort")
                return
            }
        val callerName = data["callerName"] ?: data["caller_name"] ?: "Incoming call"
        val callerId = data["callerId"] ?: data["caller_id"] ?: ""
        val avatar = data["callerAvatar"] ?: data["caller_avatar"] ?: ""
        val isVideo = (data["hasVideo"] ?: data["is_video"] ?: "false")
            .equals("true", ignoreCase = true)

        // Build the plugin's Data via its Map constructor — keys match what
        // CallKitParams.toJson() produces on the Dart side, so the resulting
        // bundle is identical to what the plugin would build itself.
        val args = mutableMapOf<String, Any?>(
            "id" to callId,
            "nameCaller" to callerName,
            "appName" to "GoAegent",
            "handle" to (callerId.ifEmpty { callerName }),
            "avatar" to avatar,
            "type" to if (isVideo) 1 else 0,
            "duration" to 45_000L,
            "textAccept" to "Accept",
            "textDecline" to "Decline",
            "isCustomNotification" to true,
            "isShowLogo" to false,
            "ringtonePath" to "system_ringtone_default",
            "backgroundColor" to "#0955fa",
            "actionColor" to "#4CAF50",
            "textColor" to "#ffffff",
            "incomingCallNotificationChannelName" to "Incoming Calls",
            "missedCallNotificationChannelName" to "Missed Calls",
            "isShowCallID" to false,
            "extra" to HashMap<String, Any?>().apply {
                // Mirror Dart's previous `_showAndroidCallKitFromFcm` extras
                // so the downstream `acceptCallFromCallKit` consumer sees
                // identical keys regardless of which path created the call.
                put("call_id", callId)
                put("caller_id", callerId)
                put("caller_name", callerName)
                put("room_id", callId)
                put("is_video", isVideo)
            },
        )

        val callData = Data(args)
        val bundle = callData.toBundle()

        val ctx = applicationContext

        // Direct render — no broadcast, no plugin singleton needed. This is
        // the difference vs. the previous attempt where we broadcast to the
        // plugin's receiver: that receiver fetches the notification manager
        // from the plugin singleton, which is null in a cold-start FCM
        // service process.
        val soundManager = CallkitSoundPlayerManager(ctx)
        val notifManager = CallkitNotificationManager(ctx, soundManager)

        // Stash the sound player so CallKitSoundStopReceiver can stop it
        // when the user taps Accept / Decline / when the ring times out.
        // The plugin's broadcast receiver would normally stop the ringtone
        // itself via the FlutterCallkitIncomingPlugin singleton, but on a
        // cold start that singleton is null and our instance would keep
        // ringing forever (until the process is killed).
        activeSoundPlayer?.let {
            try { it.stop() } catch (_: Throwable) {}
        }
        activeSoundPlayer = soundManager

        // Persist the call to SharedPreferences so the Flutter side's
        // cold-start retry loop (`_processColdStartActiveCalls` /
        // `peekActiveCallIds`) can discover and process it after launch.
        addCall(ctx, callData, false)

        // Stash a copy under our own key. If the user taps Decline while
        // Flutter is still dead, the plugin's `removeCall` will wipe its
        // own ACTIVE_CALLS entry and the decline broadcast will be
        // dropped (no engine to dispatch it). [GoAegentApplication]
        // then reads this stash and promotes the entry to a pending
        // decline that Dart drains and rejects server-side on next
        // startup.
        PendingCallKitStore.saveIncoming(
            ctx,
            callId,
            mapOf(
                "call_id" to callId,
                "room_id" to callId,
                "caller_id" to callerId,
                "caller_name" to callerName,
                "is_video" to isVideo,
            ),
        )

        Log.d(TAG, "Showing CallKit notification: callId=$callId video=$isVideo")
        notifManager.showIncomingNotification(bundle)
    }

    private fun isAppForeground(): Boolean {
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return false
            val processes = am.runningAppProcesses ?: return false
            val myPkg = packageName
            processes.any {
                it.processName == myPkg &&
                    it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
            }
        } catch (t: Throwable) {
            Log.w(TAG, "isAppForeground check failed; assuming background", t)
            false
        }
    }
}

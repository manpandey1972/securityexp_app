package com.goaegent.securityexperts

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.app.FlutterApplication
import org.json.JSONArray
import org.json.JSONObject

/**
 * Custom [FlutterApplication] used as `android:name` in the manifest.
 *
 * Why it exists:
 *   On a cold start from FCM, the `flutter_callkit_incoming` plugin renders
 *   the incoming-call UI (full-screen ringing activity AND a heads-up
 *   banner with Accept/Decline action buttons). Both Accept and Decline,
 *   from either surface, route through the plugin's
 *   `CallkitIncomingBroadcastReceiver`. On cold start that receiver's
 *   `callkitNotificationManager` reference is null (it comes from the
 *   Flutter-side plugin singleton which hasn't initialized), so:
 *     • `clearIncomingNotification` is a no-op → ringer keeps playing,
 *       notification can linger.
 *     • `sendEventFlutter(actionCallDecline)` is a no-op → backend
 *       `rejectCall` Cloud Function is never invoked → caller waits
 *       the full server ring timeout (~30s).
 *
 *   The plugin's broadcasts use EXPLICIT intents targeting
 *   `CallkitIncomingBroadcastReceiver::class.java`, so we cannot
 *   intercept them with a sibling manifest receiver. And the heads-up
 *   banner Decline never opens any Activity in our process, so
 *   `ActivityLifecycleCallbacks` cannot observe it.
 *
 *   What we CAN observe is the plugin's own SharedPreferences. Every
 *   accept / decline / timeout / ended path goes through `addCall(...)`
 *   or `removeCall(...)` in the plugin's `SharedPreferencesUtils.kt`,
 *   which `commit()`s to the file `flutter_callkit_incoming` under the
 *   key `ACTIVE_CALLS`. That file is in our app's data dir, so a
 *   [SharedPreferences.OnSharedPreferenceChangeListener] registered
 *   here fires synchronously inside the plugin's `commit()` — same
 *   process, same JVM, no IPC race.
 *
 *   Transitions of interest:
 *     • `id` disappears from ACTIVE_CALLS → terminal (decline / timeout
 *       / ended). We stop the ringer, dismiss the notification, and on
 *       cold start enqueue [RejectCallWorker] to call the backend
 *       directly (NO Flutter wakeup required — the worker uses
 *       Firebase Auth's persisted token to authenticate the callable).
 *     • `id` stays in ACTIVE_CALLS but `isAccepted` flips false → true
 *       → user accepted. Stop ringer + notification. (Dart's cold-start
 *       synth path picks up the answer when the app finishes starting.)
 */
class GoAegentApplication : FlutterApplication() {

    companion object {
        private const val TAG = "GreenHiveApp"

        // Plugin's SharedPreferences file + key — must match the
        // hardcoded values in the plugin's SharedPreferencesUtils.kt.
        private const val CALLKIT_PREFS_FILE = "flutter_callkit_incoming"
        private const val ACTIVE_CALLS_KEY = "ACTIVE_CALLS"
    }

    /**
     * Last-known snapshot of the plugin's ACTIVE_CALLS, as
     * `id → isAccepted`. Used to detect transitions on each listener fire.
     */
    @Volatile
    private var lastActive: Map<String, Boolean> = emptyMap()

    /**
     * Strong reference to the listener — SharedPreferences holds the
     * listener via a WeakReference, so without this field it would be
     * garbage-collected mid-call and silently stop firing.
     */
    private lateinit var activeCallsListener:
        SharedPreferences.OnSharedPreferenceChangeListener

    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var callkitPrefs: SharedPreferences

    private val periodicReconcile = object : Runnable {
        override fun run() {
            try {
                reconcileActiveCalls("poll")
            } catch (t: Throwable) {
                Log.w(TAG, "Periodic reconcile failed", t)
            } finally {
                mainHandler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            installActiveCallsListener()
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to install ACTIVE_CALLS listener", t)
        }
    }

    private fun installActiveCallsListener() {
        val prefs = applicationContext.getSharedPreferences(
            CALLKIT_PREFS_FILE,
            Context.MODE_PRIVATE,
        )
        callkitPrefs = prefs
        // Seed the snapshot so the first real change is diffed against
        // the actual current state (e.g. process started while a call
        // was already ringing).
        val initialState = prefs.getString(ACTIVE_CALLS_KEY, null)
        lastActive = parseActiveCalls(initialState)

        activeCallsListener = SharedPreferences.OnSharedPreferenceChangeListener { p, key ->
            if (key != ACTIVE_CALLS_KEY) return@OnSharedPreferenceChangeListener
            val rawNew = p.getString(ACTIVE_CALLS_KEY, null)
            val newSnapshot = parseActiveCalls(rawNew)
            val previous = lastActive
            lastActive = newSnapshot

            // Dispatch work to the main thread so notification /
            // activity-launch APIs run on a well-defined looper. The
            // listener itself can fire on any thread.
            mainHandler.post {
                try {
                    handleTransition(previous, newSnapshot)
                } catch (t: Throwable) {
                    Log.e(TAG, "handleTransition failed", t)
                }
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(activeCallsListener)
        mainHandler.removeCallbacks(periodicReconcile)
        mainHandler.postDelayed(periodicReconcile, 1000L)
    }

    /**
     * Fallback path in case the SharedPreferences listener misses a callback.
     * This keeps repeated incoming-call cycles reliable in long-lived processes.
     */
    private fun reconcileActiveCalls(source: String) {
        val raw = callkitPrefs.getString(ACTIVE_CALLS_KEY, null)
        val current = parseActiveCalls(raw)
        val previous = lastActive
        if (current == previous) return

        lastActive = current
        Log.d(TAG, "Reconciled ACTIVE_CALLS from $source: previous=$previous current=$current")
        handleTransition(previous, current)
    }

    /**
     * Compute the diff between [previous] and [current] and react to each
     * relevant transition.
     */
    private fun handleTransition(
        previous: Map<String, Boolean>,
        current: Map<String, Boolean>,
    ) {
        // 1. Removed ids → terminal (decline / timeout / ended).
        val removed = previous.keys - current.keys
        for (callId in removed) {
            Log.d(TAG, "ACTIVE_CALLS removal detected for $callId")
            onCallRemoved(callId)
        }

        // 2. Ids that flipped from isAccepted=false → true (accept tap).
        for ((callId, accepted) in current) {
            val wasAccepted = previous[callId] == true
            if (accepted && !wasAccepted) {
                Log.d(TAG, "ACTIVE_CALLS accept detected for $callId")
                onCallAccepted(callId)
            }
        }
    }

    /**
     * Called when an id leaves ACTIVE_CALLS. Stops the ringer, dismisses
     * the heads-up notification, and on cold start fires a native
     * `rejectCall` via [RejectCallWorker] so the caller drops out of
     * "connecting…" within a couple of seconds rather than waiting for
     * server-side ring timeout.
     */
    private fun onCallRemoved(callId: String) {
        stopRingerAndNotification(callId)

        try {
            val roomId = resolveRoomId(callId)
            if (roomId.isBlank()) {
                Log.w(TAG, "No room_id resolvable for $callId — skipping reject")
                return
            }
            // Inline best-effort reject. Runs on a background thread held
            // alive by a partial wakelock so the FCM service process can't
            // die before the HTTP call completes. The broadcast receiver
            // that triggered this listener has a ~10s window, which is
            // typically plenty for the network round trip.
            InlineRejectDispatcher.dispatch(applicationContext, roomId)

            // Belt-and-braces: also enqueue the WorkManager-backed worker
            // so a retry happens if the inline attempt was killed mid-flight
            // or hit a transient network error. Server is idempotent.
            RejectCallWorker.enqueue(applicationContext, roomId)
        } catch (t: Throwable) {
            Log.w(TAG, "onCallRemoved for $callId failed", t)
        }
    }

    /**
     * Look up the `room_id` for a callId we just saw vanish from
     * ACTIVE_CALLS. Falls back to the callId itself if no stash exists
     * (our FCM dispatch always saves both, so a missing stash means
     * the call came in through a path we don't own — e.g. plugin's
     * own showCallkitIncoming from Dart in a previous foreground
     * session — in which case the callId IS the room id).
     */
    private fun resolveRoomId(callId: String): String {
        val stashed: JSONObject? = try {
            PendingCallKitStore.getIncoming(applicationContext, callId)
        } catch (_: Throwable) {
            null
        }
        val fromStash = stashed?.optString("room_id", "")?.takeIf { it.isNotBlank() }
        return fromStash ?: callId
    }

    /**
     * Called when isAccepted flips to true for an id that is still in
     * ACTIVE_CALLS. The plugin's TransparentActivity / Dart side picks
     * up the answer; we just need to stop our native ringer and dismiss
     * any leftover incoming notification. We clear our stash here too —
     * Dart's cold-start synth path handles the answer side.
     */
    private fun onCallAccepted(callId: String) {
        stopRingerAndNotification(callId)
        try {
            PendingCallKitStore.clearIncoming(applicationContext, callId)
        } catch (t: Throwable) {
            Log.w(TAG, "Clearing stash on accept of $callId failed", t)
        }
    }

    /**
     * Stop the in-process ringer and cancel the incoming-call
     * notification.
     *
     * Why both `stop()` AND `destroy()`:
     *   The plugin's `CallkitSoundPlayerManager.stop()` calls
     *   `ringtone?.stop()` and nulls out the field. `destroy()` does
     *   the same plus unregisters its screen-off receiver. We've seen
     *   reports of the system [Ringtone] continuing to play after
     *   `stop()` on some Android 13+ devices (the Ringtone object
     *   delegates to the system AudioService, which can outlive a
     *   stop request if the call to `stop()` happened mid-`play()`).
     *   Calling both, then nulling our reference, then re-issuing
     *   `stop()` on the next main-loop tick has reliably caught these
     *   stragglers in field testing.
     *
     *   We also call [NotificationManagerCompat.cancel] explicitly
     *   even though the action button's PendingIntent triggers
     *   auto-cancel — on Android 12+ the auto-cancel path occasionally
     *   doesn't fire when the launching process was frozen at the
     *   moment of the tap.
     */
    private fun stopRingerAndNotification(callId: String) {
        Log.d(TAG, "Stopping ringer + notification for $callId")
        val player = GoAegentMessagingService.activeSoundPlayer
        try {
            player?.let {
                try { it.stop() } catch (_: Throwable) {}
                try { it.destroy() } catch (_: Throwable) {}
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Stopping sound for $callId failed", t)
        } finally {
            GoAegentMessagingService.activeSoundPlayer = null
        }
        // Belt-and-braces: re-issue stop on the next tick in case the
        // Ringtone#stop() raced its own internal play() handler.
        mainHandler.post {
            try {
                player?.stop()
            } catch (_: Throwable) {}
        }
        try {
            // Plugin uses callId.hashCode() as the incoming notification id.
            val notificationId = callId.hashCode()
            NotificationManagerCompat.from(applicationContext).cancel(notificationId)
        } catch (t: Throwable) {
            Log.w(TAG, "Cancelling notification for $callId failed", t)
        }
    }

    /**
     * Parse the plugin's ACTIVE_CALLS JSON array into `id → isAccepted`.
     * The plugin serializes its `Data` class with Jackson using
     * `@JsonProperty` keys; the fields we care about are `id` and
     * `isAccepted`. Returns empty on malformed/missing JSON.
     */
    private fun parseActiveCalls(raw: String?): Map<String, Boolean> {
        if (raw.isNullOrBlank() || raw == "[]") return emptyMap()
        return try {
            val arr = JSONArray(raw)
            val out = HashMap<String, Boolean>(arr.length())
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val id = o.optString("id", "")
                if (id.isEmpty()) continue
                out[id] = o.optBoolean("isAccepted", false)
            }
            out
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to parse ACTIVE_CALLS", t)
            emptyMap()
        }
    }
}

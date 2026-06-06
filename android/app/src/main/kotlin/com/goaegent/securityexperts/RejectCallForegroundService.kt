package com.goaegent.securityexperts

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Foreground service that calls the backend `rejectCall` Cloud Function
 * directly from the Android side. This is the **primary** native decline
 * path used on cold start.
 *
 * Why a foreground service (and not just `Thread` + wakelock, nor a
 * WorkManager expedited job):
 *
 *   • A bare `Thread` started from a `BroadcastReceiver.onReceive` lives
 *     only as long as the process. Once `onReceive` returns, Android is
 *     free to kill the process — even with a `PARTIAL_WAKE_LOCK` held —
 *     because nothing in the OOM-adjuster table is keeping the process
 *     priority elevated. We've observed the HTTP request being cut off
 *     mid-flight on cold-start declines as a result.
 *
 *   • `WorkManager` expedited workers theoretically run as foreground
 *     services via `getForegroundInfo()`, but the scheduling layer
 *     introduces tens or hundreds of milliseconds of latency on cold
 *     start, and on some OEM ROMs the foreground-service promotion is
 *     denied silently (logcat shows `FGS not allowed`), which causes
 *     the worker to fall back to deferrable execution that gets
 *     killed alongside the process.
 *
 *   • A *direct* foreground service started via
 *     `Context.startForegroundService(...)` and immediately promoted
 *     with `startForeground(...)` is the contract Android explicitly
 *     supports for "I need a few seconds to finish background work."
 *     With `FOREGROUND_SERVICE_TYPE_SHORT_SERVICE` (Android 14+), no
 *     additional permissions are required and the service may run
 *     for up to ~3 minutes. That's orders of magnitude longer than
 *     we need.
 *
 * Lifecycle:
 *   1. [GoAegentApplication]'s SharedPreferences listener (inside the
 *      plugin's broadcast receiver) calls [start] with the room id.
 *   2. The system delivers `onStartCommand` to us, with the broadcast
 *      receiver still holding the "while in onReceive" wakelock, so we
 *      always have time to call `startForeground(...)` within the
 *      mandatory ~5 s window even when the device is in Doze.
 *   3. We submit the auth + HTTP work to a worker thread and return
 *      `START_NOT_STICKY` — if the OS somehow kills the service before
 *      it finishes, the safety-net `RejectCallWorker` enqueued by the
 *      same listener will retry.
 *   4. When the worker completes (success, terminal-state failure, or
 *      timeout), we call `stopSelf(startId)`.
 *
 * Idempotency: the backend `handleRejectCall` returns
 * `failed-precondition` on a second call for the same room — we treat
 * that as success.
 */
class RejectCallForegroundService : Service() {

    companion object {
        private const val TAG = "RejectFGS"
        private const val EXTRA_ROOM_ID = "room_id"

        // Foreground notification — kept deliberately ugly so we know
        // immediately in field reports if it's been seen by a user
        // (it shouldn't be — the call ends in ~1 s).
        private const val CHANNEL_ID = "call_reject_progress"
        private const val NOTIFICATION_ID_BASE = 9100

        private const val FUNCTIONS_BASE_URL =
            "https://us-central1-securityexp-app.cloudfunctions.net"
        private const val TOKEN_TIMEOUT_MS = 4_000L
        private const val CALL_TIMEOUT_MS = 6_000L
        private const val AUTH_WAIT_TIMEOUT_MS = 4_000L
        private const val AUTH_POLL_INTERVAL_MS = 100L

        /**
         * In-flight room ids. Used to debounce duplicate starts so a
         * double-tap on Decline (or a listener + reconciliation race)
         * only fires the network call once.
         */
        private val inFlight: MutableSet<String> = ConcurrentHashMap.newKeySet()

        fun start(context: Context, roomId: String) {
            if (roomId.isBlank()) {
                Log.w(TAG, "Refusing to start with blank roomId")
                return
            }
            if (!inFlight.add(roomId)) {
                Log.d(TAG, "start($roomId): already in flight, skipping")
                return
            }
            val intent = Intent(context, RejectCallForegroundService::class.java).apply {
                putExtra(EXTRA_ROOM_ID, roomId)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.applicationContext.startForegroundService(intent)
                } else {
                    context.applicationContext.startService(intent)
                }
                Log.i(TAG, "Started RejectCallForegroundService for $roomId")
            } catch (t: Throwable) {
                // Most likely: BackgroundServiceStartNotAllowedException on
                // some OEM ROMs. The WorkManager safety-net will retry.
                Log.e(TAG, "Failed to start RejectCallForegroundService for $roomId", t)
                inFlight.remove(roomId)
            }
        }
    }

    private val worker = Executors.newSingleThreadExecutor { r ->
        Thread(r, "RejectFGS-Worker").apply { isDaemon = false }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        Log.d(TAG, "onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val roomId = intent?.getStringExtra(EXTRA_ROOM_ID).orEmpty()
        Log.d(TAG, "onStartCommand startId=$startId roomId=$roomId")

        // We MUST promote to foreground within ~5s of startForegroundService.
        // Do it immediately, even before we look at the payload, so we never
        // hit a ForegroundServiceDidNotStartInTimeException.
        promoteToForeground(roomId)

        if (roomId.isBlank()) {
            Log.w(TAG, "Empty roomId; stopping")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        worker.execute {
            try {
                runReject(roomId)
            } catch (t: Throwable) {
                Log.e(TAG, "Worker crashed for $roomId", t)
            } finally {
                inFlight.remove(roomId)
                stopSelf(startId)
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun promoteToForeground(roomId: String) {
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle("Declining call…")
            .setContentText(if (roomId.isBlank()) "" else "Room $roomId")
            .setOngoing(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // API 34+: must pass a foregroundServiceType. SHORT_SERVICE
                // does not require any permission and is appropriate for
                // a <3-minute network round trip.
                startForeground(
                    NOTIFICATION_ID_BASE,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE,
                )
            } else {
                startForeground(NOTIFICATION_ID_BASE, notification)
            }
        } catch (t: Throwable) {
            // If we can't promote, the OS will eventually kill us anyway —
            // but we still try the network call on the worker thread; it
            // may complete before that happens.
            Log.e(TAG, "startForeground failed", t)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Call control",
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "Background work for call accept/decline"
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun runReject(roomId: String) {
        Log.d(TAG, "runReject($roomId): start")
        if (!FirebaseBootstrap.ensureInitialized(applicationContext)) {
            Log.e(TAG, "runReject($roomId): could not initialize FirebaseApp — abort")
            return
        }
        val user = awaitCurrentUser()
        if (user == null) {
            Log.w(TAG, "runReject($roomId): no signed-in user after ${AUTH_WAIT_TIMEOUT_MS}ms — abort")
            return
        }
        Log.d(TAG, "runReject($roomId): auth ready uid=${user.uid}")

        val idToken: String = try {
            val task = user.getIdToken(false)
            val latch = CountDownLatch(1)
            var token: String? = null
            var error: Throwable? = null
            task.addOnSuccessListener { r -> token = r.token; latch.countDown() }
            task.addOnFailureListener { e -> error = e; latch.countDown() }
            if (!latch.await(TOKEN_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                Log.w(TAG, "runReject($roomId): ID-token fetch timed out")
                return
            }
            if (error != null) {
                Log.w(TAG, "runReject($roomId): ID-token fetch failed", error)
                return
            }
            token ?: run {
                Log.w(TAG, "runReject($roomId): ID-token was null")
                return
            }
        } catch (t: Throwable) {
            Log.w(TAG, "runReject($roomId): ID-token threw", t)
            return
        }

        val body = JSONObject()
            .put("data", JSONObject()
                .put("action", "rejectCall")
                .put("payload", JSONObject().put("room_id", roomId)))
            .toString()

        val endpoint = "$FUNCTIONS_BASE_URL/api"
        var conn: HttpURLConnection? = null
        try {
            conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = CALL_TIMEOUT_MS.toInt()
                readTimeout = CALL_TIMEOUT_MS.toInt()
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $idToken")
            }
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = conn.responseCode
            val responseBody = readStream(
                if (status in 200..299) conn.inputStream else conn.errorStream,
            )
            when {
                status in 200..299 -> {
                    Log.i(TAG, "runReject($roomId) SUCCESS status=$status body=$responseBody")
                    try {
                        PendingCallKitStore.clearIncoming(applicationContext, roomId)
                    } catch (_: Throwable) {}
                }
                status == 400 && (
                    responseBody.contains("failed-precondition", ignoreCase = true) ||
                        responseBody.contains("failed_precondition", ignoreCase = true) ||
                        responseBody.contains("already handled", ignoreCase = true)
                    ) -> {
                    // Server already handled this call (e.g. caller cancelled
                    // first, or one of the parallel reject paths won the race).
                    // Idempotent success.
                    Log.i(TAG, "runReject($roomId) already-handled (FAILED_PRECONDITION) — treating as success")
                    try {
                        PendingCallKitStore.clearIncoming(applicationContext, roomId)
                    } catch (_: Throwable) {}
                }
                else -> {
                    Log.w(TAG, "runReject($roomId) non-2xx: status=$status body=$responseBody")
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "runReject($roomId) HTTP threw", t)
        } finally {
            try { conn?.disconnect() } catch (_: Throwable) {}
        }
        Log.d(TAG, "runReject($roomId): end")
    }

    private fun readStream(stream: InputStream?): String {
        if (stream == null) return ""
        return try {
            BufferedReader(InputStreamReader(stream)).use { it.readText() }
        } catch (_: Throwable) {
            ""
        }
    }

    /**
     * Firebase Auth rehydrates `currentUser` lazily on cold start. Poll
     * briefly while we have the foreground-service priority.
     */
    private fun awaitCurrentUser(): com.google.firebase.auth.FirebaseUser? {
        val auth = FirebaseAuth.getInstance()
        val immediate = auth.currentUser
        if (immediate != null) return immediate
        val deadline = System.currentTimeMillis() + AUTH_WAIT_TIMEOUT_MS
        while (System.currentTimeMillis() < deadline) {
            try {
                Thread.sleep(AUTH_POLL_INTERVAL_MS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                return auth.currentUser
            }
            val u = auth.currentUser
            if (u != null) return u
        }
        return auth.currentUser
    }
}

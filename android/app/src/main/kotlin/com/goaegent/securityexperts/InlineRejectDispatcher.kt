package com.goaegent.securityexperts

import android.content.Context
import android.os.PowerManager
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Performs a best-effort HTTP rejectCall directly from the
 * SharedPreferences listener thread, holding a partial wakelock so
 * the FCM service process is kept alive past the broadcast
 * receiver's normal lifetime.
 *
 * Why this exists alongside [RejectCallWorker]:
 *   On a cold start, the FCM service process can be torn down
 *   moments after the plugin's broadcast receiver returns. That
 *   leaves no time for a WorkManager job to authenticate and call
 *   the backend. The inline path executes immediately, in-process,
 *   while the receiver is still alive, so the network round trip
 *   completes before the process can be killed.
 *
 *   The WorkManager backup runs in parallel; the server is
 *   idempotent so duplicate calls are harmless (returns
 *   "already handled").
 */
object InlineRejectDispatcher {

    private const val TAG = "InlineRejectDispatcher"
    private const val FUNCTIONS_BASE_URL =
        "https://us-central1-securityexp-app.cloudfunctions.net"
    private const val TOKEN_TIMEOUT_MS = 4_000L
    private const val CALL_TIMEOUT_MS = 5_000L
    private const val OVERALL_TIMEOUT_MS = 12_000L
    private const val AUTH_WAIT_TIMEOUT_MS = 4_000L
    private const val AUTH_POLL_INTERVAL_MS = 100L

    fun dispatch(context: Context, roomId: String) {
        if (roomId.isBlank()) {
            Log.w(TAG, "Refusing inline dispatch with blank roomId")
            return
        }

        // Take a wakelock now (on the caller's thread, which still has
        // the broadcast-receiver wakelock from the system) and hand it
        // to the worker. We do NOT block the caller — doing so on the
        // main thread (which is where the plugin's BroadcastReceiver
        // and our SharedPreferences listener run) causes an ANR and
        // the OS force-kills the process before the HTTP call lands.
        val appCtx = context.applicationContext
        val pm = appCtx.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = pm?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "goaegent:reject_$roomId",
        )?.apply {
            setReferenceCounted(false)
            try {
                acquire(OVERALL_TIMEOUT_MS + 2_000L)
            } catch (t: Throwable) {
                Log.w(TAG, "Wakelock acquire failed", t)
            }
        }

        Log.d(TAG, "dispatch(roomId=$roomId) — spawning worker thread")
        val thread = Thread({
            try {
                runReject(appCtx, roomId)
            } catch (t: Throwable) {
                Log.w(TAG, "Inline reject thread crashed for $roomId", t)
            } finally {
                try {
                    if (wakeLock?.isHeld == true) wakeLock.release()
                } catch (_: Throwable) {
                }
            }
        }, "InlineReject-$roomId")
        // Non-daemon so the process stays alive while the call is in flight.
        thread.isDaemon = false
        thread.start()
    }

    private fun runReject(context: Context, roomId: String) {
        if (!FirebaseBootstrap.ensureInitialized(context.applicationContext)) {
            Log.w(TAG, "Could not initialize FirebaseApp — abort inline reject for $roomId")
            return
        }
        val user = awaitCurrentUser()
        if (user == null) {
            Log.w(TAG, "No signed-in user after ${AUTH_WAIT_TIMEOUT_MS}ms — skipping inline reject for $roomId")
            return
        }
        Log.d(TAG, "Auth ready for inline reject of $roomId (uid=${user.uid})")

        val idToken: String = try {
            val task = user.getIdToken(false)
            val latch = CountDownLatch(1)
            var token: String? = null
            var error: Throwable? = null
            task.addOnSuccessListener { r ->
                token = r.token
                latch.countDown()
            }
            task.addOnFailureListener { e ->
                error = e
                latch.countDown()
            }
            if (!latch.await(TOKEN_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                Log.w(TAG, "ID-token fetch timed out for $roomId")
                return
            }
            if (error != null) {
                Log.w(TAG, "ID-token fetch failed for $roomId", error)
                return
            }
            token ?: run {
                Log.w(TAG, "ID-token was null for $roomId")
                return
            }
        } catch (t: Throwable) {
            Log.w(TAG, "ID-token retrieval threw for $roomId", t)
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
                    Log.i(TAG, "inline rejectCall($roomId) succeeded: status=$status body=$responseBody")
                    try {
                        PendingCallKitStore.clearIncoming(context, roomId)
                    } catch (_: Throwable) {}
                }
                status == 400 && (
                    responseBody.contains("failed-precondition", ignoreCase = true) ||
                        responseBody.contains("failed_precondition", ignoreCase = true) ||
                        responseBody.contains("already handled", ignoreCase = true)
                    ) -> {
                    Log.i(TAG, "inline rejectCall($roomId) already-handled (FAILED_PRECONDITION) — treating as success")
                    try {
                        PendingCallKitStore.clearIncoming(context, roomId)
                    } catch (_: Throwable) {}
                }
                else -> {
                    Log.w(TAG, "inline rejectCall($roomId) non-2xx: status=$status body=$responseBody (backup worker will retry)")
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "inline rejectCall($roomId) failed (backup worker will retry)", t)
        } finally {
            try { conn?.disconnect() } catch (_: Throwable) {}
        }
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
     * Firebase Auth rehydrates `currentUser` lazily on cold start.
     * Poll briefly (we hold a wakelock so the thread is allowed to
     * stay alive) so the inline path can still authenticate even
     * when the FCM service raced the auth-disk-load.
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

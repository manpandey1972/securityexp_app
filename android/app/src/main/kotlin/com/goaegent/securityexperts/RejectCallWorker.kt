package com.goaegent.securityexperts

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * Calls the backend `api { action: "rejectCall", payload: { room_id } }`
 * Cloud Function from the Android side, without requiring the Flutter
 * engine to start.
 *
 * Why this exists:
 *   When an `incoming_call` FCM arrives while the app is killed, the
 *   `flutter_callkit_incoming` plugin renders the ringing UI. If the
 *   user taps Decline (heads-up banner action OR full-screen UI
 *   button), the plugin's `CallkitIncomingBroadcastReceiver`:
 *     • cannot clear the incoming notification (its
 *       `callkitNotificationManager` reference comes from
 *       `FlutterCallkitIncomingPlugin.getInstance()` which is null
 *       on cold start), so sound and notification linger;
 *     • cannot dispatch the `actionCallDecline` event to Dart for the
 *       same reason; the server is therefore never told the call was
 *       rejected, and the caller waits the full ~30s server ring
 *       timeout before getting a "no answer" signal.
 *
 *   We bridge the gap natively. [GoAegentApplication] observes the
 *   plugin's SharedPreferences-backed `ACTIVE_CALLS` for removals, and
 *   on a cold-start decline enqueues this worker. The worker uses the
 *   Firebase Functions Android SDK — which automatically attaches the
 *   persisted Firebase Auth ID token — to call `rejectCall` directly.
 *
 *   The backend handler ([functions/src/callStateManagement.ts]
 *   `handleRejectCall`) is idempotent: a second reject after the call
 *   has already been declined returns `"already handled"`, which we
 *   treat as success.
 *
 *   We use WorkManager rather than a raw coroutine because:
 *     • The process may be killed any time after the user taps
 *       Decline (notification action delivery to a backgrounded
 *       process is short-lived). WorkManager survives process death.
 *     • Network may be momentarily unavailable. WorkManager retries
 *       with exponential backoff under our chosen constraints.
 */
class RejectCallWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "RejectCallWorker"
        private const val INPUT_ROOM_ID = "room_id"

        // Region default — must match the Cloud Functions deployment.
        // The Dart side uses `FirebaseFunctions.instance` (us-central1),
        // so we match.
        private const val FUNCTIONS_REGION = "us-central1"
        private const val FUNCTIONS_BASE_URL =
            "https://us-central1-securityexp-app.cloudfunctions.net"

        private const val TOKEN_TIMEOUT_MS = 8_000L
        private const val CALL_TIMEOUT_MS = 6_000L
        private const val AUTH_WAIT_TIMEOUT_MS = 5_000L
        private const val AUTH_POLL_INTERVAL_MS = 200L

        // Cap retries so a permanently-broken call doesn't loop forever.
        private const val MAX_ATTEMPTS = 6

        /**
         * Convenience to enqueue a one-shot rejection for [roomId]. Uses
         * a unique work name keyed by room id so duplicate enqueues
         * (e.g. listener fires twice) coalesce into a single attempt.
         */
        fun enqueue(context: Context, roomId: String) {
            if (roomId.isBlank()) {
                Log.w(TAG, "Refusing to enqueue with blank roomId")
                return
            }
            val request = OneTimeWorkRequestBuilder<RejectCallWorker>()
                .setInputData(Data.Builder().putString(INPUT_ROOM_ID, roomId).build())
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    10,
                    TimeUnit.SECONDS,
                )
                .addTag("RejectCall:$roomId")
                .build()
            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                "RejectCall:$roomId",
                ExistingWorkPolicy.KEEP,
                request,
            )
            Log.d(TAG, "Enqueued reject worker for $roomId")
        }
    }

    override suspend fun doWork(): Result {
        val roomId = inputData.getString(INPUT_ROOM_ID)
        if (roomId.isNullOrBlank()) {
            Log.w(TAG, "Missing room_id input — failing permanently")
            return Result.failure()
        }
        Log.d(TAG, "Starting reject worker for $roomId (attempt=$runAttemptCount)")
        if (runAttemptCount >= MAX_ATTEMPTS) {
            Log.w(TAG, "Giving up on $roomId after $runAttemptCount attempts")
            return Result.failure()
        }

        // Firebase Auth persists the user's session to encrypted disk on
        // sign-in. On a cold start the SDK rehydrates `currentUser`
        // lazily — we briefly poll for it to become non-null before
        // failing, so a worker started before disk-load completes can
        // still succeed.
        val user = awaitCurrentUser(roomId) ?: run {
            Log.w(TAG, "No signed-in user for $roomId after wait — failing permanently")
            return Result.failure()
        }
        val idToken = try {
            // forceRefresh=false; we just want whatever cached token the
            // SDK has. If it's stale the Functions SDK will reject and
            // we retry.
            val tokenResult = withTimeout(TOKEN_TIMEOUT_MS) {
                user.getIdToken(false).await()
            }
            val token = tokenResult.token
            if (token.isNullOrBlank()) {
                Log.w(TAG, "ID token was blank for $roomId — will retry")
                return Result.retry()
            }
            token
        } catch (t: TimeoutCancellationException) {
            Log.w(TAG, "ID-token mint timed out for $roomId — will retry", t)
            return Result.retry()
        } catch (t: Throwable) {
            Log.w(TAG, "ID-token mint failed for $roomId — will retry", t)
            return Result.retry()
        }

        val payload = mapOf(
            "action" to "rejectCall",
            "payload" to mapOf("room_id" to roomId),
        )

        val sdkAttempt = callViaFunctionsSdk(roomId, payload)
        if (sdkAttempt != null) {
            return sdkAttempt
        }

        // SDK timed out or hit a transient error — fall back to the
        // raw callable HTTPS protocol.
        return callViaHttpFallback(roomId, idToken)
    }

    private suspend fun awaitCurrentUser(roomId: String): com.google.firebase.auth.FirebaseUser? {
        val auth = FirebaseAuth.getInstance()
        val immediate = auth.currentUser
        if (immediate != null) return immediate
        val deadline = System.currentTimeMillis() + AUTH_WAIT_TIMEOUT_MS
        while (System.currentTimeMillis() < deadline) {
            kotlinx.coroutines.delay(AUTH_POLL_INTERVAL_MS)
            val u = auth.currentUser
            if (u != null) return u
        }
        return auth.currentUser
    }

    private suspend fun callViaFunctionsSdk(
        roomId: String,
        payload: Map<String, Any>,
    ): Result? {
        val functions = FirebaseFunctions.getInstance(FUNCTIONS_REGION)
        return try {
            val result = withTimeout(CALL_TIMEOUT_MS) {
                functions.getHttpsCallable("api").call(payload).await()
            }
            Log.i(TAG, "rejectCall($roomId) succeeded via SDK: ${result.data}")
            clearStash(roomId)
            Result.success()
        } catch (e: TimeoutCancellationException) {
            Log.w(TAG, "rejectCall($roomId) SDK timed out; falling back to HTTP", e)
            null
        } catch (e: FirebaseFunctionsException) {
            when (e.code) {
                FirebaseFunctionsException.Code.FAILED_PRECONDITION,
                FirebaseFunctionsException.Code.NOT_FOUND -> {
                    Log.i(TAG, "rejectCall($roomId): SDK terminal state (${e.code}); treating as success")
                    clearStash(roomId)
                    Result.success()
                }
                FirebaseFunctionsException.Code.UNAUTHENTICATED,
                FirebaseFunctionsException.Code.PERMISSION_DENIED -> {
                    Log.w(TAG, "rejectCall($roomId) SDK auth failed: ${e.code}")
                    Result.failure()
                }
                else -> {
                    Log.w(TAG, "rejectCall($roomId) SDK error: ${e.code}; falling back to HTTP", e)
                    null
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "rejectCall($roomId) SDK failed; falling back to HTTP", t)
            null
        }
    }

    private fun callViaHttpFallback(roomId: String, idToken: String): Result {
        return try {
            val endpoint = "$FUNCTIONS_BASE_URL/api"
            val body = JSONObject()
                .put("data", JSONObject()
                    .put("action", "rejectCall")
                    .put("payload", JSONObject().put("room_id", roomId)))
                .toString()

            val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = CALL_TIMEOUT_MS.toInt()
                readTimeout = CALL_TIMEOUT_MS.toInt()
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $idToken")
            }

            conn.outputStream.use { os ->
                os.write(body.toByteArray(Charsets.UTF_8))
            }

            val status = conn.responseCode
            val responseBody = readStream(
                if (status in 200..299) conn.inputStream else conn.errorStream,
            )

            when {
                status in 200..299 -> {
                    Log.i(TAG, "rejectCall($roomId) succeeded via HTTP fallback: status=$status body=$responseBody")
                    clearStash(roomId)
                    Result.success()
                }
                status == 401 || status == 403 -> {
                    Log.w(TAG, "rejectCall($roomId) HTTP auth failed: status=$status body=$responseBody")
                    Result.failure()
                }
                status == 404 -> {
                    Log.w(TAG, "rejectCall($roomId) HTTP endpoint not found: $endpoint")
                    Result.failure()
                }
                else -> {
                    Log.w(TAG, "rejectCall($roomId) HTTP transient failure: status=$status body=$responseBody")
                    Result.retry()
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "rejectCall($roomId) HTTP fallback failed; will retry", t)
            Result.retry()
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

    private fun clearStash(roomId: String) {
        try {
            PendingCallKitStore.clearIncoming(applicationContext, roomId)
        } catch (_: Throwable) {
        }
    }
}

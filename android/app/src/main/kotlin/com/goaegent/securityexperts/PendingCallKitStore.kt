package com.goaegent.securityexperts

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * SharedPreferences-backed registry of incoming CallKit calls that arrived
 * via FCM — used as the canonical source of `room_id` for a given plugin
 * `callId` once the original FCM payload is no longer in scope.
 *
 * Why it exists:
 *   When an `incoming_call` push arrives in [GoAegentMessagingService],
 *   the plugin's own `ACTIVE_CALLS` registry stores the call's `id` but
 *   nothing else app-specific. If the user later declines from a cold
 *   start, [GoAegentApplication]'s prefs listener sees the id leave
 *   ACTIVE_CALLS — but to call the backend `rejectCall(room_id)` we need
 *   the room id, which the plugin's `id` happens to equal in our
 *   dispatcher today but isn't guaranteed to in future. This stash makes
 *   the mapping explicit and survives process death (commit, not apply).
 *
 *   [RejectCallWorker] consumes the stash after a successful reject; on
 *   accept we leave it for [AndroidCallKitService] to clear during its
 *   warm-path teardown (via the `stopCallKit` MethodChannel).
 */
object PendingCallKitStore {

    private const val PREFS_NAME = "ghkit_pending"
    /** Map<callId, JSON payload> for calls received via FCM. */
    private const val KEY_INCOMING = "incoming"

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Persist a payload under the incoming map. Overwrites any prior entry for [callId]. */
    fun saveIncoming(context: Context, callId: String, payload: Map<String, Any?>) {
        val obj = readMap(prefs(context), KEY_INCOMING)
        obj.put(callId, JSONObject(payload.filterValues { it != null }))
        prefs(context).edit().putString(KEY_INCOMING, obj.toString()).apply()
    }

    /** Look up a saved incoming payload by [callId]; returns null if absent. */
    fun getIncoming(context: Context, callId: String): JSONObject? {
        val obj = readMap(prefs(context), KEY_INCOMING)
        return if (obj.has(callId)) obj.getJSONObject(callId) else null
    }

    /** Remove an incoming entry (called after accept or after a successful native reject). */
    fun clearIncoming(context: Context, callId: String) {
        val obj = readMap(prefs(context), KEY_INCOMING)
        if (obj.has(callId)) {
            obj.remove(callId)
            prefs(context).edit().putString(KEY_INCOMING, obj.toString()).apply()
        }
    }

    private fun readMap(prefs: SharedPreferences, key: String): JSONObject {
        val raw = prefs.getString(key, null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Throwable) {
            JSONObject()
        }
    }
}

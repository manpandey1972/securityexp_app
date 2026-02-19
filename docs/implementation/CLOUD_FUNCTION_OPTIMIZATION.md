# Cloud Function Optimization Plan

**Created:** February 6, 2026  
**Status:** Planned  
**Goal:** Reduce cold starts, invocation costs, and latency for a low-traffic app

---

## Current State

### Deployed Cloud Functions (15 total)

| # | Function | Type | Trigger Path / Schedule |
|---|---|---|---|
| 1 | `createCall` | onCall | Flutter callable |
| 2 | `acceptCall` | onCall | Flutter callable |
| 3 | `rejectCall` | onCall | Flutter callable |
| 4 | `endCall` | onCall | Flutter callable |
| 5 | `generateLiveKitTokenFunction` | onCall | Flutter callable |
| 6 | `markRoomRead` | onCall | Flutter callable |
| 7 | `chatMessageCreated` | Firestore trigger | `chat_rooms/{room_id}/messages/{messageid}` onCreate |
| 8 | `updateUnreadCount` | Firestore trigger | `chat_rooms/{room_id}/messages/{messageid}` onCreate |
| 9 | `sendCallNotification` | Firestore trigger | `call_history/{docId}` onCreate |
| 10 | `onRatingCreated` | Firestore trigger | `ratings/{ratingId}` onCreate |
| 11 | `onTicketCreate` | Firestore trigger | `support_tickets/{ticketId}` onCreate |
| 12 | `onSupportMessageCreate` | Firestore trigger | `support_tickets/{ticketId}/messages/{messageId}` onCreate |
| 13 | `onTicketUpdate` | Firestore trigger | `support_tickets/{ticketId}` onUpdate |
| 14 | `handleCallTimeouts` | Scheduled | Every 1 minute |
| 15 | `autoCloseResolvedTickets` | Scheduled | Daily at 2 AM UTC |

### Flutter Call Sites (7 invocations across 3 files)

| Function Called | Flutter File | Usage |
|---|---|---|
| `createCall` | `lib/features/calling/infrastructure/repositories/firebase_call_repository.dart` | Initiate a call |
| `acceptCall` | `lib/features/calling/infrastructure/repositories/firebase_call_repository.dart` | Accept incoming call |
| `endCall` | `lib/features/calling/infrastructure/repositories/firebase_call_repository.dart` | End active call |
| `rejectCall` | `lib/features/calling/infrastructure/repositories/firebase_call_repository.dart` | Reject incoming call |
| `generateLiveKitTokenFunction` | `lib/features/calling/infrastructure/repositories/firebase_call_repository.dart` | Fallback token generation |
| `generateLiveKitTokenFunction` | `lib/shared/services/livekit_token_service.dart` | Standalone token generation |
| `markRoomRead` | `lib/features/chat/services/unread_messages_service.dart` | Mark chat room as read |

---

## Problem

Cold starts on Cloud Functions (Gen2) take **1–5 seconds**. For a low-traffic app where containers frequently spin down, users experience this latency on nearly every callable invocation. Each deployed function is an independent container that cold-starts separately. More functions = more cold-start surface area.

---

## Optimization 1: Move `markRoomRead` to Client-Side

**Priority: High** — Most frequent callable, easiest to eliminate.

### Current Behavior
`markRoomRead` cloud function: reads room's `unreadCount`, sets it to 0, decrements user's `totalUnreadCount` by that amount.

### Proposed Change
Replace with client-side Firestore batch write. Security rules already permit:
- Write to `users/{userId}/rooms/{roomId}` (owner)
- Update `users/{userId}.totalUnreadCount` (owner)

```dart
// Client-side replacement (pseudocode)
final batch = firestore.batch();
batch.update(roomRef, {'unreadCount': 0, 'lastReadAt': FieldValue.serverTimestamp()});
batch.update(userRef, {'totalUnreadCount': FieldValue.increment(-currentUnreadCount)});
await batch.commit();
```

### Bonus: `markRoomsAsRead` Consolidation
Currently fires N parallel cloud function calls for N rooms. With client-side approach, this becomes a **single Firestore batch write** (up to 500 operations per batch).

| Pros | Cons |
|------|------|
| Eliminates most frequent callable function | No server-side atomicity (read + write not transactional) |
| Zero cold start latency on chat open | Tiny race: new message between read and write could drift `totalUnreadCount` by 1 |
| N rooms → single batch write instead of N function calls | Client-side error handling needed |
| Reduces cloud function cost | |

---

## Optimization 2: Merge Duplicate Message Triggers

**Priority: High** — Fires on every single chat message.

### Current Behavior
Two separate functions trigger on the same Firestore path:
- `chatMessageCreated` → sends FCM push notification
- `updateUnreadCount` → increments recipient's unread counts

Both trigger on `chat_rooms/{room_id}/messages/{messageid}` onCreate. Every message cold-starts **two containers**.

### Proposed Change
Merge into a single `onMessageCreated` trigger that does both: send notification AND update unread counts.

```typescript
// Merged function (pseudocode)
export const onMessageCreated = onDocumentCreated(
  { document: "chat_rooms/{room_id}/messages/{messageid}", database: "green-hive-db" },
  async (event) => {
    const [notifResult, unreadResult] = await Promise.allSettled([
      handleNotification(event),   // existing chatMessageCreated logic
      handleUnreadCount(event),    // existing updateUnreadCount logic
    ]);
    // Log failures independently — one failing doesn't block the other
  }
);
```

| Pros | Cons |
|------|------|
| Halves cold starts per message (1 function instead of 2) | Larger function = slightly longer per-invocation time |
| ~50% fewer invocations for message events | Failure in one path (e.g., FCM) could complicate error handling |
| Shared context — no duplicate Firestore reads | Deployment coupling: notification + unread logic changes deploy together |
| Lower cost (billed per invocation) | |

---

## Optimization 3: Unified Callable Facade (Single HTTP Endpoint)

**Priority: High** — Reduces 6 callable functions to 1 container.

### Current Behavior
6 separate `onCall` functions deployed as independent containers:
- `createCall`, `acceptCall`, `rejectCall`, `endCall` (call management)
- `generateLiveKitTokenFunction` (token generation)
- `markRoomRead` (chat — potentially eliminated by Optimization 1)

Each cold-starts independently. A user making a call hits `createCall` (cold start), callee hits `acceptCall` (cold start on a different container), then `endCall` (possibly another cold start).

### Proposed Change
Replace all `onCall` functions with a single `api` callable that routes by action type:

```typescript
// Server: Single facade function
export const api = onCall(
  { secrets: [apnsKeyId, apnsTeamId, apnsPrivateKey, apnsBundleId] },
  async (request) => {
    const { action, payload } = request.data;
    
    switch (action) {
      case "createCall":     return handleCreateCall(request.auth, payload);
      case "acceptCall":     return handleAcceptCall(request.auth, payload);
      case "rejectCall":     return handleRejectCall(request.auth, payload);
      case "endCall":        return handleEndCall(request.auth, payload);
      case "generateToken":  return handleGenerateToken(request.auth, payload);
      case "markRoomRead":   return handleMarkRoomRead(request.auth, payload);
      default: throw new HttpsError("invalid-argument", `Unknown action: ${action}`);
    }
  }
);
```

```dart
// Flutter: Thin client wrapper
class CloudApi {
  final _callable = FirebaseFunctions.instance.httpsCallable('api');
  
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> payload) async {
    final result = await _callable.call({'action': action, 'payload': payload});
    return result.data as Map<String, dynamic>;
  }
  
  Future<CallResponse> createCall(CreateCallRequest req) => call('createCall', req.toMap());
  Future<CallResponse> acceptCall(String roomId) => call('acceptCall', {'room_id': roomId});
  // ... etc
}
```

### Cold Start Impact

| Scenario | Before (6 functions) | After (1 facade) |
|---|---|---|
| First call action in session | Cold start ~3s | Cold start ~3s |
| Second different action (e.g., endCall) | **Another cold start ~3s** | **Warm — <100ms** (same container) |
| Chat open (markRoomRead) | Cold start ~3s | Likely warm from earlier call | 
| Concurrent users | Up to 6 separate cold containers | 1 container serves all actions |

### Trade-offs

| Pros | Cons |
|------|------|
| **Single container** for all callable operations — one cold start warms everything | All secrets loaded for every invocation (APNS keys loaded even for `markRoomRead`) |
| Subsequent actions are warm (~100ms vs ~3s) | Single function failure could affect all actions (mitigate with try/catch per handler) |
| Simpler deployment — one function to monitor | Harder to set per-action memory/timeout limits |
| Container stays warm longer (more total traffic to one function) | Slightly larger bundle size (all handlers loaded) |
| Easier to add new actions without deploying new functions | Loss of per-function invocation metrics in Firebase console (need custom logging) |
| Lower total idle cost (1 container vs 6) | `maxInstances` applies to all actions collectively |

### Secret Loading Concern
`createCall` requires APNS secrets (`defineSecret`). In the facade model, secrets are declared at the function level, so they're available for all actions even when not needed. This is a minor inefficiency but not a security concern (secrets are only accessible server-side).

### Monitoring Mitigation
Add structured logging with action labels to preserve per-action observability:
```typescript
logger.info(`[${action}] Request received`, { userId: request.auth?.uid, action, payload });
```

---

## Optimization 4: Remove Standalone `generateLiveKitTokenFunction`

**Priority: Low** — Only used as a fallback.

### Current Behavior
`createCall` and `acceptCall` already return a LiveKit token in their response. The standalone function exists as a fallback in `firebase_call_repository.dart` and `livekit_token_service.dart`.

### Proposed Change
Remove the fallback path. Rely solely on tokens returned by `createCall`/`acceptCall`. If the facade approach (Optimization 3) is adopted, this function is absorbed into the facade anyway.

| Pros | Cons |
|------|------|
| One fewer deployed function | No fallback if token missing from call response |
| Simplifies call flow | If token expires mid-call, no way to refresh without ending/restarting |

### Recommendation
If implementing the facade, this is automatically handled. If not, verify no code paths besides the fallback use it before removing.

---

## Optimization 5: Client-Side Rating Aggregation (NOT RECOMMENDED)

### Current Behavior
`onRatingCreated` trigger queries all ratings and computes average, writes to expert's user doc.

### Why Not Client-Side
A malicious client could increment `ratingSum` by arbitrary values (e.g., 500 instead of 5). Security rules cannot easily validate that the increment matches the rating value. **Keep server-side.**

---

## Optimization 6: Min Instances (Budget Permitting)

**Priority: Low** — Only if budget allows ~$70–150/month per function.

Set `minInstances: 1` on latency-critical functions to eliminate cold starts entirely.

| Candidate | Why |
|---|---|
| `api` (facade) or `createCall` | User-facing, latency-critical call initiation |
| Merged `onMessageCreated` | Fires on every message |

| Pros | Cons |
|------|------|
| Zero cold start | ~$0.10/hr per idle instance (~$70/month per function) |
| Simple config change | Expensive for low-traffic app |

---

## Implementation Priority

| Order | Optimization | Impact | Effort | Risk |
|-------|---|---|---|---|
| 1 | Move `markRoomRead` client-side | High | Low (1–2 hrs) | Low |
| 2 | Merge message triggers | High | Medium (2–3 hrs) | Low |
| 3 | Unified callable facade | **Very High** | Medium (4–6 hrs) | Medium |
| 4 | Remove standalone token function | Low | Low (30 min) | Low |
| 5 | Min instances | Medium | Trivial (config) | None (cost only) |

### Combined Impact
Optimizations 1–4 together would reduce deployed callable functions from **6 to 1**, trigger functions from **2 to 1** on the message path, and eliminate the highest-frequency callable entirely. For a low-traffic app, this dramatically reduces cold-start exposure.

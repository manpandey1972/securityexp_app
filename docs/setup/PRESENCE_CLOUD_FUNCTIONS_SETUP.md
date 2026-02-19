# Presence-Aware Push Notifications - Cloud Functions Guide

This guide explains how to add presence checking to your existing Cloud Functions to suppress push notifications when users are actively viewing a chat.

## Key Concept

**Cloud Functions only READ from Realtime Database** - they never write presence data. The Flutter app handles all presence updates.

## Prerequisites

1. Firebase Cloud Functions already set up (TypeScript recommended)
2. Firebase Realtime Database enabled in console
3. Existing `onNewChatMessage` Firestore trigger (or similar)

## Setup Steps

### 1. Add RTDB to Cloud Functions Dependencies

Update `functions/package.json`:

```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.1"
  }
}
```

Run: `npm install` in the functions directory

### 2. Add Presence Check Helper Function

Create `functions/src/utils/presenceHelper.ts`:

```typescript
import * as admin from "firebase-admin";

interface PresenceData {
  isOnline: boolean;
  currentChatRoomId: string | null;
  lastUpdated: number;
}

/**
 * Checks if a push notification should be sent to a user.
 * Returns false if user is actively viewing the specific chat room.
 */
export async function shouldSendPushNotification(
  recipientUserId: string,
  chatRoomId?: string
): Promise<boolean> {
  try {
    const presenceRef = admin.database().ref(`presence/${recipientUserId}`);
    const snapshot = await presenceRef.once("value");
    
    if (!snapshot.exists()) {
      return true; // No presence data = offline, send notification
    }
    
    const presence = snapshot.val() as PresenceData;
    
    // If user is offline, always send notification
    // (even if currentChatRoomId is set - they backgrounded the app)
    if (!presence.isOnline) {
      return true;
    }
    
    // User is online - check if viewing this specific chat room
    if (chatRoomId && presence.currentChatRoomId === chatRoomId) {
      console.log(`User ${recipientUserId} is viewing chat ${chatRoomId}, suppressing push`);
      return false;
    }
    
    // User is online but not in this chat room, send notification
    return true;
    
  } catch (error) {
    console.error(`Error checking presence for ${recipientUserId}:`, error);
    return true; // On error, default to sending
  }
}
```

### 3. Update Your Existing Message Trigger

Add presence check to your existing `onNewChatMessage` function:

```typescript
import { shouldSendPushNotification } from "./utils/presenceHelper";

export const onNewChatMessage = functions.firestore
  .document("chatRooms/{roomId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const roomId = context.params.roomId;
    const messageData = snapshot.data();
    const recipientId = /* your logic to get recipient */;
    
    // ADD THIS CHECK:
    const shouldSend = await shouldSendPushNotification(recipientId, roomId);
    if (!shouldSend) {
      console.log('User is viewing this chat, skipping notification');
      return;
    }
    
    // Your existing notification code...
    await admin.messaging().send({
      token: recipientToken,
      notification: {
        title: "New Message",
        body: messageData.text,
      },
      data: {
        roomId: roomId,
      },
    });
  });
```

### 4. Deploy

```bash
cd functions
npm run build
firebase deploy --only functions
```

## RTDB Rules Configuration

Add these Realtime Database Rules to allow presence tracking:

**File: database.rules.json**

```json
{
  "rules": {
    "presence": {
      "$userId": {
        ".read": true,
        ".write": "$userId === auth.uid",
        ".indexOn": ["isOnline", "lastUpdated"]
      }
    }
  }
}
```

Deploy with:
```bash
firebase deploy --only database
```

**Or configure in Firebase Console:**
1. Go to Firebase Console → Realtime Database → Rules tab
2. Paste the rules above
3. Click "Publish"

## How It Works

### Flutter App Updates Presence (WRITES)

```
User opens app → isOnline: true
User enters chat → currentChatRoomId: "room123"
User leaves chat → currentChatRoomId: null
User backgrounds app → isOnline: false
User kills app → onDisconnect() fires → isOnline: false (automatic!)
```

**Key:** `onDisconnect()` is server-side - Firebase automatically sets offline status when TCP connection drops. **No Cloud Function trigger needed.**

### Cloud Function Checks Presence (READS)

```
Message created in Firestore
  ↓
onNewChatMessage trigger fires
  ↓
Read presence from RTDB
  ↓
Is user viewing this chat? → YES → Skip push
                          → NO  → Send push
```

**Cloud Functions never write presence data** - they only read to make send/don't-send decisions.

## Integration with Flutter

The Flutter app automatically updates presence data:

1. **On Login** - `initialize()` sets `isOnline: true`
2. **On Chat Room Enter** - `enterChatRoom(id)` sets `currentChatRoomId`
3. **On Chat Room Leave** - `leaveChatRoom()` clears `currentChatRoomId`
4. **On App Background** - `setAppInBackground()` sets `isOnline: false`
5. **On App Kill** - `onDisconnect()` automatically sets `isOnline: false`

## RTDB Presence Structure

```
presence/
  {userId}/
    isOnline: boolean           // Is app in foreground
    currentChatRoomId: string   // Which chat room they're viewing (null if none)
    lastUpdated: number         // Timestamp for staleness check
```

Example:

```json
{
  "isOnline": true,
  "currentChatRoomId": "room_abc123",
  "lastUpdated": 1705868400000
}
```

## Customization

### Change Suppression Logic

In `presenceHelper.ts`, modify the logic:

```typescript
// Option 1: Suppress ALL notifications when app is open
if (presence.isOnline) {
  return false; // Don't send any push when app is open
}

// Option 2: Only suppress for the specific chat being viewed (default)
if (chatRoomId && presence.currentChatRoomId === chatRoomId) {
  return false;
}
```

## Testing

### 1. Test Presence Tracking (RTDB Console)

1. Open your app and login
2. Go to Firebase Console → Realtime Database → Data tab
3. Navigate to `presence/{yourUserId}`
4. You should see:
   ```json
   {
     "isOnline": true,
     "currentChatRoomId": null,
     "lastUpdated": 1705868400000
   }
   ```

5. Open a chat room → `currentChatRoomId` should update
6. Leave chat → `currentChatRoomId` should become `null`
7. Background the app → `isOnline` should become `false`
8. Force quit → `isOnline` should become `false` (within 1-2 seconds)

### 2. Test Push Notification Suppression

**Scenario A: User viewing chat (should suppress)**
1. User A opens chat with User B
2. User B sends a message
3. Check Cloud Function logs → Should see "suppressing push"
4. User A should NOT receive notification

**Scenario B: User not viewing chat (should send)**
1. User A is on home screen or different chat
2. User B sends a message
3. User A should receive push notification

**Monitor logs:**
```bash
firebase functions:log --only onNewChatMessage
```

## Troubleshooting

### Presence Not Updating

**Check:**
- `UserPresenceService.initialize()` called after login in auth_provider.dart
- RTDB Rules allow write for `"$userId === auth.uid"`
- App lifecycle listener registered in main.dart
- Firebase RTDB is enabled in Firebase Console

**Debug:**
```dart
// Add to UserPresenceService
print('Presence updated: isOnline=$_isAppInForeground, room=$_currentChatRoomId');
```

### Notifications Still Being Sent When User Is Viewing Chat

**Check:**
- Cloud Function has `shouldSendPushNotification()` call before sending
- `currentChatRoomId` matches exactly (check for ID format differences)
- Cloud Function logs show the presence check is happening

**Debug in Cloud Function:**
```typescript
console.log(`Presence data:`, presence);
console.log(`Checking roomId: ${chatRoomId} vs ${presence.currentChatRoomId}`);
```

### onDisconnect() Not Firing

**This is rare** - Firebase handles it automatically. If you see issues:
- Check network stability (airplane mode test)
- Verify RTDB connection with `.info/connected` listener
- Check Firebase credentials are valid

## FAQ

**Q: Does this use up my RTDB quota?**  
A: Minimal - only writes on state changes (open chat, close chat, background). ~10-20 writes per user per day.

**Q: What if RTDB is down?**  
A: Cloud Function defaults to sending push (see `catch` block in helper).

**Q: Can I use this for call notifications too?**  
A: Yes! Just check presence before sending call notifications.

**Q: Do I need to clean up old presence data?**  
A: Optional. Consider a daily cleanup function to delete presence data older than 24 hours.

## Summary

This approach uses:
- ✅ **Flutter app** - WRITES presence to RTDB
- ✅ **RTDB `onDisconnect()`** - Auto-cleanup on app kill (server-side)
- ✅ **Cloud Functions** - READS presence before sending push
- ✅ **No polling** - Event-driven, efficient
- ✅ **No extra triggers** - Uses your existing `onNewChatMessage` trigger

The same pattern used by Slack, Discord, and WhatsApp for presence tracking.

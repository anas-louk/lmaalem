# FCM Push Notifications for Incoming Audio Calls - Setup Guide

## Overview

This implementation sends FCM push notifications with **notification + data** format to ensure system notifications appear even when the app is backgrounded or closed.

## Architecture

### 1. Cloud Function (`functions/index.js`)

**Function:** `sendIncomingAudioCallNotification`

**Trigger:** Firestore document create/update at `calls/{callId}` when `status="ringing"` and `type="audio"`

**Message Format:**
```javascript
{
  notification: {
    title: "Incoming Call",
    body: "Audio call from <callerName>",
    sound: "default"
  },
  data: {
    type: "incoming_audio_call",
    callId: "<string>",
    callerId: "<string>",
    callerName: "<string>",
    audio: "true"
  },
  android: {
    priority: "high",
    ttl: 30000, // 30 seconds
    notification: {
      sound: "default",
      priority: "high",
      channelId: "incoming_calls"
    }
  },
  apns: {
    headers: {
      "apns-priority": "10",
      "apns-expiration": "<timestamp + 30 seconds>"
    },
    payload: {
      aps: {
        alert: {
          title: "Incoming Call",
          body: "Audio call from <callerName>"
        },
        sound: "default",
        badge: 1
      }
    }
  }
}
```

### 2. Flutter Handlers

#### Background Handler (`lib/main.dart`)

Registered in `main()`:
```dart
FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
```

**Location:** `lib/core/services/push_notifications.dart`

**Behavior:**
- Executes in a separate isolate when app is backgrounded/closed
- Receives FCM message with notification + data
- System automatically displays notification from "notification" block
- When user taps notification, `onMessageOpenedApp` is triggered

#### Foreground Handler (`lib/core/services/push_notifications.dart`)

**Handler:** `_handleForegroundMessage`

**Triggered by:** `FirebaseMessaging.onMessage.listen()`

**Behavior:**
- App is in foreground
- Shows snackbar: "Incoming Call - Call from <callerName>"
- Immediately navigates to `IncomingCallScreen`

#### Tap Handler (`lib/core/services/push_notifications.dart`)

**Handler:** `_handleNotificationClick`

**Triggered by:** `FirebaseMessaging.onMessageOpenedApp.listen()`

**Behavior:**
- User taps system notification (app was backgrounded/closed)
- Extracts `callId`, `callerId`, `callerName` from message data
- Calls `CallController.handleIncomingCallFromFCM()`
- Navigates to `IncomingCallScreen`

### 3. CallController Integration

**Method:** `handleIncomingCallFromFCM()`

**Location:** `lib/controllers/call_controller.dart`

**Parameters:**
- `callId`: Firestore document ID of the call
- `callerId`: User ID of the caller
- `isVideo`: Always `false` for audio calls

**Behavior:**
- Checks if user already has an active call (ignores if yes)
- Navigates to `/incoming-call` route with call arguments

## Testing

### 1. Test HTTP Function

**Endpoint:** `testAudioCallNotify`

**Method:** POST

**URL:** `https://<region>-<project-id>.cloudfunctions.net/testAudioCallNotify`

**Body:**
```json
{
  "calleeId": "user123",
  "callerId": "user456",
  "callerName": "Test Caller",
  "callId": "test-call-123"
}
```

**Response:**
```json
{
  "success": true,
  "messageId": "<FCM message ID>",
  "message": "Test notification sent to user123"
}
```

### 2. Test Scenarios

#### Scenario 1: App in Foreground
1. Open app on device
2. Trigger test notification or start a real call
3. **Expected:** Snackbar appears + `IncomingCallScreen` opens immediately

#### Scenario 2: App Backgrounded/Minimized
1. Minimize app (press home button)
2. Trigger test notification or start a real call
3. **Expected:** System notification appears in notification tray
4. Tap notification
5. **Expected:** App opens to `IncomingCallScreen`

#### Scenario 3: App Closed/Terminated
1. Force close app
2. Trigger test notification or start a real call
3. **Expected:** System notification appears in notification tray
4. Tap notification
5. **Expected:** App launches and opens to `IncomingCallScreen`

## Firestore Security Rules

```javascript
match /calls/{callId} {
  allow read: if request.auth != null && (
    request.auth.uid == resource.data.callerId ||
    request.auth.uid == resource.data.calleeId
  );
  
  allow create: if request.auth != null && 
    request.auth.uid == request.resource.data.callerId &&
    request.resource.data.keys().hasAll(['callerId', 'calleeId', 'type', 'status']) &&
    request.resource.data.type in ['audio', 'video'] &&
    request.resource.data.status == 'ringing';
  
  allow update: if request.auth != null && (
    request.auth.uid == resource.data.callerId ||
    request.auth.uid == resource.data.calleeId
  );
}
```

## Deployment

### 1. Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### 2. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 3. Verify FCM Token Storage

Ensure `AuthController` saves FCM tokens to Firestore:
- Path: `users/{userId}/fcmToken`
- Updated on login and token refresh

## Troubleshooting

### Notification Not Appearing

1. **Check FCM Token:**
   - Verify token exists in Firestore: `users/{userId}/fcmToken`
   - Check token is valid (not expired)

2. **Check Cloud Function Logs:**
   ```bash
   firebase functions:log
   ```

3. **Check Flutter Logs:**
   - Look for `[FCM]` prefixed messages
   - Verify handlers are registered

4. **Check Permissions:**
   - Android: Notification permissions granted
   - iOS: Push notification permissions granted

### Notification Appears But Tap Doesn't Work

1. **Verify `onMessageOpenedApp` is registered:**
   - Check `PushNotificationService.initialize()`
   - Should call `FirebaseMessaging.onMessageOpenedApp.listen()`

2. **Check message data:**
   - Verify `callId` and `callerId` are present in `message.data`
   - Check Flutter logs for data extraction errors

3. **Verify route exists:**
   - Ensure `/incoming-call` route is registered in `AppRoutes`

## Notes

- **TTL:** Notifications expire after 30 seconds (expired calls are ignored)
- **Priority:** High priority ensures notifications appear even in Do Not Disturb mode (Android)
- **Sound:** Default system call sound plays when notification arrives
- **Badge:** iOS badge count increments when notification arrives


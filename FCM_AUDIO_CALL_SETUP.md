# FCM Audio Call Setup Guide

This document describes how to set up Firebase Cloud Functions and FCM for incoming audio call notifications.

## Prerequisites

1. Firebase project with Cloud Functions enabled
2. Node.js 18+ installed
3. Firebase CLI installed: `npm install -g firebase-tools`

## Setup Steps

### 1. Initialize Cloud Functions (if not already done)

```bash
cd functions
npm install
```

### 2. Deploy Cloud Functions

```bash
firebase deploy --only functions
```

### 3. Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

## Testing

### Test the Cloud Function Manually

Use the HTTP test function:

```bash
curl -X POST https://<region>-<project-id>.cloudfunctions.net/testAudioCallNotify \
  -H "Content-Type: application/json" \
  -d '{
    "calleeId": "user123",
    "callerId": "user456",
    "callerName": "Test Caller",
    "callId": "test-call-123"
  }'
```

Replace:
- `<region>` with your Firebase region (e.g., `us-central1`)
- `<project-id>` with your Firebase project ID

### Test End-to-End

1. **User A** starts an audio call to **User B** (app in foreground)
   - Call document is created in Firestore
   - Cloud Function triggers automatically
   - FCM message sent to User B

2. **User B** receives notification:
   - **App in foreground**: Snackbar + IncomingCallScreen opens
   - **App in background**: Local notification appears
   - **App terminated**: Local notification appears
   - **User taps notification**: IncomingCallScreen opens

3. **User B** accepts call:
   - Call connects via WebRTC
   - Both users see CallScreen

## FCM Message Format

The Cloud Function sends **data-only** messages (no notification block):

```json
{
  "type": "incoming_audio_call",
  "callId": "<string>",
  "callerId": "<string>",
  "callerName": "<string>",
  "audio": "true"
}
```

## Important Notes

- **Audio only**: This implementation only handles audio calls, not video
- **TTL**: Messages expire after 30 seconds
- **No CallKit**: Native call UI (CallKit/PushKit) is not implemented yet (Task 5)
- **FCM Token**: Must be stored in `/users/{userId}/fcmToken` in Firestore
- **Permissions**: Microphone permission is requested when accepting a call

## Troubleshooting

### Cloud Function not triggering

1. Check Firestore rules allow document creation
2. Verify call document has `status: "ringing"` and `type: "audio"`
3. Check Cloud Functions logs: `firebase functions:log`

### FCM message not received

1. Verify FCM token exists in `/users/{userId}/fcmToken`
2. Check token is valid (not expired)
3. Verify app has notification permissions
4. Check device is connected to internet

### Call screen not opening

1. Verify `handleIncomingCallFromFCM` is called
2. Check GetX navigation is working
3. Verify CallController is initialized

## Next Steps (Task 5)

- Implement native CallKit/PushKit for iOS
- Implement native call UI for Android
- Handle calls when app is completely terminated
- Add call history and missed call notifications


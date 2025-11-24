/**
 * Firebase Cloud Functions for Lmaalem App
 * 
 * This file contains Cloud Functions for handling incoming audio call notifications.
 * 
 * Setup:
 * 1. Run: npm install firebase-functions@latest firebase-admin@latest
 * 2. Deploy: firebase deploy --only functions
 * 
 * Testing:
 * - Use testAudioCallNotify HTTP function to manually trigger a test notification
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function: sendIncomingAudioCallNotification
 * 
 * Triggered when:
 * - A document is created in calls/{callId} with status="ringing" and type="audio"
 * - OR a document is updated to status="ringing" and type="audio"
 * 
 * Sends an FCM message with notification + data to the callee's device.
 * This ensures system notifications appear even when app is backgrounded or closed.
 * 
 * FCM Message Format (notification + data):
 * {
 *   "notification": {
 *     "title": "Incoming Call",
 *     "body": "Audio call from <callerName>",
 *     "sound": "default"
 *   },
 *   "data": {
 *     "type": "incoming_audio_call",
 *     "callId": "<string>",
 *     "callerId": "<string>",
 *     "callerName": "<string>",
 *     "audio": "true"
 *   }
 * }
 */
exports.sendIncomingAudioCallNotification = functions.firestore
  .document('calls/{callId}')
  .onWrite(async (change, context) => {
    const callId = context.params.callId;
    const callData = change.after.exists ? change.after.data() : null;
    const previousData = change.before.exists ? change.before.data() : null;

    // Only process if call is ringing and type is audio
    if (!callData || callData.status !== 'ringing' || callData.type !== 'audio') {
      console.log(`[sendIncomingAudioCallNotification] Skipping: status=${callData?.status}, type=${callData?.type}`);
      return null;
    }

    // Skip if this is just an update that doesn't change status to ringing
    if (previousData && previousData.status === 'ringing' && previousData.type === 'audio') {
      console.log(`[sendIncomingAudioCallNotification] Call ${callId} already ringing, skipping duplicate notification`);
      return null;
    }

    const calleeId = callData.calleeId;
    const callerId = callData.callerId;
    const callerName = callData.callerName || 'Someone';

    if (!calleeId || !callerId) {
      console.error(`[sendIncomingAudioCallNotification] Missing calleeId or callerId for call ${callId}`);
      return null;
    }

    console.log(`[sendIncomingAudioCallNotification] Processing call ${callId} from ${callerId} to ${calleeId}`);

    try {
      // Fetch callee's FCM token from Firestore
      const calleeDoc = await admin.firestore().collection('users').doc(calleeId).get();
      
      if (!calleeDoc.exists) {
        console.error(`[sendIncomingAudioCallNotification] Callee ${calleeId} not found in users collection`);
        return null;
      }

      const calleeData = calleeDoc.data();
      const fcmToken = calleeData?.fcmToken;

      if (!fcmToken) {
        console.log(`[sendIncomingAudioCallNotification] No FCM token for callee ${calleeId}, skipping notification`);
        return null;
      }

      // Prepare FCM message with notification + data
      // Notification block ensures system notification appears when app is backgrounded/closed
      // Data block allows Flutter to handle the notification tap and navigate to IncomingCallScreen
      const message = {
        token: fcmToken,
        notification: {
          title: 'Incoming Call',
          body: `Audio call from ${callerName}`,
          sound: 'default',
        },
        data: {
          type: 'incoming_audio_call',
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          audio: 'true',
        },
        android: {
          priority: 'high',
          ttl: 30000, // 30 seconds TTL
          notification: {
            sound: 'default',
            priority: 'high',
            channelId: 'incoming_calls', // Optional: create a dedicated channel for calls
          },
        },
        apns: {
          headers: {
            'apns-priority': '10', // High priority for calls
            'apns-expiration': Math.floor(Date.now() / 1000 + 30).toString(), // 30 seconds
          },
          payload: {
            aps: {
              alert: {
                title: 'Incoming Call',
                body: `Audio call from ${callerName}`,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send FCM message
      const response = await admin.messaging().send(message);
      console.log(`[sendIncomingAudioCallNotification] Successfully sent message to ${calleeId}: ${response}`);
      
      return null;
    } catch (error) {
      console.error(`[sendIncomingAudioCallNotification] Error sending notification for call ${callId}:`, error);
      
      // If token is invalid, remove it from Firestore
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        console.log(`[sendIncomingAudioCallNotification] Removing invalid token for user ${calleeId}`);
        await admin.firestore().collection('users').doc(calleeId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
      
      return null;
    }
  });

/**
 * Test HTTP Function: testAudioCallNotify
 * 
 * Manually trigger an incoming audio call notification for testing.
 * 
 * Usage:
 * POST https://<region>-<project-id>.cloudfunctions.net/testAudioCallNotify
 * Body: {
 *   "calleeId": "user123",
 *   "callerId": "user456",
 *   "callerName": "Test Caller",
 *   "callId": "test-call-123"
 * }
 */
exports.testAudioCallNotify = functions.https.onRequest(async (req, res) => {
  // CORS handling
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const { calleeId, callerId, callerName, callId } = req.body;

  if (!calleeId || !callerId || !callId) {
    res.status(400).json({ error: 'Missing required fields: calleeId, callerId, callId' });
    return;
  }

  try {
    // Fetch callee's FCM token
    const calleeDoc = await admin.firestore().collection('users').doc(calleeId).get();
    
    if (!calleeDoc.exists) {
      res.status(404).json({ error: `Callee ${calleeId} not found` });
      return;
    }

    const calleeData = calleeDoc.data();
    const fcmToken = calleeData?.fcmToken;

    if (!fcmToken) {
      res.status(404).json({ error: `No FCM token for callee ${calleeId}` });
      return;
    }

    // Send test notification with notification + data
    const message = {
      token: fcmToken,
      notification: {
        title: 'Incoming Call',
        body: `Audio call from ${callerName || 'Test Caller'}`,
        sound: 'default',
      },
      data: {
        type: 'incoming_audio_call',
        callId: callId,
        callerId: callerId,
        callerName: callerName || 'Test Caller',
        audio: 'true',
      },
      android: {
        priority: 'high',
        ttl: 30000,
        notification: {
          sound: 'default',
          priority: 'high',
          channelId: 'incoming_calls',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-expiration': Math.floor(Date.now() / 1000 + 30).toString(),
        },
        payload: {
          aps: {
            alert: {
              title: 'Incoming Call',
              body: `Audio call from ${callerName || 'Test Caller'}`,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    res.status(200).json({
      success: true,
      messageId: response,
      message: `Test notification sent to ${calleeId}`,
    });
  } catch (error) {
    console.error('[testAudioCallNotify] Error:', error);
    res.status(500).json({
      error: 'Failed to send test notification',
      details: error.message,
    });
  }
});


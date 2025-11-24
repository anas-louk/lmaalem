/**
 * Firebase Cloud Functions for Lmaalem App
 * 
 * This file contains Cloud Functions for handling:
 * - Incoming audio call notifications
 * - New request notifications (for employees)
 * - Employee acceptance notifications (for clients)
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

/**
 * Cloud Function: sendNewRequestNotification
 * 
 * Triggered when:
 * - A new document is created in requests/{requestId} with statut="Pending"
 * 
 * Sends FCM notifications to all employees in the request's category.
 * This ensures notifications appear even when app is backgrounded or closed.
 */
exports.sendNewRequestNotification = functions.firestore
  .document('requests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const requestId = context.params.requestId;
    const requestData = snapshot.data();

    // Only process pending requests
    if (requestData.statut !== 'Pending') {
      console.log(`[sendNewRequestNotification] Skipping: statut=${requestData.statut}`);
      return null;
    }

    const categorieId = requestData.categorieId;
    const clientId = requestData.clientId;
    const description = requestData.description || 'Nouvelle demande';
    const address = requestData.address || '';

    if (!categorieId) {
      console.error(`[sendNewRequestNotification] Missing categorieId for request ${requestId}`);
      return null;
    }

    console.log(`[sendNewRequestNotification] Processing new request ${requestId} in category ${categorieId}`);

    try {
      // Get category reference (handle both string and DocumentReference)
      const categoryRef = typeof categorieId === 'string' 
        ? admin.firestore().collection('categories').doc(categorieId)
        : categorieId;

      // Get all employees in this category
      const employeesSnapshot = await admin.firestore()
        .collection('employees')
        .where('categorieId', '==', categoryRef)
        .get();

      if (employeesSnapshot.empty) {
        console.log(`[sendNewRequestNotification] No employees found for category ${categorieId}`);
        return null;
      }

      console.log(`[sendNewRequestNotification] Found ${employeesSnapshot.size} employees in category`);

      // Get client document to get userId (handle both string and DocumentReference)
      let clientUserId = null;
      if (clientId) {
        const clientRef = typeof clientId === 'string'
          ? admin.firestore().collection('clients').doc(clientId)
          : clientId;
        const clientDoc = await clientRef.get();
        if (clientDoc.exists) {
          const clientData = clientDoc.data();
          clientUserId = clientData.userId;
          // Handle DocumentReference for userId
          if (clientUserId && clientUserId.id) {
            clientUserId = clientUserId.id;
          }
        }
      }

      // Prepare notification message
      const shortDescription = description.length > 50 
        ? `${description.substring(0, 50)}...` 
        : description;
      const notificationBody = `${shortDescription}\nLocation: ${address}`;

      // Send notifications to all employees
      const notificationPromises = [];
      for (const employeeDoc of employeesSnapshot.docs) {
        const employeeData = employeeDoc.data();
        const employeeUserId = employeeData.userId;
        
        // Handle DocumentReference for userId
        let userId = employeeUserId;
        if (employeeUserId && employeeUserId.id) {
          userId = employeeUserId.id;
        }

        // Skip if this is the client's own request (client is also an employee)
        if (userId === clientUserId) {
          console.log(`[sendNewRequestNotification] Skipping employee ${employeeDoc.id}: is the client`);
          continue;
        }

        // Get employee's FCM token from users collection
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (!userDoc.exists) {
          console.log(`[sendNewRequestNotification] User ${userId} not found, skipping`);
          continue;
        }

        const userData = userDoc.data();
        const fcmToken = userData?.fcmToken;

        if (!fcmToken) {
          console.log(`[sendNewRequestNotification] No FCM token for user ${userId}, skipping`);
          continue;
        }

        // Prepare FCM message with notification + data
        const message = {
          token: fcmToken,
          notification: {
            title: 'Nouvelle demande',
            body: notificationBody,
            sound: 'default',
          },
          data: {
            type: 'new_request',
            requestId: requestId,
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              priority: 'high',
              channelId: 'new_requests_channel',
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
            },
            payload: {
              aps: {
                alert: {
                  title: 'Nouvelle demande',
                  body: notificationBody,
                },
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        notificationPromises.push(
          admin.messaging().send(message)
            .then((response) => {
              console.log(`[sendNewRequestNotification] Sent to user ${userId}: ${response}`);
            })
            .catch((error) => {
              console.error(`[sendNewRequestNotification] Error sending to user ${userId}:`, error);
              // Remove invalid token
              if (error.code === 'messaging/invalid-registration-token' || 
                  error.code === 'messaging/registration-token-not-registered') {
                return admin.firestore().collection('users').doc(userId).update({
                  fcmToken: admin.firestore.FieldValue.delete(),
                });
              }
            })
        );
      }

      // Wait for all notifications to be sent
      await Promise.all(notificationPromises);
      console.log(`[sendNewRequestNotification] ✅ Sent notifications for request ${requestId}`);
      
      return null;
    } catch (error) {
      console.error(`[sendNewRequestNotification] Error processing request ${requestId}:`, error);
      return null;
    }
  });

/**
 * Cloud Function: sendEmployeeAcceptedNotification
 * 
 * Triggered when:
 * - A request document is updated and acceptedEmployeeIds array changes
 * 
 * Sends FCM notification to the client when an employee accepts their request.
 * This ensures notifications appear even when app is backgrounded or closed.
 */
exports.sendEmployeeAcceptedNotification = functions.firestore
  .document('requests/{requestId}')
  .onUpdate(async (change, context) => {
    const requestId = context.params.requestId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Only process pending requests
    if (afterData.statut !== 'Pending') {
      return null;
    }

    const beforeAcceptedIds = beforeData.acceptedEmployeeIds || [];
    const afterAcceptedIds = afterData.acceptedEmployeeIds || [];

    // Find newly accepted employees
    const newAcceptedIds = afterAcceptedIds.filter(id => !beforeAcceptedIds.includes(id));

    if (newAcceptedIds.length === 0) {
      return null; // No new acceptances
    }

    console.log(`[sendEmployeeAcceptedNotification] Processing request ${requestId} with ${newAcceptedIds.length} new acceptances`);

    try {
      // Get client document
      const clientId = afterData.clientId;
      if (!clientId) {
        console.error(`[sendEmployeeAcceptedNotification] Missing clientId for request ${requestId}`);
        return null;
      }

      const clientRef = typeof clientId === 'string'
        ? admin.firestore().collection('clients').doc(clientId)
        : clientId;
      const clientDoc = await clientRef.get();

      if (!clientDoc.exists) {
        console.error(`[sendEmployeeAcceptedNotification] Client ${clientId} not found`);
        return null;
      }

      const clientData = clientDoc.data();
      let clientUserId = clientData.userId;
      
      // Handle DocumentReference for userId
      if (clientUserId && clientUserId.id) {
        clientUserId = clientUserId.id;
      }

      if (!clientUserId) {
        console.error(`[sendEmployeeAcceptedNotification] Missing userId for client ${clientId}`);
        return null;
      }

      // Get client's FCM token
      const userDoc = await admin.firestore().collection('users').doc(clientUserId).get();
      if (!userDoc.exists) {
        console.error(`[sendEmployeeAcceptedNotification] User ${clientUserId} not found`);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      if (!fcmToken) {
        console.log(`[sendEmployeeAcceptedNotification] No FCM token for client ${clientUserId}, skipping`);
        return null;
      }

      // Get employee names for notification
      const employeeNames = [];
      for (const employeeId of newAcceptedIds) {
        try {
          const employeeDoc = await admin.firestore().collection('employees').doc(employeeId).get();
          if (employeeDoc.exists) {
            const employeeData = employeeDoc.data();
            employeeNames.push(employeeData.nomComplet || 'Un employé');
          }
        } catch (e) {
          console.error(`[sendEmployeeAcceptedNotification] Error getting employee ${employeeId}:`, e);
        }
      }

      const employeeName = employeeNames.length > 0 
        ? employeeNames[0] 
        : 'Un employé';
      const notificationBody = employeeNames.length > 1
        ? `${employeeNames.length} employés ont accepté votre demande`
        : `${employeeName} a accepté votre demande`;

      // Prepare FCM message with notification + data
      const message = {
        token: fcmToken,
        notification: {
          title: 'Demande acceptée',
          body: notificationBody,
          sound: 'default',
        },
        data: {
          type: 'employee_accepted',
          requestId: requestId,
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            priority: 'high',
            channelId: 'employee_accepted_channel',
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: {
              alert: {
                title: 'Demande acceptée',
                body: notificationBody,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send FCM message
      const response = await admin.messaging().send(message);
      console.log(`[sendEmployeeAcceptedNotification] ✅ Sent notification to client ${clientUserId}: ${response}`);
      
      return null;
    } catch (error) {
      console.error(`[sendEmployeeAcceptedNotification] Error processing request ${requestId}:`, error);
      
      // If token is invalid, remove it
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        try {
          const clientId = afterData.clientId;
          const clientRef = typeof clientId === 'string'
            ? admin.firestore().collection('clients').doc(clientId)
            : clientId;
          const clientDoc = await clientRef.get();
          if (clientDoc.exists) {
            const clientData = clientDoc.data();
            let clientUserId = clientData.userId;
            if (clientUserId && clientUserId.id) {
              clientUserId = clientUserId.id;
            }
            if (clientUserId) {
              await admin.firestore().collection('users').doc(clientUserId).update({
                fcmToken: admin.firestore.FieldValue.delete(),
              });
            }
          }
        } catch (e) {
          console.error(`[sendEmployeeAcceptedNotification] Error removing invalid token:`, e);
        }
      }
      
      return null;
    }
  });


import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../controllers/auth_controller.dart';
import '../../firebase_options.dart';
import 'local_notification_service.dart';

/// Service to handle background notifications using WorkManager and periodic Firestore polling
/// This ensures notifications work even when app is minimized (background)
class BackgroundNotificationService {
  static final BackgroundNotificationService _instance = BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  Timer? _backgroundPollingTimer;
  bool _isPolling = false;
  bool _workManagerInitialized = false;
  final LocalNotificationService _notificationService = LocalNotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize WorkManager for background tasks
  /// This should be called once at app startup
  /// It automatically registers the periodic task so it works even when app is terminated
  Future<void> initializeWorkManager() async {
    if (_workManagerInitialized) {
      debugPrint('[BackgroundNotification] WorkManager already initialized');
      // Still register the task to ensure it's active
      _registerWorkManagerTask();
      return;
    }

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      _workManagerInitialized = true;
      debugPrint('[BackgroundNotification] ✅ WorkManager initialized successfully');
      
      // Register the periodic task immediately after initialization
      // This ensures it's active even if app is terminated before startBackgroundPolling is called
      _registerWorkManagerTask();
    } catch (e) {
      debugPrint('[BackgroundNotification] ❌ Error initializing WorkManager: $e');
    }
  }

  /// Register WorkManager task (internal helper)
  /// This ensures the task is registered even when app is terminated
  void _registerWorkManagerTask() {
    try {
      // Cancel any existing task first to avoid conflicts
      Workmanager().cancelByUniqueName('background-notification-task');
      
      // Register periodic task
      Workmanager().registerPeriodicTask(
        'background-notification-task',
        'backgroundNotificationTask',
        frequency: const Duration(minutes: 15), // Minimum interval for periodic tasks
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false, // Allow even if battery is low
          requiresCharging: false, // Allow even if not charging
          requiresDeviceIdle: false, // Allow even if device is in use
          requiresStorageNotLow: false,
        ),
        initialDelay: const Duration(minutes: 1), // Start after 1 minute
      );
      debugPrint('[BackgroundNotification] ✅ WorkManager task registered (will work even when app is terminated)');
    } catch (e) {
      debugPrint('[BackgroundNotification] ❌ Error registering WorkManager task: $e');
      // Try to register as one-time task as fallback
      try {
        Workmanager().registerOneOffTask(
          'background-notification-task-once',
          'backgroundNotificationTask',
          initialDelay: const Duration(minutes: 1),
          constraints: Constraints(networkType: NetworkType.connected),
        );
        debugPrint('[BackgroundNotification] ✅ Registered as one-time task fallback');
      } catch (e2) {
        debugPrint('[BackgroundNotification] ❌ Error registering one-time task: $e2');
      }
    }
  }

  /// Start background polling when app goes to background
  void startBackgroundPolling() {
    debugPrint('[BackgroundNotification] Starting background polling');
    
    // Always register WorkManager task (even if already polling)
    // This ensures it's registered even when app is terminated
    // WorkManager will handle deduplication
    try {
      // Cancel any existing task first to avoid conflicts
      Workmanager().cancelByUniqueName('background-notification-task');
      
      // Register periodic task with WorkManager (minimum 15 minutes)
      // This ensures background tasks run even when app is killed
      Workmanager().registerPeriodicTask(
        'background-notification-task',
        'backgroundNotificationTask',
        frequency: const Duration(minutes: 15), // Minimum interval for periodic tasks
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false, // Allow even if battery is low
          requiresCharging: false, // Allow even if not charging
          requiresDeviceIdle: false, // Allow even if device is in use
          requiresStorageNotLow: false,
        ),
        initialDelay: const Duration(seconds: 30), // Start checking after 30 seconds
      );
      debugPrint('[BackgroundNotification] ✅ WorkManager periodic task registered (works even when app is terminated)');
    } catch (e) {
      debugPrint('[BackgroundNotification] ❌ Error registering WorkManager task: $e');
      // Try to register as one-time task as fallback
      try {
        Workmanager().registerOneOffTask(
          'background-notification-task-once',
          'backgroundNotificationTask',
          initialDelay: const Duration(minutes: 1),
          constraints: Constraints(networkType: NetworkType.connected),
        );
        debugPrint('[BackgroundNotification] ✅ Registered as one-time task fallback');
      } catch (e2) {
        debugPrint('[BackgroundNotification] ❌ Error registering one-time task: $e2');
      }
    }

    // Only start Timer if not already polling (Timer only works when app process is alive)
    if (_isPolling) {
      debugPrint('[BackgroundNotification] Timer already running, skipping Timer registration');
      return;
    }
    
    _isPolling = true;

    // Also use Timer for immediate polling when app is just backgrounded
    // This works as long as app process is still alive
    // Use shorter interval (15 seconds) for better responsiveness
    // Note: Android may kill the process after a few minutes, but this gives us
    // immediate notifications for the first few minutes after backgrounding
    _backgroundPollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      pollForNotifications();
    });

    // Immediate first poll
    pollForNotifications();
    
    // Also poll after 5 seconds to catch quick changes
    Future.delayed(const Duration(seconds: 5), () {
      if (_isPolling) {
        pollForNotifications();
      }
    });
  }

  /// Stop background polling when app comes to foreground
  void stopBackgroundPolling() {
    if (!_isPolling) {
      return;
    }

    debugPrint('[BackgroundNotification] Stopping background polling');
    
    // Cancel Timer-based polling
    _backgroundPollingTimer?.cancel();
    _backgroundPollingTimer = null;
    
    // Cancel WorkManager task (it will resume when app goes to background again)
    try {
      Workmanager().cancelByUniqueName('background-notification-task');
      debugPrint('[BackgroundNotification] WorkManager task cancelled');
    } catch (e) {
      debugPrint('[BackgroundNotification] Error cancelling WorkManager task: $e');
    }
    
    _isPolling = false;
  }

  /// Poll Firestore for new notifications (called by Timer and WorkManager)
  /// Made public so WorkManager callback can access it
  Future<void> pollForNotifications() async {
    // Prevent concurrent polls
    if (_isPolling && _backgroundPollingTimer == null) {
      debugPrint('[BackgroundNotification] Poll already in progress, skipping');
      return;
    }

    try {
      debugPrint('[BackgroundNotification] ⏰ Polling started at ${DateTime.now()}');
      
      final authController = Get.find<AuthController>();
      final currentUser = authController.currentUser.value;
      
      if (currentUser == null) {
        debugPrint('[BackgroundNotification] No user logged in, skipping poll');
        return;
      }

      debugPrint('[BackgroundNotification] Polling for user: ${currentUser.id} (${currentUser.type})');

      // Check if user is employee or client
      final isEmployee = currentUser.type.toLowerCase() == 'employee';
      
      if (isEmployee) {
        await _pollForEmployeeNotifications(currentUser.id);
      } else {
        await _pollForClientNotifications(currentUser.id);
      }
      
      // Also check for accepted requests (when client accepts employee)
      // This detects requests with statut "Accepted" assigned to this employee
      if (isEmployee) {
        try {
          final employeeDoc = await _firestore
              .collection('employees')
              .where('userId', isEqualTo: currentUser.id)
              .limit(1)
              .get();
          
          if (employeeDoc.docs.isNotEmpty) {
            final employeeDocumentId = employeeDoc.docs.first.id;
            await _checkForAcceptedRequests(employeeDocumentId, _notificationService);
          }
        } catch (acceptedError) {
          debugPrint('[BackgroundNotification] ⚠️ Error checking accepted requests: $acceptedError');
        }
      }
      
      debugPrint('[BackgroundNotification] ✅ Poll completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[BackgroundNotification] ❌ Error polling: $e');
      debugPrint('[BackgroundNotification] Stack trace: $stackTrace');
      
      // If GetX controller is not available (app killed), try to use SharedPreferences
      if (e.toString().contains('GetX') || e.toString().contains('not found')) {
        debugPrint('[BackgroundNotification] ⚠️ GetX not available, this is expected in WorkManager isolate');
        // WorkManager will handle this case separately
      }
    }
  }

  /// Poll for new requests (for employees)
  Future<void> _pollForEmployeeNotifications(String userId) async {
    try {
      debugPrint('[BackgroundNotification] 🔍 Polling employee notifications for userId: $userId');
      
      // Get employee document to find category
      final employeeDoc = await _firestore
          .collection('employees')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (employeeDoc.docs.isEmpty) {
        debugPrint('[BackgroundNotification] ⚠️ No employee document found for userId: $userId');
        return;
      }

      final employeeData = employeeDoc.docs.first.data();
      final categorieId = employeeData['categorieId'];
      final employeeDocumentId = employeeDoc.docs.first.id;

      if (categorieId == null) {
        debugPrint('[BackgroundNotification] ⚠️ No category ID found for employee: $employeeDocumentId');
        return;
      }

      debugPrint('[BackgroundNotification] 📋 Employee category: $categorieId, DocumentId: $employeeDocumentId');

      // Extract category ID as string (requests store categorieId as string, not DocumentReference)
      String categoryIdString;
      if (categorieId is String) {
        categoryIdString = categorieId;
      } else if (categorieId is DocumentReference) {
        categoryIdString = categorieId.id;
      } else {
        debugPrint('[BackgroundNotification] ⚠️ Unknown categorieId type: ${categorieId.runtimeType}');
        return;
      }

      debugPrint('[BackgroundNotification] 🔍 Querying requests with categoryId (string): $categoryIdString');

      // Query for pending requests in this category
      // IMPORTANT: Requests store categorieId as STRING, not DocumentReference
      // Retry logic for network issues
      QuerySnapshot<Map<String, dynamic>>? requestsQuery;
      int retryCount = 0;
      const maxRetries = 2;
      
      while (retryCount <= maxRetries) {
        try {
          // Try with string first (most common case)
          // Use Source.server to force server query and avoid cache issues
          requestsQuery = await _firestore
              .collection('requests')
              .where('categorieId', isEqualTo: categoryIdString)
              .where('statut', isEqualTo: 'Pending')
              .orderBy('createdAt', descending: true)
              .limit(20)
              .get(const GetOptions(source: Source.server))
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  debugPrint('[BackgroundNotification] ⚠️ Query timeout (attempt ${retryCount + 1}/${maxRetries + 1})');
                  throw TimeoutException('Query timeout', const Duration(seconds: 15));
                },
              );
          
          debugPrint('[BackgroundNotification] ✅ Query successful: found ${requestsQuery.docs.length} requests');
          
          // If query returned 0, verify network connectivity by checking if we can reach Firestore
          if (requestsQuery.docs.isEmpty) {
            debugPrint('[BackgroundNotification] ⚠️ Query returned 0 results - checking network connectivity...');
            try {
              // Try a simple Firestore operation to verify connectivity
              final testDoc = await _firestore.collection('categories').doc(categoryIdString).get(
                const GetOptions(source: Source.server),
              ).timeout(const Duration(seconds: 5));
              debugPrint('[BackgroundNotification] ✅ Network connectivity OK - category document exists: ${testDoc.exists}');
            } catch (networkError) {
              debugPrint('[BackgroundNotification] ❌ Network connectivity issue: $networkError');
              debugPrint('[BackgroundNotification] ⚠️ This might be why no requests were found');
            }
          }
          
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          debugPrint('[BackgroundNotification] ❌ Query error (attempt $retryCount/${maxRetries + 1}): $e');
          
          if (retryCount > maxRetries) {
            debugPrint('[BackgroundNotification] ❌ Query failed after $maxRetries retries: $e');
            // Try alternative query with DocumentReference as fallback
            try {
              final categoryRef = _firestore.collection('categories').doc(categoryIdString);
              requestsQuery = await _firestore
                  .collection('requests')
                  .where('categorieId', isEqualTo: categoryRef)
                  .where('statut', isEqualTo: 'Pending')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .get()
                  .timeout(const Duration(seconds: 10));
              debugPrint('[BackgroundNotification] ✅ Fallback query (DocumentReference) successful: found ${requestsQuery.docs.length} requests');
            } catch (e2) {
              debugPrint('[BackgroundNotification] ❌ Fallback query also failed: $e2');
              requestsQuery = null;
            }
            break;
          }
          debugPrint('[BackgroundNotification] 🔄 Retrying query (attempt $retryCount/${maxRetries + 1})...');
          await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
        }
      }
      
      // If query failed, return early
      if (requestsQuery == null) {
        debugPrint('[BackgroundNotification] ⚠️ Query failed completely, skipping notification check');
        return;
      }

      debugPrint('[BackgroundNotification] 📊 Found ${requestsQuery.docs.length} pending requests');
      
      // If query returned 0 but we suspect network issues, log warning
      if (requestsQuery.docs.isEmpty) {
        debugPrint('[BackgroundNotification] ⚠️ Query returned 0 requests');
        debugPrint('[BackgroundNotification] 🔍 Debug: categoryIdString=$categoryIdString, employeeDocumentId=$employeeDocumentId');
        // Try a simple query to see if there are ANY pending requests
        // Use Source.server to force server query
        try {
          final allPending = await _firestore
              .collection('requests')
              .where('statut', isEqualTo: 'Pending')
              .limit(5)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 10));
          debugPrint('[BackgroundNotification] 🔍 Debug: Total pending requests in DB: ${allPending.docs.length}');
          if (allPending.docs.isNotEmpty) {
            final firstRequest = allPending.docs.first.data();
            final firstRequestId = allPending.docs.first.id;
            debugPrint('[BackgroundNotification] 🔍 Debug: Sample request ID: $firstRequestId');
            debugPrint('[BackgroundNotification] 🔍 Debug: Sample request categorieId type: ${firstRequest['categorieId'].runtimeType}, value: ${firstRequest['categorieId']}');
            debugPrint('[BackgroundNotification] 🔍 Debug: Sample request statut: ${firstRequest['statut']}');
            
            // Check if this request matches our category
            final sampleCategorieId = firstRequest['categorieId'];
            String? sampleCategoryIdString;
            if (sampleCategorieId is String) {
              sampleCategoryIdString = sampleCategorieId;
            } else if (sampleCategorieId is DocumentReference) {
              sampleCategoryIdString = sampleCategorieId.id;
            }
            debugPrint('[BackgroundNotification] 🔍 Debug: Sample category ID (string): $sampleCategoryIdString');
            debugPrint('[BackgroundNotification] 🔍 Debug: Our category ID: $categoryIdString');
            debugPrint('[BackgroundNotification] 🔍 Debug: Match: ${sampleCategoryIdString == categoryIdString}');
          } else {
            debugPrint('[BackgroundNotification] ⚠️ No pending requests found in entire database - might be network issue');
          }
        } catch (e) {
          debugPrint('[BackgroundNotification] 🔍 Debug query failed: $e');
          debugPrint('[BackgroundNotification] ⚠️ This confirms network connectivity issue in background');
        }
      }

      // Get last checked IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lastCheckedIdsStr = prefs.getStringList('last_employee_request_ids') ?? [];
      final lastCheckedIds = Set<String>.from(lastCheckedIdsStr);
      
      final currentRequestIds = requestsQuery.docs.map((doc) => doc.id).toSet();
      
      debugPrint('[BackgroundNotification] 📋 Current request IDs: ${currentRequestIds.toList()}');
      debugPrint('[BackgroundNotification] 📋 Last checked IDs: ${lastCheckedIds.toList()}');
      
      // IMPORTANT: If we have requests but lastCheckedIds is empty, treat all as new
      // This handles the case where SharedPreferences was cleared or this is first poll
      final newRequestIds = lastCheckedIds.isEmpty && currentRequestIds.isNotEmpty
          ? currentRequestIds // All requests are new if we haven't checked before
          : currentRequestIds.difference(lastCheckedIds);
      
      debugPrint('[BackgroundNotification] 🆕 New requests: ${newRequestIds.length} (Last checked: ${lastCheckedIds.length}, Current: ${currentRequestIds.length})');
      if (newRequestIds.isNotEmpty) {
        debugPrint('[BackgroundNotification] 🆕 New request IDs: ${newRequestIds.toList()}');
      } else if (currentRequestIds.isNotEmpty && lastCheckedIds.isNotEmpty) {
        debugPrint('[BackgroundNotification] ℹ️ All ${currentRequestIds.length} requests were already checked - no new notifications');
      }
      
      if (newRequestIds.isNotEmpty) {
        debugPrint('[BackgroundNotification] ✅ Found ${newRequestIds.length} new requests for employee');
        
        for (final requestId in newRequestIds) {
          try {
            final requestDoc = requestsQuery.docs.firstWhere((doc) => doc.id == requestId);
            final requestData = requestDoc.data();
            
            // Skip if employee already accepted/refused
            final acceptedIds = List<String>.from(requestData['acceptedEmployeeIds'] ?? []);
            final refusedIds = List<String>.from(requestData['refusedEmployeeIds'] ?? []);
            
            if (acceptedIds.contains(employeeDocumentId)) {
              debugPrint('[BackgroundNotification] ⏭️ Skipping request $requestId: already accepted');
              continue;
            }
            
            if (refusedIds.contains(employeeDocumentId)) {
              debugPrint('[BackgroundNotification] ⏭️ Skipping request $requestId: already refused');
              continue;
            }
            
            // Check if this is the employee's own request
            final clientId = requestData['clientId'];
            if (clientId is DocumentReference) {
              final clientDocId = clientId.id;
              final clientDoc = await _firestore.collection('clients').doc(clientDocId).get();
              if (clientDoc.exists && clientDoc.data()?['userId'] == userId) {
                debugPrint('[BackgroundNotification] ⏭️ Skipping request $requestId: own request');
                continue;
              }
            }

            debugPrint('[BackgroundNotification] 🔔 Showing notification for request: $requestId');
            debugPrint('[BackgroundNotification] 📝 Request data: description=${requestData['description']}, address=${requestData['address']}');
            
            // Show notification
            try {
              await _notificationService.showNewRequestNotification(
                requestId: requestId,
                description: requestData['description'] ?? 'Nouvelle demande',
                address: requestData['address'] ?? '',
              );
              debugPrint('[BackgroundNotification] ✅ Notification displayed successfully for request: $requestId');
            } catch (e, stackTrace) {
              debugPrint('[BackgroundNotification] ❌ Error showing notification for request $requestId: $e');
              debugPrint('[BackgroundNotification] Stack trace: $stackTrace');
            }
          } catch (e) {
            debugPrint('[BackgroundNotification] ❌ Error processing request $requestId: $e');
          }
        }
      }

      // Save updated IDs to SharedPreferences
      await prefs.setStringList('last_employee_request_ids', currentRequestIds.toList());
      debugPrint('[BackgroundNotification] 💾 Saved ${currentRequestIds.length} request IDs to SharedPreferences');
    } catch (e, stackTrace) {
      debugPrint('[BackgroundNotification] ❌ Error polling employee notifications: $e');
      debugPrint('[BackgroundNotification] Stack trace: $stackTrace');
    }
  }

  /// Poll for employee acceptances (for clients)
  Future<void> _pollForClientNotifications(String userId) async {
    try {
      debugPrint('[BackgroundNotification] 🔍 Polling client notifications for userId: $userId');
      
      // Get client document ID
      final clientDoc = await _firestore
          .collection('clients')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (clientDoc.docs.isEmpty) {
        debugPrint('[BackgroundNotification] ⚠️ No client document found for userId: $userId');
        return;
      }

      final clientDocumentId = clientDoc.docs.first.id;
      debugPrint('[BackgroundNotification] 📋 Client document ID: $clientDocumentId');

      // Query for pending requests created by this client
      // Use timeout to prevent hanging queries
      final requestsQuery = await _firestore
          .collection('requests')
          .where('clientId', isEqualTo: _firestore.collection('clients').doc(clientDocumentId))
          .where('statut', isEqualTo: 'Pending')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[BackgroundNotification] ⚠️ Query timeout - returning empty result');
              return _firestore.collection('requests').limit(0).get();
            },
          );

      debugPrint('[BackgroundNotification] 📊 Found ${requestsQuery.docs.length} pending requests for client');
      
      // If query returned 0 but we suspect network issues, log warning
      if (requestsQuery.docs.isEmpty) {
        debugPrint('[BackgroundNotification] ⚠️ Query returned 0 requests - this might be a network issue');
      }

      // Get SharedPreferences for tracking
      final prefs = await SharedPreferences.getInstance();

      for (final requestDoc in requestsQuery.docs) {
        final requestId = requestDoc.id;
        final requestData = requestDoc.data();
        
        final acceptedIds = List<String>.from(requestData['acceptedEmployeeIds'] ?? []);
        
        // Get last checked IDs for this request from SharedPreferences
        final lastCheckedKey = 'last_accepted_$requestId';
        final lastCheckedStr = prefs.getString(lastCheckedKey) ?? '';
        final lastCheckedIds = lastCheckedStr.isEmpty 
            ? <String>{}
            : lastCheckedStr.split(',').where((id) => id.isNotEmpty).toSet();
        
        // Find newly accepted employees
        final newAcceptedIds = acceptedIds.where((id) => !lastCheckedIds.contains(id)).toList();
        
        debugPrint('[BackgroundNotification] 🆕 Request $requestId: ${newAcceptedIds.length} new acceptances (Last: ${lastCheckedIds.length}, Current: ${acceptedIds.length})');
        
        if (newAcceptedIds.isNotEmpty) {
          debugPrint('[BackgroundNotification] ✅ Found ${newAcceptedIds.length} new employee acceptances for client');
          
          // Get employee names and show notifications
          for (final employeeId in newAcceptedIds) {
            try {
              final employeeDoc = await _firestore
                  .collection('employees')
                  .doc(employeeId)
                  .get();
              
              if (employeeDoc.exists) {
                final employeeData = employeeDoc.data();
                final employeeName = employeeData?['nomComplet'] ?? 'Un employé';
                final requestDescription = requestData['description'] ?? 'Votre demande';
                
                debugPrint('[BackgroundNotification] 🔔 Showing notification: $employeeName accepted request $requestId');
                _notificationService.showEmployeeAcceptedNotification(
                  requestId: requestId,
                  employeeName: employeeName,
                  requestDescription: requestDescription,
                );
              }
            } catch (e) {
              debugPrint('[BackgroundNotification] ❌ Error getting employee name for $employeeId: $e');
            }
          }
        }
        
        // Save updated IDs to SharedPreferences
        await prefs.setString(lastCheckedKey, acceptedIds.join(','));
      }
      
      debugPrint('[BackgroundNotification] 💾 Saved client notification state to SharedPreferences');
    } catch (e, stackTrace) {
      debugPrint('[BackgroundNotification] ❌ Error polling client notifications: $e');
      debugPrint('[BackgroundNotification] Stack trace: $stackTrace');
    }
  }

  /// Reset tracking when user logs out
  Future<void> reset() async {
    // Clear SharedPreferences tracking
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_employee_request_ids');
      // Clear all last_accepted_* keys
      final keys = prefs.getKeys().where((key) => key.startsWith('last_accepted_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
      debugPrint('[BackgroundNotification] 🗑️ Cleared SharedPreferences tracking data');
    } catch (e) {
      debugPrint('[BackgroundNotification] ❌ Error clearing SharedPreferences: $e');
    }
    
    stopBackgroundPolling();
  }

  /// Dispose resources
  Future<void> dispose() async {
    stopBackgroundPolling();
    await reset();
  }
}

/// Top-level function for WorkManager callback (must be top-level)
/// This runs in a separate isolate, so we can't use GetX controllers
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('[WorkManager] Background task executed: $task');
    
    try {
      // Initialize Firebase in the isolate
      // Import firebase_options dynamically
      await _initializeFirebaseInIsolate();
      
      // Poll for notifications directly (without GetX)
      await _pollForNotificationsInIsolate();
      
      debugPrint('[WorkManager] Background task completed successfully');
      return Future.value(true);
    } catch (e) {
      debugPrint('[WorkManager] Error in background task: $e');
      return Future.value(false);
    }
  });
}

/// Initialize Firebase in WorkManager isolate
Future<void> _initializeFirebaseInIsolate() async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      debugPrint('[WorkManager] Firebase already initialized');
      return;
    }
    
    // Initialize Firebase in the isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[WorkManager] Firebase initialized in isolate');
  } catch (e) {
    // If already initialized, ignore error
    if (e.toString().contains('already exists') || 
        e.toString().contains('duplicate-app')) {
      debugPrint('[WorkManager] Firebase already initialized (error ignored)');
    } else {
      debugPrint('[WorkManager] Error initializing Firebase: $e');
    }
  }
}

/// Poll for notifications in WorkManager isolate (without GetX)
Future<void> _pollForNotificationsInIsolate() async {
  try {
    final firestore = FirebaseFirestore.instance;
    final notificationService = LocalNotificationService();
    
    // Get user info from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('current_user_id');
    final userType = prefs.getString('current_user_type');
    
    if (userId == null || userType == null) {
      debugPrint('[WorkManager] No user logged in, skipping poll');
      return;
    }
    
    debugPrint('[WorkManager] Polling for notifications for user: $userId (type: $userType)');
    
    final isEmployee = userType == 'employee';
    
    if (isEmployee) {
      await _pollForEmployeeNotificationsInIsolate(userId, firestore, notificationService);
    } else {
      await _pollForClientNotificationsInIsolate(userId, firestore, notificationService);
    }
  } catch (e) {
    debugPrint('[WorkManager] Error polling notifications: $e');
  }
}

/// Poll for employee notifications in isolate
Future<void> _pollForEmployeeNotificationsInIsolate(
  String userId,
  FirebaseFirestore firestore,
  LocalNotificationService notificationService,
) async {
  try {
    // Get employee document
    final employeeDoc = await firestore
        .collection('employees')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (employeeDoc.docs.isEmpty) return;

    final employeeData = employeeDoc.docs.first.data();
    final categorieId = employeeData['categorieId'];
    final employeeDocumentId = employeeDoc.docs.first.id;

    if (categorieId == null) return;

    // Extract category ID as string (requests store categorieId as string)
    String categoryIdString;
    if (categorieId is String) {
      categoryIdString = categorieId;
    } else if (categorieId is DocumentReference) {
      categoryIdString = categorieId.id;
    } else {
      debugPrint('[WorkManager] Unknown categorieId type: ${categorieId.runtimeType}');
      return;
    }

    debugPrint('[WorkManager] Querying requests with categoryId (string): $categoryIdString');

    // Query with string (requests store categorieId as string, not DocumentReference)
    QuerySnapshot<Map<String, dynamic>> requestsQuery;
    try {
      requestsQuery = await firestore
          .collection('requests')
          .where('categorieId', isEqualTo: categoryIdString)
          .where('statut', isEqualTo: 'Pending')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      debugPrint('[WorkManager] Query successful: found ${requestsQuery.docs.length} requests');
    } catch (e) {
      debugPrint('[WorkManager] String query failed, trying DocumentReference: $e');
      // Fallback to DocumentReference
      final categoryRef = firestore.collection('categories').doc(categoryIdString);
      requestsQuery = await firestore
          .collection('requests')
          .where('categorieId', isEqualTo: categoryRef)
          .where('statut', isEqualTo: 'Pending')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      debugPrint('[WorkManager] DocumentReference query successful: found ${requestsQuery.docs.length} requests');
    }

    // Get last checked request IDs from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final lastCheckedKey = 'last_employee_request_ids';
    final lastCheckedStr = prefs.getString(lastCheckedKey) ?? '';
    final lastCheckedIds = lastCheckedStr.isEmpty 
        ? <String>{}
        : lastCheckedStr.split(',').where((id) => id.isNotEmpty).toSet();
    
    final currentRequestIds = <String>{};
    final newRequestIds = <String>{};

    for (final requestDoc in requestsQuery.docs) {
      final requestId = requestDoc.id;
      final requestData = requestDoc.data();
      
      currentRequestIds.add(requestId);
      
      // Skip if already checked
      if (lastCheckedIds.contains(requestId)) {
        continue;
      }
      
      final acceptedIds = List<String>.from(requestData['acceptedEmployeeIds'] ?? []);
      final refusedIds = List<String>.from(requestData['refusedEmployeeIds'] ?? []);
      
      if (acceptedIds.contains(employeeDocumentId) || 
          refusedIds.contains(employeeDocumentId) ||
          requestData['clientId'] == userId) {
        continue;
      }

      newRequestIds.add(requestId);
      
      // Show notification
      notificationService.showNewRequestNotification(
        requestId: requestId,
        description: requestData['description'] ?? 'Nouvelle demande',
        address: requestData['address'] ?? '',
      );
    }
    
    // Save updated checked IDs
    if (currentRequestIds.isNotEmpty) {
      await prefs.setString(lastCheckedKey, currentRequestIds.join(','));
    }
  } catch (e) {
    debugPrint('[WorkManager] Error polling employee notifications: $e');
  }
}

/// Poll for client notifications in isolate
Future<void> _pollForClientNotificationsInIsolate(
  String userId,
  FirebaseFirestore firestore,
  LocalNotificationService notificationService,
) async {
  try {
    final clientDoc = await firestore
        .collection('clients')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (clientDoc.docs.isEmpty) return;

    final clientDocumentId = clientDoc.docs.first.id;

    final requestsQuery = await firestore
        .collection('requests')
        .where('clientId', isEqualTo: firestore.collection('clients').doc(clientDocumentId))
        .where('statut', isEqualTo: 'Pending')
        .get();

    // Get last checked state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    
    for (final requestDoc in requestsQuery.docs) {
      final requestId = requestDoc.id;
      final requestData = requestDoc.data();
      
      final acceptedIds = List<String>.from(requestData['acceptedEmployeeIds'] ?? []);
      
      // Get last checked IDs for this request
      final lastCheckedKey = 'last_accepted_$requestId';
      final lastCheckedStr = prefs.getString(lastCheckedKey) ?? '';
      final lastCheckedIds = lastCheckedStr.isEmpty 
          ? <String>{}
          : lastCheckedStr.split(',').where((id) => id.isNotEmpty).toSet();
      
      final newAcceptedIds = acceptedIds.where((id) => !lastCheckedIds.contains(id)).toList();
      
      if (newAcceptedIds.isNotEmpty) {
        for (final employeeId in newAcceptedIds) {
          try {
            final employeeDoc = await firestore
                .collection('employees')
                .doc(employeeId)
                .get();
            
            if (employeeDoc.exists) {
              final employeeData = employeeDoc.data();
              final employeeName = employeeData?['nomComplet'] ?? 'Un employé';
              final requestDescription = requestData['description'] ?? 'Votre demande';
              
              notificationService.showEmployeeAcceptedNotification(
                requestId: requestId,
                employeeName: employeeName,
                requestDescription: requestDescription,
              );
            }
          } catch (e) {
            debugPrint('[WorkManager] Error getting employee name: $e');
          }
        }
        
        // Save updated IDs
        await prefs.setString(lastCheckedKey, acceptedIds.join(','));
      }
    }
  } catch (e) {
    debugPrint('[WorkManager] Error polling client notifications: $e');
  }
}

/// Check for accepted requests for an employee (when client accepts them)
Future<void> _checkForAcceptedRequests(
  String employeeDocumentId,
  LocalNotificationService notificationService,
) async {
  try {
    debugPrint('[BackgroundNotification] 🔍 Checking for accepted requests for employee: $employeeDocumentId');
    
    final firestore = FirebaseFirestore.instance;
    
    // Query for requests with statut "Accepted" and employeeId matching this employee
    final requestsQuery = await firestore
        .collection('requests')
        .where('statut', isEqualTo: 'Accepted')
        .where('employeeId', isEqualTo: employeeDocumentId)
        .get();
    
    debugPrint('[BackgroundNotification] Found ${requestsQuery.docs.length} accepted requests');
    
    // Get last checked request IDs from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final lastCheckedKey = 'last_employee_accepted_request_ids_$employeeDocumentId';
    final lastCheckedStr = prefs.getString(lastCheckedKey) ?? '';
    final lastCheckedIds = lastCheckedStr.isEmpty
        ? <String>{}
        : lastCheckedStr.split(',').where((id) => id.isNotEmpty).toSet();
    
    final currentRequestIds = <String>{};
    final newRequestIds = <String>{};
    
    for (final requestDoc in requestsQuery.docs) {
      final requestId = requestDoc.id;
      final requestData = requestDoc.data();
      
      currentRequestIds.add(requestId);
      
      // Skip if already checked
      if (lastCheckedIds.contains(requestId)) {
        continue;
      }
      
      // This is a new accepted request - notify the employee
      newRequestIds.add(requestId);
      
      // Get client name from request
      String clientName = 'Un client';
      try {
        final clientId = requestData['clientId'];
        if (clientId != null) {
          // clientId might be a DocumentReference or a string
          String clientDocId;
          if (clientId is DocumentReference) {
            clientDocId = clientId.id;
          } else {
            clientDocId = clientId.toString();
          }
          
          final clientDoc = await firestore.collection('clients').doc(clientDocId).get();
          if (clientDoc.exists) {
            final clientData = clientDoc.data();
            final clientUserId = clientData?['userId'];
            if (clientUserId != null) {
              String userIdStr;
              if (clientUserId is DocumentReference) {
                userIdStr = clientUserId.id;
              } else {
                userIdStr = clientUserId.toString();
              }
              
              final userDoc = await firestore.collection('users').doc(userIdStr).get();
              if (userDoc.exists) {
                final userData = userDoc.data();
                clientName = userData?['nomComplet'] ?? 'Un client';
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[BackgroundNotification] ⚠️ Error getting client name: $e');
      }
      
      // Show notification
      notificationService.showClientAcceptedEmployeeNotification(
        requestId: requestId,
        clientName: clientName,
        requestDescription: requestData['description'] ?? 'Nouvelle demande',
      );
      
      debugPrint('[BackgroundNotification] ✅ Notified employee about accepted request $requestId');
    }
    
    // Save updated checked IDs
    if (currentRequestIds.isNotEmpty) {
      await prefs.setString(lastCheckedKey, currentRequestIds.join(','));
    }
    
    if (newRequestIds.isNotEmpty) {
      debugPrint('[BackgroundNotification] 🆕 Found ${newRequestIds.length} new accepted requests: ${newRequestIds.toList()}');
    }
  } catch (e) {
    debugPrint('[BackgroundNotification] ❌ Error checking for accepted requests: $e');
  }
}

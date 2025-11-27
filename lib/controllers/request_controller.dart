import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../data/models/request_model.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/mission_repository.dart';
import '../../data/repositories/cancellation_report_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/cancellation_report_model.dart';
import '../../core/utils/logger.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/qr_code_service.dart';
import '../../core/services/location_service.dart';
import '../../core/helpers/snackbar_helper.dart';
import '../../components/employee_cancellation_report_form_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_controller.dart';

/// Controller pour gérer les demandes (GetX)
class RequestController extends GetxController {
  final RequestRepository _requestRepository = RequestRepository();
  final ChatRepository _chatRepository = ChatRepository();
  final MissionRepository _missionRepository = MissionRepository();
  final CancellationReportRepository _cancellationReportRepository = CancellationReportRepository();
  final QRCodeService _qrCodeService = QRCodeService();

  // Observable states
  final RxList<RequestModel> requests = <RequestModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasReceivedFirstData = false.obs; // Track if we've received first stream data
  final RxString errorMessage = ''.obs;
  final Rx<RequestModel?> selectedRequest = Rx<RequestModel?>(null);
  
  // Stream subscription management
  StreamSubscription<List<RequestModel>>? _requestsStreamSubscription;
  StreamSubscription<List<RequestModel>>? _cancelledRequestsStreamSubscription;
  String? _currentCategorieId;
  String? _currentClientId;
  
  // Cache employee document ID for notification count calculation
  String? _currentEmployeeDocumentId;
  
  // Notification service
  final LocalNotificationService _notificationService = LocalNotificationService();
  
    // Track previous request IDs to detect new ones
    final Set<String> _previousRequestIds = <String>{};
    
    // Track notified employees per request to avoid duplicate notifications for clients
    final Map<String, Set<String>> _notifiedEmployeesPerRequest = <String, Set<String>>{};
    
    // Track previous request statuses to detect cancellations
    final Map<String, String> _previousRequestStatuses = <String, String>{};
    
    // Track open cancellation report dialogs to avoid duplicates
    final Set<String> _openCancellationDialogs = <String>{};
  
  // Notification count for employees (pending requests excluding own requests and already dealt with)
  int get notificationCount {
    try {
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user == null) return 0;
      
      return requests.where((request) {
        // Only count pending requests
        if (request.statut.toLowerCase() != 'pending') return false;
        
        // Don't count own requests
        if (request.clientId == user.id) return false;
        
        // Don't count requests that employee has already accepted
        if (_currentEmployeeDocumentId != null && 
            request.acceptedEmployeeIds.contains(_currentEmployeeDocumentId)) {
          return false;
        }
        
        // Don't count requests that employee has already refused
        if (_currentEmployeeDocumentId != null && 
            request.refusedEmployeeIds.contains(_currentEmployeeDocumentId)) {
          return false;
        }
        
        return true;
      }).length;
    } catch (e) {
      // AuthController not found or not initialized
      return 0;
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Initialize notification service
    _notificationService.initialize();
  }
  
  @override
  void onClose() {
    _requestsStreamSubscription?.cancel();
    _cancelledRequestsStreamSubscription?.cancel();
    super.onClose();
  }

  /// Charger les demandes d'un client
  Future<void> loadRequestsByClient(String clientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final requestList = await _requestRepository.getRequestsByClientId(clientId);
      Future.microtask(() {
        requests.assignAll(requestList);
        isLoading.value = false;
      });
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.loadRequestsByClient', e, stackTrace);
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          SnackbarHelper.showError(errorMessage.value);
        });
      });
    }
  }

  /// Charger les demandes par catégorie
  Future<void> loadRequestsByCategorie(String categorieId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final requestList = await _requestRepository.getRequestsByCategorieId(categorieId);
      Future.microtask(() {
        requests.assignAll(requestList);
        isLoading.value = false;
      });
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.loadRequestsByCategorie', e, stackTrace);
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          SnackbarHelper.showError(errorMessage.value);
        });
      });
    }
  }

  /// Charger les demandes par statut
  Future<void> loadRequestsByStatut(String statut) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final requestList = await _requestRepository.getRequestsByStatut(statut);
      Future.microtask(() {
        requests.assignAll(requestList);
        isLoading.value = false;
      });
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.loadRequestsByStatut', e, stackTrace);
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          SnackbarHelper.showError(errorMessage.value);
        });
      });
    }
  }

  /// Charger les demandes annulées pour un employé
  Future<List<RequestModel>> getCancelledRequestsByEmployeeId(String employeeId) async {
    try {
      return await _requestRepository.getCancelledRequestsByEmployeeId(employeeId);
    } catch (e, stackTrace) {
      Logger.logError('RequestController.getCancelledRequestsByEmployeeId', e, stackTrace);
      return [];
    }
  }

  /// Stream des demandes d'un client (temps réel)
  Future<void> streamRequestsByClient(String clientId) async {
    // Cancel existing subscription if switching to a different client
    if (_currentClientId == clientId && _requestsStreamSubscription != null) {
      debugPrint('[RequestController] Stream already active for client: $clientId, skipping');
      return;
    }

    _requestsStreamSubscription?.cancel();
    _requestsStreamSubscription = null;
    
    _currentClientId = clientId;
    _currentCategorieId = null;
    
    hasReceivedFirstData.value = false;
    isLoading.value = true;

      // Load initial data first
    try {
      debugPrint('[RequestController] Loading initial data for client: $clientId');
      final initialData = await _requestRepository.getRequestsByClientId(clientId);
      // Filtrer les demandes annulées pour ne pas les afficher au client
      final filteredInitialData = initialData.where((request) => 
        request.statut.toLowerCase() != 'cancelled'
      ).toList();
      requests.assignAll(filteredInitialData);
      hasReceivedFirstData.value = true;
      isLoading.value = false;
      update();
      debugPrint('[RequestController] Initial data loaded: ${filteredInitialData.length} requests (${initialData.length - filteredInitialData.length} cancelled filtered)');
    } catch (e) {
      debugPrint('[RequestController] Error loading initial data: $e');
      Logger.logError('RequestController.streamRequestsByClient', e, StackTrace.current);
    }
    
    _requestsStreamSubscription = _requestRepository.streamRequestsByClientId(clientId).listen(
      (requestList) {
        hasReceivedFirstData.value = true;
        
        // Filtrer les demandes annulées pour ne pas les afficher au client
        final filteredRequests = requestList.where((request) => 
          request.statut.toLowerCase() != 'cancelled'
        ).toList();
        
        // Detect and notify about new employee acceptances for clients
        _detectAndNotifyEmployeeAcceptances(filteredRequests, clientId);
        
        requests.assignAll(filteredRequests);
        update();
        isLoading.value = false;
        debugPrint('[RequestController] ✅ Stream update: ${filteredRequests.length} requests for client $clientId (${requestList.length - filteredRequests.length} cancelled filtered)');
      },
      onError: (error) {
        errorMessage.value = error.toString();
        Logger.logError('RequestController.streamRequestsByClient', error, StackTrace.current);
        isLoading.value = false;
        debugPrint('[RequestController] ❌ Stream error: $error');
      },
      cancelOnError: false,
    );
  }

  /// Set employee document ID for notification count calculation
  void setEmployeeDocumentId(String? employeeDocumentId) {
    _currentEmployeeDocumentId = employeeDocumentId;
  }

  /// Stream des demandes par catégorie (temps réel)
  Future<void> streamRequestsByCategorie(String categorieId, {String? employeeDocumentId}) async {
    // Only recreate if category changed or stream doesn't exist
    if (_currentCategorieId == categorieId && _requestsStreamSubscription != null) {
      debugPrint('[RequestController] Stream already active for category: $categorieId, skipping');
      return;
    }
    
    // Cancel existing subscription
    _requestsStreamSubscription?.cancel();
    _requestsStreamSubscription = null;
    
    _currentCategorieId = categorieId;
    _currentClientId = null;
    
    // Cache employee document ID if provided
    if (employeeDocumentId != null) {
      _currentEmployeeDocumentId = employeeDocumentId;
      // Start listening to cancelled requests for this employee
      _startListeningToCancelledRequests(employeeDocumentId);
    }
    
    // Reset first data flag when starting new stream
    hasReceivedFirstData.value = false;
    isLoading.value = true;
    
    Logger.logInfo('RequestController.streamRequestsByCategorie', 'Starting stream for category: $categorieId');
    debugPrint('[RequestController] Starting NEW stream for category: $categorieId');
    
    // Load initial data first to ensure UI has data immediately
    try {
      debugPrint('[RequestController] Loading initial data for category: $categorieId');
      final initialData = await _requestRepository.getRequestsByCategorieId(categorieId);
      requests.assignAll(initialData);
      hasReceivedFirstData.value = true;
      isLoading.value = false;
      debugPrint('[RequestController] Initial data loaded: ${initialData.length} requests');
    } catch (e) {
      debugPrint('[RequestController] Error loading initial data: $e');
      // Continue with stream even if initial load fails
    }
    
    // Now start the stream for real-time updates
    _requestsStreamSubscription = _requestRepository.streamRequestsByCategorieId(categorieId).listen(
      (requestList) {
        debugPrint('[RequestController] ⚡ Stream received ${requestList.length} requests');
        
        // Mark that we've received first data
        hasReceivedFirstData.value = true;
        
        // Detect new requests and show notifications
        _detectAndNotifyNewRequests(requestList);
        
        // Detect cancelled requests and show report to employee
        _detectAndNotifyCancellations(requestList);
        
        // Update using assignAll - this should trigger GetX reactivity
        requests.assignAll(requestList);
        
        // Update previous statuses
        for (final request in requestList) {
          _previousRequestStatuses[request.id] = request.statut;
        }
        
        // Force update to ensure all listeners are notified
        update();
        
        isLoading.value = false;
        
        // Debug log to verify updates
        Logger.logInfo('RequestController.streamRequestsByCategorie', 'Stream update: ${requestList.length} requests for category $categorieId');
        debugPrint('[RequestController] ✅ Updated requests list, current count: ${requests.length}');
      },
      onError: (error) {
        errorMessage.value = error.toString();
        Logger.logError('RequestController.streamRequestsByCategorie', error, StackTrace.current);
        debugPrint('[RequestController] ❌ Stream error: $error');
        isLoading.value = false;
      },
      cancelOnError: false, // Keep stream alive on error
      onDone: () {
        Logger.logInfo('RequestController.streamRequestsByCategorie', 'Stream completed for category: $categorieId');
        debugPrint('[RequestController] ⚠️ Stream done for category: $categorieId');
      },
    );
    isLoading.value = true;
    
    debugPrint('[RequestController] Stream subscription created, isPaused: ${_requestsStreamSubscription?.isPaused}');
  }

  /// Démarrer l'écoute des demandes annulées pour un employé
  void _startListeningToCancelledRequests(String employeeId) async {
    // Cancel existing subscription if any
    _cancelledRequestsStreamSubscription?.cancel();
    
    debugPrint('[RequestController] Starting stream for cancelled requests for employee: $employeeId');
    
    // Load existing cancelled requests first
    try {
      final existingCancelledRequests = await _requestRepository.getCancelledRequestsByEmployeeId(employeeId);
      debugPrint('[RequestController] Found ${existingCancelledRequests.length} existing cancelled requests');
      
      // Process existing cancelled requests
      for (final request in existingCancelledRequests) {
        _previousRequestStatuses[request.id] = request.statut;
        _checkAndShowCancellationReport(request);
      }
    } catch (e) {
      debugPrint('[RequestController] Error loading existing cancelled requests: $e');
    }
    
    // Now start the stream for real-time updates
    _cancelledRequestsStreamSubscription = _requestRepository.streamCancelledRequestsByEmployeeId(employeeId).listen(
      (cancelledRequests) {
        debugPrint('[RequestController] ⚡ Cancelled requests stream received ${cancelledRequests.length} requests');
        
        // Process each cancelled request
        for (final request in cancelledRequests) {
          // Check if this is a new cancellation
          final previousStatus = _previousRequestStatuses[request.id];
          if (previousStatus != null && previousStatus.toLowerCase() == 'cancelled') {
            continue; // Already processed
          }
          
          // Update previous status
          _previousRequestStatuses[request.id] = request.statut;
          
          // Check if employee has already filled the report
          _checkAndShowCancellationReport(request);
        }
      },
      onError: (error) {
        Logger.logError('RequestController._startListeningToCancelledRequests', error, StackTrace.current);
        debugPrint('[RequestController] ❌ Cancelled requests stream error: $error');
      },
      cancelOnError: false,
    );
  }

  /// Vérifier et afficher le formulaire de rapport d'annulation
  Future<void> _checkAndShowCancellationReport(RequestModel request) async {
    try {
      // Check if dialog is already open for this request
      if (_openCancellationDialogs.contains(request.id)) {
        debugPrint('[RequestController] Dialog already open for request ${request.id}');
        return;
      }

      // Check if employee has already filled the report
      final existingReport = await _cancellationReportRepository.getReportByRequestId(request.id);
      if (existingReport != null && existingReport.employeeNotificationReason != null && existingReport.employeeNotificationReason!.isNotEmpty) {
        debugPrint('[RequestController] Employee already filled report for request ${request.id}');
        return; // Employee already filled the report
      }

      // Get client name
      String? clientName;
      try {
        final userRepository = UserRepository();
        final clientUser = await userRepository.getUserById(request.clientId);
        clientName = clientUser?.nomComplet;
      } catch (e) {
        debugPrint('Erreur lors du chargement du client: $e');
      }

      // Get client reason from report
      String? clientReason;
      if (existingReport != null) {
        clientReason = existingReport.clientReason;
      }

      // Mark dialog as open
      _openCancellationDialogs.add(request.id);

      // Show the form
      debugPrint('[RequestController] Showing cancellation report form for request ${request.id}');
      _showCancellationReportFormToEmployee(request, clientReason, clientName);
    } catch (e) {
      debugPrint('[RequestController] Error checking cancellation report: $e');
      Logger.logError('RequestController._checkAndShowCancellationReport', e, StackTrace.current);
    }
  }
  
  /// Arrêter le stream actif
  void stopStreaming() {
    _requestsStreamSubscription?.cancel();
    _requestsStreamSubscription = null;
    _cancelledRequestsStreamSubscription?.cancel();
    _cancelledRequestsStreamSubscription = null;
    _currentCategorieId = null;
    _currentClientId = null;
    _currentEmployeeDocumentId = null;
    _previousRequestIds.clear();
    _notifiedEmployeesPerRequest.clear(); // Clear notification tracking
    _previousRequestStatuses.clear();
    _openCancellationDialogs.clear(); // Clear open dialogs tracking
    hasReceivedFirstData.value = false;
  }

  /// Détecter les nouvelles demandes et afficher des notifications
  void _detectAndNotifyNewRequests(List<RequestModel> newRequests) {
    try {
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user == null) return;

      // Filter pending requests not made by current user and not already dealt with
      // Only notify for requests that employee hasn't accepted or refused
      final pendingRequests = newRequests.where((request) {
        // Only pending requests
        if (request.statut.toLowerCase() != 'pending') return false;
        
        // Don't notify for own requests
        if (request.clientId == user.id) return false;
        
        // Don't notify for requests that employee has already accepted
        if (_currentEmployeeDocumentId != null && 
            request.acceptedEmployeeIds.contains(_currentEmployeeDocumentId)) {
          return false;
        }
        
        // Don't notify for requests that employee has already refused
        if (_currentEmployeeDocumentId != null && 
            request.refusedEmployeeIds.contains(_currentEmployeeDocumentId)) {
          return false;
        }
        
        return true;
      }).toList();

      // Find new requests (not in previous list)
      final newRequestIds = pendingRequests.map((r) => r.id).toSet();
      final actuallyNewRequests = pendingRequests.where((request) {
        return !_previousRequestIds.contains(request.id);
      }).toList();

      // Show notifications only for new requests that employee hasn't dealt with
      for (final request in actuallyNewRequests) {
        _notificationService.showNewRequestNotification(
          requestId: request.id,
          description: request.description,
          address: request.address,
        );
      }

      // Update previous request IDs (only for requests that can trigger notifications)
      _previousRequestIds.clear();
      _previousRequestIds.addAll(newRequestIds);
    } catch (e) {
      // Silently handle errors to avoid breaking the stream
      Logger.logError('RequestController._detectAndNotifyNewRequests', e, StackTrace.current);
    }
  }

  /// Détecter les annulations de demandes et afficher le formulaire de rapport à l'employé
  void _detectAndNotifyCancellations(List<RequestModel> requestList) async {
    try {
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user == null) return;

      // Vérifier si l'utilisateur est un employé
      if (user.type.toLowerCase() != 'employee') return;

      // Récupérer l'ID du document employé
      if (_currentEmployeeDocumentId == null) {
        try {
          final employeeRepository = EmployeeRepository();
          final employee = await employeeRepository.getEmployeeByUserId(user.id);
          if (employee != null) {
            _currentEmployeeDocumentId = employee.id;
          } else {
            return; // Pas d'employé trouvé
          }
        } catch (e) {
          debugPrint('Erreur lors de la récupération de l\'employé: $e');
          return;
        }
      }

      for (final request in requestList) {
        // Vérifier si la demande a été annulée et était assignée à cet employé
        if (request.statut.toLowerCase() == 'cancelled' &&
            request.employeeId != null &&
            request.employeeId == _currentEmployeeDocumentId) {
          
          // Vérifier si c'est une nouvelle annulation (statut précédent n'était pas 'cancelled')
          final previousStatus = _previousRequestStatuses[request.id];
          if (previousStatus != null && previousStatus.toLowerCase() == 'cancelled') {
            continue; // Déjà notifié
          }

          // Vérifier si l'employé a déjà rempli son rapport
          try {
            final existingReport = await _cancellationReportRepository.getReportByRequestId(request.id);
            if (existingReport != null && existingReport.employeeNotificationReason != null && existingReport.employeeNotificationReason!.isNotEmpty) {
              continue; // L'employé a déjà rempli son rapport
            }
          } catch (e) {
            debugPrint('Erreur lors de la vérification du rapport existant: $e');
          }

          // Récupérer le rapport d'annulation du client
          try {
            final report = await _cancellationReportRepository.getReportByRequestId(request.id);
            
            // Récupérer le nom du client
            String? clientName;
            try {
              final userRepository = UserRepository();
              final clientUser = await userRepository.getUserById(request.clientId);
              clientName = clientUser?.nomComplet;
            } catch (e) {
              debugPrint('Erreur lors du chargement du client: $e');
            }

            // Afficher le formulaire de rapport pour l'employé
            _showCancellationReportFormToEmployee(request, report?.clientReason, clientName);
          } catch (e) {
            debugPrint('Erreur lors de la récupération du rapport: $e');
            // Afficher quand même le formulaire sans raison du client
            _showCancellationReportFormToEmployee(request, null, null);
          }
        }
      }
    } catch (e) {
      // Silently handle errors to avoid breaking the stream
      Logger.logError('RequestController._detectAndNotifyCancellations', e, StackTrace.current);
    }
  }

  /// Afficher le formulaire de rapport d'annulation à l'employé
  void _showCancellationReportFormToEmployee(
    RequestModel request,
    String? clientReason,
    String? clientName,
  ) {
    try {
      Get.dialog(
        EmployeeCancellationReportFormDialog(
          requestId: request.id,
          clientName: clientName,
          clientReason: clientReason,
          onConfirm: (employeeReason) async {
            // Mettre à jour le rapport avec la raison de l'employé
            try {
              final existingReport = await _cancellationReportRepository.getReportByRequestId(request.id);
              if (existingReport != null) {
                final updatedReport = existingReport.copyWith(
                  employeeNotificationReason: employeeReason,
                  updatedAt: DateTime.now(),
                );
                await _cancellationReportRepository.updateReport(updatedReport);
                debugPrint('[RequestController] Rapport employé mis à jour pour la demande ${request.id}');
              } else {
                // Créer un nouveau rapport si aucun n'existe
                final reportId = FirebaseFirestore.instance.collection('cancellation_reports').doc().id;
                final now = DateTime.now();
                final newReport = CancellationReportModel(
                  id: reportId,
                  requestId: request.id,
                  clientId: request.clientId,
                  employeeId: request.employeeId,
                  clientReason: clientReason,
                  employeeNotificationReason: employeeReason,
                  createdAt: now,
                  updatedAt: now,
                );
                await _cancellationReportRepository.createReport(newReport);
                debugPrint('[RequestController] Nouveau rapport créé pour la demande ${request.id}');
              }
              
              // Remove from open dialogs set
              _openCancellationDialogs.remove(request.id);
              
              // Show success message
              SnackbarHelper.showSuccess('report_submitted_successfully'.tr);
            } catch (e) {
              debugPrint('Erreur lors de la mise à jour du rapport: $e');
              SnackbarHelper.showError('error_submitting_report'.tr);
              rethrow; // Re-throw to let the dialog handle it
            }
          },
        ),
        barrierDismissible: false,
      ).then((_) {
        // Remove from open dialogs when dialog is closed (even if cancelled)
        _openCancellationDialogs.remove(request.id);
      });
    } catch (e) {
      // Remove from open dialogs on error
      _openCancellationDialogs.remove(request.id);
      debugPrint('Erreur lors de l\'affichage du formulaire de rapport: $e');
    }
  }

  /// Détecter les nouvelles acceptations d'employés et notifier le client
  void _detectAndNotifyEmployeeAcceptances(List<RequestModel> requestList, String clientId) {
    try {
      final authController = Get.find<AuthController>();
      final currentUser = authController.currentUser.value;
      
      // Only notify if current user is the client
      if (currentUser == null || currentUser.id != clientId) return;

      for (final request in requestList) {
        // Only check pending requests owned by this client
        if (request.statut.toLowerCase() != 'pending' || request.clientId != clientId) continue;
        
        // Get previously notified employees for this request
        final previouslyNotified = _notifiedEmployeesPerRequest[request.id] ?? <String>{};
        
        // Find newly accepted employees
        final newAcceptedIds = request.acceptedEmployeeIds.where(
          (employeeId) => !previouslyNotified.contains(employeeId)
        ).toList();
        
        // Notify for each new employee acceptance
        for (final employeeId in newAcceptedIds) {
          _notifyClientAboutEmployeeAcceptance(request, employeeId);
          
          // Mark as notified
          if (!_notifiedEmployeesPerRequest.containsKey(request.id)) {
            _notifiedEmployeesPerRequest[request.id] = <String>{};
          }
          _notifiedEmployeesPerRequest[request.id]!.add(employeeId);
        }
        
        // Clean up old entries if request is no longer pending
        if (request.statut.toLowerCase() != 'pending') {
          _notifiedEmployeesPerRequest.remove(request.id);
        }
      }
    } catch (e) {
      // Silently handle errors to avoid breaking the stream
      Logger.logError('RequestController._detectAndNotifyEmployeeAcceptances', e, StackTrace.current);
    }
  }

  /// Notifier le client qu'un employé a accepté sa demande
  Future<void> _notifyClientAboutEmployeeAcceptance(RequestModel request, String employeeId) async {
    try {
      // Load employee data
      final employeeRepository = EmployeeRepository();
      final employee = await employeeRepository.getEmployeeById(employeeId);
      
      if (employee != null) {
        _notificationService.showEmployeeAcceptedNotification(
          requestId: request.id,
          employeeName: employee.nomComplet,
          requestDescription: request.description,
        );
        debugPrint('[RequestController] Notified client about employee ${employee.nomComplet} accepting request ${request.id}');
      }
    } catch (e) {
      // Silently handle errors - notification is not critical
      Logger.logError('RequestController._notifyClientAboutEmployeeAcceptance', e, StackTrace.current);
    }
  }

  /// Notifier l'employé qu'un client l'a accepté pour une demande
  /// Cette méthode est appelée après qu'une mission soit créée avec le requestId et employeeId
  Future<void> notifyEmployeeAboutClientAcceptance({
    required RequestModel request,
    required String employeeUserId,
    required String clientName,
  }) async {
    try {
      debugPrint('[RequestController] notifyEmployeeAboutClientAcceptance called');
      debugPrint('[RequestController] Request ID: ${request.id}, Employee User ID: $employeeUserId, Client Name: $clientName');
      
      // Show local notification
      await _notificationService.showClientAcceptedEmployeeNotification(
        requestId: request.id,
        clientName: clientName,
        requestDescription: request.description,
      );
      
      debugPrint('[RequestController] ✅ Notified employee $employeeUserId about client $clientName accepting them for request ${request.id}');
    } catch (e, stackTrace) {
      // Log error but don't fail
      debugPrint('[RequestController] ❌ Error notifying employee: $e');
      Logger.logError('RequestController.notifyEmployeeAboutClientAcceptance', e, stackTrace);
    }
  }

  /// Créer une demande
  Future<bool> createRequest(RequestModel request) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _requestRepository.createRequest(request);
      SnackbarHelper.showSuccess('request_created'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.createRequest', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mettre à jour une demande
  Future<bool> updateRequest(RequestModel request) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _requestRepository.updateRequest(request);
      SnackbarHelper.showSuccess('request_updated'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.updateRequest', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Supprimer une demande
  Future<bool> deleteRequest(String requestId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _requestRepository.deleteRequest(requestId);
      SnackbarHelper.showSuccess('request_deleted'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.deleteRequest', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sélectionner une demande
  void selectRequest(RequestModel request) {
    selectedRequest.value = request;
  }

  /// Récupérer une demande par ID
  Future<RequestModel?> getRequestById(String requestId) async {
    try {
      return await _requestRepository.getRequestById(requestId);
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.getRequestById', e, stackTrace);
      return null;
    }
  }

  /// Vérifier si le client a une demande active (Pending ou Accepted)
  Future<bool> hasActiveRequest(String clientId) async {
    try {
      final clientRequests = await _requestRepository.getRequestsByClientId(clientId);
      return clientRequests.any((request) => 
        request.statut.toLowerCase() == 'pending' || 
        request.statut.toLowerCase() == 'accepted'
      );
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.hasActiveRequest', e, stackTrace);
      return false;
    }
  }

  /// Obtenir la demande active du client
  Future<RequestModel?> getActiveRequest(String clientId) async {
    try {
      final clientRequests = await _requestRepository.getRequestsByClientId(clientId);
      return clientRequests.firstWhereOrNull((request) => 
        request.statut.toLowerCase() == 'pending' || 
        request.statut.toLowerCase() == 'accepted'
      );
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.getActiveRequest', e, stackTrace);
      return null;
    }
  }

  /// Accepter une demande (par un employé)
  Future<bool> acceptRequestByEmployee(String requestId, String userId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Get employee document ID from user ID
      final employeeRepository = EmployeeRepository();
      final employee = await employeeRepository.getEmployeeByUserId(userId);
      if (employee == null) {
        throw 'Profil employé non trouvé';
      }

      final employeeDocumentId = employee.id;
      
      // Cache employee document ID for notification count
      _currentEmployeeDocumentId = employeeDocumentId;
      
      final request = await _requestRepository.getRequestById(requestId);
      if (request == null) {
        throw 'Demande non trouvée';
      }

      // Vérifier que la demande est toujours en attente
      if (request.statut.toLowerCase() != 'pending') {
        throw 'Cette demande n\'est plus disponible';
      }

      // Vérifier que l'employé n'a pas déjà accepté (using employee document ID)
      if (request.acceptedEmployeeIds.contains(employeeDocumentId)) {
        throw 'Vous avez déjà accepté cette demande';
      }

      // Vérifier que l'employé n'a pas refusé cette demande
      if (request.refusedEmployeeIds.contains(employeeDocumentId)) {
        throw 'Vous avez refusé cette demande et ne pouvez plus l\'accepter';
      }

      // Capturer la localisation GPS de l'employé
      Map<String, double>? employeeLocation;
      try {
        final locationService = LocationService();
        final locationData = await locationService.getCurrentLocationWithAddress();
        employeeLocation = {
          'latitude': locationData['latitude'] as double,
          'longitude': locationData['longitude'] as double,
        };
        debugPrint('[RequestController] Localisation GPS de l\'employé capturée: ${employeeLocation['latitude']}, ${employeeLocation['longitude']}');
      } catch (e) {
        debugPrint('[RequestController] Erreur lors de la capture de la localisation GPS: $e');
        // Continuer même si la localisation n'a pas pu être capturée
        // L'employé sera quand même ajouté mais sans coordonnées GPS
      }

      // Ajouter l'employé à la liste des acceptés avec sa localisation GPS
      final updatedAcceptedIds = [...request.acceptedEmployeeIds, employeeDocumentId];
      final updatedLocations = Map<String, Map<String, double>>.from(request.acceptedEmployeeLocations);
      if (employeeLocation != null) {
        updatedLocations[employeeDocumentId] = employeeLocation;
      }
      
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
        acceptedEmployeeLocations: updatedLocations,
        updatedAt: DateTime.now(),
      );

      await _requestRepository.updateRequest(updatedRequest);
      
      // Note: Client notification is handled in RequestDetailScreen stream listener
      // This ensures notifications work correctly when client is viewing the detail screen
      
      // Don't reload if stream is active - stream will update automatically
      // Only reload if no stream is active
      if (_currentCategorieId == null) {
        await loadRequestsByCategorie(request.categorieId);
      }

      SnackbarHelper.showSuccess('request_accepted_success'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.acceptRequestByEmployee', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Refuser une demande (par un employé) - Retirer de la liste des acceptés si déjà accepté
  Future<bool> refuseRequestByEmployee(String requestId, String userId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Get employee document ID from user ID
      final employeeRepository = EmployeeRepository();
      final employee = await employeeRepository.getEmployeeByUserId(userId);
      if (employee == null) {
        throw 'Profil employé non trouvé';
      }

      final employeeDocumentId = employee.id;
      
      // Cache employee document ID for notification count
      _currentEmployeeDocumentId = employeeDocumentId;
      
      final request = await _requestRepository.getRequestById(requestId);
      if (request == null) {
        throw 'Demande non trouvée';
      }

      // Retirer l'employé de la liste des acceptés s'il y est (using employee document ID)
      final updatedAcceptedIds = request.acceptedEmployeeIds.where((id) => id != employeeDocumentId).toList();
      
      // Retirer aussi la localisation GPS de l'employé s'il était dans les acceptés
      final updatedLocations = Map<String, Map<String, double>>.from(request.acceptedEmployeeLocations);
      updatedLocations.remove(employeeDocumentId);
      
      // Ajouter l'employé à la liste des refusés s'il n'y est pas déjà
      final updatedRefusedIds = request.refusedEmployeeIds.contains(employeeDocumentId)
          ? request.refusedEmployeeIds
          : [...request.refusedEmployeeIds, employeeDocumentId];
      
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
        acceptedEmployeeLocations: updatedLocations,
        refusedEmployeeIds: updatedRefusedIds,
        updatedAt: DateTime.now(),
      );

      await _requestRepository.updateRequest(updatedRequest);
      
      // Don't reload if stream is active - stream will update automatically
      // Only reload if no stream is active
      if (_currentCategorieId == null) {
        await loadRequestsByCategorie(request.categorieId);
      }

      SnackbarHelper.showSuccess('request_refused'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.refuseRequestByEmployee', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Accepter un employé pour une demande (par le client)
  Future<bool> acceptEmployeeForRequest(String requestId, String employeeId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final request = await _requestRepository.getRequestById(requestId);
      if (request == null) {
        throw 'Demande non trouvée';
      }

      // Vérifier que l'employé a bien accepté la demande
      if (!request.acceptedEmployeeIds.contains(employeeId)) {
        throw 'Cet employé n\'a pas accepté cette demande';
      }

      // Vérifier que la demande est toujours disponible
      if (request.statut.toLowerCase() != 'pending') {
        throw 'Cette demande n\'est plus disponible';
      }

      // Récupérer les informations de l'employé (nom + userId)
      final employeeRepository = EmployeeRepository();
      final employee = await employeeRepository.getEmployeeById(employeeId);
      final employeeName = employee?.nomComplet ?? 'Employé';
      final employeeUserId = employee?.userId;

      // Mettre à jour la demande avec l'employé accepté
      final updatedRequest = request.copyWith(
        employeeId: employeeId,
        statut: 'Accepted',
        updatedAt: DateTime.now(),
      );

      await _requestRepository.updateRequest(updatedRequest);
      
      // Don't reload if stream is active for this client - stream will update automatically
      // Only reload if no stream is active or stream is for a different client
      if (_currentClientId != request.clientId) {
        await loadRequestsByClient(request.clientId);
      }

      // Créer/activer le chat pour cette demande
      try {
        final authController = Get.find<AuthController>();
        final clientName = authController.currentUser.value?.nomComplet ?? 'Client';
        await _chatRepository.createOrActivateThread(
          requestId: request.id,
          requestTitle: request.description,
          clientId: request.clientId,
          clientName: clientName,
          employeeId: employeeId,
          employeeName: employeeName,
          employeeUserId: employeeUserId,
          requestStatus: 'Accepted',
        );
      } catch (chatError, chatStack) {
        Logger.logError('RequestController.acceptEmployeeForRequest.Chat', chatError, chatStack);
      }

      // Notifier l'employé qu'il a été accepté par le client
      // This happens when request statut changes to "Accepted"
      if (employeeUserId != null) {
        try {
          final authController = Get.find<AuthController>();
          final clientName = authController.currentUser.value?.nomComplet ?? 'Client';
          await notifyEmployeeAboutClientAcceptance(
            request: updatedRequest,
            employeeUserId: employeeUserId,
            clientName: clientName,
          );
        } catch (notifError) {
          // Silently handle errors - notification is not critical
          Logger.logError('RequestController.acceptEmployeeForRequest.Notification', notifError, StackTrace.current);
        }
      }

      SnackbarHelper.showSuccess('employee_accepted'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.acceptEmployeeForRequest', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Refuser un employé pour une demande (par le client)
  Future<bool> rejectEmployeeForRequest(String requestId, String employeeId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final request = await _requestRepository.getRequestById(requestId);
      if (request == null) {
        throw 'Demande non trouvée';
      }

      // Retirer l'employé de la liste des acceptés
      final updatedAcceptedIds = request.acceptedEmployeeIds.where((id) => id != employeeId).toList();
      
      // Retirer aussi la localisation GPS de l'employé s'il était dans les acceptés
      final updatedLocations = Map<String, Map<String, double>>.from(request.acceptedEmployeeLocations);
      updatedLocations.remove(employeeId);
      
      // Ajouter l'employé à la liste des refusés par le client s'il n'y est pas déjà
      final updatedClientRefusedIds = request.clientRefusedEmployeeIds.contains(employeeId)
          ? request.clientRefusedEmployeeIds
          : [...request.clientRefusedEmployeeIds, employeeId];
      
      debugPrint('[RequestController] rejectEmployeeForRequest: RequestId=$requestId, EmployeeId=$employeeId');
      debugPrint('[RequestController] Before: acceptedEmployeeIds=${request.acceptedEmployeeIds}, clientRefusedEmployeeIds=${request.clientRefusedEmployeeIds}');
      debugPrint('[RequestController] After: acceptedEmployeeIds=$updatedAcceptedIds, clientRefusedEmployeeIds=$updatedClientRefusedIds');
      
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
        acceptedEmployeeLocations: updatedLocations,
        clientRefusedEmployeeIds: updatedClientRefusedIds,
        updatedAt: DateTime.now(),
      );

      debugPrint('[RequestController] Updated request clientRefusedEmployeeIds: ${updatedRequest.clientRefusedEmployeeIds}');
      debugPrint('[RequestController] Updated request toMap: ${updatedRequest.toMap()}');
      
      await _requestRepository.updateRequest(updatedRequest);
      
      debugPrint('[RequestController] Request updated successfully');
      
      // Don't reload if stream is active for this client - stream will update automatically
      // Only reload if no stream is active or stream is for a different client
      if (_currentClientId != request.clientId) {
        await loadRequestsByClient(request.clientId);
      }

      SnackbarHelper.showSuccess('employee_rejected'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.rejectEmployeeForRequest', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Annuler une demande
  /// Retourne la raison d'annulation si fournie, null sinon
  Future<String?> cancelRequest(String requestId, {String? cancellationReason}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final request = await _requestRepository.getRequestById(requestId);
      if (request == null) {
        throw 'Demande non trouvée';
      }

      // Vérifier que la demande peut être annulée (Pending ou Accepted)
      if (request.statut.toLowerCase() != 'pending' && 
          request.statut.toLowerCase() != 'accepted') {
        throw 'Cette demande ne peut pas être annulée';
      }

      // Si la demande est assignée à un employé, supprimer la mission associée
      if (request.employeeId != null) {
        try {
          final mission = await _missionRepository.getMissionByRequestId(requestId);
          if (mission != null) {
            await _missionRepository.deleteMission(mission.id);
            Logger.logInfo('RequestController.cancelRequest', 'Mission ${mission.id} supprimée pour la demande ${requestId}');
          }
        } catch (missionError, missionStack) {
          Logger.logError('RequestController.cancelRequest.Mission', missionError, missionStack);
          // Continuer même si la suppression de la mission échoue
        }
      }

      // Mettre à jour le statut à "Cancelled"
      final cancelledRequest = request.copyWith(
        statut: 'Cancelled',
        updatedAt: DateTime.now(),
      );

      await _requestRepository.updateRequest(cancelledRequest);

      // Désactiver le chat si existant
      try {
        await _chatRepository.closeThreadForRequest(request.id, requestStatus: 'Cancelled');
      } catch (chatError, chatStack) {
        Logger.logError('RequestController.cancelRequest.Chat', chatError, chatStack);
      }
      
      // Don't reload if stream is active for this client - stream will update automatically
      // Only reload if no stream is active or stream is for a different client
      if (request.clientId.isNotEmpty && _currentClientId != request.clientId) {
        await loadRequestsByClient(request.clientId);
      }

      SnackbarHelper.showSuccess('request_cancelled'.tr);
      return cancellationReason;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.cancelRequest', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Valider un token QR code et terminer la demande
  Future<bool> validateQRTokenAndFinishRequest(String token) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user == null) {
        throw 'Utilisateur non authentifié';
      }
      
      // Valider le token
      final tokenData = await _qrCodeService.validateAndUseToken(
        token: token,
        employeeId: user.id,
      );
      
      if (tokenData == null) {
        throw 'Token invalide, expiré ou déjà utilisé';
      }
      
      final requestId = tokenData['requestId'] as String;
      final price = tokenData['price'] as double;
      final rating = tokenData['rating'] as double?;
      final comment = tokenData['comment'] as String?;
      
      // Récupérer la demande
      final request = await _requestRepository.getRequestById(requestId);
      if (request == null) {
        throw 'Demande non trouvée';
      }
      
      // Récupérer la mission
      final mission = await _missionRepository.getMissionByRequestId(requestId);
      if (mission == null) {
        throw 'Mission non trouvée';
      }
      
      // Mettre à jour la mission
      final updatedMission = mission.copyWith(
        prixMission: price,
        statutMission: 'Completed',
        rating: rating,
        commentaire: comment,
        dateEnd: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _missionRepository.updateMission(updatedMission);
      
      // Mettre à jour la demande
      final updatedRequest = request.copyWith(
        statut: 'Completed',
        updatedAt: DateTime.now(),
      );
      
      await _requestRepository.updateRequest(updatedRequest);
      
      // Fermer le thread de chat
      await _chatRepository.closeThreadForRequest(requestId, requestStatus: 'Completed');
      
      SnackbarHelper.showSuccess('request_completed_success'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.validateQRTokenAndFinishRequest', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}


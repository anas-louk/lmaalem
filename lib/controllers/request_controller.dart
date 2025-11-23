import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../data/models/request_model.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../core/utils/logger.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/helpers/snackbar_helper.dart';
import 'auth_controller.dart';

/// Controller pour gérer les demandes (GetX)
class RequestController extends GetxController {
  final RequestRepository _requestRepository = RequestRepository();

  // Observable states
  final RxList<RequestModel> requests = <RequestModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasReceivedFirstData = false.obs; // Track if we've received first stream data
  final RxString errorMessage = ''.obs;
  final Rx<RequestModel?> selectedRequest = Rx<RequestModel?>(null);
  
  // Stream subscription management
  StreamSubscription<List<RequestModel>>? _requestsStreamSubscription;
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
      requests.assignAll(initialData);
      hasReceivedFirstData.value = true;
      isLoading.value = false;
      update();
      debugPrint('[RequestController] Initial data loaded: ${initialData.length} requests');
    } catch (e) {
      debugPrint('[RequestController] Error loading initial data: $e');
      Logger.logError('RequestController.streamRequestsByClient', e, StackTrace.current);
    }
    
    _requestsStreamSubscription = _requestRepository.streamRequestsByClientId(clientId).listen(
      (requestList) {
        hasReceivedFirstData.value = true;
        
        // Detect and notify about new employee acceptances for clients
        _detectAndNotifyEmployeeAcceptances(requestList, clientId);
        
        requests.assignAll(requestList);
        update();
        isLoading.value = false;
        debugPrint('[RequestController] ✅ Stream update: ${requestList.length} requests for client $clientId');
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
        
        // Update using assignAll - this should trigger GetX reactivity
        requests.assignAll(requestList);
        
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
  
  /// Arrêter le stream actif
  void stopStreaming() {
    _requestsStreamSubscription?.cancel();
    _requestsStreamSubscription = null;
    _currentCategorieId = null;
    _currentClientId = null;
    _previousRequestIds.clear();
    _notifiedEmployeesPerRequest.clear(); // Clear notification tracking
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

      // Ajouter l'employé à la liste des acceptés (using employee document ID)
      final updatedAcceptedIds = [...request.acceptedEmployeeIds, employeeDocumentId];
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
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
      
      // Ajouter l'employé à la liste des refusés s'il n'y est pas déjà
      final updatedRefusedIds = request.refusedEmployeeIds.contains(employeeDocumentId)
          ? request.refusedEmployeeIds
          : [...request.refusedEmployeeIds, employeeDocumentId];
      
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
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
      
      // Ajouter l'employé à la liste des refusés par le client s'il n'y est pas déjà
      final updatedClientRefusedIds = request.clientRefusedEmployeeIds.contains(employeeId)
          ? request.clientRefusedEmployeeIds
          : [...request.clientRefusedEmployeeIds, employeeId];
      
      debugPrint('[RequestController] rejectEmployeeForRequest: RequestId=$requestId, EmployeeId=$employeeId');
      debugPrint('[RequestController] Before: acceptedEmployeeIds=${request.acceptedEmployeeIds}, clientRefusedEmployeeIds=${request.clientRefusedEmployeeIds}');
      debugPrint('[RequestController] After: acceptedEmployeeIds=$updatedAcceptedIds, clientRefusedEmployeeIds=$updatedClientRefusedIds');
      
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
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
  Future<bool> cancelRequest(String requestId) async {
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

      // Mettre à jour le statut à "Cancelled"
      final cancelledRequest = request.copyWith(
        statut: 'Cancelled',
        updatedAt: DateTime.now(),
      );

      await _requestRepository.updateRequest(cancelledRequest);
      
      // Don't reload if stream is active for this client - stream will update automatically
      // Only reload if no stream is active or stream is for a different client
      if (request.clientId.isNotEmpty && _currentClientId != request.clientId) {
        await loadRequestsByClient(request.clientId);
      }

      SnackbarHelper.showSuccess('request_cancelled'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.cancelRequest', e, stackTrace);
      SnackbarHelper.showError(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}


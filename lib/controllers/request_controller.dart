import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../data/models/request_model.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../core/utils/logger.dart';
import '../../core/services/local_notification_service.dart';
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
  
  // Notification service
  final LocalNotificationService _notificationService = LocalNotificationService();
  
  // Track previous request IDs to detect new ones
  final Set<String> _previousRequestIds = <String>{};
  
  // Notification count for employees (pending requests excluding own requests)
  int get notificationCount {
    try {
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user == null) return 0;
      
      return requests.where((request) {
        return request.statut.toLowerCase() == 'pending' &&
               request.clientId != user.id; // Don't show own requests
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
          Get.snackbar('error'.tr, errorMessage.value);
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
          Get.snackbar('error'.tr, errorMessage.value);
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
          Get.snackbar('error'.tr, errorMessage.value);
        });
      });
    }
  }

  /// Stream des demandes d'un client (temps réel)
  void streamRequestsByClient(String clientId) {
    // Cancel existing subscription if switching to a different client
    if (_currentClientId != clientId) {
      _requestsStreamSubscription?.cancel();
      _currentClientId = clientId;
      _currentCategorieId = null;
      
      _requestsStreamSubscription = _requestRepository.streamRequestsByClientId(clientId).listen(
        (requestList) {
          requests.assignAll(requestList);
          isLoading.value = false;
        },
        onError: (error) {
          errorMessage.value = error.toString();
          Logger.logError('RequestController.streamRequestsByClient', error, StackTrace.current);
          isLoading.value = false;
        },
      );
      isLoading.value = true;
    }
  }

  /// Stream des demandes par catégorie (temps réel)
  Future<void> streamRequestsByCategorie(String categorieId) async {
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
    hasReceivedFirstData.value = false;
  }

  /// Détecter les nouvelles demandes et afficher des notifications
  void _detectAndNotifyNewRequests(List<RequestModel> newRequests) {
    try {
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user == null) return;

      // Filter pending requests not made by current user
      final pendingRequests = newRequests.where((request) {
        return request.statut.toLowerCase() == 'pending' &&
               request.clientId != user.id;
      }).toList();

      // Find new requests (not in previous list)
      final newRequestIds = pendingRequests.map((r) => r.id).toSet();
      final actuallyNewRequests = pendingRequests.where((request) {
        return !_previousRequestIds.contains(request.id);
      }).toList();

      // Show notifications for new requests
      for (final request in actuallyNewRequests) {
        _notificationService.showNewRequestNotification(
          requestId: request.id,
          description: request.description,
          address: request.address,
        );
      }

      // Update previous request IDs
      _previousRequestIds.clear();
      _previousRequestIds.addAll(newRequestIds);
    } catch (e) {
      // Silently handle errors to avoid breaking the stream
      Logger.logError('RequestController._detectAndNotifyNewRequests', e, StackTrace.current);
    }
  }

  /// Créer une demande
  Future<bool> createRequest(RequestModel request) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _requestRepository.createRequest(request);
      Get.snackbar('success'.tr, 'request_created'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.createRequest', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
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
      Get.snackbar('success'.tr, 'request_updated'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.updateRequest', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
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
      Get.snackbar('success'.tr, 'request_deleted'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.deleteRequest', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
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

      // Ajouter l'employé à la liste des acceptés (using employee document ID)
      final updatedAcceptedIds = [...request.acceptedEmployeeIds, employeeDocumentId];
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
        updatedAt: DateTime.now(),
      );

      await _requestRepository.updateRequest(updatedRequest);
      
      // Don't reload if stream is active - stream will update automatically
      // Only reload if no stream is active
      if (_currentCategorieId == null) {
        await loadRequestsByCategorie(request.categorieId);
      }

      Get.snackbar('success'.tr, 'request_accepted_success'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.acceptRequestByEmployee', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
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
      
      final request = await _requestRepository.getRequestById(requestId);
      if (request == null) {
        throw 'Demande non trouvée';
      }

      // Retirer l'employé de la liste des acceptés s'il y est (using employee document ID)
      final updatedAcceptedIds = request.acceptedEmployeeIds.where((id) => id != employeeDocumentId).toList();
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
        updatedAt: DateTime.now(),
      );

      await _requestRepository.updateRequest(updatedRequest);
      
      // Don't reload if stream is active - stream will update automatically
      // Only reload if no stream is active
      if (_currentCategorieId == null) {
        await loadRequestsByCategorie(request.categorieId);
      }

      Get.snackbar('success'.tr, 'request_refused'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.refuseRequestByEmployee', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
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

      Get.snackbar('success'.tr, 'employee_accepted'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.acceptEmployeeForRequest', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
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
      final updatedRequest = request.copyWith(
        acceptedEmployeeIds: updatedAcceptedIds,
        updatedAt: DateTime.now(),
      );

      await _requestRepository.updateRequest(updatedRequest);
      
      // Don't reload if stream is active for this client - stream will update automatically
      // Only reload if no stream is active or stream is for a different client
      if (_currentClientId != request.clientId) {
        await loadRequestsByClient(request.clientId);
      }

      Get.snackbar('success'.tr, 'employee_rejected'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.rejectEmployeeForRequest', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
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

      Get.snackbar('success'.tr, 'request_cancelled'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('RequestController.cancelRequest', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}


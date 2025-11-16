import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import '../../data/models/request_model.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../core/utils/logger.dart';

/// Controller pour gérer les demandes (GetX)
class RequestController extends GetxController {
  final RequestRepository _requestRepository = RequestRepository();

  // Observable states
  final RxList<RequestModel> requests = <RequestModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<RequestModel?> selectedRequest = Rx<RequestModel?>(null);

  @override
  void onInit() {
    super.onInit();
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
          Get.snackbar('Erreur', errorMessage.value);
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
          Get.snackbar('Erreur', errorMessage.value);
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
          Get.snackbar('Erreur', errorMessage.value);
        });
      });
    }
  }

  /// Stream des demandes d'un client (temps réel)
  void streamRequestsByClient(String clientId) {
    _requestRepository.streamRequestsByClientId(clientId).listen((requestList) {
      requests.assignAll(requestList);
    });
  }

  /// Stream des demandes par catégorie (temps réel)
  void streamRequestsByCategorie(String categorieId) {
    _requestRepository.streamRequestsByCategorieId(categorieId).listen((requestList) {
      requests.assignAll(requestList);
    });
  }

  /// Créer une demande
  Future<bool> createRequest(RequestModel request) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _requestRepository.createRequest(request);
      Get.snackbar('Succès', 'Demande créée avec succès');
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
      Get.snackbar('Succès', 'Demande mise à jour avec succès');
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
      Get.snackbar('Succès', 'Demande supprimée avec succès');
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
      
      // Recharger les demandes
      await loadRequestsByCategorie(request.categorieId);

      Get.snackbar('Succès', 'Demande acceptée avec succès');
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
      
      // Recharger les demandes
      await loadRequestsByCategorie(request.categorieId);

      Get.snackbar('Succès', 'Demande refusée');
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
      
      // Recharger les demandes du client
      await loadRequestsByClient(request.clientId);

      Get.snackbar('Succès', 'Employé accepté avec succès');
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
      
      // Recharger les demandes du client
      await loadRequestsByClient(request.clientId);

      Get.snackbar('Succès', 'Employé refusé');
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
      
      // Recharger les demandes du client
      if (request.clientId.isNotEmpty) {
        await loadRequestsByClient(request.clientId);
      }

      Get.snackbar('Succès', 'Demande annulée avec succès');
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


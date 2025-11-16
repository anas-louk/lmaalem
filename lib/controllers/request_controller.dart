import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import '../../data/models/request_model.dart';
import '../../data/repositories/request_repository.dart';

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
    } catch (e) {
      errorMessage.value = e.toString();
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
    } catch (e) {
      errorMessage.value = e.toString();
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
    } catch (e) {
      errorMessage.value = e.toString();
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
    } catch (e) {
      errorMessage.value = e.toString();
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
    } catch (e) {
      errorMessage.value = e.toString();
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
    } catch (e) {
      errorMessage.value = e.toString();
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
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    }
  }
}


import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import '../../data/models/mission_model.dart';
import '../../data/repositories/mission_repository.dart';
import '../../core/utils/logger.dart';

/// Controller pour gérer les missions (GetX)
class MissionController extends GetxController {
  final MissionRepository _missionRepository = MissionRepository();

  // Observable states
  final RxList<MissionModel> missions = <MissionModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<MissionModel?> selectedMission = Rx<MissionModel?>(null);
  
  // Stream subscription management
  StreamSubscription<List<MissionModel>>? _missionsStreamSubscription;
  String? _currentClientId;
  String? _currentEmployeeId;

  @override
  void onInit() {
    super.onInit();
  }
  
  @override
  void onClose() {
    _missionsStreamSubscription?.cancel();
    super.onClose();
  }

  /// Charger les missions d'un client
  Future<void> loadMissionsByClient(String clientId) async {
    try {
      errorMessage.value = '';
      // Defer isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = true;
      });
      final missionList = await _missionRepository.getMissionsByClientId(clientId);
      // Defer state updates to avoid calling during build
      Future.microtask(() {
        missions.assignAll(missionList);
        isLoading.value = false;
      });
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('MissionController.loadMissionsByClient', e, stackTrace);
      // Defer snackbar and isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Get.snackbar('error'.tr, errorMessage.value);
        });
      });
    }
  }

  /// Charger les missions d'un employé
  Future<void> loadMissionsByEmployee(String employeeId) async {
    try {
      errorMessage.value = '';
      // Defer isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = true;
      });
      final missionList = await _missionRepository.getMissionsByEmployeeId(employeeId);
      // Defer state updates to avoid calling during build
      Future.microtask(() {
        missions.assignAll(missionList);
        isLoading.value = false;
      });
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('MissionController.loadMissionsByEmployee', e, stackTrace);
      // Defer snackbar and isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Get.snackbar('error'.tr, errorMessage.value);
        });
      });
    }
  }

  /// Charger les missions par statut
  Future<void> loadMissionsByStatut(String statut) async {
    try {
      errorMessage.value = '';
      // Defer isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = true;
      });
      final missionList = await _missionRepository.getMissionsByStatut(statut);
      // Defer state updates to avoid calling during build
      Future.microtask(() {
        missions.assignAll(missionList);
        isLoading.value = false;
      });
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('MissionController.loadMissionsByStatut', e, stackTrace);
      // Defer snackbar and isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Get.snackbar('error'.tr, errorMessage.value);
        });
      });
    }
  }

  /// Stream des missions d'un client (temps réel)
  void streamMissionsByClient(String clientId) {
    // Cancel existing subscription if switching to a different client
    if (_currentClientId != clientId) {
      _missionsStreamSubscription?.cancel();
      _currentClientId = clientId;
      _currentEmployeeId = null;
      
      _missionsStreamSubscription = _missionRepository.streamMissionsByClientId(clientId).listen(
        (missionList) {
          missions.assignAll(missionList);
          isLoading.value = false;
        },
        onError: (error) {
          errorMessage.value = error.toString();
          Logger.logError('MissionController.streamMissionsByClient', error, StackTrace.current);
          isLoading.value = false;
        },
      );
      isLoading.value = true;
    }
  }

  /// Stream des missions d'un employé (temps réel)
  void streamMissionsByEmployee(String employeeId) {
    // Cancel existing subscription if switching to a different employee
    if (_currentEmployeeId != employeeId) {
      _missionsStreamSubscription?.cancel();
      _currentEmployeeId = employeeId;
      _currentClientId = null;
      
      _missionsStreamSubscription = _missionRepository.streamMissionsByEmployeeId(employeeId).listen(
        (missionList) {
          missions.assignAll(missionList);
          isLoading.value = false;
        },
        onError: (error) {
          errorMessage.value = error.toString();
          Logger.logError('MissionController.streamMissionsByEmployee', error, StackTrace.current);
          isLoading.value = false;
        },
      );
      isLoading.value = true;
    }
  }
  
  /// Arrêter le stream actif
  void stopStreaming() {
    _missionsStreamSubscription?.cancel();
    _missionsStreamSubscription = null;
    _currentClientId = null;
    _currentEmployeeId = null;
  }

  /// Créer une mission
  Future<bool> createMission(MissionModel mission) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _missionRepository.createMission(mission);
      Get.snackbar('success'.tr, 'mission_created'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('MissionController.createMission', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mettre à jour une mission
  Future<bool> updateMission(MissionModel mission) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _missionRepository.updateMission(mission);
      Get.snackbar('success'.tr, 'mission_updated'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('MissionController.updateMission', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Supprimer une mission
  Future<bool> deleteMission(String missionId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _missionRepository.deleteMission(missionId);
      Get.snackbar('success'.tr, 'mission_deleted'.tr);
      return true;
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('MissionController.deleteMission', e, stackTrace);
      Get.snackbar('Erreur', errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sélectionner une mission
  void selectMission(MissionModel mission) {
    selectedMission.value = mission;
  }

  /// Récupérer une mission par ID
  Future<MissionModel?> getMissionById(String missionId) async {
    try {
      return await _missionRepository.getMissionById(missionId);
    } catch (e, stackTrace) {
      errorMessage.value = e.toString();
      Logger.logError('MissionController.getMissionById', e, stackTrace);
      return null;
    }
  }
}


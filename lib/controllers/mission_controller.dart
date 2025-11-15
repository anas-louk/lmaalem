import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import '../../data/models/mission_model.dart';
import '../../data/repositories/mission_repository.dart';

/// Controller pour gérer les missions (GetX)
class MissionController extends GetxController {
  final MissionRepository _missionRepository = MissionRepository();

  // Observable states
  final RxList<MissionModel> missions = <MissionModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<MissionModel?> selectedMission = Rx<MissionModel?>(null);

  @override
  void onInit() {
    super.onInit();
  }

  /// Charger les missions d'un client
  Future<void> loadMissionsByClient(String clientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final missionList = await _missionRepository.getMissionsByClientId(clientId);
      // Defer state updates to avoid calling during build
      Future.microtask(() {
        missions.assignAll(missionList);
        isLoading.value = false;
      });
    } catch (e) {
      errorMessage.value = e.toString();
      // Defer snackbar and isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Get.snackbar('Erreur', errorMessage.value);
        });
      });
    }
  }

  /// Charger les missions d'un employé
  Future<void> loadMissionsByEmployee(String employeeId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final missionList = await _missionRepository.getMissionsByEmployeeId(employeeId);
      // Defer state updates to avoid calling during build
      Future.microtask(() {
        missions.assignAll(missionList);
        isLoading.value = false;
      });
    } catch (e) {
      errorMessage.value = e.toString();
      // Defer snackbar and isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Get.snackbar('Erreur', errorMessage.value);
        });
      });
    }
  }

  /// Charger les missions par statut
  Future<void> loadMissionsByStatut(String statut) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final missionList = await _missionRepository.getMissionsByStatut(statut);
      // Defer state updates to avoid calling during build
      Future.microtask(() {
        missions.assignAll(missionList);
        isLoading.value = false;
      });
    } catch (e) {
      errorMessage.value = e.toString();
      // Defer snackbar and isLoading update to avoid calling during build
      Future.microtask(() {
        isLoading.value = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Get.snackbar('Erreur', errorMessage.value);
        });
      });
    }
  }

  /// Stream des missions d'un client (temps réel)
  void streamMissionsByClient(String clientId) {
    _missionRepository.streamMissionsByClientId(clientId).listen((missionList) {
      missions.assignAll(missionList);
    });
  }

  /// Stream des missions d'un employé (temps réel)
  void streamMissionsByEmployee(String employeeId) {
    _missionRepository.streamMissionsByEmployeeId(employeeId).listen((missionList) {
      missions.assignAll(missionList);
    });
  }

  /// Créer une mission
  Future<bool> createMission(MissionModel mission) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _missionRepository.createMission(mission);
      Get.snackbar('Succès', 'Mission créée avec succès');
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
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
      Get.snackbar('Succès', 'Mission mise à jour avec succès');
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
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
      Get.snackbar('Succès', 'Mission supprimée avec succès');
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
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
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    }
  }
}


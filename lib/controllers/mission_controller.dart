import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
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
  final RxBool hasReceivedFirstData = false.obs;
  
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
  Future<void> streamMissionsByClient(String clientId) async {
    // Cancel existing subscription if switching to a different client
    if (_currentClientId == clientId && _missionsStreamSubscription != null) {
      debugPrint('[MissionController] Stream already active for client: $clientId, skipping');
      return;
    }

    _missionsStreamSubscription?.cancel();
    _missionsStreamSubscription = null;
    
    _currentClientId = clientId;
    _currentEmployeeId = null;
    
    hasReceivedFirstData.value = false;
    isLoading.value = true;

    // Load initial data first to ensure UI has data immediately
    try {
      debugPrint('[MissionController] Loading initial data for client: $clientId');
      final initialData = await _missionRepository.getMissionsByClientId(clientId);
      missions.assignAll(initialData);
      hasReceivedFirstData.value = true;
      isLoading.value = false;
      update(); // Force GetX reactivity
      debugPrint('[MissionController] Initial data loaded: ${initialData.length} missions');
    } catch (e) {
      debugPrint('[MissionController] Error loading initial data: $e');
      Logger.logError('MissionController.streamMissionsByClient', e, StackTrace.current);
    }
    
    _missionsStreamSubscription = _missionRepository.streamMissionsByClientId(clientId).listen(
      (missionList) {
        hasReceivedFirstData.value = true;
        missions.assignAll(missionList);
        update(); // Force GetX reactivity
        isLoading.value = false;
        debugPrint('[MissionController] ✅ Stream update: ${missionList.length} missions for client $clientId');
      },
      onError: (error) {
        errorMessage.value = error.toString();
        Logger.logError('MissionController.streamMissionsByClient', error, StackTrace.current);
        isLoading.value = false;
        debugPrint('[MissionController] ❌ Stream error: $error');
      },
      cancelOnError: false, // Keep stream alive on error
    );
  }

  /// Stream des missions d'un employé (temps réel)
  Future<void> streamMissionsByEmployee(String employeeId) async {
    // Cancel existing subscription if switching to a different employee
    if (_currentEmployeeId == employeeId && _missionsStreamSubscription != null) {
      debugPrint('[MissionController] Stream already active for employee: $employeeId, skipping');
      return;
    }

    _missionsStreamSubscription?.cancel();
    _missionsStreamSubscription = null;
    
    _currentEmployeeId = employeeId;
    _currentClientId = null;
    
    hasReceivedFirstData.value = false;
    isLoading.value = true;

    // Load initial data first to ensure UI has data immediately
    try {
      debugPrint('[MissionController] Loading initial data for employee: $employeeId');
      final initialData = await _missionRepository.getMissionsByEmployeeId(employeeId);
      missions.assignAll(initialData);
      hasReceivedFirstData.value = true;
      isLoading.value = false;
      update(); // Force GetX reactivity
      debugPrint('[MissionController] Initial data loaded: ${initialData.length} missions');
    } catch (e) {
      debugPrint('[MissionController] Error loading initial data: $e');
      Logger.logError('MissionController.streamMissionsByEmployee', e, StackTrace.current);
    }
    
    _missionsStreamSubscription = _missionRepository.streamMissionsByEmployeeId(employeeId).listen(
      (missionList) {
        hasReceivedFirstData.value = true;
        missions.assignAll(missionList);
        update(); // Force GetX reactivity
        isLoading.value = false;
        debugPrint('[MissionController] ✅ Stream update: ${missionList.length} missions for employee $employeeId');
      },
      onError: (error) {
        errorMessage.value = error.toString();
        Logger.logError('MissionController.streamMissionsByEmployee', error, StackTrace.current);
        isLoading.value = false;
        debugPrint('[MissionController] ❌ Stream error: $error');
      },
      cancelOnError: false, // Keep stream alive on error
    );
  }
  
  /// Arrêter le stream actif
  void stopStreaming() {
    _missionsStreamSubscription?.cancel();
    _missionsStreamSubscription = null;
    _currentClientId = null;
    _currentEmployeeId = null;
    hasReceivedFirstData.value = false;
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


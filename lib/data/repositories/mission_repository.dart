import '../models/mission_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository pour gérer les missions dans Firestore
class MissionRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final String _collection = 'missions';

  /// Récupérer une mission par ID
  Future<MissionModel?> getMissionById(String missionId) async {
    try {
      final data = await _firestoreService.read(
        collection: _collection,
        docId: missionId,
      );

      if (data != null) {
        return MissionModel.fromMap({...data, 'id': missionId});
      }
      return null;
    } catch (e, stackTrace) {
      Logger.logError('MissionRepository.getMissionById', e, stackTrace);
      throw 'Erreur lors de la récupération de la mission: $e';
    }
  }

  /// Stream d'une mission
  Stream<MissionModel?> streamMission(String missionId) {
    return _firestoreService
        .streamDocument(collection: _collection, docId: missionId)
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return MissionModel.fromDocument(doc);
      }
      return null;
    });
  }

  /// Créer une mission
  Future<void> createMission(MissionModel mission) async {
    try {
      await _firestoreService.create(
        collection: _collection,
        docId: mission.id,
        data: mission.toMap(),
      );
    } catch (e, stackTrace) {
      Logger.logError('MissionRepository.createMission', e, stackTrace);
      throw 'Erreur lors de la création de la mission: $e';
    }
  }

  /// Mettre à jour une mission
  Future<void> updateMission(MissionModel mission) async {
    try {
      await _firestoreService.update(
        collection: _collection,
        docId: mission.id,
        data: mission.copyWith(updatedAt: DateTime.now()).toMap(),
      );
    } catch (e, stackTrace) {
      Logger.logError('MissionRepository.updateMission', e, stackTrace);
      throw 'Erreur lors de la mise à jour de la mission: $e';
    }
  }

  /// Supprimer une mission
  Future<void> deleteMission(String missionId) async {
    try {
      await _firestoreService.delete(
        collection: _collection,
        docId: missionId,
      );
    } catch (e, stackTrace) {
      Logger.logError('MissionRepository.deleteMission', e, stackTrace);
      throw 'Erreur lors de la suppression de la mission: $e';
    }
  }

  /// Récupérer les missions d'un client
  Future<List<MissionModel>> getMissionsByClientId(String clientId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      // Use DocumentReference for querying since missions store clientId as DocumentReference
      final clientRef = firestore.collection('clients').doc(clientId);
      
      // Without orderBy - avoids composite index requirement
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('clientId', isEqualTo: clientRef),
      );

      // Sort in Dart instead of Firestore
      final missions = data.map((map) => MissionModel.fromMap(map)).toList();
      missions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
      return missions;
    } catch (e, stackTrace) {
      Logger.logError('MissionRepository.getMissionsByClientId', e, stackTrace);
      throw 'Erreur lors de la récupération des missions: $e';
    }
  }

  /// Récupérer les missions d'un employé
  Future<List<MissionModel>> getMissionsByEmployeeId(String employeeId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      // Use DocumentReference for querying since missions store employeeId as DocumentReference
      final employeeRef = firestore.collection('employees').doc(employeeId);
      
      // Without orderBy - avoids composite index requirement
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('employeeId', isEqualTo: employeeRef),
      );

      // Sort in Dart instead of Firestore
      final missions = data.map((map) => MissionModel.fromMap(map)).toList();
      missions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
      return missions;
    } catch (e, stackTrace) {
      Logger.logError('MissionRepository.getMissionsByEmployeeId', e, stackTrace);
      throw 'Erreur lors de la récupération des missions: $e';
    }
  }

  /// Récupérer les missions par statut
  Future<List<MissionModel>> getMissionsByStatut(String statut) async {
    try {
      // Without orderBy - avoids composite index requirement
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('statutMission', isEqualTo: statut),
      );

      // Sort in Dart instead of Firestore
      final missions = data.map((map) => MissionModel.fromMap(map)).toList();
      missions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
      return missions;
    } catch (e, stackTrace) {
      Logger.logError('MissionRepository.getMissionsByStatut', e, stackTrace);
      throw 'Erreur lors de la récupération des missions: $e';
    }
  }

  /// Stream de toutes les missions d'un client
  Stream<List<MissionModel>> streamMissionsByClientId(String clientId) {
    final firestore = FirebaseFirestore.instance;
    // Use DocumentReference for querying since missions store clientId as DocumentReference
    final clientRef = firestore.collection('clients').doc(clientId);
    
    return _firestoreService
        .streamCollection(
          collection: _collection,
          queryBuilder: (q) => q.where('clientId', isEqualTo: clientRef),
        )
        .map((snapshot) {
          // Sort in Dart instead of Firestore
          final missions = snapshot.docs
              .map((doc) => MissionModel.fromDocument(doc))
              .toList();
          missions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
          return missions;
        });
  }

  /// Stream de toutes les missions d'un employé
  Stream<List<MissionModel>> streamMissionsByEmployeeId(String employeeId) {
    final firestore = FirebaseFirestore.instance;
    // Use DocumentReference for querying since missions store employeeId as DocumentReference
    final employeeRef = firestore.collection('employees').doc(employeeId);
    
    return _firestoreService
        .streamCollection(
          collection: _collection,
          queryBuilder: (q) => q.where('employeeId', isEqualTo: employeeRef),
        )
        .map((snapshot) {
          // Sort in Dart instead of Firestore
          final missions = snapshot.docs
              .map((doc) => MissionModel.fromDocument(doc))
              .toList();
          missions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
          return missions;
        });
  }

  /// Récupérer une mission par requestId
  Future<MissionModel?> getMissionByRequestId(String requestId) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('requestId', isEqualTo: requestId),
      );

      if (data.isNotEmpty) {
        // Return the first matching mission (should be unique)
        return MissionModel.fromMap(data.first);
      }
      return null;
    } catch (e, stackTrace) {
      Logger.logError('MissionRepository.getMissionByRequestId', e, stackTrace);
      throw 'Erreur lors de la récupération de la mission: $e';
    }
  }
}


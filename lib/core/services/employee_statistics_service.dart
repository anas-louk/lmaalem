import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/employee_statistics.dart';
import '../../data/models/mission_model.dart';
import 'package:flutter/foundation.dart';

/// Service pour calculer les statistiques d'un employé
class EmployeeStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Récupérer les statistiques d'un employé
  Future<EmployeeStatistics> getEmployeeStatistics(String employeeId) async {
    try {
      // Récupérer toutes les missions de l'employé
      final missionsSnapshot = await _firestore
          .collection('missions')
          .where('employeeId', isEqualTo: _firestore.collection('employees').doc(employeeId))
          .get();

      if (missionsSnapshot.docs.isEmpty) {
        return EmployeeStatistics.empty();
      }

      final missions = missionsSnapshot.docs
          .map((doc) => MissionModel.fromDocument(doc))
          .toList();

      // Calculer les statistiques
      int totalMissions = missions.length;
      int completedMissions = 0;
      int cancelledMissions = 0;
      int inProgressMissions = 0;
      double totalRating = 0.0;
      int ratingsCount = 0;
      double totalEarnings = 0.0;

      for (final mission in missions) {
        // Compter par statut
        switch (mission.statutMission.toLowerCase()) {
          case 'completed':
            completedMissions++;
            totalEarnings += mission.prixMission;
            break;
          case 'cancelled':
            cancelledMissions++;
            break;
          case 'in progress':
            inProgressMissions++;
            break;
        }

        // Calculer la note moyenne
        if (mission.rating != null && mission.rating! > 0) {
          totalRating += mission.rating!;
          ratingsCount++;
        }
      }

      // Calculer les moyennes
      final averageRating = ratingsCount > 0 ? totalRating / ratingsCount : 0.0;
      final completionRate = totalMissions > 0
          ? (completedMissions / totalMissions) * 100
          : 0.0;

      return EmployeeStatistics(
        totalMissions: totalMissions,
        completedMissions: completedMissions,
        cancelledMissions: cancelledMissions,
        inProgressMissions: inProgressMissions,
        averageRating: averageRating,
        completionRate: completionRate,
        totalEarnings: totalEarnings,
        totalRatings: ratingsCount,
      );
    } catch (e, stackTrace) {
      debugPrint('[EmployeeStatisticsService] Error getting statistics: $e');
      debugPrint('[EmployeeStatisticsService] Stack trace: $stackTrace');
      // Retourner des statistiques vides en cas d'erreur
      return EmployeeStatistics.empty();
    }
  }

  /// Récupérer les statistiques d'un employé (version avec string ID)
  /// Cette méthode est utilisée quand employeeId est stocké comme string
  Future<EmployeeStatistics> getEmployeeStatisticsByStringId(String employeeId) async {
    try {
      // Essayer d'abord avec DocumentReference
      try {
        final missionsSnapshot = await _firestore
            .collection('missions')
            .where('employeeId', isEqualTo: _firestore.collection('employees').doc(employeeId))
            .get();

        if (missionsSnapshot.docs.isNotEmpty) {
          return _calculateStatistics(missionsSnapshot.docs);
        }
      } catch (e) {
        debugPrint('[EmployeeStatisticsService] DocumentReference query failed, trying string: $e');
      }

      // Fallback: essayer avec string
      final missionsSnapshot = await _firestore
          .collection('missions')
          .where('employeeId', isEqualTo: employeeId)
          .get();

      if (missionsSnapshot.docs.isEmpty) {
        return EmployeeStatistics.empty();
      }

      return _calculateStatistics(missionsSnapshot.docs);
    } catch (e, stackTrace) {
      debugPrint('[EmployeeStatisticsService] Error getting statistics: $e');
      debugPrint('[EmployeeStatisticsService] Stack trace: $stackTrace');
      return EmployeeStatistics.empty();
    }
  }

  /// Calculer les statistiques à partir des documents de missions
  EmployeeStatistics _calculateStatistics(List<QueryDocumentSnapshot> missionDocs) {
    final missions = missionDocs
        .map((doc) => MissionModel.fromDocument(doc))
        .toList();

    int totalMissions = missions.length;
    int completedMissions = 0;
    int cancelledMissions = 0;
    int inProgressMissions = 0;
    double totalRating = 0.0;
    int ratingsCount = 0;
    double totalEarnings = 0.0;

    for (final mission in missions) {
      // Compter par statut
      switch (mission.statutMission.toLowerCase()) {
        case 'completed':
          completedMissions++;
          totalEarnings += mission.prixMission;
          break;
        case 'cancelled':
          cancelledMissions++;
          break;
        case 'in progress':
          inProgressMissions++;
          break;
      }

      // Calculer la note moyenne
      if (mission.rating != null && mission.rating! > 0) {
        totalRating += mission.rating!;
        ratingsCount++;
      }
    }

    // Calculer les moyennes
    final averageRating = ratingsCount > 0 ? totalRating / ratingsCount : 0.0;
    final completionRate = totalMissions > 0
        ? (completedMissions / totalMissions) * 100
        : 0.0;

    return EmployeeStatistics(
      totalMissions: totalMissions,
      completedMissions: completedMissions,
      cancelledMissions: cancelledMissions,
      inProgressMissions: inProgressMissions,
      averageRating: averageRating,
      completionRate: completionRate,
      totalEarnings: totalEarnings,
      totalRatings: ratingsCount,
    );
  }
}


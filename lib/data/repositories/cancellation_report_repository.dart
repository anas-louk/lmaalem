import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/logger.dart';
import '../models/cancellation_report_model.dart';

/// Repository pour gérer les rapports d'annulation
class CancellationReportRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'cancellation_reports';

  /// Créer un rapport d'annulation
  Future<void> createReport(CancellationReportModel report) async {
    try {
      await _firestoreService.create(
        collection: _collection,
        docId: report.id,
        data: report.toMap(),
      );
    } catch (e, stackTrace) {
      Logger.logError('CancellationReportRepository.createReport', e, stackTrace);
      throw 'Erreur lors de la création du rapport: $e';
    }
  }

  /// Mettre à jour un rapport d'annulation
  Future<void> updateReport(CancellationReportModel report) async {
    try {
      await _firestoreService.update(
        collection: _collection,
        docId: report.id,
        data: report.copyWith(updatedAt: DateTime.now()).toMap(),
      );
    } catch (e, stackTrace) {
      Logger.logError('CancellationReportRepository.updateReport', e, stackTrace);
      throw 'Erreur lors de la mise à jour du rapport: $e';
    }
  }

  /// Récupérer un rapport par requestId
  Future<CancellationReportModel?> getReportByRequestId(String requestId) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('requestId', isEqualTo: requestId),
      );

      if (data.isNotEmpty) {
        return CancellationReportModel.fromMap(data.first);
      }
      return null;
    } catch (e, stackTrace) {
      Logger.logError('CancellationReportRepository.getReportByRequestId', e, stackTrace);
      throw 'Erreur lors de la récupération du rapport: $e';
    }
  }

  /// Récupérer les rapports d'un employé
  Future<List<CancellationReportModel>> getReportsByEmployeeId(String employeeId) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('employeeId', isEqualTo: employeeId),
      );

      final reports = data.map((map) => CancellationReportModel.fromMap(map)).toList();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
      return reports;
    } catch (e, stackTrace) {
      Logger.logError('CancellationReportRepository.getReportsByEmployeeId', e, stackTrace);
      throw 'Erreur lors de la récupération des rapports: $e';
    }
  }
}


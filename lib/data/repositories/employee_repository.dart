import '../models/employee_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository pour gérer les employés dans Firestore
class EmployeeRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final String _collection = 'employees';

  /// Récupérer un employé par ID
  Future<EmployeeModel?> getEmployeeById(String employeeId) async {
    try {
      final data = await _firestoreService.read(
        collection: _collection,
        docId: employeeId,
      );

      if (data != null) {
        return EmployeeModel.fromMap({...data, 'id': employeeId});
      }
      return null;
    } catch (e, stackTrace) {
      Logger.logError('EmployeeRepository', e, stackTrace);
      throw 'Erreur lors de la récupération de l\'employé: $e';
    }
  }

  /// Stream d'un employé
  Stream<EmployeeModel?> streamEmployee(String employeeId) {
    return _firestoreService
        .streamDocument(collection: _collection, docId: employeeId)
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return EmployeeModel.fromDocument(doc);
      }
      return null;
    });
  }

  /// Créer un employé
  Future<void> createEmployee(EmployeeModel employee) async {
    try {
      await _firestoreService.create(
        collection: _collection,
        docId: employee.id,
        data: employee.toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la création de l\'employé: $e';
    }
  }

  /// Mettre à jour un employé
  Future<void> updateEmployee(EmployeeModel employee) async {
    try {
      await _firestoreService.update(
        collection: _collection,
        docId: employee.id,
        data: employee.copyWith(updatedAt: DateTime.now()).toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la mise à jour de l\'employé: $e';
    }
  }

  /// Récupérer tous les employés disponibles
  Future<List<EmployeeModel>> getAvailableEmployees() async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q
            .where('disponibilite', isEqualTo: true)
            .orderBy('createdAt', descending: true),
      );

      return data.map((map) => EmployeeModel.fromMap(map)).toList();
    } catch (e) {
      throw 'Erreur lors de la récupération des employés: $e';
    }
  }

  /// Récupérer les employés par catégorie
  Future<List<EmployeeModel>> getEmployeesByCategory(String categoryId) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q
            .where('categorieId', isEqualTo: categoryId)
            .where('disponibilite', isEqualTo: true),
      );

      return data.map((map) => EmployeeModel.fromMap(map)).toList();
    } catch (e) {
      throw 'Erreur lors de la récupération des employés: $e';
    }
  }

  /// Récupérer les employés par ville
  Future<List<EmployeeModel>> getEmployeesByVille(String ville) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q
            .where('ville', isEqualTo: ville)
            .orderBy('createdAt', descending: true),
      );

      return data.map((map) => EmployeeModel.fromMap(map)).toList();
    } catch (e) {
      throw 'Erreur lors de la récupération des employés: $e';
    }
  }

  /// Rechercher des employés
  Future<List<EmployeeModel>> searchEmployees(String query) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q
            .where('nomComplet', isGreaterThanOrEqualTo: query)
            .where('nomComplet', isLessThan: '${query}z')
            .limit(20),
      );

      return data.map((map) => EmployeeModel.fromMap(map)).toList();
    } catch (e) {
      throw 'Erreur lors de la recherche: $e';
    }
  }

  /// Supprimer un employé
  Future<void> deleteEmployee(String employeeId) async {
    try {
      await _firestoreService.delete(
        collection: _collection,
        docId: employeeId,
      );
    } catch (e) {
      throw 'Erreur lors de la suppression de l\'employé: $e';
    }
  }

  /// Récupérer un employé par userId
  Future<EmployeeModel?> getEmployeeByUserId(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        return EmployeeModel.fromMap({...data, 'id': doc.id});
      }
      return null;
    } catch (e, stackTrace) {
      Logger.logError('EmployeeRepository', e, stackTrace);
      throw 'Erreur lors de la récupération de l\'employé: $e';
    }
  }
}


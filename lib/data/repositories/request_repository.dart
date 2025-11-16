import '../models/request_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository pour gérer les demandes dans Firestore
class RequestRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final String _collection = 'requests';

  /// Récupérer une demande par ID
  Future<RequestModel?> getRequestById(String requestId) async {
    try {
      final data = await _firestoreService.read(
        collection: _collection,
        docId: requestId,
      );

      if (data != null) {
        return RequestModel.fromMap({...data, 'id': requestId});
      }
      return null;
    } catch (e, stackTrace) {
      Logger.logError('RequestRepository.getRequestById', e, stackTrace);
      throw 'Erreur lors de la récupération de la demande: $e';
    }
  }

  /// Stream d'une demande
  Stream<RequestModel?> streamRequest(String requestId) {
    return _firestoreService
        .streamDocument(collection: _collection, docId: requestId)
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return RequestModel.fromDocument(doc);
      }
      return null;
    });
  }

  /// Créer une demande
  Future<void> createRequest(RequestModel request) async {
    try {
      await _firestoreService.create(
        collection: _collection,
        docId: request.id,
        data: request.toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la création de la demande: $e';
    }
  }

  /// Mettre à jour une demande
  Future<void> updateRequest(RequestModel request) async {
    try {
      await _firestoreService.update(
        collection: _collection,
        docId: request.id,
        data: request.copyWith(updatedAt: DateTime.now()).toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la mise à jour de la demande: $e';
    }
  }

  /// Supprimer une demande
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestoreService.delete(
        collection: _collection,
        docId: requestId,
      );
    } catch (e) {
      throw 'Erreur lors de la suppression de la demande: $e';
    }
  }

  /// Récupérer les demandes d'un client
  Future<List<RequestModel>> getRequestsByClientId(String clientId) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('clientId', isEqualTo: clientId),
      );

      final requests = data.map((map) => RequestModel.fromMap(map)).toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
      return requests;
    } catch (e) {
      throw 'Erreur lors de la récupération des demandes: $e';
    }
  }

  /// Récupérer les demandes par catégorie
  Future<List<RequestModel>> getRequestsByCategorieId(String categorieId) async {
    try {
      Logger.logInfo('RequestRepository.getRequestsByCategorieId', 'Querying with categorieId: $categorieId');
      
      // First try with string (requests are stored as string)
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('categorieId', isEqualTo: categorieId)
            .where('statut', isEqualTo: 'Pending'),
      );

      Logger.logInfo('RequestRepository.getRequestsByCategorieId', 'Found ${data.length} documents with string query');
      
      final requests = data.map((map) {
        try {
          final request = RequestModel.fromMap(map);
          Logger.logInfo('RequestRepository.getRequestsByCategorieId', 'Parsed request ${request.id}: categorieId=${request.categorieId}, statut=${request.statut}');
          return request;
        } catch (e) {
          Logger.logError('RequestRepository.getRequestsByCategorieId', 'Error parsing request: $e');
          rethrow;
        }
      }).toList();
      
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
      
      Logger.logInfo('RequestRepository.getRequestsByCategorieId', 'Returning ${requests.length} requests');
      
      // If no results and categorieId might be stored as DocumentReference, try that
      if (requests.isEmpty) {
        Logger.logInfo('RequestRepository.getRequestsByCategorieId', 'No results with string query, trying DocumentReference');
        try {
          final firestore = FirebaseFirestore.instance;
          final categorieRef = firestore.collection('categories').doc(categorieId);
          
          final dataRef = await _firestoreService.readAll(
            collection: _collection,
            queryBuilder: (q) => q.where('categorieId', isEqualTo: categorieRef)
                .where('statut', isEqualTo: 'Pending'),
          );

          Logger.logInfo('RequestRepository.getRequestsByCategorieId', 'Found ${dataRef.length} documents with DocumentReference query');
          
          final requestsRef = dataRef.map((map) => RequestModel.fromMap(map)).toList();
          requestsRef.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
          return requestsRef;
        } catch (e2, stackTrace2) {
          Logger.logError('RequestRepository.getRequestsByCategorieId', 'DocumentReference query failed: $e2', stackTrace2);
          // Ignore DocumentReference query error, return empty list from string query
        }
      }
      
      return requests;
    } catch (e, stackTrace) {
      Logger.logError('RequestRepository.getRequestsByCategorieId', e, stackTrace);
      throw 'Erreur lors de la récupération des demandes: $e';
    }
  }

  /// Récupérer les demandes par statut
  Future<List<RequestModel>> getRequestsByStatut(String statut) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('statut', isEqualTo: statut),
      );

      final requests = data.map((map) => RequestModel.fromMap(map)).toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
      return requests;
    } catch (e) {
      throw 'Erreur lors de la récupération des demandes: $e';
    }
  }

  /// Stream de toutes les demandes d'un client
  Stream<List<RequestModel>> streamRequestsByClientId(String clientId) {
    return _firestoreService
        .streamCollection(
          collection: _collection,
          queryBuilder: (q) => q.where('clientId', isEqualTo: clientId),
        )
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => RequestModel.fromDocument(doc))
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
          return requests;
        });
  }

  /// Stream des demandes par catégorie
  Stream<List<RequestModel>> streamRequestsByCategorieId(String categorieId) {
    // Use string for querying (requests are stored as string)
    return _firestoreService
        .streamCollection(
          collection: _collection,
          queryBuilder: (q) => q.where('categorieId', isEqualTo: categorieId)
              .where('statut', isEqualTo: 'Pending'),
        )
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => RequestModel.fromDocument(doc))
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
          return requests;
        });
  }
}


import '../models/request_model.dart';
import '../../core/services/firestore_service.dart';

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
    } catch (e) {
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
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.where('categorieId', isEqualTo: categorieId)
            .where('statut', isEqualTo: 'Pending'),
      );

      final requests = data.map((map) => RequestModel.fromMap(map)).toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending
      return requests;
    } catch (e) {
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


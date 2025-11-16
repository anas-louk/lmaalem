import '../models/client_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository pour gérer les clients dans Firestore
class ClientRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final String _collection = 'clients';

  /// Récupérer un client par ID
  Future<ClientModel?> getClientById(String clientId) async {
    try {
      final data = await _firestoreService.read(
        collection: _collection,
        docId: clientId,
      );

      if (data != null) {
        return ClientModel.fromMap({...data, 'id': clientId});
      }
      return null;
    } catch (e, stackTrace) {
      Logger.logError('ClientRepository', e, stackTrace);
      throw 'Erreur lors de la récupération du client: $e';
    }
  }

  /// Stream d'un client
  Stream<ClientModel?> streamClient(String clientId) {
    return _firestoreService
        .streamDocument(collection: _collection, docId: clientId)
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ClientModel.fromDocument(doc);
      }
      return null;
    });
  }

  /// Créer un client
  Future<void> createClient(ClientModel client) async {
    try {
      await _firestoreService.create(
        collection: _collection,
        docId: client.id,
        data: client.toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la création du client: $e';
    }
  }

  /// Mettre à jour un client
  Future<void> updateClient(ClientModel client) async {
    try {
      await _firestoreService.update(
        collection: _collection,
        docId: client.id,
        data: client.copyWith(updatedAt: DateTime.now()).toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la mise à jour du client: $e';
    }
  }

  /// Rechercher des clients
  Future<List<ClientModel>> searchClients(String query) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q
            .where('nomComplet', isGreaterThanOrEqualTo: query)
            .where('nomComplet', isLessThan: '${query}z')
            .limit(20),
      );

      return data.map((map) => ClientModel.fromMap(map)).toList();
    } catch (e) {
      throw 'Erreur lors de la recherche: $e';
    }
  }

  /// Récupérer un client par userId
  Future<ClientModel?> getClientByUserId(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        return ClientModel.fromMap({...data, 'id': doc.id});
      }
      return null;
    } catch (e, stackTrace) {
      Logger.logError('ClientRepository', e, stackTrace);
      throw 'Erreur lors de la récupération du client: $e';
    }
  }
}


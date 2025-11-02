import '../models/user_model.dart';
import '../../core/services/firestore_service.dart';

/// Repository pour gérer les utilisateurs dans Firestore
class UserRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final String _collection = 'users';

  /// Récupérer un utilisateur par ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final data = await _firestoreService.read(
        collection: _collection,
        docId: userId,
      );

      if (data != null) {
        return UserModel.fromMap({...data, 'id': userId});
      }
      return null;
    } catch (e) {
      throw 'Erreur lors de la récupération de l\'utilisateur: $e';
    }
  }

  /// Stream d'un utilisateur
  Stream<UserModel?> streamUser(String userId) {
    return _firestoreService
        .streamDocument(collection: _collection, docId: userId)
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromDocument(doc);
      }
      return null;
    });
  }

  /// Mettre à jour un utilisateur
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestoreService.update(
        collection: _collection,
        docId: user.id,
        data: user.copyWith(updatedAt: DateTime.now()).toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la mise à jour de l\'utilisateur: $e';
    }
  }

  /// Créer un utilisateur
  Future<void> createUser(UserModel user) async {
    try {
      await _firestoreService.create(
        collection: _collection,
        docId: user.id,
        data: user.toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la création de l\'utilisateur: $e';
    }
  }

  /// Rechercher des utilisateurs par nom
  Future<List<UserModel>> searchUsersByName(String query) async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThan: '${query}z')
            .limit(20),
      );

      return data.map((map) => UserModel.fromMap(map)).toList();
    } catch (e) {
      throw 'Erreur lors de la recherche: $e';
    }
  }
}


import '../models/categorie_model.dart';
import '../../core/services/firestore_service.dart';

/// Repository pour gérer les catégories dans Firestore
class CategorieRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final String _collection = 'categories';

  /// Récupérer une catégorie par ID
  Future<CategorieModel?> getCategorieById(String categorieId) async {
    try {
      final data = await _firestoreService.read(
        collection: _collection,
        docId: categorieId,
      );

      if (data != null) {
        return CategorieModel.fromMap({...data, 'id': categorieId});
      }
      return null;
    } catch (e) {
      throw 'Erreur lors de la récupération de la catégorie: $e';
    }
  }

  /// Stream d'une catégorie
  Stream<CategorieModel?> streamCategorie(String categorieId) {
    return _firestoreService
        .streamDocument(collection: _collection, docId: categorieId)
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return CategorieModel.fromDocument(doc);
      }
      return null;
    });
  }

  /// Créer une catégorie
  Future<void> createCategorie(CategorieModel categorie) async {
    try {
      await _firestoreService.create(
        collection: _collection,
        docId: categorie.id,
        data: categorie.toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la création de la catégorie: $e';
    }
  }

  /// Mettre à jour une catégorie
  Future<void> updateCategorie(CategorieModel categorie) async {
    try {
      await _firestoreService.update(
        collection: _collection,
        docId: categorie.id,
        data: categorie.copyWith(updatedAt: DateTime.now()).toMap(),
      );
    } catch (e) {
      throw 'Erreur lors de la mise à jour de la catégorie: $e';
    }
  }

  /// Supprimer une catégorie
  Future<void> deleteCategorie(String categorieId) async {
    try {
      await _firestoreService.delete(
        collection: _collection,
        docId: categorieId,
      );
    } catch (e) {
      throw 'Erreur lors de la suppression de la catégorie: $e';
    }
  }

  /// Récupérer toutes les catégories
  Future<List<CategorieModel>> getAllCategories() async {
    try {
      final data = await _firestoreService.readAll(
        collection: _collection,
        queryBuilder: (q) => q.orderBy('nom', descending: false),
      );

      return data.map((map) => CategorieModel.fromMap(map)).toList();
    } catch (e) {
      throw 'Erreur lors de la récupération des catégories: $e';
    }
  }

  /// Stream de toutes les catégories
  Stream<List<CategorieModel>> streamAllCategories() {
    return _firestoreService
        .streamCollection(
          collection: _collection,
          queryBuilder: (q) => q.orderBy('nom', descending: false),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) => CategorieModel.fromDocument(doc))
            .toList());
  }
}


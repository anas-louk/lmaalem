import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/categorie_model.dart';
import '../../data/repositories/categorie_repository.dart';

/// Script pour initialiser 5 catégories dans Firestore
class InitCategories {
  final CategorieRepository _categorieRepository = CategorieRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ajouter 5 catégories par défaut
  Future<void> initializeCategories() async {
    try {
      print('🚀 Début de l\'initialisation des catégories...');

      final now = DateTime.now();
      
      // Liste des 5 catégories à créer
      final categories = [
        CategorieModel(
          id: _firestore.collection('categories').doc().id,
          nom: 'Plombier',
          createdAt: now,
          updatedAt: now,
        ),
        CategorieModel(
          id: _firestore.collection('categories').doc().id,
          nom: 'Électricien',
          createdAt: now,
          updatedAt: now,
        ),
        CategorieModel(
          id: _firestore.collection('categories').doc().id,
          nom: 'Peintre',
          createdAt: now,
          updatedAt: now,
        ),
        CategorieModel(
          id: _firestore.collection('categories').doc().id,
          nom: 'Menuisier',
          createdAt: now,
          updatedAt: now,
        ),
        CategorieModel(
          id: _firestore.collection('categories').doc().id,
          nom: 'Nettoyage',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Vérifier si les catégories existent déjà
      final existingCategories = await _categorieRepository.getAllCategories();
      final existingNames = existingCategories.map((c) => c.nom.toLowerCase()).toSet();

      int createdCount = 0;
      int skippedCount = 0;

      for (final category in categories) {
        // Vérifier si la catégorie existe déjà
        if (existingNames.contains(category.nom.toLowerCase())) {
          print('⏭️  Catégorie "${category.nom}" existe déjà, ignorée.');
          skippedCount++;
          continue;
        }

        try {
          await _categorieRepository.createCategorie(category);
          print('✅ Catégorie "${category.nom}" créée avec succès (ID: ${category.id})');
          createdCount++;
        } catch (e) {
          print('❌ Erreur lors de la création de la catégorie "${category.nom}": $e');
        }
      }

      print('\n📊 Résumé:');
      print('   - Catégories créées: $createdCount');
      print('   - Catégories ignorées (déjà existantes): $skippedCount');
      print('   - Total: ${categories.length}');
      
      if (createdCount > 0) {
        print('\n🎉 Initialisation terminée avec succès!');
      } else {
        print('\nℹ️  Toutes les catégories existent déjà.');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des catégories: $e');
      rethrow;
    }
  }

  /// Méthode statique pour exécuter le script
  static Future<void> run() async {
    final init = InitCategories();
    await init.initializeCategories();
  }
}


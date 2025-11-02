import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de données pour une catégorie
class CategorieModel {
  final String id;
  final String nom; // Nom de la catégorie
  final DateTime createdAt;
  final DateTime updatedAt;

  CategorieModel({
    required this.id,
    required this.nom,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Créer un CategorieModel depuis un Map (Firestore)
  factory CategorieModel.fromMap(Map<String, dynamic> map) {
    return CategorieModel(
      id: map['id'] ?? '',
      nom: map['nom'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Créer un CategorieModel depuis un DocumentSnapshot
  factory CategorieModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategorieModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Créer une copie avec des modifications
  CategorieModel copyWith({
    String? id,
    String? nom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategorieModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'CategorieModel(id: $id, nom: $nom)';
  }
}


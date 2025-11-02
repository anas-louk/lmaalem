import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// Modèle de données pour un employé (hérite de UserModel)
class EmployeeModel extends UserModel {
  final String? image;
  final String ville;
  final bool disponabilite;
  final String competence;
  final String? bio;
  final String? gallery;
  final List<String>? categorieIds; // IDs des catégories

  EmployeeModel({
    required super.id,
    required super.nomComplet,
    required super.localisation,
    required super.tel,
    required super.createdAt,
    required super.updatedAt,
    this.image,
    required this.ville,
    required this.disponabilite,
    required this.competence,
    this.bio,
    this.gallery,
    this.categorieIds,
  }) : super(type: 'Employee');

  /// Créer un EmployeeModel depuis un Map (Firestore)
  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id'] ?? '',
      nomComplet: map['nomComplet'] ?? '',
      localisation: map['localisation'] ?? '',
      tel: map['tel'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      image: map['image'],
      ville: map['ville'] ?? '',
      disponabilite: map['disponabilite'] ?? false,
      competence: map['competence'] ?? '',
      bio: map['bio'],
      gallery: map['gallery'],
      categorieIds: map['categorieIds'] != null
          ? List<String>.from(map['categorieIds'])
          : null,
    );
  }

  /// Créer un EmployeeModel depuis un DocumentSnapshot
  factory EmployeeModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  /// Créer depuis un UserModel (pour la conversion)
  factory EmployeeModel.fromUserModel(UserModel user, {
    String? image,
    required String ville,
    required bool disponabilite,
    required String competence,
    String? bio,
    String? gallery,
    List<String>? categorieIds,
  }) {
    return EmployeeModel(
      id: user.id,
      nomComplet: user.nomComplet,
      localisation: user.localisation,
      tel: user.tel,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      image: image,
      ville: ville,
      disponabilite: disponabilite,
      competence: competence,
      bio: bio,
      gallery: gallery,
      categorieIds: categorieIds,
    );
  }

  /// Convertir en Map pour Firestore
  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'image': image,
      'ville': ville,
      'disponabilite': disponabilite,
      'competence': competence,
      'bio': bio,
      'gallery': gallery,
      'categorieIds': categorieIds,
    };
  }

  /// Créer une copie avec des modifications
  @override
  EmployeeModel copyWith({
    String? id,
    String? nomComplet,
    String? localisation,
    String? type,
    String? tel,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? image,
    String? ville,
    bool? disponabilite,
    String? competence,
    String? bio,
    String? gallery,
    List<String>? categorieIds,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      nomComplet: nomComplet ?? this.nomComplet,
      localisation: localisation ?? this.localisation,
      tel: tel ?? this.tel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      image: image ?? this.image,
      ville: ville ?? this.ville,
      disponabilite: disponabilite ?? this.disponabilite,
      competence: competence ?? this.competence,
      bio: bio ?? this.bio,
      gallery: gallery ?? this.gallery,
      categorieIds: categorieIds ?? this.categorieIds,
    );
  }

  @override
  String toString() {
    return 'EmployeeModel(id: $id, nomComplet: $nomComplet, ville: $ville)';
  }
}


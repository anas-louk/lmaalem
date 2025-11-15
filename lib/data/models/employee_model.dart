import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// Modèle de données pour un employé (hérite de UserModel)
class EmployeeModel extends UserModel {
  final String? image;
  final String categorieId; // Reference to Categorie collection (document ID)
  final String ville;
  final bool disponibilite; // Note: UML uses "Disponibilite"
  final String competence;
  final String? bio;
  final String? gallery;
  final String userId; // Reference to User collection (document ID)

  EmployeeModel({
    required super.id,
    required super.nomComplet,
    required super.localisation,
    required super.tel,
    required super.createdAt,
    required super.updatedAt,
    this.image,
    required this.categorieId,
    required this.ville,
    required this.disponibilite,
    required this.competence,
    this.bio,
    this.gallery,
    required this.userId,
  }) : super(type: 'Employee');

  /// Créer un EmployeeModel depuis un Map (Firestore)
  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    // Handle DocumentReference for categorieId
    String categorieId = '';
    if (map['categorieId'] != null) {
      if (map['categorieId'] is DocumentReference) {
        categorieId = (map['categorieId'] as DocumentReference).id;
      } else {
        categorieId = map['categorieId'].toString();
      }
    }
    
    // Handle DocumentReference for userId
    String userId = '';
    if (map['userId'] != null) {
      if (map['userId'] is DocumentReference) {
        userId = (map['userId'] as DocumentReference).id;
      } else {
        userId = map['userId'].toString();
      }
    }

    return EmployeeModel(
      id: map['id'] ?? '',
      nomComplet: map['nomComplet'] ?? '',
      localisation: map['localisation'] ?? '',
      tel: map['tel'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      image: map['image'],
      categorieId: categorieId,
      ville: map['ville'] ?? '',
      disponibilite: map['disponibilite'] ?? false,
      competence: map['competence'] ?? '',
      bio: map['bio'],
      gallery: map['gallery'],
      userId: userId,
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
    required String categorieId,
    required String ville,
    required bool disponibilite,
    required String competence,
    String? bio,
    String? gallery,
  }) {
    return EmployeeModel(
      id: user.id,
      nomComplet: user.nomComplet,
      localisation: user.localisation,
      tel: user.tel,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      image: image,
      categorieId: categorieId,
      ville: ville,
      disponibilite: disponibilite,
      competence: competence,
      bio: bio,
      gallery: gallery,
      userId: user.id,
    );
  }

  /// Convertir en Map pour Firestore
  @override
  Map<String, dynamic> toMap() {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    return {
      ...super.toMap(),
      'image': image,
      'categorieId': firestore.collection('categories').doc(categorieId),
      'ville': ville,
      'disponibilite': disponibilite,
      'competence': competence,
      'bio': bio,
      'gallery': gallery,
      'userId': firestore.collection('users').doc(userId),
    };
  }
  
  /// Convertir en Map pour Firestore (avec IDs seulement, sans DocumentReference)
  Map<String, dynamic> toMapWithIds() {
    return {
      ...super.toMap(),
      'image': image,
      'categorieId': categorieId,
      'ville': ville,
      'disponibilite': disponibilite,
      'competence': competence,
      'bio': bio,
      'gallery': gallery,
      'userId': userId,
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
    String? categorieId,
    String? ville,
    bool? disponibilite,
    String? competence,
    String? bio,
    String? gallery,
    String? userId,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      nomComplet: nomComplet ?? this.nomComplet,
      localisation: localisation ?? this.localisation,
      tel: tel ?? this.tel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      image: image ?? this.image,
      categorieId: categorieId ?? this.categorieId,
      ville: ville ?? this.ville,
      disponibilite: disponibilite ?? this.disponibilite,
      competence: competence ?? this.competence,
      bio: bio ?? this.bio,
      gallery: gallery ?? this.gallery,
      userId: userId ?? this.userId,
    );
  }

  @override
  String toString() {
    return 'EmployeeModel(id: $id, nomComplet: $nomComplet, ville: $ville)';
  }
}


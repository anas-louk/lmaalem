import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de données pour un utilisateur (classe de base)
class UserModel {
  final String id;
  final String nomComplet;
  final String localisation;
  final String type; // 'Employee' ou 'Client'
  final String tel;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.nomComplet,
    required this.localisation,
    required this.type,
    required this.tel,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Créer un UserModel depuis un Map (Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      nomComplet: map['nomComplet'] ?? '',
      localisation: map['localisation'] ?? '',
      type: map['type'] ?? '',
      tel: map['tel'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Créer un UserModel depuis un DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomComplet': nomComplet,
      'localisation': localisation,
      'type': type,
      'tel': tel,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Créer une copie avec des modifications
  UserModel copyWith({
    String? id,
    String? nomComplet,
    String? localisation,
    String? type,
    String? tel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nomComplet: nomComplet ?? this.nomComplet,
      localisation: localisation ?? this.localisation,
      type: type ?? this.type,
      tel: tel ?? this.tel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, nomComplet: $nomComplet, type: $type)';
  }
}

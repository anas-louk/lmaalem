import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// Modèle de données pour un client (hérite de UserModel)
class ClientModel extends UserModel {
  ClientModel({
    required super.id,
    required super.nomComplet,
    required super.localisation,
    required super.tel,
    required super.createdAt,
    required super.updatedAt,
  }) : super(type: 'Client');

  /// Créer un ClientModel depuis un Map (Firestore)
  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] ?? '',
      nomComplet: map['nomComplet'] ?? '',
      localisation: map['localisation'] ?? '',
      tel: map['tel'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Créer un ClientModel depuis un DocumentSnapshot
  factory ClientModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClientModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  /// Créer depuis un UserModel (pour la conversion)
  factory ClientModel.fromUserModel(UserModel user) {
    return ClientModel(
      id: user.id,
      nomComplet: user.nomComplet,
      localisation: user.localisation,
      tel: user.tel,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  /// Créer une copie avec des modifications
  @override
  ClientModel copyWith({
    String? id,
    String? nomComplet,
    String? localisation,
    String? type,
    String? tel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      nomComplet: nomComplet ?? this.nomComplet,
      localisation: localisation ?? this.localisation,
      tel: tel ?? this.tel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ClientModel(id: $id, nomComplet: $nomComplet)';
  }
}


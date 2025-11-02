import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de données pour une mission
class MissionModel {
  final String id;
  final double prixMission;
  final DateTime dateStart;
  final DateTime dateEnd;
  final String? qrMission;
  final String statutMission; // 'Pending', 'In Progress', 'Completed', 'Cancelled'
  final String? commentaire;
  final double? rating;
  final String employeeId; // ID de l'employé assigné
  final String clientId; // ID du client qui a créé la mission
  final DateTime createdAt;
  final DateTime updatedAt;

  MissionModel({
    required this.id,
    required this.prixMission,
    required this.dateStart,
    required this.dateEnd,
    this.qrMission,
    required this.statutMission,
    this.commentaire,
    this.rating,
    required this.employeeId,
    required this.clientId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Créer un MissionModel depuis un Map (Firestore)
  factory MissionModel.fromMap(Map<String, dynamic> map) {
    return MissionModel(
      id: map['id'] ?? '',
      prixMission: (map['prixMission'] as num?)?.toDouble() ?? 0.0,
      dateStart: (map['dateStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateEnd: (map['dateEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      qrMission: map['qrMission'],
      statutMission: map['statutMission'] ?? 'Pending',
      commentaire: map['commentaire'],
      rating: (map['rating'] as num?)?.toDouble(),
      employeeId: map['employeeId'] ?? '',
      clientId: map['clientId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Créer un MissionModel depuis un DocumentSnapshot
  factory MissionModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MissionModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prixMission': prixMission,
      'dateStart': Timestamp.fromDate(dateStart),
      'dateEnd': Timestamp.fromDate(dateEnd),
      'qrMission': qrMission,
      'statutMission': statutMission,
      'commentaire': commentaire,
      'rating': rating,
      'employeeId': employeeId,
      'clientId': clientId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Créer une copie avec des modifications
  MissionModel copyWith({
    String? id,
    double? prixMission,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? qrMission,
    String? statutMission,
    String? commentaire,
    double? rating,
    String? employeeId,
    String? clientId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MissionModel(
      id: id ?? this.id,
      prixMission: prixMission ?? this.prixMission,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      qrMission: qrMission ?? this.qrMission,
      statutMission: statutMission ?? this.statutMission,
      commentaire: commentaire ?? this.commentaire,
      rating: rating ?? this.rating,
      employeeId: employeeId ?? this.employeeId,
      clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MissionModel(id: $id, statutMission: $statutMission, prixMission: $prixMission)';
  }
}


import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de données pour une mission
class MissionModel {
  final String id;
  final double prixMission; // UML: PrixMission
  final DateTime dateStart; // UML: DateStart
  final DateTime dateEnd; // UML: DateEnd
  final String objMission; // UML: ObjMission (objectif de la mission)
  final String statutMission; // UML: StatutMission - 'Pending', 'In Progress', 'Completed', 'Cancelled'
  final String? commentaire; // UML: Commentaire
  final double? rating; // UML: Rating
  final String employeeId; // Reference to Employee collection (document ID)
  final String clientId; // Reference to Client collection (document ID)
  final String? requestId; // Reference to associated request (optional)
  final DateTime createdAt;
  final DateTime updatedAt;

  MissionModel({
    required this.id,
    required this.prixMission,
    required this.dateStart,
    required this.dateEnd,
    required this.objMission,
    required this.statutMission,
    this.commentaire,
    this.rating,
    required this.employeeId,
    required this.clientId,
    this.requestId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Créer un MissionModel depuis un Map (Firestore)
  factory MissionModel.fromMap(Map<String, dynamic> map) {
    // Handle DocumentReference for employeeId
    String employeeId = '';
    if (map['employeeId'] != null) {
      if (map['employeeId'] is DocumentReference) {
        employeeId = (map['employeeId'] as DocumentReference).id;
      } else {
        employeeId = map['employeeId'].toString();
      }
    }
    
    // Handle DocumentReference for clientId
    String clientId = '';
    if (map['clientId'] != null) {
      if (map['clientId'] is DocumentReference) {
        clientId = (map['clientId'] as DocumentReference).id;
      } else {
        clientId = map['clientId'].toString();
      }
    }

    return MissionModel(
      id: map['id'] ?? '',
      prixMission: (map['prixMission'] as num?)?.toDouble() ?? 0.0,
      dateStart: (map['dateStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateEnd: (map['dateEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      objMission: map['objMission'] ?? '',
      statutMission: map['statutMission'] ?? 'Pending',
      commentaire: map['commentaire'],
      rating: (map['rating'] as num?)?.toDouble(),
      employeeId: employeeId,
      clientId: clientId,
      requestId: map['requestId'],
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
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    return {
      'id': id,
      'prixMission': prixMission,
      'dateStart': Timestamp.fromDate(dateStart),
      'dateEnd': Timestamp.fromDate(dateEnd),
      'objMission': objMission,
      'statutMission': statutMission,
      'commentaire': commentaire,
      'rating': rating,
      'employeeId': firestore.collection('employees').doc(employeeId),
      'clientId': firestore.collection('clients').doc(clientId),
      'requestId': requestId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
  
  /// Convertir en Map pour Firestore (avec IDs seulement, sans DocumentReference)
  Map<String, dynamic> toMapWithIds() {
    return {
      'id': id,
      'prixMission': prixMission,
      'dateStart': Timestamp.fromDate(dateStart),
      'dateEnd': Timestamp.fromDate(dateEnd),
      'objMission': objMission,
      'statutMission': statutMission,
      'commentaire': commentaire,
      'rating': rating,
      'employeeId': employeeId,
      'clientId': clientId,
      'requestId': requestId,
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
    String? objMission,
    String? statutMission,
    String? commentaire,
    double? rating,
    String? employeeId,
    String? clientId,
    String? requestId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MissionModel(
      id: id ?? this.id,
      prixMission: prixMission ?? this.prixMission,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      objMission: objMission ?? this.objMission,
      statutMission: statutMission ?? this.statutMission,
      commentaire: commentaire ?? this.commentaire,
      rating: rating ?? this.rating,
      employeeId: employeeId ?? this.employeeId,
      clientId: clientId ?? this.clientId,
      requestId: requestId ?? this.requestId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MissionModel(id: $id, statutMission: $statutMission, prixMission: $prixMission, requestId: $requestId)';
  }
}


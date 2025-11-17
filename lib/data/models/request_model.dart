import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de données pour une demande client
class RequestModel {
  final String id;
  final String description; // Description de la demande
  final List<String> images; // URLs des images
  final double latitude; // Latitude de la localisation
  final double longitude; // Longitude de la localisation
  final String address; // Adresse textuelle
  final String categorieId; // ID de la catégorie
  final String clientId; // ID du client
  final String statut; // Statut: 'Pending', 'Accepted', 'Completed', 'Cancelled'
  final String? employeeId; // ID de l'employé finalement accepté par le client
  final List<String> acceptedEmployeeIds; // IDs des employés qui ont accepté la demande
  final List<String> refusedEmployeeIds; // IDs des employés qui ont refusé la demande
  final DateTime createdAt;
  final DateTime updatedAt;

  RequestModel({
    required this.id,
    required this.description,
    List<String>? images,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.categorieId,
    required this.clientId,
    this.statut = 'Pending',
    this.employeeId,
    List<String>? acceptedEmployeeIds,
    List<String>? refusedEmployeeIds,
    required this.createdAt,
    required this.updatedAt,
  }) : images = images ?? [],
       acceptedEmployeeIds = acceptedEmployeeIds ?? [],
       refusedEmployeeIds = refusedEmployeeIds ?? [];

  /// Créer un RequestModel depuis un Map (Firestore)
  factory RequestModel.fromMap(Map<String, dynamic> map) {
    // Handle DocumentReference for categorieId (backward compatibility)
    String categorieId = '';
    if (map['categorieId'] != null) {
      if (map['categorieId'] is DocumentReference) {
        categorieId = (map['categorieId'] as DocumentReference).id;
      } else {
        categorieId = map['categorieId'].toString();
      }
    }
    
    return RequestModel(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      categorieId: categorieId,
      clientId: map['clientId'] ?? '',
      statut: map['statut'] ?? 'Pending',
      employeeId: map['employeeId'],
      acceptedEmployeeIds: List<String>.from(map['acceptedEmployeeIds'] ?? []),
      refusedEmployeeIds: List<String>.from(map['refusedEmployeeIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Créer un RequestModel depuis un DocumentSnapshot
  factory RequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RequestModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'images': images,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'categorieId': categorieId,
      'clientId': clientId,
      'statut': statut,
      'employeeId': employeeId,
      'acceptedEmployeeIds': acceptedEmployeeIds,
      'refusedEmployeeIds': refusedEmployeeIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Créer une copie avec des modifications
  RequestModel copyWith({
    String? id,
    String? description,
    List<String>? images,
    double? latitude,
    double? longitude,
    String? address,
    String? categorieId,
    String? clientId,
    String? statut,
    String? employeeId,
    List<String>? acceptedEmployeeIds,
    List<String>? refusedEmployeeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RequestModel(
      id: id ?? this.id,
      description: description ?? this.description,
      images: images ?? this.images,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      categorieId: categorieId ?? this.categorieId,
      clientId: clientId ?? this.clientId,
      statut: statut ?? this.statut,
      employeeId: employeeId ?? this.employeeId,
      acceptedEmployeeIds: acceptedEmployeeIds ?? this.acceptedEmployeeIds,
      refusedEmployeeIds: refusedEmployeeIds ?? this.refusedEmployeeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'RequestModel(id: $id, statut: $statut, categorieId: $categorieId)';
  }
}


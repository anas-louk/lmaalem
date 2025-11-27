import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/enums/request_flow_state.dart';
import 'accepted_employee_summary.dart';

/// Modèle de données pour une demande client
class RequestModel {
  final String id;
  final String description; // Description de la demande
  final double latitude; // Latitude de la localisation
  final double longitude; // Longitude de la localisation
  final String address; // Adresse textuelle
  final String categorieId; // ID de la catégorie
  final String clientId; // ID du client
  final String statut; // Statut: 'Pending', 'Accepted', 'Completed', 'Cancelled'
  final String? employeeId; // ID de l'employé finalement accepté par le client
  final List<String> acceptedEmployeeIds; // IDs des employés qui ont accepté la demande
  final List<String> refusedEmployeeIds; // IDs des employés qui ont refusé la demande
  final List<String> clientRefusedEmployeeIds; // IDs des employés refusés par le client
  final DateTime createdAt;
  final DateTime updatedAt;

  RequestModel({
    required this.id,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.categorieId,
    required this.clientId,
    this.statut = 'Pending',
    this.employeeId,
    List<String>? acceptedEmployeeIds,
    List<String>? refusedEmployeeIds,
    List<String>? clientRefusedEmployeeIds,
    required this.createdAt,
    required this.updatedAt,
  }) : acceptedEmployeeIds = acceptedEmployeeIds ?? [],
       refusedEmployeeIds = refusedEmployeeIds ?? [],
       clientRefusedEmployeeIds = clientRefusedEmployeeIds ?? [];

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
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      categorieId: categorieId,
      clientId: map['clientId'] ?? '',
      statut: map['statut'] ?? 'Pending',
      employeeId: map['employeeId'],
      acceptedEmployeeIds: List<String>.from(map['acceptedEmployeeIds'] ?? []),
      refusedEmployeeIds: List<String>.from(map['refusedEmployeeIds'] ?? []),
      clientRefusedEmployeeIds: List<String>.from(map['clientRefusedEmployeeIds'] ?? []),
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
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'categorieId': categorieId,
      'clientId': clientId,
      'statut': statut,
      'employeeId': employeeId,
      'acceptedEmployeeIds': acceptedEmployeeIds,
      'refusedEmployeeIds': refusedEmployeeIds,
      'clientRefusedEmployeeIds': clientRefusedEmployeeIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Créer une copie avec des modifications
  RequestModel copyWith({
    String? id,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? categorieId,
    String? clientId,
    String? statut,
    String? employeeId,
    List<String>? acceptedEmployeeIds,
    List<String>? refusedEmployeeIds,
    List<String>? clientRefusedEmployeeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RequestModel(
      id: id ?? this.id,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      categorieId: categorieId ?? this.categorieId,
      clientId: clientId ?? this.clientId,
      statut: statut ?? this.statut,
      employeeId: employeeId ?? this.employeeId,
      acceptedEmployeeIds: acceptedEmployeeIds ?? this.acceptedEmployeeIds,
      refusedEmployeeIds: refusedEmployeeIds ?? this.refusedEmployeeIds,
      clientRefusedEmployeeIds: clientRefusedEmployeeIds ?? this.clientRefusedEmployeeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'RequestModel(id: $id, statut: $statut, categorieId: $categorieId)';
  }
}

/// Extension pour ajouter des propriétés calculées à RequestModel
extension RequestModelX on RequestModel {
  /// Convertit le statut String en RequestFlowState
  RequestFlowState get requestStatus {
    return RequestFlowStateX.fromLegacyStatut(statut);
  }

  /// Récupère l'employé accepté (si disponible)
  /// Note: Cette propriété peut être null si aucun employé n'a été accepté
  AcceptedEmployeeSummary? get acceptedEmployee {
    // Si employeeId est défini, on peut créer un résumé basique
    // Dans un cas réel, on devrait charger les détails de l'employé depuis la base de données
    if (employeeId != null && employeeId!.isNotEmpty) {
      return AcceptedEmployeeSummary(id: employeeId!);
    }
    return null;
  }
}


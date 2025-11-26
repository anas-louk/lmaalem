import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle pour les rapports d'annulation de demande
class CancellationReportModel {
  final String id;
  final String requestId;
  final String clientId;
  final String? employeeId;
  final String? clientReason; // Raison donnée par le client
  final String? employeeNotificationReason; // Raison notifiée à l'employé
  final DateTime createdAt;
  final DateTime updatedAt;

  CancellationReportModel({
    required this.id,
    required this.requestId,
    required this.clientId,
    this.employeeId,
    this.clientReason,
    this.employeeNotificationReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CancellationReportModel.fromMap(Map<String, dynamic> map) {
    return CancellationReportModel(
      id: map['id'] ?? '',
      requestId: map['requestId'] ?? '',
      clientId: map['clientId'] ?? '',
      employeeId: map['employeeId'],
      clientReason: map['clientReason'],
      employeeNotificationReason: map['employeeNotificationReason'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory CancellationReportModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CancellationReportModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'clientId': clientId,
      'employeeId': employeeId,
      'clientReason': clientReason,
      'employeeNotificationReason': employeeNotificationReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CancellationReportModel copyWith({
    String? id,
    String? requestId,
    String? clientId,
    String? employeeId,
    String? clientReason,
    String? employeeNotificationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CancellationReportModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      clientId: clientId ?? this.clientId,
      employeeId: employeeId ?? this.employeeId,
      clientReason: clientReason ?? this.clientReason,
      employeeNotificationReason: employeeNotificationReason ?? this.employeeNotificationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


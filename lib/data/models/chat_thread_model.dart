import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant un fil de discussion entre un client et un employé.
class ChatThreadModel {
  final String id;
  final String requestId;
  final String requestTitle;
  final String clientId;
  final String clientName;
  final String employeeId; // Employee document ID
  final String? employeeUserId; // User ID correspondant à l'employé
  final String employeeName;
  final bool isActive;
  final String requestStatus;
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatThreadModel({
    required this.id,
    required this.requestId,
    required this.requestTitle,
    required this.clientId,
    required this.clientName,
    required this.employeeId,
    required this.employeeName,
    this.employeeUserId,
    required this.isActive,
    required this.requestStatus,
    this.lastMessage,
    this.lastSenderId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatThreadModel.fromMap(Map<String, dynamic> map) {
    return ChatThreadModel(
      id: map['id'] ?? map['requestId'] ?? '',
      requestId: map['requestId'] ?? '',
      requestTitle: map['requestTitle'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeUserId: map['employeeUserId'],
      employeeName: map['employeeName'] ?? '',
      isActive: map['isActive'] ?? false,
      requestStatus: map['requestStatus'] ?? 'Pending',
      lastMessage: map['lastMessage'],
      lastSenderId: map['lastSenderId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ChatThreadModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatThreadModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'requestTitle': requestTitle,
      'clientId': clientId,
      'clientName': clientName,
      'employeeId': employeeId,
      'employeeUserId': employeeUserId,
      'employeeName': employeeName,
      'isActive': isActive,
      'requestStatus': requestStatus,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ChatThreadModel copyWith({
    String? id,
    String? requestId,
    String? requestTitle,
    String? clientId,
    String? clientName,
    String? employeeId,
    String? employeeUserId,
    String? employeeName,
    bool? isActive,
    String? requestStatus,
    String? lastMessage,
    String? lastSenderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatThreadModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      requestTitle: requestTitle ?? this.requestTitle,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      employeeId: employeeId ?? this.employeeId,
      employeeUserId: employeeUserId ?? this.employeeUserId,
      employeeName: employeeName ?? this.employeeName,
      isActive: isActive ?? this.isActive,
      requestStatus: requestStatus ?? this.requestStatus,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}



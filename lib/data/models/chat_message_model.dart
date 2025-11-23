import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant un message dans un fil de discussion.
class ChatMessageModel {
  final String id;
  final String threadId;
  final String senderId;
  final String senderRole; // 'client' ou 'employee'
  final String content;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] ?? '',
      threadId: map['threadId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderRole: map['senderRole'] ?? 'client',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ChatMessageModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessageModel.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'threadId': threadId,
      'senderId': senderId,
      'senderRole': senderRole,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}



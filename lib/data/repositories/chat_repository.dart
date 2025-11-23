import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/logger.dart';
import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';

/// Repository pour gérer les discussions client-employé.
class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _threadsCollection = 'chats';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_threadsCollection);

  Future<ChatThreadModel?> getThreadByRequestId(String requestId) async {
    try {
      final doc = await _collection.doc(requestId).get();
      if (!doc.exists) return null;
      return ChatThreadModel.fromDocument(doc);
    } catch (e, stackTrace) {
      Logger.logError('ChatRepository.getThreadByRequestId', e, stackTrace);
      rethrow;
    }
  }

  Future<ChatThreadModel> createOrActivateThread({
    required String requestId,
    required String requestTitle,
    required String clientId,
    required String clientName,
    required String employeeId,
    required String employeeName,
    String? employeeUserId,
    required String requestStatus,
  }) async {
    try {
      final docRef = _collection.doc(requestId);
      final now = DateTime.now();
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        await docRef.update({
          'isActive': true,
          'requestStatus': requestStatus,
          'updatedAt': Timestamp.fromDate(now),
        });
        final refreshed = await docRef.get();
        return ChatThreadModel.fromDocument(refreshed);
      }

      final thread = ChatThreadModel(
        id: requestId,
        requestId: requestId,
        requestTitle: requestTitle,
        clientId: clientId,
        clientName: clientName,
        employeeId: employeeId,
        employeeUserId: employeeUserId,
        employeeName: employeeName,
        isActive: true,
        requestStatus: requestStatus,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(thread.toMap());
      return thread;
    } catch (e, stackTrace) {
      Logger.logError('ChatRepository.createOrActivateThread', e, stackTrace);
      rethrow;
    }
  }

  Future<void> closeThreadForRequest(
    String requestId, {
    String requestStatus = 'Completed',
  }) async {
    try {
      final docRef = _collection.doc(requestId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;
      await docRef.update({
        'isActive': false,
        'requestStatus': requestStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e, stackTrace) {
      Logger.logError('ChatRepository.closeThreadForRequest', e, stackTrace);
      rethrow;
    }
  }

  Stream<List<ChatMessageModel>> streamMessages(String requestId) {
    return _collection
        .doc(requestId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromDocument(doc))
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String requestId,
    required String senderId,
    required String senderRole,
    required String content,
  }) async {
    if (content.trim().isEmpty) return;

    final docRef = _collection.doc(requestId);
    final threadSnapshot = await docRef.get();
    if (!threadSnapshot.exists) {
      throw 'Chat introuvable pour cette demande';
    }

    final thread = ChatThreadModel.fromDocument(threadSnapshot);
    if (!thread.isActive) {
      throw 'Le chat est désactivé pour cette demande';
    }

    final messagesRef = docRef.collection('messages').doc();
    final now = DateTime.now();
    final message = ChatMessageModel(
      id: messagesRef.id,
      threadId: requestId,
      senderId: senderId,
      senderRole: senderRole,
      content: content.trim(),
      createdAt: now,
    );

    final batch = _firestore.batch();
    batch.set(messagesRef, message.toMap());
    batch.update(docRef, {
      'lastMessage': message.content,
      'lastSenderId': senderId,
      'updatedAt': Timestamp.fromDate(now),
    });

    await batch.commit();
  }
}



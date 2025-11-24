import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { ringing, accepted, ended }
enum CallType { audio, video }

CallStatus callStatusFromString(String value) {
  switch (value) {
    case 'accepted':
      return CallStatus.accepted;
    case 'ended':
      return CallStatus.ended;
    default:
      return CallStatus.ringing;
  }
}

CallType callTypeFromString(String value) {
  switch (value) {
    case 'video':
      return CallType.video;
    default:
      return CallType.audio;
  }
}

class CallSession {
  final String id;
  final String callerId;
  final String calleeId;
  final CallType type;
  final CallStatus status;
  final Map<String, dynamic>? sdpOffer;
  final Map<String, dynamic>? sdpAnswer;
  final Timestamp? createdAt;
  final Timestamp? lastUpdatedAt;

  CallSession({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.type,
    required this.status,
    required this.sdpOffer,
    required this.sdpAnswer,
    this.createdAt,
    this.lastUpdatedAt,
  });

  factory CallSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CallSession(
      id: doc.id,
      callerId: data['callerId'] ?? '',
      calleeId: data['calleeId'] ?? '',
      type: callTypeFromString(data['type'] ?? 'audio'),
      status: callStatusFromString(data['status'] ?? 'ringing'),
      sdpOffer: data['sdpOffer'],
      sdpAnswer: data['sdpAnswer'],
      createdAt: data['createdAt'],
      lastUpdatedAt: data['lastUpdatedAt'],
    );
  }
}



import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de paiement pour Firestore
class PaymentModel {
  final String id;
  final String userId;
  final String paymentIntentId;
  final double amount;
  final String currency;
  final String status; // 'pending', 'succeeded', 'failed', 'canceled'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  PaymentModel({
    required this.id,
    required this.userId,
    required this.paymentIntentId,
    required this.amount,
    this.currency = 'eur',
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  /// Créer depuis un document Firestore
  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      userId: data['userId'] as String,
      paymentIntentId: data['paymentIntentId'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'eur',
      status: data['status'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'paymentIntentId': paymentIntentId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
    };
  }

  /// Créer une copie avec des valeurs modifiées
  PaymentModel copyWith({
    String? id,
    String? userId,
    String? paymentIntentId,
    double? amount,
    String? currency,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Vérifier si le paiement a réussi
  bool get isSucceeded => status == 'succeeded';

  /// Vérifier si le paiement est en attente
  bool get isPending => status == 'pending';

  /// Vérifier si le paiement a échoué
  bool get isFailed => status == 'failed';

  @override
  String toString() {
    return 'PaymentModel(id: $id, userId: $userId, amount: $amount $currency, status: $status)';
  }
}


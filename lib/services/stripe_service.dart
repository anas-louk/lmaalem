import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/stripe_config.dart';
import '../models/payment_model.dart';

/// Service pour gérer les paiements Stripe
class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialiser Stripe avec la clé publique
  Future<void> initialize() async {
    try {
      Stripe.publishableKey = StripeConfig.publishableKey;
      Stripe.merchantIdentifier = StripeConfig.merchantIdentifier;
      await Stripe.instance.applySettings();
    } catch (e) {
      throw 'Erreur lors de l\'initialisation de Stripe: $e';
    }
  }

  /// Créer un PaymentIntent via le backend
  Future<String> createPaymentIntent({
    required double amount,
    required String userId,
    String currency = 'eur',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(StripeConfig.createPaymentIntentEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'metadata': {
            'userId': userId,
            ...?metadata,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['clientSecret'] as String;
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw error['message'] ?? 'Erreur lors de la création du PaymentIntent';
      }
    } catch (e) {
      throw 'Erreur réseau: $e';
    }
  }

  /// Confirmer le paiement avec PaymentSheet
  Future<void> confirmPayment({
    required String clientSecret,
    required String userId,
    required double amount,
    String currency = 'eur',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Initialiser PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Lmaalem',
          applePay: const PaymentSheetApplePay(
            merchantCountryCode: 'FR',
          ),
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'FR',
            testEnv: true, // Mettez à false en production
          ),
        ),
      );

      // Afficher PaymentSheet
      await Stripe.instance.presentPaymentSheet();

      // Récupérer les détails du PaymentIntent
      final paymentIntent = await Stripe.instance.retrievePaymentIntent(clientSecret);

      // Enregistrer le paiement dans Firestore
      // Le statut est une String: 'succeeded', 'processing', 'requires_payment_method', etc.
      final status = paymentIntent.status;
      if (status == 'succeeded') {
        await _savePaymentToFirestore(
          userId: userId,
          paymentIntentId: paymentIntent.id,
          amount: amount,
          currency: currency,
          status: 'succeeded',
          metadata: metadata,
        );
      }
    } on StripeException catch (e) {
      // Gérer les erreurs Stripe
      if (e.error.code == FailureCode.Canceled) {
        throw 'Paiement annulé par l\'utilisateur';
      } else {
        throw 'Erreur de paiement: ${e.error.message ?? "Erreur inconnue"}';
      }
    } catch (e) {
      throw 'Erreur lors de la confirmation du paiement: $e';
    }
  }

  /// Sauvegarder le paiement dans Firestore
  Future<void> _savePaymentToFirestore({
    required String userId,
    required String paymentIntentId,
    required double amount,
    required String currency,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final paymentData = {
        'userId': userId,
        'paymentIntentId': paymentIntentId,
        'amount': amount,
        'currency': currency,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (metadata != null) 'metadata': metadata,
      };

      await _firestore
          .collection('payments')
          .add(paymentData);
    } catch (e) {
      // Log l'erreur mais ne pas faire échouer le paiement
      print('Erreur lors de la sauvegarde du paiement dans Firestore: $e');
    }
  }

  /// Processus complet de paiement
  /// 
  /// Cette méthode combine la création du PaymentIntent et la confirmation
  Future<void> processPayment({
    required double amount,
    required String userId,
    String currency = 'eur',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 1. Créer le PaymentIntent
      final clientSecret = await createPaymentIntent(
        amount: amount,
        userId: userId,
        currency: currency,
        metadata: metadata,
      );

      // 2. Enregistrer le paiement en attente dans Firestore
      await _savePaymentToFirestore(
        userId: userId,
        paymentIntentId: '', // Sera mis à jour après confirmation
        amount: amount,
        currency: currency,
        status: 'pending',
        metadata: metadata,
      );

      // 3. Confirmer le paiement
      await confirmPayment(
        clientSecret: clientSecret,
        userId: userId,
        amount: amount,
        currency: currency,
        metadata: metadata,
      );
    } catch (e) {
      // En cas d'erreur, mettre à jour le statut dans Firestore si possible
      rethrow;
    }
  }

  /// Récupérer les paiements d'un utilisateur
  Stream<List<PaymentModel>> getUserPayments(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Récupérer un paiement par ID
  Future<PaymentModel?> getPaymentById(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        return PaymentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Erreur lors de la récupération du paiement: $e';
    }
  }
}


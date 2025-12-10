import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/stripe_service.dart';
import '../core/helpers/snackbar_helper.dart';
import '../config/stripe_config.dart';

/// Controller pour gérer les paiements Stripe
class PaymentController extends GetxController {
  final StripeService _stripeService = StripeService();

  // Observable states
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxDouble amount = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
  }

  /// Traiter un paiement
  Future<bool> processPayment({
    required double amount,
    required String userId,
    String currency = 'eur',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      print('[PaymentController] Début du traitement du paiement: $amount $currency');

      // Valider le montant
      if (amount <= 0) {
        errorMessage.value = 'Le montant doit être supérieur à 0';
        SnackbarHelper.showError('Le montant doit être supérieur à 0');
        return false;
      }

      // Vérifier la configuration Stripe
      if (!StripeConfig.isConfigured) {
        final errorMsg = 'Stripe n\'est pas configuré correctement';
        errorMessage.value = errorMsg;
        SnackbarHelper.showError(errorMsg);
        print('[PaymentController] ❌ $errorMsg');
        return false;
      }

      print('[PaymentController] Configuration Stripe OK, traitement du paiement...');

      // Traiter le paiement
      // Si aucune exception n'est levée, le paiement a réussi
      await _stripeService.processPayment(
        amount: amount,
        userId: userId,
        currency: currency,
        metadata: metadata,
      );

      print('[PaymentController] ✅ Paiement traité avec succès');

      // Si on arrive ici, le paiement a réussi
      SnackbarHelper.showSuccess('Paiement réussi !');
      return true;
    } on StripeException catch (e) {
      print('[PaymentController] ❌ Erreur Stripe: ${e.error.code} - ${e.error.message}');
      String message = 'Erreur de paiement';
      if (e.error.code == FailureCode.Canceled) {
        message = 'Paiement annulé';
      } else if (e.error.message != null) {
        message = e.error.message!;
      } else {
        message = 'Erreur: ${e.error.code}';
      }
      errorMessage.value = message;
      SnackbarHelper.showError(message);
      return false;
    } catch (e, stackTrace) {
      print('[PaymentController] ❌ Erreur: $e');
      print('[PaymentController] Stack trace: $stackTrace');
      errorMessage.value = e.toString();
      SnackbarHelper.showError('Erreur: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mettre à jour le montant
  void updateAmount(double newAmount) {
    amount.value = newAmount;
  }
}


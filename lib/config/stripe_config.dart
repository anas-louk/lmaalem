/// Configuration Stripe
/// 
/// Centralisé la configuration Stripe pour l'application.
/// 
/// IMPORTANT: Utilisez uniquement la clé PUBLIQUE Stripe ici.
/// La clé secrète doit rester sur le backend.
class StripeConfig {
  StripeConfig._();

  /// Clé publique Stripe (publishable key)
  /// 
  /// Obtenez-la depuis: https://dashboard.stripe.com/apikeys
  /// 
  /// Pour les tests, utilisez la clé de test (commence par pk_test_)
  /// Pour la production, utilisez la clé de production (commence par pk_live_)
  static const String publishableKey = 'pk_test_51ScpYqJzkJ8OjG5uBB2orwDGoLyBtlrYeSgbT4MZ1dEf1sLcEgG2757SnOSS47q1JRzBG6UGb6WLhZ0gPLbAYQVv00aipwVB9y';

  /// URL du backend pour créer les PaymentIntents
  /// 
  /// Remplacez par votre URL Vercel/Netlify après déploiement
  /// Exemple: https://votre-projet.vercel.app
  static const String backendUrl = 'https://lmaalem.vercel.app';

  /// Endpoint pour créer un PaymentIntent
  static String get createPaymentIntentEndpoint => '$backendUrl/api/create-payment-intent';

  /// Merchant Identifier pour Apple Pay (iOS uniquement)
  /// 
  /// Obtenez-le depuis votre compte Apple Developer
  /// Format: merchant.com.votredomaine.app
  static const String merchantIdentifier = 'merchant.com.lmaalem.app';

  /// Vérifier si la configuration est valide
  static bool get isConfigured {
    return publishableKey.isNotEmpty && 
           publishableKey.startsWith('pk_') &&
           backendUrl.isNotEmpty &&
           !backendUrl.contains('YOUR');
  }

  /// Obtenir un résumé de la configuration (pour le debug)
  static String getConfigSummary() {
    return '''
Stripe Configuration:
  Publishable Key: ${publishableKey.substring(0, 20)}...
  Backend URL: $backendUrl
  Merchant ID: $merchantIdentifier
  Configured: $isConfigured
''';
  }
}


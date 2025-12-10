# Guide d'intégration Stripe - Lmaalem

Ce guide vous explique comment configurer et utiliser le système de paiement Stripe dans l'application Lmaalem.

## 📋 Table des matières

1. [Prérequis](#prérequis)
2. [Configuration Stripe](#configuration-stripe)
3. [Configuration du Backend](#configuration-du-backend)
4. [Configuration Flutter](#configuration-flutter)
5. [Déploiement du Backend](#déploiement-du-backend)
6. [Utilisation dans l'application](#utilisation-dans-lapplication)
7. [Tests](#tests)
8. [Dépannage](#dépannage)

## 🔧 Prérequis

- Compte Stripe (gratuit) : [https://dashboard.stripe.com/register](https://dashboard.stripe.com/register)
- Compte Vercel ou Netlify (gratuit)
- Node.js 18+ (pour le développement local)
- Flutter SDK avec les dépendances installées

## 💳 Configuration Stripe

### 1. Obtenir les clés API Stripe

1. Connectez-vous à votre [tableau de bord Stripe](https://dashboard.stripe.com)
2. Allez dans **Developers** → **API keys**
3. Copiez votre **Publishable key** (commence par `pk_test_` pour les tests)
4. Copiez votre **Secret key** (commence par `sk_test_` pour les tests)

⚠️ **IMPORTANT**: 
- Utilisez les clés de **test** pour le développement
- Utilisez les clés de **production** uniquement en production
- Ne partagez JAMAIS votre clé secrète dans le code client

### 2. Activer Apple Pay / Google Pay (optionnel)

#### Apple Pay (iOS)
1. Allez dans **Settings** → **Apple Pay**
2. Créez un **Merchant Identifier** dans votre compte Apple Developer
3. Configurez-le dans `lib/config/stripe_config.dart`

#### Google Pay (Android)
1. Allez dans **Settings** → **Google Pay**
2. Suivez les instructions pour activer Google Pay
3. Le test est activé par défaut dans le code (modifiez `testEnv: false` en production)

## 🖥️ Configuration du Backend

### 1. Configuration locale

1. Allez dans le dossier `stripe-backend`:
```bash
cd stripe-backend
```

2. Installez les dépendances:
```bash
npm install
```

3. Créez un fichier `.env`:
```env
STRIPE_SECRET_KEY=sk_test_VOTRE_CLE_SECRETE_ICI
PORT=3000
NODE_ENV=development
```

4. Testez localement:
```bash
npm start
```

Le serveur devrait démarrer sur `http://localhost:3000`

### 2. Test de l'endpoint

Testez avec curl ou Postman:
```bash
curl -X POST http://localhost:3000/create-payment-intent \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "currency": "eur"}'
```

Vous devriez recevoir une réponse avec `clientSecret`.

## 📱 Configuration Flutter

### 1. Mettre à jour la configuration Stripe

Éditez `lib/config/stripe_config.dart`:

```dart
static const String publishableKey = 'pk_test_VOTRE_CLE_PUBLIQUE_ICI';
static const String backendUrl = 'https://votre-projet.vercel.app';
```

### 2. Installer les dépendances

```bash
flutter pub get
```

### 3. Configuration Android

Aucune configuration supplémentaire n'est nécessaire pour Android. Le package `flutter_stripe` gère automatiquement les permissions nécessaires.

### 4. Configuration iOS

#### a. Ajouter le Merchant Identifier

1. Ouvrez `ios/Runner.xcworkspace` dans Xcode
2. Sélectionnez le projet **Runner**
3. Allez dans **Signing & Capabilities**
4. Cliquez sur **+ Capability** et ajoutez **Apple Pay**
5. Sélectionnez votre Merchant Identifier

#### b. Mettre à jour Info.plist

Ajoutez dans `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

⚠️ En production, configurez correctement les domaines autorisés.

## 🚀 Déploiement du Backend

### Option A: Déploiement sur Vercel (Recommandé)

#### 1. Installation de Vercel CLI

```bash
npm install -g vercel
```

#### 2. Connexion à Vercel

```bash
vercel login
```

#### 3. Déploiement

```bash
cd stripe-backend
vercel
```

Suivez les instructions:
- Créez un nouveau projet
- Ajoutez la variable d'environnement `STRIPE_SECRET_KEY` quand demandé

#### 4. Configuration des variables d'environnement

1. Allez sur [vercel.com](https://vercel.com)
2. Sélectionnez votre projet
3. Allez dans **Settings** → **Environment Variables**
4. Ajoutez:
   - `STRIPE_SECRET_KEY` = votre clé secrète Stripe

#### 5. Obtenir l'URL de l'API

Après le déploiement, Vercel vous donnera une URL comme:
```
https://votre-projet.vercel.app
```

Mettez à jour `lib/config/stripe_config.dart` avec cette URL.

### Option B: Déploiement sur Netlify

#### 1. Créer netlify.toml

Créez `stripe-backend/netlify.toml`:

```toml
[build]
  functions = "."
  command = "echo 'No build needed'"

[[redirects]]
  from = "/*"
  to = "/.netlify/functions/index"
  status = 200
```

#### 2. Créer la fonction serverless

Créez `stripe-backend/netlify/functions/index.js` et copiez le contenu de `index.js` en adaptant pour Netlify.

#### 3. Déployer

1. Allez sur [netlify.com](https://netlify.com)
2. Créez un nouveau site depuis Git
3. Ajoutez la variable d'environnement `STRIPE_SECRET_KEY`

## 💻 Utilisation dans l'application

### 1. Navigation vers l'écran de paiement

```dart
// Paiement simple
Get.toNamed(AppRoutes.payment);

// Paiement avec montant initial
Get.toNamed(
  AppRoutes.payment,
  arguments: {
    'amount': 100.0,
    'metadata': {
      'orderId': 'order123',
      'description': 'Paiement de service',
    },
  },
);
```

### 2. Utilisation du service directement

```dart
final stripeService = StripeService();

try {
  await stripeService.processPayment(
    amount: 100.0,
    userId: currentUser.id,
    currency: 'eur',
    metadata: {
      'orderId': 'order123',
    },
  );
  // Paiement réussi
} catch (e) {
  // Gérer l'erreur
  print('Erreur: $e');
}
```

### 3. Récupérer l'historique des paiements

```dart
final stripeService = StripeService();

// Stream des paiements de l'utilisateur
stripeService.getUserPayments(userId).listen((payments) {
  // Mettre à jour l'UI avec les paiements
});
```

## 🧪 Tests

### 1. Cartes de test Stripe

Utilisez ces cartes pour tester:

| Numéro de carte | Description |
|----------------|-------------|
| `4242 4242 4242 4242` | Paiement réussi |
| `4000 0000 0000 0002` | Paiement refusé |
| `4000 0025 0000 3155` | 3D Secure requis |

**Date d'expiration**: N'importe quelle date future  
**CVC**: N'importe quel code à 3 chiffres  
**Code postal**: N'importe quel code postal valide

### 2. Tester le flux complet

1. Lancez l'application
2. Naviguez vers l'écran de paiement
3. Entrez un montant (ex: 10.00)
4. Cliquez sur "Payer maintenant"
5. Utilisez une carte de test
6. Vérifiez que le paiement est enregistré dans Firestore

## 🔍 Dépannage

### Erreur: "Stripe non configuré"

**Solution**: Vérifiez que `StripeConfig.isConfigured` retourne `true`. Assurez-vous que:
- La clé publique est définie dans `stripe_config.dart`
- L'URL du backend est définie
- Les clés commencent par `pk_` (publique) et `sk_` (secrète)

### Erreur: "Network error" lors de la création du PaymentIntent

**Solutions**:
1. Vérifiez que le backend est déployé et accessible
2. Vérifiez l'URL dans `stripe_config.dart`
3. Vérifiez que la clé secrète est correcte dans les variables d'environnement du backend
4. Vérifiez les logs du backend (Vercel/Netlify)

### Erreur: "Payment sheet failed to initialize"

**Solutions**:
1. Vérifiez que Stripe est initialisé dans `main.dart`
2. Vérifiez que la clé publique est correcte
3. Vérifiez les logs de l'application

### Apple Pay / Google Pay ne s'affichent pas

**Solutions**:
1. Vérifiez que les services sont activés dans votre compte Stripe
2. Pour Apple Pay: vérifiez le Merchant Identifier dans Xcode
3. Pour Google Pay: vérifiez que `testEnv` est correctement configuré

### Le paiement réussit mais n'est pas enregistré dans Firestore

**Solutions**:
1. Vérifiez les règles de sécurité Firestore
2. Vérifiez que l'utilisateur est authentifié
3. Vérifiez les logs de l'application pour les erreurs

## 📚 Ressources

- [Documentation Stripe Flutter](https://stripe.dev/stripe-flutter/)
- [Documentation Stripe API](https://stripe.com/docs/api)
- [Documentation Vercel](https://vercel.com/docs)
- [Documentation Netlify Functions](https://docs.netlify.com/functions/overview/)

## 🔒 Sécurité

### ⚠️ Règles importantes

1. **NE JAMAIS** exposer la clé secrète Stripe dans le code client
2. **TOUJOURS** utiliser HTTPS en production
3. **VALIDER** les montants côté backend (optionnel mais recommandé)
4. **LIMITER** les origines CORS en production
5. **UTILISER** les clés de test pour le développement

### Configuration CORS en production

Modifiez `stripe-backend/index.js` pour limiter les origines:

```javascript
app.use(cors({
  origin: ['https://votre-domaine.com'], // Limitez aux domaines autorisés
  credentials: true
}));
```

## 📝 Structure Firestore

Les paiements sont enregistrés dans la collection `payments` avec cette structure:

```json
{
  "userId": "user123",
  "paymentIntentId": "pi_xxx",
  "amount": 100.0,
  "currency": "eur",
  "status": "succeeded",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "metadata": {
    "orderId": "order123"
  }
}
```

## ✅ Checklist de déploiement

- [ ] Compte Stripe créé
- [ ] Clés API obtenues (test et production)
- [ ] Backend déployé sur Vercel/Netlify
- [ ] Variables d'environnement configurées
- [ ] URL du backend mise à jour dans `stripe_config.dart`
- [ ] Clé publique mise à jour dans `stripe_config.dart`
- [ ] Merchant Identifier configuré (iOS)
- [ ] Tests effectués avec les cartes de test
- [ ] Règles Firestore configurées pour la collection `payments`
- [ ] CORS configuré pour la production

---

**Support**: Pour toute question, consultez la documentation Stripe ou créez une issue dans le dépôt du projet.


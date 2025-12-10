# 🚀 Instructions de déploiement - Backend Stripe Vercel

## ✅ Structure finale du projet

```
stripe-backend/
├── api/
│   └── create-payment-intent.js    ← Fonction serverless Vercel
├── index.js                          ← Pour développement local (optionnel)
├── package.json                      ← Dépendances mises à jour
├── vercel.json                       ← Configuration Vercel
└── ...
```

## 📋 Checklist avant déploiement

- [x] Dossier `/api` créé
- [x] Fonction `create-payment-intent.js` créée
- [x] `package.json` mis à jour (Node.js 20.x, Stripe latest)
- [x] `vercel.json` configuré correctement
- [ ] Variable d'environnement `STRIPE_SECRET_KEY` configurée sur Vercel

## 🔧 Étape 1 : Vérifier la variable d'environnement

Assurez-vous que `STRIPE_SECRET_KEY` est configurée sur Vercel :

1. Allez sur [vercel.com](https://vercel.com)
2. Sélectionnez votre projet **lmaalem**
3. **Settings** → **Environment Variables**
4. Vérifiez que `STRIPE_SECRET_KEY` existe avec votre clé secrète Stripe (commence par `sk_test_` pour les tests)

## 🚀 Étape 2 : Déployer sur Vercel

### Option A : Via Vercel CLI (Recommandé)

```bash
cd stripe-backend
vercel --prod
```

### Option B : Via Git

Si votre projet est lié à Git :

```bash
cd stripe-backend
git add .
git commit -m "Fix: Restructure for Vercel serverless functions"
git push
```

Vercel redéploiera automatiquement.

### Option C : Via l'interface web

1. Allez sur [vercel.com](https://vercel.com)
2. Sélectionnez votre projet **lmaalem**
3. **Deployments** → Cliquez sur les trois points (⋯) → **Redeploy**

## ✅ Étape 3 : Tester l'endpoint

Après le déploiement, testez :

```bash
curl -X POST https://lmaalem.vercel.app/api/create-payment-intent \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "currency": "eur"}'
```

**Réponse attendue** :
```json
{
  "clientSecret": "pi_xxx_secret_xxx",
  "paymentIntentId": "pi_xxx"
}
```

## 📱 Étape 4 : Mettre à jour Flutter (IMPORTANT)

**L'URL de l'endpoint a changé !**

Mettez à jour `lib/config/stripe_config.dart` :

```dart
static const String backendUrl = 'https://lmaalem.vercel.app';
```

L'endpoint sera automatiquement : `https://lmaalem.vercel.app/api/create-payment-intent`

**Note** : Le code Flutter devrait déjà fonctionner car `createPaymentIntentEndpoint` construit l'URL automatiquement. Vérifiez juste que `backendUrl` est correct.

## 🔍 Dépannage

### Erreur 404
- ✅ Vérifiez que le dossier `/api` existe
- ✅ Vérifiez que `create-payment-intent.js` est dans `/api`
- ✅ Vérifiez que vous utilisez `/api/create-payment-intent` (avec `/api`)

### Erreur 500
- ✅ Vérifiez que `STRIPE_SECRET_KEY` est configurée sur Vercel
- ✅ Vérifiez les logs dans Vercel → **Deployments** → **Functions** → **View Function Logs**

### Erreur CORS
- ✅ Les headers CORS sont déjà configurés dans la fonction
- ✅ Vérifiez que l'origine est autorisée (actuellement `*` pour tous)

## 📊 Vérification finale

1. ✅ Endpoint accessible : `https://lmaalem.vercel.app/api/create-payment-intent`
2. ✅ Réponse 200 avec `clientSecret`
3. ✅ Flutter peut créer des PaymentIntents
4. ✅ PaymentSheet s'affiche correctement

---

**Le backend est maintenant prêt !** 🎉


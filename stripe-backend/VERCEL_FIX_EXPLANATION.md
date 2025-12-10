# 🔧 Explication de la correction du backend Vercel

## ❌ Problème identifié (404 NOT_FOUND)

### Cause principale
Le projet utilisait **Express avec une configuration Vercel incorrecte**. Vercel ne détectait pas correctement les routes car :

1. **Structure incorrecte** : Pas de dossier `/api` requis par Vercel
2. **Format incorrect** : Utilisation d'Express avec `module.exports = app` au lieu de serverless functions natives
3. **Configuration Vercel** : `vercel.json` essayait de wrapper Express, ce qui causait des problèmes de routing
4. **Runtime** : Node.js 24.x n'est pas encore supporté par Vercel (utilisez 20.x)

## ✅ Solution appliquée

### 1. Structure corrigée
```
stripe-backend/
├── api/
│   └── create-payment-intent.js  ← Nouvelle fonction serverless
├── index.js                       ← Gardé pour dev local
├── package.json                  ← Mis à jour
├── vercel.json                   ← Corrigé
└── ...
```

### 2. Fonction serverless native
- Créé `/api/create-payment-intent.js` avec le format Vercel natif
- Utilise `module.exports = async function handler(req, res)`
- Pas besoin d'Express pour les serverless functions
- Gestion CORS intégrée
- Support OPTIONS (preflight)

### 3. package.json corrigé
- ✅ `stripe: latest` (sera mis à jour automatiquement)
- ✅ Node.js 20.x (compatible Vercel)
- ❌ Express retiré des dépendances principales (gardé en devDependencies pour le dev local)
- ❌ `serverless-http` retiré (pas nécessaire avec les fonctions natives)

### 4. vercel.json simplifié
```json
{
  "functions": {
    "api/*.js": {
      "runtime": "nodejs20.x"
    }
  }
}
```

## 📍 Nouvelle URL de l'endpoint

**Avant (ne fonctionnait pas)** :
- `https://lmaalem.vercel.app/create-payment-intent` ❌

**Maintenant (fonctionne)** :
- `https://lmaalem.vercel.app/api/create-payment-intent` ✅

## 🚀 Instructions de redéploiement

### Option 1 : Via Vercel CLI (Recommandé)
```bash
cd stripe-backend
vercel --prod
```

### Option 2 : Via Git
1. Commitez les changements :
   ```bash
   git add .
   git commit -m "Fix: Restructure for Vercel serverless functions"
   git push
   ```
2. Vercel redéploiera automatiquement

### Option 3 : Via l'interface Vercel
1. Allez sur [vercel.com](https://vercel.com)
2. Sélectionnez votre projet **lmaalem**
3. Allez dans **Deployments**
4. Cliquez sur **Redeploy** sur le dernier déploiement

## ✅ Vérification après déploiement

Testez l'endpoint :
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

## 🔄 Mise à jour Flutter

**IMPORTANT** : Mettez à jour l'URL dans `lib/config/stripe_config.dart` :

```dart
static const String backendUrl = 'https://lmaalem.vercel.app';
```

L'endpoint sera automatiquement : `https://lmaalem.vercel.app/api/create-payment-intent`

## 📝 Notes importantes

1. **Développement local** : Le fichier `index.js` est toujours disponible pour tester localement avec Express
2. **Production** : Vercel utilisera automatiquement les fonctions dans `/api`
3. **Variables d'environnement** : Assurez-vous que `STRIPE_SECRET_KEY` est configuré dans Vercel
4. **CORS** : Les headers CORS sont maintenant gérés directement dans la fonction

## 🎯 Résumé des changements

| Avant | Après |
|-------|-------|
| Express avec wrapper | Serverless functions natives |
| Pas de dossier `/api` | Dossier `/api` avec fonction |
| Node.js 24.x | Node.js 20.x |
| URL: `/create-payment-intent` | URL: `/api/create-payment-intent` |
| Configuration complexe | Configuration simple |

---

**Le backend devrait maintenant fonctionner correctement sur Vercel !** 🎉


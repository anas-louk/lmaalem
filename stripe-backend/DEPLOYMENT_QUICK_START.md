# 🚀 Guide de déploiement rapide - Backend Stripe

## ⚠️ IMPORTANT - Sécurité

**VOTRE CLÉ SECRÈTE STRIPE :**
```
sk_test_VOTRE_CLE_SECRETE_STRIPE
```

**Cette clé doit être :**
- ✅ Ajoutée dans les variables d'environnement de Vercel/Netlify
- ✅ Utilisée uniquement dans le backend
- ❌ JAMAIS commitée dans Git
- ❌ JAMAIS exposée dans le code Flutter

## 📦 Déploiement sur Vercel (Recommandé - 2 minutes)

### Étape 1 : Installer Vercel CLI
```bash
npm install -g vercel
```

### Étape 2 : Se connecter
```bash
vercel login
```

### Étape 3 : Déployer
```bash
cd stripe-backend
vercel
```

### Étape 4 : Ajouter la variable d'environnement

**Option A : Pendant le déploiement**
- Quand Vercel demande, ajoutez :
  - Variable: `STRIPE_SECRET_KEY`
  - Valeur: `sk_test_VOTRE_CLE_SECRETE_STRIPE`

**Option B : Via l'interface web**
1. Allez sur [vercel.com](https://vercel.com)
2. Sélectionnez votre projet
3. **Settings** → **Environment Variables**
4. Ajoutez :
   - Key: `STRIPE_SECRET_KEY`
   - Value: `sk_test_VOTRE_CLE_SECRETE_STRIPE`
   - Environment: Production, Preview, Development (cochez les trois)

### Étape 5 : Obtenir l'URL

Après le déploiement, Vercel vous donnera une URL comme :
```
https://stripe-backend-xxx.vercel.app
```

### Étape 6 : Mettre à jour Flutter

Dans `lib/config/stripe_config.dart`, remplacez :
```dart
static const String backendUrl = 'https://votre-projet.vercel.app';
```

Par votre URL Vercel :
```dart
static const String backendUrl = 'https://stripe-backend-xxx.vercel.app';
```

## 🌐 Déploiement sur Netlify

### Étape 1 : Créer un compte
Allez sur [netlify.com](https://netlify.com) et créez un compte

### Étape 2 : Déployer depuis Git
1. Connectez votre dépôt Git
2. Sélectionnez le dossier `stripe-backend`
3. Build command: laissez vide
4. Publish directory: laissez vide

### Étape 3 : Ajouter la variable d'environnement
1. **Site settings** → **Environment variables**
2. Ajoutez :
   - Key: `STRIPE_SECRET_KEY`
   - Value: `sk_test_VOTRE_CLE_SECRETE_STRIPE`

### Étape 4 : Obtenir l'URL
Netlify vous donnera une URL comme :
```
https://votre-projet.netlify.app
```

### Étape 5 : Mettre à jour Flutter
Mettez à jour `stripe_config.dart` avec l'URL Netlify.

## 🧪 Test local (optionnel)

### 1. Créer le fichier .env
```bash
cd stripe-backend
cp .env.example .env
```

Le fichier `.env` contient déjà votre clé secrète.

### 2. Installer les dépendances
```bash
npm install
```

### 3. Lancer le serveur
```bash
npm start
```

### 4. Tester
```bash
curl -X POST http://localhost:3000/create-payment-intent \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "currency": "eur"}'
```

Vous devriez recevoir un `clientSecret`.

## ✅ Checklist

- [ ] Backend déployé sur Vercel/Netlify
- [ ] Variable d'environnement `STRIPE_SECRET_KEY` ajoutée
- [ ] URL du backend mise à jour dans `lib/config/stripe_config.dart`
- [ ] Test effectué avec curl ou Postman
- [ ] Application Flutter testée avec une carte de test

## 🔒 Sécurité finale

Après le déploiement, vérifiez que :
- ✅ Le fichier `.env` est dans `.gitignore`
- ✅ La clé secrète n'apparaît pas dans le code source
- ✅ Les variables d'environnement sont bien configurées sur Vercel/Netlify

---

**Besoin d'aide ?** Consultez `STRIPE_PAYMENT_SETUP.md` pour plus de détails.


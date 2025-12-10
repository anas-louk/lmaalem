# Backend Stripe pour Lmaalem

Backend Node.js simple pour créer des PaymentIntents Stripe, déployable gratuitement sur Vercel ou Netlify.

## 🚀 Déploiement sur Vercel

### 1. Prérequis
- Compte Vercel (gratuit)
- Compte Stripe avec clé secrète

### 2. Installation locale (optionnel)

```bash
cd stripe-backend
npm install
```

### 3. Configuration des variables d'environnement

Créez un fichier `.env` :
```env
STRIPE_SECRET_KEY=sk_test_...  # Votre clé secrète Stripe
```

### 4. Déploiement sur Vercel

#### Option A : Via Vercel CLI
```bash
npm install -g vercel
vercel login
vercel
```

Lors du déploiement, Vercel vous demandera d'ajouter la variable d'environnement `STRIPE_SECRET_KEY`.

#### Option B : Via l'interface Vercel
1. Allez sur [vercel.com](https://vercel.com)
2. Importez ce dossier comme nouveau projet
3. Dans les paramètres du projet → Environment Variables, ajoutez :
   - `STRIPE_SECRET_KEY` = votre clé secrète Stripe

### 5. Obtenir l'URL de l'API

Après le déploiement, Vercel vous donnera une URL comme :
```
https://votre-projet.vercel.app
```

L'endpoint sera :
```
https://votre-projet.vercel.app/create-payment-intent
```

## 🌐 Déploiement sur Netlify

### 1. Créer netlify.toml

Créez un fichier `netlify.toml` à la racine :
```toml
[build]
  functions = "."
  command = "echo 'No build needed'"

[[redirects]]
  from = "/*"
  to = "/.netlify/functions/index"
  status = 200
```

### 2. Créer netlify/functions/index.js

Créez le dossier `netlify/functions/` et déplacez `index.js` dedans, puis modifiez-le pour Netlify :

```javascript
// netlify/functions/index.js
const express = require('express');
const serverless = require('serverless-http');
// ... reste du code ...

module.exports.handler = serverless(app);
```

### 3. Déployer

1. Allez sur [netlify.com](https://netlify.com)
2. Créez un nouveau site depuis Git
3. Ajoutez la variable d'environnement `STRIPE_SECRET_KEY` dans les paramètres

## 📡 Utilisation de l'API

### Endpoint: POST /create-payment-intent

**Body:**
```json
{
  "amount": 100.00,
  "currency": "eur",
  "metadata": {
    "userId": "user123",
    "orderId": "order456"
  }
}
```

**Response:**
```json
{
  "clientSecret": "pi_xxx_secret_xxx",
  "paymentIntentId": "pi_xxx"
}
```

## 🔒 Sécurité

- ⚠️ **NE JAMAIS** exposer la clé secrète Stripe dans le code client
- ✅ Utiliser uniquement la clé publique dans Flutter
- ✅ Stocker la clé secrète uniquement dans les variables d'environnement du backend
- ✅ En production, configurez CORS pour limiter les origines autorisées

## 🧪 Test local

```bash
npm install
node index.js
```

Testez avec curl :
```bash
curl -X POST http://localhost:3000/create-payment-intent \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "currency": "eur"}'
```


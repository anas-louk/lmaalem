# 📁 Structure finale du projet

## Structure des fichiers

```
stripe-backend/
├── api/                                    ← Dossier requis par Vercel
│   └── create-payment-intent.js           ← Fonction serverless (NOUVEAU)
│
├── index.js                                ← Pour développement local (Express)
├── package.json                            ← Mis à jour (Node.js 20.x, Stripe latest)
├── vercel.json                             ← Configuration simplifiée
│
├── netlify/                                ← Configuration Netlify (optionnel)
│   ├── functions/
│   │   └── index.js
│   └── netlify.toml
│
└── Documentation/
    ├── README.md
    ├── VERCEL_FIX_EXPLANATION.md          ← Explication du fix
    ├── DEPLOYMENT_INSTRUCTIONS.md         ← Instructions de déploiement
    └── ...
```

## 🔑 Fichiers clés

### `/api/create-payment-intent.js`
- Fonction serverless native Vercel
- Format : `module.exports = async function handler(req, res)`
- Gère CORS, validation, création PaymentIntent
- **Endpoint** : `POST /api/create-payment-intent`

### `package.json`
- Node.js 20.x (compatible Vercel)
- Stripe latest
- Express en devDependencies (pour dev local uniquement)

### `vercel.json`
- Configuration minimale
- Runtime Node.js 20.x
- Détection automatique des fonctions dans `/api`

## 🌐 URLs

**Production Vercel** :
- Base URL : `https://lmaalem.vercel.app`
- Endpoint : `https://lmaalem.vercel.app/api/create-payment-intent`

**Développement local** (si vous utilisez `index.js`) :
- Base URL : `http://localhost:3000`
- Endpoint : `http://localhost:3000/create-payment-intent`

## ✅ Vérifications

- [x] Dossier `/api` existe
- [x] `create-payment-intent.js` dans `/api`
- [x] `package.json` avec Node.js 20.x
- [x] `vercel.json` configuré
- [x] Flutter configuré avec `/api/create-payment-intent`


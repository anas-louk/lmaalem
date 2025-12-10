# 🔧 Ajouter la variable d'environnement STRIPE_SECRET_KEY sur Vercel

## ⚠️ Problème résolu

Le fichier `vercel.json` référençait un secret qui n'existait pas. Cette référence a été supprimée.

## ✅ Solution : Ajouter la variable via l'interface Vercel

### Option 1 : Via l'interface web (Recommandé)

1. Allez sur [vercel.com](https://vercel.com)
2. Connectez-vous et sélectionnez votre projet **lmaalem**
3. Allez dans **Settings** → **Environment Variables**
4. Cliquez sur **Add New**
5. Ajoutez :
   - **Key**: `STRIPE_SECRET_KEY`
   - **Value**: `sk_test_VOTRE_CLE_SECRETE_STRIPE`
   - **Environment**: Cochez les trois (Production, Preview, Development)
6. Cliquez sur **Save**

### Option 2 : Via Vercel CLI

```bash
cd stripe-backend
vercel env add STRIPE_SECRET_KEY
```

Quand demandé, entrez la valeur :
```
sk_test_VOTRE_CLE_SECRETE_STRIPE
```

Sélectionnez les environnements : Production, Preview, Development

## 🚀 Redéployer

Après avoir ajouté la variable d'environnement, redéployez :

```bash
cd stripe-backend
vercel --prod
```

Ou via l'interface web, allez dans **Deployments** et cliquez sur **Redeploy**.

## ✅ Vérification

Testez l'endpoint après le déploiement :

```bash
curl -X POST https://lmaalem.vercel.app/create-payment-intent \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "currency": "eur"}'
```

Vous devriez recevoir un `clientSecret` en réponse.


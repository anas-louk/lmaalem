# ✅ Vérifier et redéployer le backend Stripe

## 📋 Situation actuelle

La variable d'environnement `STRIPE_SECRET_KEY` existe déjà sur Vercel. Vérifions qu'elle a la bonne valeur et redéployons.

## 🔍 Vérifier la valeur actuelle

### Option 1 : Via l'interface web Vercel

1. Allez sur [vercel.com](https://vercel.com)
2. Sélectionnez votre projet **lmaalem**
3. Allez dans **Settings** → **Environment Variables**
4. Vérifiez que `STRIPE_SECRET_KEY` a la valeur :
   ```
   sk_test_VOTRE_CLE_SECRETE_STRIPE
   ```

### Option 2 : Via Vercel CLI

```bash
vercel env ls
```

Pour voir la valeur (si vous avez les permissions) :
```bash
vercel env pull
```

Cela créera un fichier `.env.local` avec les variables.

## 🔄 Mettre à jour la valeur (si nécessaire)

Si la valeur n'est pas correcte, supprimez et recréez :

```bash
# Supprimer l'ancienne
vercel env rm STRIPE_SECRET_KEY

# Ajouter la nouvelle avec la bonne valeur
vercel env add STRIPE_SECRET_KEY
```

Entrez la valeur :
```
sk_test_VOTRE_CLE_SECRETE_STRIPE
```

Sélectionnez les trois environnements (Production, Preview, Development).

## 🚀 Redéployer

Une fois la variable vérifiée/corrigée, redéployez :

```bash
vercel --prod
```

Ou via l'interface web :
1. Allez dans **Deployments**
2. Cliquez sur les trois points (⋯) du dernier déploiement
3. Sélectionnez **Redeploy**
4. Choisissez **Production**

## ✅ Tester l'endpoint

Après le redéploiement, testez :

```bash
curl -X POST https://lmaalem.vercel.app/create-payment-intent \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "currency": "eur"}'
```

**Réponse attendue :**
```json
{
  "clientSecret": "pi_xxx_secret_xxx",
  "paymentIntentId": "pi_xxx"
}
```

Si vous obtenez une erreur, vérifiez les logs dans Vercel → **Deployments** → **Functions** → **View Function Logs**.


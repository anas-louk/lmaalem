# 🚨 Correction IMMÉDIATE pour ApiException: 7

## ❌ Problème détecté

Votre fichier `android/app/google-services.json` a :
```json
"oauth_client": []  // ← VIDE ! C'est le problème
```

Cela signifie que **Google Sign-In n'est pas configuré** dans Firebase Console.

## ✅ Solution en 3 étapes OBLIGATOIRES

### Étape 1 : Activer Google Sign-In dans Firebase Console ⚠️ OBLIGATOIRE

1. Allez sur https://console.firebase.google.com/
2. Sélectionnez votre projet **lmaalem-23777**
3. Dans le menu de gauche, cliquez sur **Authentication**
4. Cliquez sur l'onglet **Sign-in method**
5. Cliquez sur **Google** dans la liste
6. **Activez** le toggle en haut
7. Configurez le **Support email** (REQUIS - mettez votre email)
8. Optionnel : Configurez le **Project public-facing name**
9. Cliquez sur **Save**

### Étape 2 : Ajouter le SHA-1 dans Firebase Console ⚠️ OBLIGATOIRE

Le SHA-1 est nécessaire pour que Firebase génère les OAuth clients.

**Obtenir le SHA-1 :**

Double-cliquez sur `android/get-sha1.bat` (script que j'ai créé)

OU exécutez dans un terminal :
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Copiez le SHA-1** (format : `AB:CD:EF:12:34:...`)

**Ajouter dans Firebase :**

1. Firebase Console > **Project settings** (icône ⚙️)
2. Section **Your apps** > votre app Android
3. Section **SHA certificate fingerprints**
4. Cliquez sur **Add fingerprint**
5. Collez votre SHA-1
6. Cliquez sur **Save**

### Étape 3 : Télécharger le nouveau google-services.json

1. Firebase Console > **Project settings** > **Your apps** > Android app
2. Cliquez sur **Download google-services.json**
3. **Remplacez** `android/app/google-services.json` avec le nouveau fichier
4. **Vérifiez** que `"oauth_client"` n'est plus vide (devrait contenir des objets)

## ⏳ Attendre la propagation

Après avoir fait ces changements, attendez **5-10 minutes** pour que Firebase génère les OAuth clients.

## ✅ Vérification

Ouvrez `android/app/google-services.json` et vérifiez que :

**AVANT (incorrect) :**
```json
"oauth_client": []
```

**APRÈS (correct) :**
```json
"oauth_client": [
  {
    "client_id": "891462076223-xxxxxxxxxxxxx.apps.googleusercontent.com",
    "client_type": 3
  }
]
```

Si `oauth_client` est toujours vide après avoir fait les 3 étapes, attendez encore quelques minutes et téléchargez à nouveau le fichier.

## 🧹 Nettoyer et reconstruire

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

## 📋 Checklist

- [ ] Google Sign-In activé dans Firebase Console (Authentication > Sign-in method > Google)
- [ ] Support email configuré
- [ ] SHA-1 ajouté dans Firebase Console
- [ ] Nouveau google-services.json téléchargé
- [ ] Vérifié que `oauth_client` n'est plus vide dans google-services.json
- [ ] Attendu 5-10 minutes après les changements
- [ ] Projet nettoyé et reconstruit

Une fois toutes ces étapes faites, Google Sign-In devrait fonctionner !


# Configuration Google Sign-In pour Flutter

## 🔴 Erreur `ApiException: 10` (DEVELOPER_ERROR)

Cette erreur indique que Google Sign-In n'est pas correctement configuré dans Firebase Console.

## 🔴 Erreur `ApiException: 7` (NETWORK_ERROR)

Cette erreur signifie généralement :
1. OAuth client non configuré dans Firebase (le plus courant)
2. Google Play Services non disponible
3. Problème de connexion réseau

### Solution rapide pour ApiException: 7

**Le problème principal :** Votre `google-services.json` a `"oauth_client": []` vide, ce qui signifie que Google Sign-In n'est pas configuré.

**Étapes obligatoires :**

1. **Activer Google Sign-In dans Firebase Console**
   - Allez sur Firebase Console > **Authentication** > **Sign-in method**
   - Cliquez sur **Google**
   - Activez le toggle
   - Configurez le **Support email** (OBLIGATOIRE)
   - Cliquez sur **Save**

2. **Ajouter SHA-1 dans Firebase Console** (OBLIGATOIRE pour que OAuth soit généré)
   - Voir étapes ci-dessous

3. **Télécharger le nouveau google-services.json**
   - Après avoir ajouté le SHA-1 et activé Google, le fichier sera mis à jour automatiquement
   - Dans Firebase Console > Project Settings > Your apps > Android app
   - Cliquez sur **Download google-services.json**
   - Remplacez `android/app/google-services.json`

4. **Attendre 5-10 minutes** pour la propagation

5. **Nettoyer et reconstruire :**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## ✅ Solution : Configurer SHA-1 dans Firebase

### Étape 1 : Obtenir le SHA-1 de votre clé de signature

#### Pour Windows (PowerShell ou CMD) :
```bash
cd android/app
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

#### Pour macOS/Linux :
```bash
cd android/app
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Copiez le SHA-1** qui ressemble à : `AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12`

### Étape 2 : Ajouter SHA-1 dans Firebase Console

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionnez votre projet
3. Cliquez sur l'icône ⚙️ (Settings) > **Project settings**
4. Descendez jusqu'à la section **Your apps**
5. Cliquez sur votre app Android (ou créez-en une si nécessaire)
6. Dans la section **SHA certificate fingerprints**, cliquez sur **Add fingerprint**
7. Collez le SHA-1 que vous avez copié
8. Cliquez sur **Save**

### Étape 3 : Télécharger le nouveau `google-services.json`

1. Dans Firebase Console, toujours dans **Project settings**
2. Dans la section **Your apps**, trouvez votre app Android
3. Cliquez sur **Download google-services.json**
4. Remplacez le fichier `android/app/google-services.json` avec le nouveau fichier

### Étape 4 : Vérifier le Package Name

Assurez-vous que le **Package name** dans Firebase correspond à celui dans votre app :

**Fichier : `android/app/build.gradle.kts`**
```kotlin
defaultConfig {
    applicationId = "com.example.lmaalem"  // Doit correspondre à Firebase
    ...
}
```

### Étape 5 : Activer Google Sign-In dans Firebase Console

**IMPORTANT :** Cette étape est OBLIGATOIRE !

1. Allez sur Firebase Console > **Authentication**
2. Cliquez sur **Sign-in method**
3. Cliquez sur **Google**
4. **Activez** Google Sign-In
5. Configurez le **Support email** (requis)
6. Optionnel : Configurez le **Project public-facing name**
7. Cliquez sur **Save**

### Étape 6 : Vérifier le google-services.json

Après avoir ajouté le SHA-1 et activé Google Sign-In, votre `google-services.json` devrait contenir des entrées dans `"oauth_client"` au lieu d'un tableau vide `[]`.

**Avant (incorrect) :**
```json
"oauth_client": []
```

**Après (correct) :**
```json
"oauth_client": [
  {
    "client_id": "...",
    "client_type": 3
  }
]
```

Si `oauth_client` est toujours vide après ces étapes, attendez 5-10 minutes et téléchargez à nouveau le fichier.

### Étape 7 : Redémarrer l'application

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

## ⚠️ Vérification importante

Ouvrez `android/app/google-services.json` et vérifiez que la section `oauth_client` n'est **PAS vide**. Si elle est vide, cela signifie que :
- Le SHA-1 n'a pas été ajouté, OU
- Google Sign-In n'a pas été activé dans Firebase Console, OU
- Vous devez attendre la propagation des changements

## 🔧 Pour Production (Release Build)

Quand vous créez une version release, vous devrez aussi ajouter le SHA-1 de votre keystore de production :

```bash
keytool -list -v -keystore path/to/your/release.keystore -alias your-alias
```

Puis ajoutez ce SHA-1 également dans Firebase Console.

## 📝 Vérification

Après avoir suivi ces étapes, Google Sign-In devrait fonctionner correctement.

Si l'erreur persiste :
1. Vérifiez que `google-services.json` est bien dans `android/app/`
2. Vérifiez que le plugin `com.google.gms.google-services` est bien dans `android/app/build.gradle.kts`
3. Vérifiez que le package name correspond exactement
4. Attendez quelques minutes après avoir ajouté le SHA-1 (la propagation peut prendre du temps)


# Guide de Résolution des Erreurs Google Sign-In

## ⚡ SOLUTION RAPIDE : SHA-1 ajouté mais toujours des problèmes

**Si vous avez déjà ajouté le SHA-1 mais que Google Sign-In ne fonctionne toujours pas**, suivez ces 3 étapes **obligatoires** :

### ✅ Étape 1 : Vérifier que Google Sign-In est ACTIVÉ
1. [Firebase Console](https://console.firebase.google.com/) > Votre projet > **Authentication** > **Sign-in method**
2. Cliquez sur **Google**
3. **Activez le toggle** (doit être vert)
4. Remplissez **Support email** (obligatoire)
5. Cliquez sur **Save**

### ✅ Étape 2 : Télécharger le NOUVEAU google-services.json
**⚠️ CRITIQUE :** Après avoir ajouté SHA-1 ET activé Google Sign-In, vous DEVEZ télécharger un nouveau fichier !

1. Firebase Console > **Project settings** (⚙️) > **Your apps** > Android app
2. Cliquez sur **Download google-services.json**
3. **Remplacez** `android/app/google-services.json` avec le nouveau fichier
4. **Vérifiez** que le fichier contient `"oauth_client"` avec des objets (pas `[]`)

### ✅ Étape 3 : Attendre 10-15 minutes puis reconstruire
```bash
flutter clean
flutter pub get
flutter run
```

**Voir la section "10. ⚠️ PROBLÈME : SHA-1 ajouté mais OAuth clients toujours vides" ci-dessous pour plus de détails.**

---

## 🔴 Erreur `ApiException: 7` (NETWORK_ERROR)

Cette erreur indique généralement un problème de connexion ou de configuration Google Play Services.

### ✅ Solutions à essayer :

#### 1. Vérifier Google Play Services sur l'émulateur/appareil

**Pour l'émulateur :**
- Assurez-vous d'utiliser un appareil avec **Google Play Store** installé
- Dans Android Studio, créez un nouvel AVD avec **Google APIs** ou **Google Play**
- Évitez les images système sans Google Play Services

**Pour un appareil physique :**
- Mettez à jour Google Play Services depuis Google Play Store
- Vérifiez que vous êtes connecté à Internet

#### 2. Vérifier la configuration OAuth dans Firebase Console

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionnez votre projet
3. Allez dans **Authentication** > **Sign-in method**
4. Cliquez sur **Google**
5. Activez Google Sign-In si ce n'est pas déjà fait
6. Configurez le **Support email** (obligatoire)
7. Vérifiez que **Project public-facing name** est défini
8. Cliquez sur **Save**

#### 3. Vérifier le SHA-1 dans Firebase Console

1. Obtenez votre SHA-1 :
   ```bash
   # Windows
   keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   
   # macOS/Linux
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

2. Dans Firebase Console :
   - **Project Settings** > **Your apps** > votre app Android
   - Section **SHA certificate fingerprints**
   - Ajoutez votre SHA-1 s'il n'est pas déjà présent
   - Cliquez sur **Save**

3. Téléchargez le nouveau `google-services.json` et remplacez-le dans `android/app/`

#### 4. Nettoyer et reconstruire le projet

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

#### 5. Vérifier la connexion Internet

- Testez votre connexion Internet
- Si vous utilisez un VPN, essayez de le désactiver temporairement
- Vérifiez que Firebase n'est pas bloqué par un pare-feu

#### 6. Vérifier le package name

Assurez-vous que le package name dans Firebase correspond exactement à celui de votre app :

**Firebase Console :** Package name de votre app Android  
**Votre app :** `com.example.lmaalem` (dans `android/app/build.gradle.kts`)

#### 7. Utiliser un émulateur avec Google Play

Si vous utilisez un émulateur :
1. Créez un nouvel AVD dans Android Studio
2. Choisissez une image système avec **Google Play** (pas "Google APIs")
3. Par exemple : **Pixel 5 with Google Play** ou **Pixel 6 with Google Play**
4. Redémarrez l'émulateur et testez à nouveau

#### 8. Vérifier les permissions Internet dans AndroidManifest.xml

Le fichier `android/app/src/main/AndroidManifest.xml` doit contenir :
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

#### 9. Attendre la propagation des changements

Après avoir modifié la configuration dans Firebase Console, attendez **5-10 minutes** pour que les changements soient propagés.

#### 10. ⚠️ PROBLÈME : SHA-1 ajouté mais OAuth clients toujours vides

Si vous avez ajouté le SHA-1 mais que `google-services.json` contient toujours `"oauth_client": []`, suivez ces étapes **dans l'ordre** :

**A. Vérifier que Google Sign-In est ACTIVÉ dans Firebase Console** ⚠️ OBLIGATOIRE

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionnez votre projet **lmaalem-23777**
3. Cliquez sur **Authentication** dans le menu de gauche
4. Cliquez sur l'onglet **Sign-in method**
5. Cliquez sur **Google** dans la liste
6. **Activez le toggle** en haut à droite (il doit être vert)
7. Remplissez le champ **Support email** (obligatoire)
8. Optionnel : Configurez le **Project public-facing name**
9. Cliquez sur **Save**

**B. Vérifier que le SHA-1 est correctement formaté**

Le SHA-1 doit être au format : `AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12`

**Important :**
- Les deux-points (`:`) doivent être présents
- Pas d'espaces avant/après
- Copiez exactement le SHA-1 depuis la sortie de `keytool`

**Obtenir le SHA-1 à nouveau :**

Dans PowerShell ou CMD :
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr "SHA1"
```

**C. Vérifier le SHA-1 dans Firebase Console**

1. Firebase Console > **Project settings** (icône ⚙️)
2. Section **Your apps** > votre app Android
3. Section **SHA certificate fingerprints**
4. Vérifiez que votre SHA-1 apparaît bien dans la liste
5. Si ce n'est pas le cas, ajoutez-le à nouveau avec **Add fingerprint**

**D. Télécharger le NOUVEAU google-services.json**

⚠️ **IMPORTANT :** Après avoir ajouté le SHA-1 ET activé Google Sign-In, vous DEVEZ télécharger un nouveau `google-services.json` !

1. Firebase Console > **Project settings** > **Your apps** > votre app Android
2. Cliquez sur **Download google-services.json**
3. **Remplacez complètement** le fichier `android/app/google-services.json` avec le nouveau
4. **Vérifiez** que le nouveau fichier contient `"oauth_client"` avec des objets (pas vide)

**E. Attendre la propagation**

Après avoir activé Google Sign-In et ajouté le SHA-1, attendez **10-15 minutes** pour que Firebase génère les OAuth clients.

**F. Vérifier que google-services.json contient les OAuth clients**

Ouvrez `android/app/google-services.json` et cherchez la section `"oauth_client"`.

**❌ Incorrect (vide) :**
```json
"oauth_client": []
```

**✅ Correct (avec objets) :**
```json
"oauth_client": [
  {
    "client_id": "xxx.apps.googleusercontent.com",
    "client_type": 1,
    ...
  },
  {
    "client_id": "xxx.apps.googleusercontent.com",
    "client_type": 3,
    ...
  }
]
```

Si `oauth_client` est toujours vide après 15 minutes :
1. Vérifiez à nouveau que Google Sign-In est activé dans Firebase Console
2. Vérifiez que le SHA-1 est bien dans la liste des fingerprints
3. Supprimez et réajoutez le SHA-1
4. Attendez encore 10 minutes
5. Téléchargez à nouveau le `google-services.json`

**G. Nettoyer et reconstruire le projet**

Après avoir remplacé `google-services.json`, nettoyez et reconstruisez :

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

## 🔴 Erreur `ApiException: 10` (DEVELOPER_ERROR)

Voir le fichier `GOOGLE_SIGNIN_SETUP.md` pour la résolution complète.

## 🧪 Test de diagnostic

Pour tester si Google Play Services fonctionne :

1. Ouvrez l'app **Play Store** sur votre appareil/émulateur
2. Si Play Store s'ouvre correctement, Google Play Services est disponible
3. Si Play Store ne s'ouvre pas, Google Play Services n'est pas installé/configuré

## 🔴 Erreur Firestore : "The database (default) does not exist"

**Si vous voyez cette erreur :**
```
W/Firestore: Status{code=NOT_FOUND, description=The database (default) does not exist for project lmaalem-23777
```

**Solution : Créer la base de données Firestore**

Votre app utilise Firestore pour stocker les données (users, missions, employees, etc.), mais la base de données n'existe pas encore dans Firebase.

### ✅ Étapes pour créer Firestore :

1. **Allez sur [Firebase Console](https://console.firebase.google.com/)**
2. **Sélectionnez votre projet** (`lmaalem-23777`)
3. **Cliquez sur "Firestore Database"** dans le menu de gauche
4. **Cliquez sur "Create database"** (ou "Créer une base de données")
5. **Choisissez le mode de démarrage :**
   - **Mode test** : Recommandé pour commencer (règles permissives pendant 30 jours)
   - **Mode production** : Nécessite des règles de sécurité strictes
6. **Choisissez la région :**
   - Pour le Maroc, choisissez une région proche (ex: `europe-west3` pour l'Allemagne, ou `europe-west1` pour la Belgique)
   - Cliquez sur **"Enable"** (Activer)

**Après création :**
- La base de données sera créée en quelques secondes
- Redémarrez votre app : `flutter run`
- Les erreurs Firestore devraient disparaître

**Note :** Google Sign-In fonctionne déjà ! Ce problème concerne uniquement la base de données Firestore.

---

## 🔴 Erreur Firestore : "Missing or insufficient permissions"

**Si vous voyez cette erreur :**
```
W/Firestore: Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.
```

**Solution : Configurer les règles de sécurité Firestore**

Votre app essaie d'accéder aux données Firestore, mais les règles de sécurité bloquent l'accès.

### ✅ Étapes pour configurer les règles Firestore :

1. **Allez sur [Firebase Console](https://console.firebase.google.com/)**
2. **Sélectionnez votre projet** (`lmaalem-23777`)
3. **Cliquez sur "Firestore Database"** dans le menu de gauche
4. **Cliquez sur l'onglet "Rules"** (Règles)
5. **Remplacez les règles par ce code** :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Règles pour la collection 'users'
    match /users/{userId} {
      // Permet à l'utilisateur authentifié de lire/écrire son propre document
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Permet la création d'un document utilisateur (pour l'inscription)
      allow create: if request.auth != null;
      
      // Permet la lecture de tous les utilisateurs (pour la recherche)
      allow read: if request.auth != null;
    }
    
    // Règles pour la collection 'employees'
    match /employees/{employeeId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == employeeId;
      allow create: if request.auth != null;
    }
    
    // Règles pour la collection 'missions'
    match /missions/{missionId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
      allow create: if request.auth != null;
    }
    
    // Règles pour la collection 'clients'
    match /clients/{clientId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == clientId;
      allow create: if request.auth != null;
    }
    
    // Règles pour toutes les autres collections (ajustez selon vos besoins)
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

6. **Cliquez sur "Publish"** (Publier) pour sauvegarder les règles

**Important :**
- Ces règles permettent aux **utilisateurs authentifiés** de lire/écrire les données
- Chaque utilisateur peut lire/écrire son propre document dans `users`
- Tous les utilisateurs authentifiés peuvent lire les autres utilisateurs (pour la recherche)
- **Pour la production**, vous devrez ajuster ces règles pour plus de sécurité

**Alternative (Mode test uniquement - DÉVELOPPEMENT) :**

Si vous êtes en mode test et voulez temporairement tout permettre :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2025, 12, 31);
    }
  }
}
```

⚠️ **ATTENTION** : Cette règle permet tout l'accès pendant le développement. **Ne l'utilisez PAS en production !**

**Après avoir publié les règles :**
- Redémarrez votre app : `flutter run`
- Les erreurs de permissions devraient disparaître

---

## 🔴 Erreur Firestore : "The query requires an index"

**Si vous voyez cette erreur :**
```
W/Firestore: Status{code=FAILED_PRECONDITION, description=The query requires an index...
```

**Solution : Créer l'index Firestore requis**

Firestore nécessite des index pour les requêtes complexes (filtres + tri). C'est **normal** et **attendu**.

### ✅ Solution rapide : Cliquer sur le lien dans l'erreur

L'erreur contient un lien direct pour créer l'index. Copiez le lien depuis les logs :

Exemple de lien dans l'erreur :
```
https://console.firebase.google.com/v1/r/project/lmaalem-23777/firestore/indexes?create_composite=...
```

1. **Copiez le lien complet** depuis l'erreur dans vos logs
2. **Ouvrez le lien** dans votre navigateur
3. **Cliquez sur "Create Index"** (Créer l'index)
4. **Attendez** que l'index soit créé (quelques minutes)
5. L'index sera automatiquement utilisé par votre app

### ✅ Solution alternative : Créer l'index manuellement

1. **Allez sur [Firebase Console](https://console.firebase.google.com/)**
2. **Sélectionnez votre projet** (`lmaalem-23777`)
3. **Cliquez sur "Firestore Database"** dans le menu de gauche
4. **Cliquez sur l'onglet "Indexes"** (Index)
5. **Cliquez sur "Create Index"** (Créer un index)
6. **Collection ID** : `missions`
7. **Champs à indexer** :
   - `clientId` : Ascending (Ascendant)
   - `createdAt` : Descending (Descendant)
8. **Query scope** : Collection (Collection)
9. **Cliquez sur "Create"** (Créer)

### ⏳ Attendre la création de l'index

La création d'un index prend généralement **1-5 minutes**. Vous verrez le statut :
- **Building** : En cours de création
- **Enabled** : Prêt à utiliser

**Pendant ce temps :**
- Votre app continuera de fonctionner, mais les requêtes qui nécessitent cet index échoueront temporairement
- Une fois l'index créé, les requêtes fonctionneront automatiquement

### 📝 Indexes couramment requis pour cette app

Votre app pourrait nécessiter ces indexes :

**1. Index pour missions par clientId :**
- Collection : `missions`
- Fields : `clientId` (Ascending), `createdAt` (Descending)

**2. Index pour missions par employeeId (si applicable) :**
- Collection : `missions`
- Fields : `employeeId` (Ascending), `createdAt` (Descending)

**3. Index pour missions par statut :**
- Collection : `missions`
- Fields : `statut` (Ascending), `createdAt` (Descending)

**Note :** Firestore vous indiquera automatiquement quels indexes sont nécessaires via les liens dans les erreurs. Créez-les au fur et à mesure.

---

## 📝 Checklist de configuration

- [ ] SHA-1 ajouté dans Firebase Console
- [ ] `google-services.json` téléchargé et placé dans `android/app/`
- [ ] Google Sign-In activé dans Firebase Console (Authentication > Sign-in method)
- [ ] Support email configuré dans Firebase Console
- [ ] **Firestore Database créée dans Firebase Console** ⚠️ IMPORTANT
- [ ] **Règles de sécurité Firestore configurées** ⚠️ IMPORTANT
- [ ] **Indexes Firestore créés** (selon les besoins, via les liens dans les erreurs)
- [ ] Package name correspond exactement entre Firebase et votre app
- [ ] Google Play Services disponible sur l'appareil/émulateur
- [ ] Connexion Internet active
- [ ] `google-services` plugin présent dans `android/app/build.gradle.kts`
- [ ] Application reconstruite après les modifications


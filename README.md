# Flutter MVC Architecture + Firebase

Structure de projet Flutter basée sur l'architecture MVC (Model-View-Controller) avec intégration Firebase complète.

## 📁 Structure du Projet

```
lib/
├── core/
│   ├── constants/          # Constantes globales
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_assets.dart
│   │   └── app_routes.dart
│   ├── helpers/            # Fonctions utilitaires
│   │   ├── date_formatter.dart
│   │   └── validator.dart
│   ├── services/           # Services Firebase
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── storage_service.dart
│   │   └── push_notifications.dart
│   └── firebase/           # Configuration Firebase
│       ├── firebase_init.dart
│       └── firebase_options.dart
│
├── data/
│   ├── models/            # Modèles de données
│   │   ├── user_model.dart
│   │   └── product_model.dart
│   └── repositories/      # Couche d'accès aux données
│       ├── user_repository.dart
│       └── product_repository.dart
│
├── controllers/           # Controllers GetX
│   ├── auth_controller.dart
│   └── product_controller.dart
│
├── views/
│   ├── screens/          # Pages principales
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── home_screen.dart
│   │   └── profile_screen.dart
│   └── widgets/          # Widgets spécifiques à une page
│       └── product_card.dart
│
├── components/           # Composants UI réutilisables
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   ├── loading_widget.dart
│   └── empty_state.dart
│
├── routes/               # Gestion des routes
│   └── app_routes.dart
│
├── theme/                # Thème de l'application
│   └── app_theme.dart
│
├── utils/                # Utilitaires globaux
│   ├── extensions/
│   │   ├── string_extensions.dart
│   │   └── datetime_extensions.dart
│   ├── responsive_helper.dart
│   └── enums/
│       └── app_enums.dart
│
└── main.dart             # Point d'entrée
```

## 🏗️ Architecture MVC

### Model (data/models)
Les modèles représentent les structures de données de l'application. Ils incluent :
- Conversion depuis/vers Map (Firestore)
- Méthodes `fromMap()`, `toMap()`, `copyWith()`
- Validation des données

**Exemple :** `UserModel`, `ProductModel`

### View (views/)
Les vues sont responsables de l'affichage de l'interface utilisateur :
- **Screens** : Pages complètes de l'application
- **Widgets** : Composants réutilisables spécifiques à une page

**Exemple :** `LoginScreen`, `HomeScreen`, `ProductCard`

### Controller (controllers/)
Les controllers gèrent la logique métier et la communication entre les modèles et les vues :
- Utilisent GetX pour la gestion d'état
- Appellent les repositories pour accéder aux données
- Émettent des observables pour mettre à jour l'UI

**Exemple :** `AuthController`, `ProductController`

## 📦 Couches d'Architecture

### 1. Core Layer
**Rôle :** Fonctionnalités centrales et configurations
- **Constants** : Couleurs, styles, routes, assets
- **Helpers** : Formatters, validateurs
- **Services** : Intégration Firebase (Auth, Firestore, Storage)
- **Firebase** : Initialisation et configuration

### 2. Data Layer
**Rôle :** Gestion des données
- **Models** : Structures de données
- **Repositories** : Interface d'accès aux données (Firestore)

### 3. Controller Layer
**Rôle :** Logique métier et gestion d'état
- GetX Controllers avec observables
- Communication entre View et Data

### 4. View Layer
**Rôle :** Interface utilisateur
- **Screens** : Pages principales
- **Widgets** : Composants spécifiques à une page
- **Components** : Composants UI réutilisables

## 🔧 Configuration Firebase

1. **Installer FlutterFire CLI :**
```bash
dart pub global activate flutterfire_cli
```

2. **Configurer Firebase :**
```bash
flutterfire configure
```

3. **Vérifier `firebase_options.dart`** :
   - Ce fichier sera généré automatiquement
   - Remplacez les valeurs par défaut par vos vraies clés Firebase

## 🚀 Installation

1. **Installer les dépendances :**
```bash
flutter pub get
```

2. **Configurer Firebase** (voir section ci-dessus)

3. **Lancer l'application :**
```bash
flutter run
```

## 📝 Exemple d'Utilisation

### Créer un Controller
```dart
class MyController extends GetxController {
  final MyRepository _repository = MyRepository();
  final RxList<MyModel> items = <MyModel>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    loadItems();
  }
  
  Future<void> loadItems() async {
    items.value = await _repository.getAll();
  }
}
```

### Utiliser dans une View
```dart
class MyScreen extends StatelessWidget {
  final MyController controller = Get.put(MyController());
  
  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView.builder(
      itemCount: controller.items.length,
      itemBuilder: (context, index) => Text(controller.items[index].name),
    ));
  }
}
```

## 🎨 Best Practices

### 1. Naming Conventions
- **Models** : `UserModel`, `ProductModel`
- **Controllers** : `AuthController`, `ProductController`
- **Screens** : `LoginScreen`, `HomeScreen`
- **Widgets** : `ProductCard`, `CustomButton`
- **Services** : `AuthService`, `FirestoreService`
- **Repositories** : `UserRepository`, `ProductRepository`

### 2. Separation of Concerns
- **Models** : Uniquement la structure de données
- **Repositories** : Uniquement l'accès aux données
- **Controllers** : Logique métier et état
- **Views** : Uniquement l'affichage

### 3. Error Handling
- Toujours utiliser try-catch dans les services
- Retourner des messages d'erreur clairs
- Afficher les erreurs à l'utilisateur via GetX Snackbar

### 4. Responsive Design
- Utiliser `ResponsiveHelper` pour adapter l'UI
- Tester sur différentes tailles d'écran
- Utiliser des breakpoints cohérents

### 5. Code Reusability
- Créer des composants réutilisables dans `components/`
- Utiliser des helpers pour les fonctions communes
- Centraliser les constantes

## 🔐 Firebase Services

### AuthService
- `signUp()` : Inscription
- `signIn()` : Connexion
- `signOut()` : Déconnexion
- `resetPassword()` : Réinitialisation du mot de passe

### FirestoreService
- `create()` : Créer un document
- `read()` : Lire un document
- `update()` : Mettre à jour
- `delete()` : Supprimer
- `streamDocument()` : Stream d'un document
- `streamCollection()` : Stream d'une collection

### StorageService
- `uploadFile()` : Uploader un fichier
- `uploadBytes()` : Uploader des bytes
- `getDownloadURL()` : Obtenir l'URL
- `deleteFile()` : Supprimer un fichier

## 📱 Responsive Design

Utilisez `ResponsiveHelper` pour adapter l'UI :

```dart
if (ResponsiveHelper.isMobile(context)) {
  // Layout mobile
} else if (ResponsiveHelper.isTablet(context)) {
  // Layout tablette
} else {
  // Layout desktop
}
```

## 🧪 Tests

Structure recommandée pour les tests :
```
test/
├── unit/
│   ├── models/
│   ├── repositories/
│   └── controllers/
├── widget/
│   └── components/
└── integration/
```

## 📚 Ressources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [GetX Documentation](https://pub.dev/packages/get)
- [FlutterFire](https://firebase.flutter.dev/)

## 🤝 Contribution

1. Suivez la structure MVC
2. Respectez les naming conventions
3. Ajoutez des commentaires pour la documentation
4. Testez vos modifications

## 📄 License

Ce projet est sous licence MIT.
# lmaalem

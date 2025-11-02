# Architecture MVC pour Flutter + Firebase

## 📐 Vue d'ensemble de l'Architecture

Cette architecture suit le pattern **MVC (Model-View-Controller)** adapté pour Flutter avec intégration Firebase complète.

### Diagramme de l'Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        VIEW LAYER                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Screens    │  │   Widgets    │  │  Components  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ Écoute via GetX (Obx, Get.find)
                        │
┌───────────────────────▼─────────────────────────────────┐
│                    CONTROLLER LAYER                     │
│  ┌──────────────────────────────────────────────────┐   │
│  │  AuthController, ProductController, etc.        │   │
│  │  - Gère la logique métier                        │   │
│  │  - Émet des observables (Rx)                     │   │
│  │  - Appelle les repositories                      │   │
│  └──────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ Appelle les repositories
                        │
┌───────────────────────▼─────────────────────────────────┐
│                      DATA LAYER                          │
│  ┌──────────────┐              ┌──────────────┐         │
│  │   Models     │              │ Repositories  │         │
│  │  - UserModel │──────────────│  UserRepo    │         │
│  │  - Product   │              │ ProductRepo  │         │
│  └──────────────┘              └──────────────┘         │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ Utilise les services
                        │
┌───────────────────────▼─────────────────────────────────┐
│                      CORE LAYER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Services    │  │   Helpers     │  │  Constants   │  │
│  │  - Auth      │  │  - Validator  │  │  - Colors    │  │
│  │  - Firestore │  │  - Formatter  │  │  - Routes    │  │
│  │  - Storage   │  │               │  │  - Styles    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 📂 Structure Détaillée des Dossiers

### 1. **core/** - Couche Core (Fonctionnalités Centrales)

#### **constants/**
- **app_colors.dart** : Palette de couleurs globale
- **app_text_styles.dart** : Styles de texte réutilisables
- **app_assets.dart** : Chemins vers les assets (images, icônes)
- **app_routes.dart** : Définitions des routes de l'application

**Exemple d'utilisation :**
```dart
import 'core/constants/app_colors.dart';

Container(
  color: AppColors.primary,
  child: Text('Hello', style: AppTextStyles.h1),
)
```

#### **helpers/**
- **date_formatter.dart** : Formatage des dates (relative, court, long)
- **validator.dart** : Validation des inputs (email, password, etc.)

**Exemple d'utilisation :**
```dart
import 'core/helpers/validator.dart';

TextFormField(
  validator: Validator.email,
)

// Formatage de date
import 'core/helpers/date_formatter.dart';
final formatted = DateFormatter.formatRelative(DateTime.now());
```

#### **services/**
- **auth_service.dart** : Service d'authentification Firebase
- **firestore_service.dart** : Service générique pour Firestore
- **storage_service.dart** : Service pour Firebase Storage
- **push_notifications.dart** : Service pour les notifications push

**Exemple d'utilisation :**
```dart
final authService = AuthService();
await authService.signIn(email: 'user@example.com', password: 'password');
```

#### **firebase/**
- **firebase_init.dart** : Initialisation Firebase
- **firebase_options.dart** : Configuration Firebase (généré par FlutterFire CLI)

### 2. **data/** - Couche Données

#### **models/**
- **user_model.dart** : Modèle utilisateur
- **product_model.dart** : Modèle produit

**Structure d'un Model :**
```dart
class UserModel {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  // Factory constructor depuis Map
  factory UserModel.fromMap(Map<String, dynamic> map) { ... }

  // Factory constructor depuis DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) { ... }

  // Conversion en Map pour Firestore
  Map<String, dynamic> toMap() { ... }

  // Méthode copyWith pour les mises à jour
  UserModel copyWith({ ... }) { ... }
}
```

#### **repositories/**
- **user_repository.dart** : Repository pour les utilisateurs
- **product_repository.dart** : Repository pour les produits

**Structure d'un Repository :**
```dart
class UserRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final String _collection = 'users';

  Future<UserModel?> getUserById(String userId) async {
    // Utilise FirestoreService pour récupérer les données
  }

  Stream<UserModel?> streamUser(String userId) {
    // Stream en temps réel
  }
}
```

### 3. **controllers/** - Couche Contrôleur (GetX)

- **auth_controller.dart** : Gestion de l'authentification
- **product_controller.dart** : Gestion des produits

**Structure d'un Controller :**
```dart
class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();

  // Observables
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialisation
  }

  Future<bool> signIn({required String email, required String password}) async {
    isLoading.value = true;
    try {
      // Logique métier
      final userCredential = await _authService.signIn(...);
      await loadUser(userCredential.user!.uid);
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
```

### 4. **views/** - Couche Vue

#### **screens/**
- **splash_screen.dart** : Écran de démarrage
- **login_screen.dart** : Écran de connexion
- **register_screen.dart** : Écran d'inscription
- **home_screen.dart** : Écran d'accueil
- **profile_screen.dart** : Écran de profil

**Structure d'un Screen :**
```dart
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => _authController.isLoading.value
        ? LoadingWidget()
        : LoginForm(),
      ),
    );
  }
}
```

#### **widgets/**
- **product_card.dart** : Carte produit spécifique

### 5. **components/** - Composants UI Réutilisables

- **custom_button.dart** : Bouton personnalisé
- **custom_text_field.dart** : Champ de texte personnalisé
- **loading_widget.dart** : Widget de chargement
- **empty_state.dart** : État vide

**Exemple d'utilisation :**
```dart
CustomButton(
  onPressed: () => _handleLogin(),
  text: 'Se connecter',
  isLoading: _authController.isLoading.value,
)

CustomTextField(
  controller: _emailController,
  label: 'Email',
  validator: Validator.email,
  prefixIcon: Icons.email,
)
```

### 6. **routes/** - Gestion des Routes

- **app_routes.dart** : Configuration des routes avec GetX

**Exemple :**
```dart
static List<GetPage> getRoutes() {
  return [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
    ),
  ];
}
```

### 7. **theme/** - Thème de l'Application

- **app_theme.dart** : Configuration du thème Material

### 8. **utils/** - Utilitaires Globaux

#### **extensions/**
- **string_extensions.dart** : Extensions pour String
- **datetime_extensions.dart** : Extensions pour DateTime

**Exemple d'utilisation :**
```dart
final capitalized = 'hello world'.capitalizeWords(); // "Hello World"
final isEmail = 'user@example.com'.isValidEmail(); // true
final relative = DateTime.now().toRelativeString(); // "Il y a 2 heures"
```

#### **responsive_helper.dart**
Helper pour le design responsive

**Exemple :**
```dart
if (ResponsiveHelper.isMobile(context)) {
  // Layout mobile
} else if (ResponsiveHelper.isTablet(context)) {
  // Layout tablette
}
```

#### **enums/**
- **app_enums.dart** : Enums globaux

## 🔄 Flux de Données MVC

### 1. **User Action → Controller**
```dart
// Dans la View
ElevatedButton(
  onPressed: () {
    _authController.signIn(email: email, password: password);
  },
)
```

### 2. **Controller → Repository**
```dart
// Dans le Controller
Future<void> loadUser(String userId) async {
  final user = await _userRepository.getUserById(userId);
  currentUser.value = user;
}
```

### 3. **Repository → Service**
```dart
// Dans le Repository
Future<UserModel?> getUserById(String userId) async {
  final data = await _firestoreService.read(
    collection: 'users',
    docId: userId,
  );
  return UserModel.fromMap(data);
}
```

### 4. **Service → Firebase**
```dart
// Dans le Service
Future<Map<String, dynamic>?> read({required String collection, required String docId}) async {
  final doc = await _firestore.collection(collection).doc(docId).get();
  return doc.data();
}
```

### 5. **Data Change → View Update**
```dart
// Dans la View avec GetX Obx
Obx(() => Text(_authController.currentUser.value?.name ?? 'Guest'))
```

## 📱 Exemple Complet : Authentification

### 1. **View (LoginScreen)**
```dart
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    final success = await _authController.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    
    if (!success) {
      Get.snackbar('Erreur', _authController.errorMessage.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => _authController.isLoading.value
        ? LoadingWidget()
        : LoginForm(...),
      ),
    );
  }
}
```

### 2. **Controller (AuthController)**
```dart
class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();
  
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;

  Future<bool> signIn({required String email, required String password}) async {
    isLoading.value = true;
    try {
      final userCredential = await _authService.signIn(
        email: email,
        password: password,
      );
      
      if (userCredential?.user != null) {
        await loadUser(userCredential!.user!.uid);
        Get.offAllNamed(AppRoutes.home);
        return true;
      }
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadUser(String userId) async {
    final user = await _userRepository.getUserById(userId);
    currentUser.value = user;
  }
}
```

### 3. **Repository (UserRepository)**
```dart
class UserRepository {
  final FirestoreService _firestoreService = FirestoreService();
  
  Future<UserModel?> getUserById(String userId) async {
    final data = await _firestoreService.read(
      collection: 'users',
      docId: userId,
    );
    
    if (data != null) {
      return UserModel.fromMap({...data, 'id': userId});
    }
    return null;
  }
}
```

### 4. **Service (AuthService)**
```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }
}
```

## 🎯 Best Practices

### 1. **Séparation des Responsabilités**
- **Models** : Uniquement la structure de données
- **Repositories** : Uniquement l'accès aux données
- **Controllers** : Logique métier et état
- **Views** : Uniquement l'affichage

### 2. **Error Handling**
```dart
try {
  // Code
} on SpecificException catch (e) {
  // Gestion spécifique
} catch (e) {
  // Gestion générique
}
```

### 3. **State Management avec GetX**
- Utilisez `Rx`, `RxBool`, `RxString`, `RxList` pour les observables
- Utilisez `Obx()` ou `GetBuilder()` pour écouter les changements
- Évitez `setState()` dans les Screens

### 4. **Naming Conventions**
- **Models** : `UserModel`, `ProductModel`
- **Controllers** : `AuthController`, `ProductController`
- **Services** : `AuthService`, `FirestoreService`
- **Repositories** : `UserRepository`, `ProductRepository`
- **Screens** : `LoginScreen`, `HomeScreen`
- **Widgets** : `ProductCard`, `CustomButton`

### 5. **Code Reusability**
- Créez des composants réutilisables dans `components/`
- Utilisez des helpers pour les fonctions communes
- Centralisez les constantes

### 6. **Responsive Design**
```dart
// Utilisez ResponsiveHelper
if (ResponsiveHelper.isMobile(context)) {
  return MobileLayout();
} else {
  return DesktopLayout();
}
```

## 🔐 Firebase Integration

### Configuration
1. Installez FlutterFire CLI : `dart pub global activate flutterfire_cli`
2. Configurez Firebase : `flutterfire configure`
3. Le fichier `firebase_options.dart` sera généré automatiquement

### Services Firebase
- **AuthService** : Authentification utilisateur
- **FirestoreService** : Base de données Firestore
- **StorageService** : Stockage de fichiers
- **PushNotificationService** : Notifications push

## 📊 Structure Scalable

Cette architecture est conçue pour :
- ✅ Faciliter l'ajout de nouvelles fonctionnalités
- ✅ Maintenir le code propre et organisé
- ✅ Faciliter les tests unitaires
- ✅ Permettre le travail en équipe
- ✅ Évoluer avec l'application

## 🚀 Prochaines Étapes

1. **Configurer Firebase** : Exécuter `flutterfire configure`
2. **Installer les dépendances** : `flutter pub get`
3. **Lancer l'application** : `flutter run`
4. **Ajouter vos propres fonctionnalités** en suivant cette structure

## 📚 Ressources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [GetX Documentation](https://pub.dev/packages/get)
- [FlutterFire](https://firebase.flutter.dev/)


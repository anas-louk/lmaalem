import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/models/employee_model.dart';

/// Service d'authentification Firebase
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserRepository _userRepository = UserRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();

  /// Getter pour l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  /// Stream de l'utilisateur actuel
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// S'inscrire avec email et mot de passe
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Créer le profil utilisateur dans Firestore
      if (userCredential.user != null) {
        final userModel = UserModel(
          id: userCredential.user!.uid,
          nomComplet: name,
          localisation: '',
          type: 'Client', // Par défaut, on crée un Client
          tel: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userModel.toMap());

        // Mettre à jour le display name
        await userCredential.user!.updateDisplayName(name);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue: $e';
    }
  }

  /// Se connecter avec email et mot de passe
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
    } catch (e) {
      throw 'Une erreur est survenue: $e';
    }
  }


  /// Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue: $e';
    }
  }

  /// Changer le mot de passe
  Future<void> changePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      } else {
        throw 'Aucun utilisateur connecté';
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue: $e';
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<void> updateProfile({
    String? name,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        if (photoUrl != null) {
          await user.updatePhotoURL(photoUrl);
        }
      } else {
        throw 'Aucun utilisateur connecté';
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Une erreur est survenue: $e';
    }
  }

  /// Se connecter avec Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Démarrer le processus de connexion Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // L'utilisateur a annulé la connexion
        return null;
      }

      // Obtenir les détails d'authentification de la demande
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Créer un nouveau credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Une fois connecté, retourner le UserCredential
      final userCredential =
          await _auth.signInWithCredential(credential);

      // Créer ou mettre à jour l'utilisateur dans Firestore
      if (userCredential.user != null) {
        await _ensureUserExists(userCredential.user!);
      }

      return userCredential;
    } on PlatformException catch (e) {
      // Gérer les erreurs spécifiques de Google Sign-In
      String errorMessage = 'Erreur lors de la connexion Google';
      
      if (e.code == 'sign_in_failed') {
        final errorDetails = e.message ?? '';
        
        if (errorDetails.contains('ApiException: 10')) {
          errorMessage = '''Erreur de configuration Google Sign-In (ApiException: 10)

Cette erreur signifie que Google Sign-In n'est pas correctement configuré.

Étapes pour corriger :
1. Obtenir le SHA-1 de votre clé de signature :
   - Ouvrez un terminal dans le dossier android
   - Exécutez : keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

2. Ajouter le SHA-1 dans Firebase Console :
   - Allez dans Firebase Console > Project Settings > Your apps > Android app
   - Cliquez sur "Add fingerprint"
   - Ajoutez le SHA-1 obtenu

3. Télécharger le nouveau google-services.json et le remplacer dans android/app/

4. Redémarrer l'application

Pour plus d'aide, consultez : https://firebase.google.com/docs/auth/android/google-signin''';
        } else if (errorDetails.contains('ApiException: 7')) {
          errorMessage = '''Erreur Google Sign-In (ApiException: 7)

Cette erreur peut être causée par :
1. Google Play Services non disponible ou obsolète
2. Problème de connexion réseau
3. Configuration OAuth incorrecte dans Firebase Console

Solutions :
1. Vérifiez votre connexion Internet
2. Assurez-vous que Google Play Services est à jour sur votre appareil/émulateur
3. Vérifiez dans Firebase Console :
   - Project Settings > Authentication > Sign-in method
   - Activez "Google" et configurez le support email
   - Vérifiez que l'OAuth client ID est correctement configuré

4. Pour l'émulateur, assurez-vous d'utiliser un appareil avec Google Play Store
5. Redémarrez l'application après avoir vérifié la configuration

Si le problème persiste :
- Vérifiez que le SHA-1 est bien ajouté dans Firebase Console
- Vérifiez que google-services.json est à jour
- Essayez de nettoyer et reconstruire : flutter clean && flutter pub get''';
        } else {
          errorMessage = 'Erreur de connexion Google: ${e.message ?? e.code}\n\nDétails: $errorDetails';
        }
      } else {
        errorMessage = 'Erreur Google Sign-In: ${e.message ?? e.code}';
      }
      
      throw errorMessage;
    } catch (e) {
      throw 'Erreur lors de la connexion Google: $e';
    }
      
    
  }

  /// S'assurer que l'utilisateur existe dans Firestore (créer si nécessaire)
  Future<void> _ensureUserExists(User firebaseUser) async {
    try {
      // Vérifier si l'utilisateur existe déjà
      final existingUser = await _userRepository.getUserById(firebaseUser.uid);

      if (existingUser == null) {
        // Créer un nouvel utilisateur avec type "Client" par défaut
        final userModel = UserModel(
          id: firebaseUser.uid,
          nomComplet: firebaseUser.displayName ?? '',
          localisation: '',
          type: 'Client', // Par défaut, on crée un Client
          tel: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _userRepository.createUser(userModel);
      }
    } catch (e) {
      throw 'Erreur lors de la création de l\'utilisateur: $e';
    }
  }

  /// Passer de Client à Employee
  /// Si l'Employee existe déjà, met à jour les données et réactive
  Future<bool> switchToEmployee({
    required String userId,
    required String categorieId,
    required String ville,
    required String competence,
    String? image,
    String? bio,
    String? gallery,
  }) async {
    try {
      // Récupérer l'utilisateur
      final user = await _userRepository.getUserById(userId);
      if (user == null) {
        throw 'Utilisateur non trouvé';
      }

      // Vérifier si l'Employee existe déjà
      final existingEmployee =
          await _employeeRepository.getEmployeeById(userId);

      if (existingEmployee != null) {
        // L'employé existe déjà, mettre à jour les données avec les nouvelles valeurs
        final updatedEmployee = existingEmployee.copyWith(
          categorieId: categorieId,
          ville: ville,
          competence: competence,
          disponibilite: true, // Réactiver la disponibilité
          image: image ?? existingEmployee.image,
          bio: bio ?? existingEmployee.bio,
          gallery: gallery ?? existingEmployee.gallery,
          updatedAt: DateTime.now(),
        );

        // Mettre à jour le document Employee
        await _employeeRepository.updateEmployee(updatedEmployee);

        // Mettre à jour le type de l'utilisateur
        await _userRepository.updateUser(
          user.copyWith(
            type: 'Employee',
            updatedAt: DateTime.now(),
          ),
        );

        return true;
      }

      // Créer un nouvel Employee
      final employeeModel = EmployeeModel.fromUserModel(
        user,
        image: image,
        categorieId: categorieId,
        ville: ville,
        disponibilite: true,
        competence: competence,
        bio: bio,
        gallery: gallery,
      );

      // Créer le document Employee
      await _employeeRepository.createEmployee(employeeModel);

      // Mettre à jour le type de l'utilisateur
      await _userRepository.updateUser(
        user.copyWith(
          type: 'Employee',
          updatedAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e) {
      throw 'Erreur lors du passage à Employee: $e';
    }
  }

  /// Vérifier si l'utilisateur est Employee
  Future<bool> isEmployee(String userId) async {
    try {
      final user = await _userRepository.getUserById(userId);
      return user?.type.toLowerCase() == 'employee';
    } catch (e) {
      return false;
    }
  }

  /// Passer de Employee à Client
  /// Note: L'Employee document est conservé pour permettre un retour facile
  Future<bool> switchToClient({
    required String userId,
  }) async {
    try {
      // Récupérer l'utilisateur
      final user = await _userRepository.getUserById(userId);
      if (user == null) {
        throw 'Utilisateur non trouvé';
      }

      // Mettre à jour le type de l'utilisateur seulement
      // L'Employee document est conservé pour permettre un retour facile
      await _userRepository.updateUser(
        user.copyWith(
          type: 'Client',
          updatedAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e) {
      throw 'Erreur lors du passage à Client: $e';
    }
  }

  /// Se déconnecter (de Google et Firebase)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw 'Erreur lors de la déconnexion: $e';
    }
  }

  /// Gérer les exceptions Firebase Auth
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'user-not-found':
        return 'Aucun utilisateur trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'invalid-email':
        return 'Email invalide';
      case 'user-disabled':
        return 'Cet utilisateur a été désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';
      case 'operation-not-allowed':
        return 'Opération non autorisée';
      default:
        return 'Erreur d\'authentification: ${e.message}';
    }
  }
}

